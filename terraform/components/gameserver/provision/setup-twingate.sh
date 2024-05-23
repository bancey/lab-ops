sudo mkdir -p /opt/twingate
cat <<EOF >/opt/twingate/servicekey.json
${TWINGATE_SERVICE_KEY}
EOF
curl https://binaries.twingate.com/client/linux/install.sh | sudo bash
sudo twingate setup --headless /opt/twingate/servicekey.json
sudo twingate start
