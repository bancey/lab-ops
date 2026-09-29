#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/ovh-firewall-rule.sh <open|close> <vps-service-name> [sequence] [port]

Temporarily punches a hole in the OVHcloud Edge Network Firewall of a VPS so the
current machine (an Azure DevOps hosted agent) can reach it over SSH.

  open   Detect this machine's public IPv4 and create a "permit tcp from <ip>/32 to
         port <port>" rule at <sequence>, replacing any stale rule left there by a
         previous run, then wait for OVH to report the rule as active.
  close  Delete the rule at <sequence> and wait for OVH to finish removing it. A
         missing rule is not an error, so this is safe to run unconditionally.

  sequence  Rule priority 0-19 (default: 18). Reserved for this script: whatever
            is at this sequence gets replaced/removed.
  port      Destination port (default: 22).

Requires the ovhcloud CLI and jq on PATH, and OVH API credentials in ~/.ovh.conf
or OVH_* environment variables.
EOF
}

if [[ $# -lt 2 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 1
fi

ACTION="$1"
VPS_SERVICE="$2"
SEQUENCE="${3:-18}"
PORT="${4:-22}"
WAIT_ATTEMPTS=60
WAIT_INTERVAL=5

# Stdin is redirected from /dev/null on every call: the CLI switches to reading rule
# parameters from stdin whenever it is not a terminal, which it never is in CI.
ovh() {
  ovhcloud "$@" </dev/null
}

vps_ipv4() {
  ovh vps ip list "$VPS_SERVICE" --output json |
    jq -r '[.[] | select(.version == "v4") | .ipAddress] | first // empty'
}

rule_state() {
  # Prints the rule's state (creationPending, ok, removalPending, ...) or nothing if
  # the rule does not exist.
  ovh ip firewall rule get "$IP_BLOCK" "$VPS_IP" "$SEQUENCE" --output json 2>/dev/null |
    jq -r '.state // empty' 2>/dev/null || true
}

wait_for_state() {
  local want="$1" state
  for ((i = 1; i <= WAIT_ATTEMPTS; i++)); do
    state="$(rule_state)"
    echo "Rule #${SEQUENCE} state: ${state:-absent} (want: ${want:-absent}, attempt ${i}/${WAIT_ATTEMPTS})"
    if [[ "$state" == "$want" ]]; then
      return 0
    fi
    sleep "$WAIT_INTERVAL"
  done
  echo "Timed out waiting for rule #${SEQUENCE} to reach state '${want:-absent}'" >&2
  return 1
}

delete_rule() {
  if [[ -z "$(rule_state)" ]]; then
    echo "No rule at sequence ${SEQUENCE}, nothing to remove"
    return 0
  fi
  # A rule still being created cannot be deleted yet
  if [[ "$(rule_state)" == "creationPending" ]]; then
    wait_for_state ok
  fi
  if [[ "$(rule_state)" != "removalPending" ]]; then
    ovh ip firewall rule delete "$IP_BLOCK" "$VPS_IP" "$SEQUENCE"
  fi
  wait_for_state ""
}

VPS_IP="$(vps_ipv4)"
if [[ -z "$VPS_IP" ]]; then
  echo "Could not find an IPv4 address for VPS ${VPS_SERVICE}" >&2
  exit 1
fi
IP_BLOCK="${VPS_IP}/32"
echo "VPS ${VPS_SERVICE} IPv4: ${VPS_IP}"

case "$ACTION" in
  open)
    AGENT_IP="$(curl -fsS --retry 3 https://api.ipify.org)"
    if [[ ! "$AGENT_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "Could not determine this agent's public IPv4 (got '${AGENT_IP}')" >&2
      exit 1
    fi
    echo "Agent public IPv4: ${AGENT_IP}"

    # Clear out anything a previous, uncleanly-terminated run left behind
    delete_rule

    ovh ip firewall rule create "$IP_BLOCK" "$VPS_IP" \
      --sequence "$SEQUENCE" \
      --action permit \
      --protocol tcp \
      --source "${AGENT_IP}/32" \
      --destination-port "$PORT"
    wait_for_state ok
    sleep 60
    ;;
  close)
    delete_rule
    ;;
  *)
    usage
    exit 1
    ;;
esac
