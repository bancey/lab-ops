eval `ssh-agent -s`
ssh-add id_rsa
pip3 install netaddr==1.3.0
ansible-galaxy install -r requirements.yaml
ansible-playbook --inventory hosts.yaml ${playbook} ${arguments}