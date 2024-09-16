# lab-ops

Configuration as code for my lab environment which spans Azure & on premise devices.

## Manual setup required

### Add required secrets to Key Vault
- `az keyvault secret set --vault-name <vault-name> --name <secret-name> --value <secret-value>`

### Setup Twingate connectors on the Raspberry Pis.
- `docker run -d --sysctl net.ipv4.ping_group_range="0 2147483647" --env TWINGATE_NETWORK="" --env TWINGATE_ACCESS_TOKEN="" --env TWINGATE_REFRESH_TOKEN=""  --env TWINGATE_LABEL_HOSTNAME="" --name "" --restart=unless-stopped --pull=always twingate/connector:1`

### Bootstrap K8S cluster

`task boostrap -- <cluster-name>

