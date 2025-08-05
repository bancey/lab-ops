eval `ssh-agent -s`
ssh-add id_rsa
ansible --version
ansible-playbook --version
apt install python3-netaddr
ansible-galaxy install -r requirements.yaml
ansible-playbook --inventory hosts.yaml ${playbook} ${arguments}