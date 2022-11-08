#!/bin/bash
#set -vxn

apt update
apt upgrade

apt install -y default-jre perl libjson-perl libwww-perl liblwp-protocol-https-perl util-linux python make wget git rdiff-backup rsync socat iptables

git clone https://github.com/MinecraftServerControl/mscs.git && cd mscs
make install


