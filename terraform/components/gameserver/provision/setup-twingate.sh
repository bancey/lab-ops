sudo mkdir -p /opt/twingate
echo "${TWINGATE_SERVICE_KEY}" > /opt/twingate/servicekey.json
curl https://binaries.twingate.com/client/linux/install.sh | sudo bash
sudo twingate setup --headless /opt/twingate/servicekey.json
sudo twingate start