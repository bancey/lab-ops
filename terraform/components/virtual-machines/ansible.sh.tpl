eval `ssh-agent -s`
ssh-add id_rsa
ansible-galaxy install -r requirements.yml
ansible-playbook --inventory hosts.yaml k3s.yaml --extra-vars run_prep=true run_install=true passed_hosts=${each.key}_k3s_cluster