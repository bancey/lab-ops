eval `ssh-agent -s`
ssh-add id_rsa
ansible-galaxy install -r requirements.yaml
ansible-playbook --inventory hosts.yaml k3s.yaml -e run_prep=true -e run_install=true -e passed_hosts=${key}_k3s_cluster