#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/deploy-rpi-swarm.sh [options]

Git-driven Raspberry Pi Swarm deployment using Ansible playbook state in this repo.

Options:
  --inventory <path>      Ansible inventory file (default: ansible/hosts.yaml)
  --manager <hostname>    Primary swarm manager hostname (default: thanos)
  --tags <csv>            Playbook tags to run (default: network,monitoring)
  --skip-bootstrap        Skip swarm/bootstrap tasks and deploy stacks only
  --check                 Run in Ansible check mode
  --help                  Show this help

Examples:
  scripts/deploy-rpi-swarm.sh --manager thanos
  scripts/deploy-rpi-swarm.sh --manager thanos --tags network
  scripts/deploy-rpi-swarm.sh --manager thanos --skip-bootstrap
EOF
}

inventory="ansible/hosts.yaml"
manager="${SWARM_MANAGER:-thanos}"
tags="network,monitoring"
skip_bootstrap="false"
check_mode="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --inventory)
      inventory="$2"
      shift 2
      ;;
    --manager)
      manager="$2"
      shift 2
      ;;
    --tags)
      tags="$2"
      shift 2
      ;;
    --skip-bootstrap)
      skip_bootstrap="true"
      shift
      ;;
    --check)
      check_mode="true"
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

extra_args=(
  "-i" "$inventory"
  "-e" "rpi_swarm_primary_manager=$manager"
)

if [[ "$skip_bootstrap" == "true" ]]; then
  extra_args+=("--tags" "$tags")
fi

if [[ "$check_mode" == "true" ]]; then
  extra_args+=("--check")
fi

echo "Running ansible/rpi-ha.yaml with manager=$manager inventory=$inventory"
ansible-playbook ansible/rpi-ha.yaml "${extra_args[@]}"

echo "Swarm deployment completed. Validate on manager with:"
echo "  docker node ls"
echo "  docker service ls"
echo "  docker stack ls"
