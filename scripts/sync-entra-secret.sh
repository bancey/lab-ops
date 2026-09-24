#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/sync-entra-secret.sh --app <name> --target <path> [options]

Builds a SOPS-encrypted Kubernetes Secret from an Entra ID app registration's credentials.

terraform/components/entra creates the app registration and writes its client ID and client
secret to Key Vault as the pair Entra-<prefix>-Client-ID / Entra-<prefix>-Client-Secret.
Terraform cannot write into a SOPS file, so this script bridges the gap for the Kubernetes
consumers, which read their credentials from *.sops.yaml committed to git.

Re-run this after any client secret rotation and commit the result, otherwise the cluster
keeps using the old secret until it expires. See docs/sso-operations.md.

Required:
  --app <name>            Application key from terraform/environments/<env>/entra.yaml,
                           e.g. lab-oauth2-proxy.
  --target <path>         Path of the *.sops.yaml file to write.

Options:
  --kv-prefix <prefix>    Override the Key Vault name prefix. Default: key_vault_prefix for
                           <app> in entra.yaml, falling back to <app> with "lab-" removed.
  --env <env>             Environment whose entra.yaml to resolve the prefix from.
                           Default: prod
  --entra-yaml <path>     Explicit entra.yaml to read instead of
                           terraform/environments/<env>/entra.yaml
  --name <name>           metadata.name of the Secret. Default: <app> with "lab-" removed.
  --namespace <ns>        metadata.namespace of the Secret. Default: same as --name.
  --id-key <key>          stringData key for the client ID. Default: client-id
  --secret-key <key>      stringData key for the client secret. Default: client-secret
  --extra <key>=<value>   Additional literal stringData entry. Repeatable.
  --extra-template <key>=<template>
                          Like --extra, but {client_id} and {client_secret} in <template> are
                           substituted. For apps that want the credentials embedded in a larger
                           blob, e.g. Paperless-ngx's PAPERLESS_SOCIALACCOUNT_PROVIDERS JSON.
                           Repeatable.
  --extra-random <key>    Additional stringData entry set to a fresh 32-byte URL-safe random
                           value, e.g. an oauth2-proxy cookie-secret. Preserved on re-runs if
                           the target already exists and can be decrypted. Repeatable.
  --vault-name <name>     Key Vault to read from. Default: bancey-vault
  --subscription <id>     az subscription to select first.
  --dry-run               Print the plaintext manifest instead of writing and encrypting it.
  --force                 Re-encrypt even when the target already holds the same values. sops
                           generates a fresh data key and IVs every run, so the ciphertext always
                           differs - without this the script leaves an unchanged target alone so
                           automation does not produce a commit on every pipeline run.
  --help                  Show this help.

Examples:
  scripts/sync-entra-secret.sh --app lab-oauth2-proxy \
    --target kubernetes/apps/tiny/oauth2-proxy-secret.sops.yaml \
    --name oauth2-proxy-entra --namespace oauth2-proxy --extra-random cookie-secret

  scripts/sync-entra-secret.sh --app lab-grafana \
    --target kubernetes/apps/tiny/grafana-oidc-secret.sops.yaml \
    --name grafana-oidc --namespace monitoring

Prerequisites:
  - Logged in with `az login` and able to read Key Vault "bancey-vault"
  - sops on PATH, and the Age private key available for --extra-random to be preserved
    across re-runs (encryption itself only needs the public key from .sops.yaml)
EOF
}

APP=""
TARGET=""
KV_PREFIX=""
ENVIRONMENT="prod"
ENTRA_YAML=""
SECRET_NAME=""
NAMESPACE=""
ID_KEY="client-id"
SECRET_KEY="client-secret"
VAULT_NAME="bancey-vault"
SUBSCRIPTION=""
DRY_RUN=false
FORCE=false
declare -a EXTRAS=()
declare -a EXTRA_TEMPLATES=()
declare -a EXTRA_RANDOM=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --kv-prefix) KV_PREFIX="$2"; shift 2 ;;
    --env) ENVIRONMENT="$2"; shift 2 ;;
    --entra-yaml) ENTRA_YAML="$2"; shift 2 ;;
    --name) SECRET_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --id-key) ID_KEY="$2"; shift 2 ;;
    --secret-key) SECRET_KEY="$2"; shift 2 ;;
    --extra) EXTRAS+=("$2"); shift 2 ;;
    --extra-template) EXTRA_TEMPLATES+=("$2"); shift 2 ;;
    --extra-random) EXTRA_RANDOM+=("$2"); shift 2 ;;
    --vault-name) VAULT_NAME="$2"; shift 2 ;;
    --subscription) SUBSCRIPTION="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --force) FORCE=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -n "$APP" ]] || { echo "--app is required" >&2; exit 1; }
[[ -n "$TARGET" ]] || { echo "--target is required" >&2; exit 1; }

for tool in az sops python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Required tool not found on PATH: $tool" >&2; exit 1; }
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRA_YAML="${ENTRA_YAML:-$REPO_ROOT/terraform/environments/$ENVIRONMENT/entra.yaml}"
# Overridable so the script can be exercised against a throwaway keypair in tests; in normal use
# this is the repo's own .sops.yaml.
SOPS_CONFIG_PATH="${SOPS_CONFIG_PATH:-$REPO_ROOT/.sops.yaml}"

# Resolve the Key Vault prefix from entra.yaml so it always matches what the entra component
# actually wrote, rather than re-deriving it and hoping the two agree.
if [[ -z "$KV_PREFIX" ]]; then
  if [[ -f "$ENTRA_YAML" ]]; then
    KV_PREFIX="$(APP="$APP" python3 -c "
import os, sys, yaml
app = os.environ['APP']
apps = (yaml.safe_load(open(sys.argv[1])) or {}).get('applications') or {}
if app not in apps:
    sys.stderr.write(f\"Application '{app}' is not defined in {sys.argv[1]}\n\")
    sys.exit(1)
print(apps[app].get('key_vault_prefix') or app.removeprefix('lab-'))
" "$ENTRA_YAML")"
  else
    echo "No entra.yaml at $ENTRA_YAML; falling back to a derived prefix." >&2
    KV_PREFIX="${APP#lab-}"
  fi
fi
SECRET_NAME="${SECRET_NAME:-${APP#lab-}}"
NAMESPACE="${NAMESPACE:-$SECRET_NAME}"

if [[ -n "$SUBSCRIPTION" ]]; then
  az account set --subscription "$SUBSCRIPTION"
fi

kv_get() {
  local name="$1"
  if ! az keyvault secret show --vault-name "$VAULT_NAME" --name "$name" --query value -o tsv 2>/dev/null; then
    echo "Could not read Key Vault secret '$name' from '$VAULT_NAME'." >&2
    echo "Has the entra component been applied? Check: terraform output key_vault_secret_names" >&2
    return 1
  fi
}

echo "Reading Entra-${KV_PREFIX}-Client-{ID,Secret} from ${VAULT_NAME}..." >&2
CLIENT_ID="$(kv_get "Entra-${KV_PREFIX}-Client-ID")"
CLIENT_SECRET="$(kv_get "Entra-${KV_PREFIX}-Client-Secret")"

# Reuse any existing random values so re-running after a rotation does not invalidate every
# session cookie, and does not break the shared cookie secret across the tiny/wanda clusters.
declare -A RANDOM_VALUES=()
for key in "${EXTRA_RANDOM[@]+"${EXTRA_RANDOM[@]}"}"; do
  existing=""
  if [[ -f "$TARGET" ]]; then
    existing="$(sops -d "$TARGET" 2>/dev/null | python3 -c "
import sys, yaml
try:
    doc = yaml.safe_load(sys.stdin) or {}
    print((doc.get('stringData') or {}).get('$key', ''))
except Exception:
    print('')
" || true)"
  fi
  if [[ -n "$existing" ]]; then
    echo "Preserving existing value for '$key'." >&2
    RANDOM_VALUES["$key"]="$existing"
  else
    echo "Generating a new random value for '$key'." >&2
    RANDOM_VALUES["$key"]="$(python3 -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())')"
  fi
done

for entry in "${EXTRA_TEMPLATES[@]+"${EXTRA_TEMPLATES[@]}"}"; do
  key="${entry%%=*}"
  tmpl="${entry#*=}"
  tmpl="${tmpl//\{client_id\}/$CLIENT_ID}"
  tmpl="${tmpl//\{client_secret\}/$CLIENT_SECRET}"
  EXTRAS+=("${key}=${tmpl}")
done

render() {
  python3 - "$SECRET_NAME" "$NAMESPACE" <<'PY'
import os, sys, yaml

name, namespace = sys.argv[1], sys.argv[2]
string_data = {
    os.environ["ID_KEY"]: os.environ["CLIENT_ID"],
    os.environ["SECRET_KEY"]: os.environ["CLIENT_SECRET"],
}
for entry in filter(None, os.environ.get("EXTRAS_JOINED", "").split("\n")):
    key, _, value = entry.partition("=")
    string_data[key] = value
for entry in filter(None, os.environ.get("RANDOMS_JOINED", "").split("\n")):
    key, _, value = entry.partition("=")
    string_data[key] = value

doc = {
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {"name": name, "namespace": namespace},
    "type": "Opaque",
    "stringData": string_data,
}
sys.stdout.write("---\n")
yaml.safe_dump(doc, sys.stdout, default_flow_style=False, sort_keys=False)
PY
}

EXTRAS_JOINED=""
for e in "${EXTRAS[@]+"${EXTRAS[@]}"}"; do EXTRAS_JOINED+="${e}"$'\n'; done
RANDOMS_JOINED=""
for k in "${!RANDOM_VALUES[@]}"; do RANDOMS_JOINED+="${k}=${RANDOM_VALUES[$k]}"$'\n'; done
export ID_KEY SECRET_KEY CLIENT_ID CLIENT_SECRET EXTRAS_JOINED RANDOMS_JOINED

if [[ "$DRY_RUN" == true ]]; then
  render
  exit 0
fi

TMP="$(mktemp -t entra-secret-XXXXXX.yaml)"
trap 'rm -f "$TMP"' EXIT
chmod 600 "$TMP"
render >"$TMP"

# Skip the write when nothing has actually changed. sops is non-deterministic - a fresh data key
# and IVs each run mean identical plaintext still yields a different file - so comparing the
# decrypted contents is the only way to tell. Without this, automated runs commit every time.
if [[ "$FORCE" != true && -f "$TARGET" ]]; then
  CURRENT="$(mktemp -t entra-current-XXXXXX.yaml)"
  trap 'rm -f "$TMP" "$CURRENT"' EXIT
  chmod 600 "$CURRENT"
  if sops -d "$TARGET" >"$CURRENT" 2>/dev/null; then
    if python3 -c '
import sys, yaml
def key(path):
    d = yaml.safe_load(open(path)) or {}
    m = d.get("metadata") or {}
    return (d.get("stringData"), m.get("name"), m.get("namespace"))
sys.exit(0 if key(sys.argv[1]) == key(sys.argv[2]) else 1)
' "$CURRENT" "$TMP"; then
      echo "$TARGET is already up to date - leaving it alone (use --force to re-encrypt)." >&2
      exit 0
    fi
  else
    echo "Could not decrypt $TARGET (no Age private key?); rewriting it unconditionally." >&2
  fi
fi

mkdir -p "$(dirname "$TARGET")"

# sops picks its creation rule by walking up from the file it is encrypting, so encrypting the
# temp file directly fails with "no matching creation rules found": /tmp has no .sops.yaml above
# it, and the path would not match the `.*.sops.yaml` path_regex anyway. --config points sops at
# the repo's rules and --filename-override makes it match the rule for the real target path,
# without ever writing plaintext inside the repo.
sops --config "$SOPS_CONFIG_PATH" --filename-override "$TARGET" --encrypt "$TMP" >"$TARGET"

echo "Wrote $TARGET" >&2
echo "Remember to add it to the overlay kustomization.yaml and commit it." >&2
