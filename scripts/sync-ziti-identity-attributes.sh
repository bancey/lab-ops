#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/sync-ziti-identity-attributes.sh [--dry-run]

Makes the Entra group role attributes of every OIDC-enrolled OpenZiti identity match the user's
current membership of the lab-* security groups.

The ext-jwt-signer only applies its /groups claim when an identity is first enrolled, so without
this a group change never reaches an existing identity, and a removal leaves stale access.

  - Entra: reads the lab-* security groups and their transitive user members from Microsoft Graph
    (guest users included). Aborts before changing anything if Graph errors or returns no groups.
  - Ziti: matches identities on externalId (= the user's oid, the signer's claimsProperty).
    Identities without an externalId (router tunnelers, JWT identities) are skipped, and so are
    admin identities (console admins, matched on a different claim), which must never get Dial
    attributes.
  - Only attributes that are lab-* group object IDs are added or removed. Every other attribute
    (home-routers, anything granted by hand) is kept. An identity is only updated when its set of
    group attributes differs, so a run with nothing to do changes nothing.

Run by terraform/components/openziti on every apply and by ziti-sync-pipeline.yaml every 15
minutes. See docs/openziti.md.

Options:
  --dry-run   Print the changes that would be made, but change nothing.

Environment:
  ZITI_ADMIN_USERNAME    Required. Controller admin username (Key Vault OpenZiti-Admin-Username).
  ZITI_ADMIN_PASSWORD    Required. Controller admin password (Key Vault OpenZiti-Admin-Password).
  ZITI_CONTROLLER_CA     Required. PEM of the controller's root CA (Key Vault OpenZiti-Controller-CA).
  ZITI_CONTROLLER_URL    Optional. Defaults to https://ziti.heimelska.co.uk:1280.
  ENTRA_GROUP_PREFIX     Optional. Defaults to lab-.

Azure: uses the current az session if there is one. Otherwise it logs in as the service principal
in ARM_CLIENT_ID / ARM_TENANT_ID with ARM_CLIENT_SECRET (or ARM_OIDC_TOKEN), into a private config
directory that is removed on exit.

Requires az, jq and the ziti CLI.
USAGE
}

DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

CONTROLLER_URL="${ZITI_CONTROLLER_URL:-https://ziti.heimelska.co.uk:1280}"
GROUP_PREFIX="${ENTRA_GROUP_PREFIX:-lab-}"
GRAPH="https://graph.microsoft.com/v1.0"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

for cmd in az jq ziti; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required but not installed."
done
for var in ZITI_ADMIN_USERNAME ZITI_ADMIN_PASSWORD ZITI_CONTROLLER_CA; do
  [[ -n "${!var:-}" ]] || die "$var is required."
done

WORK_DIR="$(mktemp -d)"
chmod 700 "$WORK_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

# Keep the ziti CLI session out of the caller's ~/.config/ziti, and gone when the script exits.
export ZITI_CONFIG_DIR="$WORK_DIR/ziti"

ensure_az_login() {
  if az account show --only-show-errors >/dev/null 2>&1; then
    return 0
  fi
  [[ -n "${ARM_CLIENT_ID:-}" && -n "${ARM_TENANT_ID:-}" ]] ||
    die "az is not logged in and ARM_CLIENT_ID / ARM_TENANT_ID are not set."

  # A private config dir, so this login neither replaces nor outlives the caller's az state.
  export AZURE_CONFIG_DIR="$WORK_DIR/azure"
  local args=(login --service-principal --username "$ARM_CLIENT_ID" --tenant "$ARM_TENANT_ID"
    --allow-no-subscriptions --only-show-errors --output none)
  if [[ -n "${ARM_CLIENT_SECRET:-}" ]]; then
    az "${args[@]}" --password "$ARM_CLIENT_SECRET" || die "az login with ARM_CLIENT_SECRET failed."
  elif [[ -n "${ARM_OIDC_TOKEN:-}" ]]; then
    az "${args[@]}" --federated-token "$ARM_OIDC_TOKEN" || die "az login with ARM_OIDC_TOKEN failed."
  else
    die "az is not logged in and neither ARM_CLIENT_SECRET nor ARM_OIDC_TOKEN is set."
  fi
}

# GETs a Graph collection, following @odata.nextLink, and prints all of its items as one JSON array.
graph_list() {
  local url="$1" page all='[]'
  while [[ -n "$url" ]]; do
    page="$(az rest --method GET --url "$url" --only-show-errors)" || return 1
    all="$(jq -c --argjson acc "$all" '$acc + .value' <<<"$page")" || return 1
    url="$(jq -r '."@odata.nextLink" // empty' <<<"$page")" || return 1
  done
  printf '%s\n' "$all"
}

# --- Entra: lab-* groups and their transitive user members ------------------------------------

ensure_az_login

groups="$(graph_list "$GRAPH/groups?\$filter=startswith(displayName,'$GROUP_PREFIX')&\$select=id,displayName,securityEnabled&\$top=999")" ||
  die "Reading the $GROUP_PREFIX* groups from Graph failed. Nothing was changed."
# Graph's startswith is case-insensitive; match the Terraform component (security groups only).
groups="$(jq -c --arg p "$GROUP_PREFIX" \
  '[.[] | select(.securityEnabled == true and (.displayName | ascii_downcase | startswith($p | ascii_downcase))) | {id, name: .displayName}]' \
  <<<"$groups")"

group_count="$(jq 'length' <<<"$groups")"
[[ "$group_count" -gt 0 ]] ||
  die "Graph returned no $GROUP_PREFIX* security groups. Refusing to continue, as that would strip every identity's group attributes. Nothing was changed."

membership='[]'
while IFS=$'\t' read -r gid gname; do
  members="$(graph_list "$GRAPH/groups/$gid/transitiveMembers?\$select=id&\$top=999")" ||
    die "Reading the members of $gname from Graph failed. Nothing was changed."
  # Users only, guests included. Nested groups are already expanded by transitiveMembers.
  membership="$(jq -c --argjson m "$members" --arg id "$gid" --arg name "$gname" \
    '. + [{id: $id, name: $name, members: [$m[] | select(."@odata.type" == "#microsoft.graph.user") | .id]}]' \
    <<<"$membership")"
done < <(jq -r '.[] | [.id, .name] | @tsv' <<<"$groups")

echo "Read $group_count $GROUP_PREFIX* groups from Entra: $(jq -r '[.[] | "\(.name) (\(.members | length))"] | join(", ")' <<<"$membership")"

# --- Ziti: identities ---------------------------------------------------------------------------

printf '%s\n' "$ZITI_CONTROLLER_CA" >"$WORK_DIR/ca.pem"
# The CLI has no way to read the password from the environment. stdout is discarded because it
# prints the session token; stderr is kept for the error.
if ! ziti edge login "$CONTROLLER_URL" --ca "$WORK_DIR/ca.pem" \
  -u "$ZITI_ADMIN_USERNAME" -p "$ZITI_ADMIN_PASSWORD" >/dev/null 2>"$WORK_DIR/login.err"; then
  grep -vi 'token' "$WORK_DIR/login.err" >&2 || true
  die "ziti edge login to $CONTROLLER_URL failed. Nothing was changed."
fi

identities="$(ziti edge list identities 'true limit none' -j)" ||
  die "Listing identities failed. Nothing was changed."
jq -e '(.data | type) == "array" and (.meta.pagination.totalCount == (.data | length))' <<<"$identities" >/dev/null ||
  die "The identity list was incomplete or not in the expected shape. Nothing was changed."

# --- Diff ---------------------------------------------------------------------------------------

# One object per identity whose group attributes need to change:
#   {id, name, attributes: <full new list>, added: [group names], removed: [group names]}
# Attributes that aren't lab-* group IDs are kept as they are, in their original order.
changes="$(jq -c --argjson groups "$membership" '
  ($groups | map({key: .id, value: .name}) | from_entries) as $names
  | [ .data[]
      | select((.externalId // "") != "" and .isAdmin != true)
      | .externalId as $oid
      | (.roleAttributes // []) as $current
      | ([$current[] | select($names[.] != null)] | unique) as $have
      | ([$groups[] | select(any(.members[]; . == $oid)) | .id] | unique) as $want
      | select($have != $want)
      | {
          id,
          name,
          attributes: ([$current[] | select($names[.] == null)] + $want),
          added: [($want - $have)[] | $names[.]],
          removed: [($have - $want)[] | $names[.]]
        }
    ]' <<<"$identities")"

checked="$(jq '[.data[] | select((.externalId // "") != "" and .isAdmin != true)] | length' <<<"$identities")"
skipped="$(jq '[.data[] | select((.externalId // "") == "" or .isAdmin == true)] | length' <<<"$identities")"
change_count="$(jq 'length' <<<"$changes")"

$DRY_RUN && echo "Dry run: no identities will be changed."

failed=0
while IFS= read -r change; do
  name="$(jq -r '.name' <<<"$change")"
  echo "$name: added [$(jq -r '.added | join(", ")' <<<"$change")] removed [$(jq -r '.removed | join(", ")' <<<"$change")]"

  # The CLI parses --role-attributes as CSV, so an attribute containing a comma or quote would be
  # split or mangled. None should exist; skip rather than corrupt it.
  if jq -e 'any(.attributes[]; test("[,\"]"))' <<<"$change" >/dev/null; then
    echo "  skipped: $name has an attribute containing a comma or quote, update it by hand." >&2
    failed=1
    continue
  fi

  $DRY_RUN && continue
  if ! ziti edge update identity \
    --role-attributes "$(jq -r '.attributes | join(",")' <<<"$change")" \
    -- "$(jq -r '.id' <<<"$change")" >/dev/null; then
    echo "  failed to update $name" >&2
    failed=1
  fi
done < <(jq -c '.[]' <<<"$changes")

echo "Checked $checked OIDC identities ($skipped without an externalId or admin skipped), $change_count to change$($DRY_RUN && echo ' (dry run)')."
exit "$failed"
