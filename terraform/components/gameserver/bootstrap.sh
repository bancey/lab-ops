#!/bin/bash
#set -vxn

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

curl -sSL https://get.docker.com/ | CHANNEL=stable bash
systemctl enable --now docker

snap install --classic certbot
certbot certonly --standalone --agree-tos --email abance@bancey.xyz --no-eff-email --non-interactive -d subdomain.bancey.xyz

mkdir -p /etc/pterodactyl
curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
chmod u+x /usr/local/bin/wings

curl -L -o /etc/systemd/system/wings.service "https://raw.githubusercontent.com/bancey/bancey-infra/master/terraform/components/gameserver/wings.service"
systemctl enable wings