eval `ssh-agent -s`
ssh-add id_rsa
pip3 install netaddr
ansible-galaxy install -r requirements.yaml
ansible-playbook --inventory hosts.yaml ${playbook} ${arguments}