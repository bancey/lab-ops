#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/run-ansible-playbook.sh <playbook> [options] [-- <extra ansible-playbook args>]

Runs an Ansible playbook locally the same way CI does. Two secret delivery styles are
supported, matching the two ways playbooks are invoked in this repo:

  1. Playbooks listed in "infra-pipeline.yaml" (ansible_deployments): secrets are
     downloaded from Key Vault into files under ansible/ that the playbooks read via
     lookup('ansible.builtin.file', ...).
  2. Playbooks driven by Terraform (the "ansible" map in
     terraform/environments/<env>/<env>.tfvars, applied by the virtual-machines
     component): secrets are passed as --extra-vars, along with the entry's
     "arguments" string.

In both cases an SSH private key is fetched and loaded into ssh-agent, and everything
is cleaned up again once the run finishes.

<playbook>  Playbook file, e.g. nut-server.yaml (the .yaml extension is optional)

Options:
  --vault-name <name>          Key Vault to read from (default: bancey-vault)
  --subscription <name|id>     az subscription to select before running
  --private-key-secret <name>  Key Vault secret holding the SSH private key
                                (default: Packer-Private-Key)
  --environment <env>          Terraform environment whose tfvars to search for the
                                playbook's ansible entry (default: prod)
  --tfvars <path>              Explicit tfvars file to search instead of
                                terraform/environments/<env>/<env>.tfvars
  --no-tf-arguments            Don't append the "arguments" string from the tfvars
                                ansible entry
  --secret <kv-name>[:<local-name>]
                                Extra secret to download to a file. Repeatable.
                                If <local-name> is omitted it defaults to <kv-name>.
  --extra-var-secret <var-name>:<kv-name>
                                Extra secret to pass as an --extra-vars value.
                                Repeatable.
  --no-auto-secrets            Don't look up secrets from infra-pipeline.yaml or the
                                Terraform tfvars, only use --secret/--extra-var-secret
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
  # mariadb.yaml is Terraform-driven; its secrets and arguments are resolved
  # automatically from terraform/environments/prod/prod.tfvars
  scripts/run-ansible-playbook.sh mariadb.yaml

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
environment="prod"
tfvars_file=""
use_tf_arguments="true"
declare -a manual_secrets=()
declare -a manual_extra_var_secrets=()
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
    --extra-var-secret)
      manual_extra_var_secrets+=("$2"); shift 2 ;;
    --environment)
      environment="$2"; shift 2 ;;
    --tfvars)
      tfvars_file="$2"; shift 2 ;;
    --no-tf-arguments)
      use_tf_arguments="false"; shift ;;
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
    found_in_pipeline="true"
  fi

  if [[ -z "$requirements_file" && -n "$pipeline_requirements" ]]; then
    requirements_file="$pipeline_requirements"
  fi
fi

# Playbooks not in the pipeline list are run by the virtual-machines Terraform
# component, which passes Key Vault secrets as --extra-vars rather than as files.
declare -a extra_var_secrets=()
tf_arguments=""
if [[ "$auto_secrets" == "true" && "${found_in_pipeline:-false}" != "true" ]]; then
  if [[ -z "$tfvars_file" ]]; then
    tfvars_file="$repo_root/terraform/environments/$environment/$environment.tfvars"
  elif [[ "$tfvars_file" != /* ]]; then
    tfvars_file="$repo_root/$tfvars_file"
  fi

  if [[ ! -f "$tfvars_file" ]]; then
    echo "Error: tfvars file $tfvars_file not found" >&2
    exit 1
  fi

  while IFS=$'\t' read -r kind field1 field2; do
    case "$kind" in
      SECRET) extra_var_secrets+=("$field1:$field2") ;;
      ARGUMENTS) tf_arguments="$field1" ;;
    esac
  done < <(python3 - "$tfvars_file" "$playbook" <<'PY'
import re
import sys

path, target = sys.argv[1], sys.argv[2]
text = open(path).read()


def block_at(source, start):
    """Return the body of the brace block whose opening brace is at `start`."""
    depth = 0
    for i in range(start, len(source)):
        if source[i] == '{':
            depth += 1
        elif source[i] == '}':
            depth -= 1
            if depth == 0:
                return source[start + 1:i], i
    sys.exit("unbalanced braces in " + path)


match = re.search(r'^ansible\s*=\s*\{', text, re.MULTILINE)
if not match:
    sys.exit(0)

ansible_block, _ = block_at(text, match.end() - 1)

entry_re = re.compile(r'"?[\w.-]+"?\s*=\s*\{')
pos = 0
while True:
    entry = entry_re.search(ansible_block, pos)
    if not entry:
        break
    body, end = block_at(ansible_block, entry.end() - 1)
    pos = end + 1

    playbook = re.search(r'playbook\s*=\s*"([^"]+)"', body)
    if not playbook or playbook.group(1) != target:
        continue

    arguments = re.search(r'arguments\s*=\s*"([^"]*)"', body)
    print("ARGUMENTS\t" + (arguments.group(1) if arguments else ""))

    secrets = re.search(r'secrets\s*=\s*\{', body)
    if secrets:
        secrets_body, _ = block_at(body, secrets.end() - 1)
        for var_name, kv_name in re.findall(r'"([^"]+)"\s*=\s*"([^"]+)"', secrets_body):
            print("SECRET\t%s\t%s" % (var_name, kv_name))
    break
PY
  )

  if [[ "${#extra_var_secrets[@]}" -gt 0 || -n "$tf_arguments" ]]; then
    echo "Found ${#extra_var_secrets[@]} extra-var secret(s) for $playbook in ${tfvars_file#"$repo_root"/}"
  else
    echo "Note: $playbook is not wired into infra-pipeline.yaml or ${tfvars_file#"$repo_root"/}."
    expected="$(grep -oP "lookup\('ansible\.builtin\.file',\s*'\K[^']+" "$ansible_dir/$playbook" | sort -u)"
    if [[ -n "$expected" ]]; then
      echo "It expects these local secret files (pass via --secret):"
      echo "$expected" | sed 's/^/  - /'
    fi
  fi
fi

for entry in "${manual_extra_var_secrets[@]:-}"; do
  [[ -z "$entry" ]] && continue
  extra_var_secrets+=("$entry")
done

declare -a downloaded_files=("id_rsa")
secrets_dir=""
cleanup() {
  if [[ "$keep_secrets" == "true" ]]; then
    return
  fi
  for f in "${downloaded_files[@]}"; do
    rm -f "$ansible_dir/$f"
  done
  [[ -n "$secrets_dir" ]] && rm -rf "$secrets_dir"
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

extra_vars_file=""
if [[ "${#extra_var_secrets[@]}" -gt 0 ]]; then
  secrets_dir="$(mktemp -d)"
  chmod 700 "$secrets_dir"
  mkdir "$secrets_dir/values"
  for entry in "${extra_var_secrets[@]}"; do
    var_name="${entry%%:*}"
    kv_name="${entry#*:}"
    echo "Downloading secret '$kv_name' -> extra-var '$var_name'"
    az keyvault secret download \
      --name "$kv_name" \
      --vault-name "$vault_name" \
      --file "$secrets_dir/values/$var_name" \
      --only-show-errors
  done
  extra_vars_file="$secrets_dir/extra-vars.json"
  python3 - "$secrets_dir/values" > "$extra_vars_file" <<'PY'
import json
import os
import sys

d = sys.argv[1]
print(json.dumps({n: open(os.path.join(d, n)).read() for n in os.listdir(d)}))
PY
  chmod 600 "$extra_vars_file"
fi

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
if [[ "$use_tf_arguments" == "true" && -n "$tf_arguments" ]]; then
  read -r -a tf_args <<< "$tf_arguments"
  args+=("${tf_args[@]}")
fi
[[ -n "$extra_vars_file" ]] && args+=(--extra-vars "@$extra_vars_file")
args+=("${extra_ansible_args[@]}")

echo "Running: ansible-playbook ${args[*]}"
(cd "$ansible_dir" && ansible-playbook "${args[@]}")
