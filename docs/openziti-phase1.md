# OpenZiti Phase 1 (Core Network on Dedicated Proxmox VM)

This phase deploys a dedicated VM for OpenZiti controller + edge router and keeps auth simple (traditional one-time JWT enrollment, no OIDC/SSO yet).

## What is provisioned in this phase

- Terraform component: existing `/home/runner/work/lab-ops/lab-ops/terraform/components/virtual-machines` (driven by `terraform/environments/prod/prod.tfvars`)
- Dedicated VM: `openziti` on Proxmox node `loki`
- DNS record: `ziti.heimelska.co.uk` -> `10.151.14.230`
- Ansible install playbook: `/home/runner/work/lab-ops/lab-ops/ansible/openziti.yaml`

The playbook installs `openziti`, `openziti-controller`, and `openziti-router`, then writes helper files to `/opt/openziti/artifacts/` for phase-1 bootstrap and test-service setup.

## Required secrets

Create these secrets in Azure Key Vault `bancey-vault`:

- `OpenZiti-Admin-Username`
- `OpenZiti-Admin-Password`

A repository sync file exists at `/home/runner/work/lab-ops/lab-ops/kubernetes/bootstrap/openziti-admin.sops.yaml` and should be kept aligned with the Key Vault values.

## Manual phase-1 bootstrap on the VM

After Terraform/Ansible completes, SSH to the OpenZiti VM and run:

```bash
sudo /opt/openziti/artifacts/phase1-next-steps.sh
sudo /opt/openziti/etc/controller/bootstrap.bash
sudo /opt/openziti/etc/router/bootstrap.bash
```

Then authenticate and publish the phase-1 test service:

```bash
source /opt/openziti/artifacts/phase1-vars.env
ziti edge login "$OPENZITI_CONTROLLER_ADDRESS:1280" -u "$OPENZITI_ADMIN_USERNAME" -p "$OPENZITI_ADMIN_PASSWORD"

# create user enrollment JWT
ziti edge create identity user "$OPENZITI_TEST_IDENTITY_NAME" -a phase1-test -o "$OPENZITI_TEST_IDENTITY_NAME.jwt"

# create intercept/host service configs
ziti edge create config "$OPENZITI_TEST_SERVICE_NAME"-intercept intercept.v1 '{
  "protocols": ["tcp"],
  "addresses": ["'"$OPENZITI_TEST_SERVICE_NAME"'.ziti"],
  "portRanges": [{"low": '"$OPENZITI_TEST_SERVICE_PORT"', "high": '"$OPENZITI_TEST_SERVICE_PORT"'}]
}'

ziti edge create config "$OPENZITI_TEST_SERVICE_NAME"-host host.v1 '{
  "address": "'"$OPENZITI_TEST_SERVICE_HOST"'",
  "port": '"$OPENZITI_TEST_SERVICE_PORT"',
  "protocol": "tcp"
}'

ziti edge create service "$OPENZITI_TEST_SERVICE_NAME" -c "$OPENZITI_TEST_SERVICE_NAME"-intercept -c "$OPENZITI_TEST_SERVICE_NAME"-host
```

## End-to-end validation (manual)

1. Install Ziti Desktop Edge (or tunneler) on a personal device.
2. Import the generated JWT (`phase1-test-user.jwt`).
3. Confirm the published service is reachable through the Ziti tunnel.
4. Confirm direct access is blocked from outside allowed network paths.

## Teardown

Phase 1 is intentionally disposable. Tear down with Terraform:

```bash
cd /home/runner/work/lab-ops/lab-ops/terraform/components/virtual-machines
terraform destroy -var-file=../../environments/prod/prod.tfvars -var "target_nodes=[\"hela\",\"loki\",\"thor\"]" -target='module.tiny_virtual_machines["openziti"]' -target='terraform_data.ansible["openziti"]'
```

Optionally remove the phase-1 DNS entry (`ziti.heimelska.co.uk`) from `terraform/environments/prod/dns.yaml` when decommissioning.
