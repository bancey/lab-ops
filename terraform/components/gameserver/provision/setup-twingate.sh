sudo mkdir -p /opt/twingate
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az login --identity
az keyvault secret download --name ${SECRET_NAME} --vault-name ${VAULT_NAME} --file /opt/twingate/servicekey.json
curl https://binaries.twingate.com/client/linux/install.sh | sudo bash
sudo twingate setup --headless /opt/twingate/servicekey.json
sudo twingate start
