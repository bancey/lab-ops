eval `ssh-agent -s`
ssh-add id_rsa
source /opt/pipx/venvs/ansible-core/bin/activate
where python
python -m pip install netaddr==1.3.0
ansible-galaxy install -r requirements.yaml
ansible-playbook --inventory hosts.yaml ${playbook} ${arguments}