echo "${TWINGATE_SERVICE_KEY}" > servicekey.json
curl https://binaries.twingate.com/client/linux/install.sh | sudo bash
sudo twingate setup --headless servicekey.json
sudo twingate start