#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/run-ansible-playbook.sh <playbook> [options] [-- <extra ansible-playbook args>]

Runs an Ansible playbook locally the same way the "infra-pipeline.yaml" Azure DevOps
pipeline does: secrets are pulled from Azure Key Vault into files that the playbooks
read via lookup('ansible.builtin.file', ...), an SSH private key is fetched and loaded
into ssh-agent, and everything is cleaned up again once the run finishes.

<playbook>  Playbook file, e.g. nut-server.yaml (the .yaml extension is optional)

Options:
  --vault-name <name>          Key Vault to read from (default: bancey-vault)
  --subscription <name|id>     az subscription to select before running
  --private-key-secret <name>  Key Vault secret holding the SSH private key
                                (default: Packer-Private-Key)
  --secret <kv-name>[:<local-name>]
                                Extra secret to download. Repeatable. Use this for
                                playbooks that aren't wired into infra-pipeline.yaml's
                                ansible_deployments list (e.g. mariadb.yaml,
                                postgresql.yaml). If <local-name> is omitted it
                                defaults to <kv-name>.
  --no-auto-secrets            Don't look up secrets from infra-pipeline.yaml, only
                                use --secret entries
  --requirements <path>        Galaxy requirements file (default: ansible/requirements.yaml
                                if it exists)
  --skip-galaxy                Don't run ansible-galaxy install
  --check                      Run ansible-playbook in --check mode
  --tags <csv>                 Only run plays/tasks tagged with these
  --limit <pattern>            Limit to matching hosts
  --keep-secrets                Don't delete downloaded secret files / key on exit (debug only)
  --help                       Show this help

Examples:
  scripts/run-ansible-playbook.sh nut-server.yaml
  scripts/run-ansible-playbook.sh scansnap.yaml --check
  scripts/run-ansible-playbook.sh mariadb.yaml \
    --secret mariadb-root-password:mariadb_root_password \
    --secret mariadb-galera-password:mariadb_galera_password

Prerequisites:
  - Logged in with `az login` and able to reach Key Vault "bancey-vault"
  - Network access to the target hosts (Twingate/VPN), same as the pipeline's
    twingate-connect step - this script does not establish that connection for you
EOF
}

repo_root="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
ansible_dir="$repo_root/ansible"
pipeline_file="$repo_root/infra-pipeline.yaml"

vault_name="bancey-vault"
subscription=""
private_key_secret="Packer-Private-Key"
requirements_file=""
skip_galaxy="false"
auto_secrets="true"
check_mode="false"
tags=""
limit=""
keep_secrets="false"
declare -a manual_secrets=()
extra_ansible_args=()

playbook_arg=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault-name)
      vault_name="$2"; shift 2 ;;
    --subscription)
      subscription="$2"; shift 2 ;;
    --private-key-secret)
      private_key_secret="$2"; shift 2 ;;
    --secret)
      manual_secrets+=("$2"); shift 2 ;;
    --no-auto-secrets)
      auto_secrets="false"; shift ;;
    --requirements)
      requirements_file="$2"; shift 2 ;;
    --skip-galaxy)
      skip_galaxy="true"; shift ;;
    --check)
      check_mode="true"; shift ;;
    --tags)
      tags="$2"; shift 2 ;;
    --limit)
      limit="$2"; shift 2 ;;
    --keep-secrets)
      keep_secrets="true"; shift ;;
    --help)
      usage; exit 0 ;;
    --)
      shift
      extra_ansible_args+=("$@")
      break
      ;;
    *)
      if [[ -z "$playbook_arg" ]]; then
        playbook_arg="$1"; shift
      else
        echo "Unknown argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$playbook_arg" ]]; then
  echo "Error: playbook argument is required" >&2
  usage
  exit 1
fi

playbook="$playbook_arg"
if [[ "$playbook" != *.yaml && "$playbook" != *.yml ]]; then
  playbook="${playbook}.yaml"
fi
if [[ ! -f "$ansible_dir/$playbook" ]]; then
  echo "Error: $ansible_dir/$playbook not found" >&2
  exit 1
fi

for bin in az ansible-playbook ssh-agent ssh-add python3; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Error: required tool '$bin' not found on PATH" >&2
    exit 1
  fi
done

if ! az account show >/dev/null 2>&1; then
  echo "Error: not logged in to Azure CLI. Run 'az login' first." >&2
  exit 1
fi

if [[ -n "$subscription" ]]; then
  echo "Setting az subscription to $subscription"
  az account set --subscription "$subscription"
fi
echo "Using az subscription: $(az account show --query name -o tsv)"

if [[ -z "$requirements_file" && -f "$ansible_dir/requirements.yaml" ]]; then
  requirements_file="requirements.yaml"
fi

declare -a kv_secrets=()
pipeline_requirements=""
if [[ "$auto_secrets" == "true" && -f "$pipeline_file" ]]; then
  mapfile -t pipeline_lookup < <(python3 - "$pipeline_file" "$playbook" <<'PY'
import sys
import yaml

path, target = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = yaml.safe_load(f)

for param in data.get("parameters", []) or []:
    if param.get("name") != "ansible_deployments":
        continue
    for deployment in param.get("default", []) or []:
        if deployment.get("playbook") == target:
            print(deployment.get("requirementsFile") or "")
            for secret in deployment.get("secrets", []) or []:
                print(secret)
            break
PY
) || true

  if [[ "${#pipeline_lookup[@]}" -gt 0 ]]; then
    pipeline_requirements="${pipeline_lookup[0]}"
    kv_secrets=("${pipeline_lookup[@]:1}")
    echo "Found ${#kv_secrets[@]} secret(s) for $playbook in infra-pipeline.yaml"
  else
    echo "Note: $playbook is not wired into infra-pipeline.yaml's ansible_deployments list."
    expected="$(grep -oP "lookup\('ansible\.builtin\.file',\s*'\K[^']+" "$ansible_dir/$playbook" | sort -u)"
    if [[ -n "$expected" ]]; then
      echo "It expects these local secret files (pass via --secret if not already using --secret/manual files):"
      echo "$expected" | sed 's/^/  - /'
    fi
  fi

  if [[ -z "$requirements_file" && -n "$pipeline_requirements" ]]; then
    requirements_file="$pipeline_requirements"
  fi
fi

declare -a downloaded_files=("id_rsa")
cleanup() {
  if [[ "$keep_secrets" == "true" ]]; then
    return
  fi
  for f in "${downloaded_files[@]}"; do
    rm -f "$ansible_dir/$f"
  done
  if [[ -n "${SSH_AGENT_PID:-}" ]]; then
    ssh-agent -k >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

download_secret() {
  local kv_name="$1" local_name="$2"
  echo "Downloading secret '$kv_name' -> ansible/$local_name"
  az keyvault secret download \
    --name "$kv_name" \
    --vault-name "$vault_name" \
    --file "$ansible_dir/$local_name" \
    --only-show-errors
  downloaded_files+=("$local_name")
}

for kv_name in "${kv_secrets[@]:-}"; do
  [[ -z "$kv_name" ]] && continue
  download_secret "$kv_name" "$kv_name"
done

for entry in "${manual_secrets[@]:-}"; do
  [[ -z "$entry" ]] && continue
  kv_name="${entry%%:*}"
  local_name="${entry#*:}"
  [[ "$local_name" == "$entry" ]] && local_name="$kv_name"
  download_secret "$kv_name" "$local_name"
done

echo "Downloading SSH private key '$private_key_secret' -> ansible/id_rsa"
az keyvault secret download \
  --name "$private_key_secret" \
  --vault-name "$vault_name" \
  --file "$ansible_dir/id_rsa" \
  --only-show-errors
chmod 600 "$ansible_dir/id_rsa"

eval "$(ssh-agent -s)" >/dev/null
ssh-add "$ansible_dir/id_rsa"

if [[ "$skip_galaxy" != "true" && -n "$requirements_file" && -f "$ansible_dir/$requirements_file" ]]; then
  echo "Installing Galaxy requirements from $requirements_file"
  (cd "$ansible_dir" && ansible-galaxy install -r "$requirements_file")
fi

args=(-i hosts.yaml "$playbook")
[[ "$check_mode" == "true" ]] && args+=(--check)
[[ -n "$tags" ]] && args+=(--tags "$tags")
[[ -n "$limit" ]] && args+=(--limit "$limit")
args+=("${extra_ansible_args[@]}")

echo "Running: ansible-playbook ${args[*]}"
(cd "$ansible_dir" && ansible-playbook "${args[@]}")
