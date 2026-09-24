#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/set-entra-group-ids.sh [--dry-run] [--vault-name <name>]

Replaces the REPLACE_WITH_LAB_*_GROUP_ID placeholders left in the repo with the real Entra
object IDs, once terraform/components/entra has created the groups.

The Entra groups claim carries object IDs rather than names, so those GUIDs end up in a handful
of places that cannot look them up at runtime:

  kubernetes/app-dependencies/config/traefik-forward-auth.yaml   oauth2-proxy allowed_groups
  ansible/templates/cluster-admins.yaml                          Kubernetes RBAC subjects

Both fail closed while the placeholders are in place: oauth2-proxy returns 403 for an
unknown group, and an RBAC subject that resolves to nothing matches nobody.

Options:
  --dry-run            Show what would change without writing.
  --vault-name <name>  Unused today; reserved for reading IDs from Key Vault.
  --help               Show this help.

Prerequisites:
  - Logged in with `az login` against the lab tenant, able to read groups (Group.Read.All or
    membership in the directory).
USAGE
}

DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --vault-name) shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

command -v az >/dev/null 2>&1 || { echo "az not found on PATH" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

declare -A PLACEHOLDERS=(
  [lab-users]=REPLACE_WITH_LAB_USERS_GROUP_ID
  [lab-media]=REPLACE_WITH_LAB_MEDIA_GROUP_ID
  [lab-infra]=REPLACE_WITH_LAB_INFRA_GROUP_ID
)

FILES=(
  "$REPO_ROOT/kubernetes/app-dependencies/config/traefik-forward-auth.yaml"
  "$REPO_ROOT/ansible/templates/cluster-admins.yaml"
)

changed=0
for group in "${!PLACEHOLDERS[@]}"; do
  placeholder="${PLACEHOLDERS[$group]}"
  id="$(az ad group list --filter "displayName eq '$group'" --query "[0].id" -o tsv 2>/dev/null || true)"
  if [[ -z "$id" || "$id" == "None" ]]; then
    echo "!! Entra group '$group' not found - has the entra component been applied?" >&2
    exit 1
  fi
  echo "$group -> $id"
  for f in "${FILES[@]}"; do
    [[ -f "$f" ]] || continue
    if grep -q "$placeholder" "$f"; then
      if [[ "$DRY_RUN" == true ]]; then
        echo "   would update $(basename "$f")"
      else
        sed -i "s/$placeholder/$id/g" "$f"
        echo "   updated $(basename "$f")"
      fi
      changed=1
    fi
  done
done

if [[ "$changed" -eq 0 ]]; then
  echo "No placeholders left - nothing to do."
elif [[ "$DRY_RUN" != true ]]; then
  echo
  echo "Review with 'git diff' and commit. Flux will roll the change out on merge to main."
fi
