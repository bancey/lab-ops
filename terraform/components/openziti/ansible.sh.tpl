eval `ssh-agent -s`
ssh-add id_rsa
source /opt/pipx/venvs/ansible-core/bin/activate

LOG_FILE=$(mktemp /tmp/ansible-openziti-log-XXXXXX.log)
INVENTORY_FILE=$(mktemp /tmp/ansible-openziti-inventory-XXXXXX.yaml)
EXTRA_VARS_FILE=$(mktemp /tmp/ansible-openziti-vars-XXXXXX.json)
chmod 600 "$EXTRA_VARS_FILE"

trap 'rm -f "$LOG_FILE" "$INVENTORY_FILE" "$EXTRA_VARS_FILE"' EXIT

cat > "$INVENTORY_FILE" << 'INVENTORY'
all:
  hosts:
    openziti:
      ansible_host: ${ip_address}
      ansible_user: ${ansible_user}
INVENTORY

python3 - > "$EXTRA_VARS_FILE" << 'PYEOF'
import json
import os

print(json.dumps({
  "openziti_admin_username": os.environ["OPENZITI_ADMIN_USERNAME"],
  "openziti_admin_password": os.environ["OPENZITI_ADMIN_PASSWORD"],
  "openziti_controller_address": "${controller_address}",
  "openziti_test_identity_name": "${test_identity_name}",
  "openziti_test_service_name": "${test_service_name}",
  "openziti_test_service_host": "${test_service_host}",
  "openziti_test_service_port": ${test_service_port},
}))
PYEOF

ansible-playbook --inventory "$INVENTORY_FILE" openziti.yaml --extra-vars "@$EXTRA_VARS_FILE" > "$LOG_FILE" 2>&1
ANSIBLE_EXIT=$?

if [ $ANSIBLE_EXIT -ne 0 ]; then
  echo "=== ANSIBLE FAILURE SUMMARY ==="
  grep -n -B2 -A10 "FAILED!\|fatal:\|ERROR!" "$LOG_FILE" || tail -200 "$LOG_FILE"
  exit $ANSIBLE_EXIT
fi

grep -E "PLAY RECAP|ok=|failed=" "$LOG_FILE" || true
