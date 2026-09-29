#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit

usage() {
  cat <<'EOF'
Usage: scripts/ovh-firewall-rule.sh <open|close> <vps-service-name> [sequence] [port]

Temporarily punches a hole in the OVHcloud Edge Network Firewall of a VPS so the
current machine (an Azure DevOps hosted agent) can reach it over SSH.

  open   Detect this machine's public IPv4 and create a "permit tcp from <ip>/32 to
         port <port>" rule at <sequence>, then wait for OVH to report it active.
         If another run holds the slot, wait for it to be released; a rule still
         there after OWNER_WAIT_SECONDS is treated as abandoned and replaced.
  close  Delete the rule at <sequence>, but only if it is ours (its source is this
         machine's IP), and wait for OVH to finish removing it. A missing rule, or
         one belonging to another run, is left alone and is not an error.

  sequence  Rule priority 0-19 (default: 18). Reserved for this script.
  port      Destination port (default: 22).

The source IP recorded by "open" is published as the OVH_RULE_SOURCE pipeline
variable so "close" matches exactly what was opened, even if the agent's egress IP
lookup would now answer differently.

Any OVH API error aborts the script: an error is never mistaken for "no rule".

Requires the ovhcloud CLI, jq and curl on PATH, and OVH API credentials in
~/.ovh.conf or OVH_* environment variables.
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
# Long enough for a full hardening run (dist-upgrade + reboot) in another pipeline
OWNER_WAIT_SECONDS="${OWNER_WAIT_SECONDS:-1500}"

# Stdin is redirected from /dev/null on every call: the CLI switches to reading rule
# parameters from stdin whenever it is not a terminal, which it never is in CI.
ovh() {
  ovhcloud "$@" </dev/null
}

vps_ipv4() {
  local out
  out="$(ovh vps ip list "$VPS_SERVICE" --output json)"
  jq -r '[.[]? | select(.version == "v4") | .ipAddress] | first // empty' <<<"$out"
}

agent_ipv4() {
  local ip
  ip="$(curl -fsS --retry 3 https://api.ipify.org)"
  if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Could not determine this agent's public IPv4 (got '${ip}')" >&2
    return 1
  fi
  echo "$ip"
}

# Prints "<state> <source>" for the rule at SEQUENCE, or nothing if there is none.
# Uses the list call rather than get so that "no rule" is an empty result, not an
# error; any failure of the call itself propagates.
rule_info() {
  local out
  if ! out="$(ovh ip firewall rule list "$IP_BLOCK" "$VPS_IP" --output json)"; then
    echo "Failed to list OVH firewall rules: ${out}" >&2
    return 1
  fi
  jq -r --argjson seq "$SEQUENCE" \
    '[.[]? | select(.sequence == $seq) | "\(.state) \(.source // "any" | sub("/32$"; ""))"] | first // empty' \
    <<<"$out"
}

wait_for_state() {
  local want="$1" info state
  for ((i = 1; i <= WAIT_ATTEMPTS; i++)); do
    info="$(rule_info)"
    state="${info%% *}"
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
  local info state
  info="$(rule_info)"
  state="${info%% *}"
  if [[ -z "$state" ]]; then
    echo "No rule at sequence ${SEQUENCE}, nothing to remove"
    return 0
  fi
  # A rule still being created cannot be deleted yet
  if [[ "$state" == "creationPending" ]]; then
    wait_for_state ok
    state=ok
  fi
  if [[ "$state" != "removalPending" ]]; then
    ovh ip firewall rule delete "$IP_BLOCK" "$VPS_IP" "$SEQUENCE"
  fi
  wait_for_state ""
}

# Waits for another run's rule to go away. Returns 0 once the slot is free (or
# already holds our own IP), 1 if it is still held after OWNER_WAIT_SECONDS.
wait_for_slot() {
  local me="$1" info source deadline=$((SECONDS + OWNER_WAIT_SECONDS))
  while true; do
    info="$(rule_info)"
    source="${info#* }"
    if [[ -z "$info" || "$source" == "$me" ]]; then
      return 0
    fi
    if ((SECONDS >= deadline)); then
      return 1
    fi
    echo "Rule #${SEQUENCE} is held by ${source} (another run?), waiting for it to be released..."
    sleep 30
  done
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
    AGENT_IP="$(agent_ipv4)"
    echo "Agent public IPv4: ${AGENT_IP}"
    echo "##vso[task.setvariable variable=OVH_RULE_SOURCE]${AGENT_IP}"

    if ! wait_for_slot "$AGENT_IP"; then
      echo "Rule #${SEQUENCE} still held after ${OWNER_WAIT_SECONDS}s, assuming it was abandoned by a failed run"
    fi
    # Clears an abandoned rule, or our own from a retried job
    delete_rule

    ovh ip firewall rule create "$IP_BLOCK" "$VPS_IP" \
      --sequence "$SEQUENCE" \
      --action permit \
      --protocol tcp \
      --source "${AGENT_IP}/32" \
      --destination-port "$PORT"
    wait_for_state ok
    # OVH reports the rule as "ok" before the edge has actually applied it
    sleep 60
    ;;
  close)
    OWNER_IP="${OVH_RULE_SOURCE:-$(agent_ipv4)}"
    info="$(rule_info)"
    source="${info#* }"
    if [[ -n "$info" && "$source" != "$OWNER_IP" ]]; then
      echo "Rule #${SEQUENCE} belongs to ${source}, not this run (${OWNER_IP}); leaving it in place"
      exit 0
    fi
    delete_rule
    ;;
  *)
    usage
    exit 1
    ;;
esac
