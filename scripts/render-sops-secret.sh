#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: SECRET_SPEC='<json>' scripts/render-sops-secret.sh <target-path>

Renders a Kubernetes Secret from a JSON spec and writes it SOPS-encrypted to <target-path>.

Called by terraform/components/entra, which already holds every value: the client ID and client
secret come straight from the azuread resources, and the oauth2-proxy cookie secret from a
random_bytes resource. Nothing is read back from Key Vault, and nothing is decrypted - Terraform
decides when a file needs rewriting, so there is no need to compare against the current contents.

SECRET_SPEC is JSON of the form:

  {"name": "grafana-oidc", "namespace": "monitoring",
   "stringData": {"client-id": "...", "client-secret": "..."}}

It is passed through the environment rather than argv so the values do not appear in the process
list, and is written to a 0600 temp file before use - the same approach as
terraform/components/virtual-machines/ansible.sh.tpl.

Encryption needs only the age *public* key from .sops.yaml, so this never requires the private
key to be present.

Environment:
  SECRET_SPEC       Required. The JSON described above.
  SOPS_CONFIG_PATH  Optional. Defaults to the repo's .sops.yaml.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

TARGET="${1:-}"
[[ -n "$TARGET" ]] || { echo "A target path is required." >&2; usage >&2; exit 1; }
[[ -n "${SECRET_SPEC:-}" ]] || { echo "SECRET_SPEC is required." >&2; exit 1; }

for tool in sops python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Required tool not found on PATH: $tool" >&2; exit 1; }
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOPS_CONFIG_PATH="${SOPS_CONFIG_PATH:-$REPO_ROOT/.sops.yaml}"

TMP="$(mktemp -t sops-secret-XXXXXX.yaml)"
trap 'rm -f "$TMP"' EXIT
chmod 600 "$TMP"

python3 - "$TMP" <<'PY'
import json, os, sys, yaml

spec = json.loads(os.environ["SECRET_SPEC"])
doc = {
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {"name": spec["name"], "namespace": spec["namespace"]},
    "type": "Opaque",
    "stringData": spec["stringData"],
}
with open(sys.argv[1], "w") as handle:
    handle.write("---\n")
    yaml.safe_dump(doc, handle, default_flow_style=False, sort_keys=True)
PY

mkdir -p "$(dirname "$TARGET")"

# sops selects its creation rule by walking up from the file being encrypted, so encrypting the
# temp file directly fails with "no matching creation rules found". --config points it at the
# repo's rules and --filename-override makes it match the rule for the real target path, without
# ever writing plaintext inside the repo.
sops --config "$SOPS_CONFIG_PATH" --filename-override "$TARGET" --encrypt "$TMP" >"$TARGET"

echo "Rendered $TARGET" >&2
