eval `ssh-agent -s`
ssh-add id_rsa
source /opt/pipx/venvs/ansible-core/bin/activate
python -m pip install netaddr==1.3.0
ansible-galaxy install -r requirements.yaml

LOG_FILE=$(mktemp /tmp/ansible-log-XXXXXX.log)
%{ if length(secret_keys) > 0 ~}
SECRETS_FILE=$(mktemp /tmp/ansible-secrets-XXXXXX.json)
chmod 600 "$SECRETS_FILE"
trap 'rm -f "$LOG_FILE" "$SECRETS_FILE"' EXIT
python3 - > "$SECRETS_FILE" << 'PYEOF'
import os, json
secrets = {}
%{ for key in secret_keys ~}
secrets["${key}"] = os.environ["ANSIBLE_VAR_${upper(key)}"]
%{ endfor ~}
print(json.dumps(secrets))
PYEOF
EXTRA_VARS_ARG="--extra-vars @$SECRETS_FILE"
%{ else ~}
trap 'rm -f "$LOG_FILE"' EXIT
EXTRA_VARS_ARG=""
%{ endif ~}

ansible-playbook --inventory hosts.yaml ${playbook} ${arguments} $EXTRA_VARS_ARG > "$LOG_FILE" 2>&1
ANSIBLE_EXIT=$?

if [ $ANSIBLE_EXIT -ne 0 ]; then
  echo "=== ANSIBLE FAILURE SUMMARY ==="
  grep -n -B2 -A10 "FAILED!\|fatal:\|ERROR!" "$LOG_FILE" || tail -200 "$LOG_FILE"
  exit $ANSIBLE_EXIT
fi

grep -E "PLAY RECAP|ok=|failed=" "$LOG_FILE" || true
