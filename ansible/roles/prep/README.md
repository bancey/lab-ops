# Prep Role

This role performs basic system preparation tasks for hosts in the lab environment.

## Tasks

- Installs aptitude package manager
- Installs required system packages
- Removes unnecessary packages (ufw, unattended-upgrades)
- Upgrades all system packages
- Removes snap packages and snapd
- Sets timezone to Europe/London
- Disables multipathd service (optional)
- Reboots hosts (optional)

## Variables

### `install_pkgs`
**Type:** List  
**Default:**
```yaml
- open-iscsi
- nfs-common
- curl
- grep
- python3-kubernetes
- python3-yaml
- python3-netaddr
```
List of packages to install on the target hosts.

### `disable_multipath`
**Type:** Boolean  
**Default:** `true`  
Whether to disable and mask the multipathd service.

### `reboot_hosts`
**Type:** Boolean  
**Default:** `false`  
Whether to reboot hosts after preparation tasks complete. When enabled, hosts will be rebooted one at a time using the `throttle: 1` directive, regardless of the playbook's `serial` setting.

**Note**: When used with Terraform, reboots are triggered by the `ansible_reboot_hosts` variable. The Terraform resource only runs Ansible (and reboots) when the variable value changes or on initial provisioning.

### `reboot_timeout`
**Type:** Integer (seconds)  
**Default:** `600`  
Maximum time to wait for the host to reboot and become available.

## Usage Examples

### Basic usage with defaults
```yaml
roles:
  - role: prep
```

### With custom packages
```yaml
roles:
  - role: prep
    install_pkgs:
      - apt-transport-https
      - ca-certificates
      - curl
      - software-properties-common
```

### With reboot enabled
```yaml
- name: Prepare hosts
  hosts: all
  become: true
  roles:
    - role: prep
      reboot_hosts: true
      reboot_timeout: 300
```

Note: Hosts will be rebooted one at a time automatically using `throttle: 1` at the task level.

## Terraform Integration

When using this role with Terraform (via `k8s-vms-config.tf`), the reboot behavior is controlled by the `ansible_reboot_hosts` variable and triggers Terraform resource replacement:

### Initial Provisioning (First Run)
```hcl
kubernetes_virtual_machines = {
  wanda = {
    target_nodes         = ["wanda-node-01", "wanda-node-02"]
    ansible_reboot_hosts = true  # Triggers reboot on first apply
    image                = "ubuntu-22.04"
    # ... other config
  }
}
```
**Result**: First `terraform apply` → Resource created → Ansible runs with `reboot_hosts=true` → Hosts reboot

### Subsequent Runs (No Reboot)
```hcl
kubernetes_virtual_machines = {
  wanda = {
    target_nodes         = ["wanda-node-01", "wanda-node-02"]
    ansible_reboot_hosts = true  # Stays true, but no reboot happens
    image                = "ubuntu-22.04"
  }
}
```
**Result**: Terraform sees no change in triggers → No resource replacement → Ansible doesn't run → No reboot

### Trigger Reboot Again
To reboot hosts after initial setup, change the value:

```hcl
kubernetes_virtual_machines = {
  wanda = {
    target_nodes         = ["wanda-node-01", "wanda-node-02"]
    ansible_reboot_hosts = false  # 1. Set to false
    # ...
  }
}
```
Run `terraform apply`, then:
```hcl
kubernetes_virtual_machines = {
  wanda = {
    target_nodes         = ["wanda-node-01", "wanda-node-02"]
    ansible_reboot_hosts = true  # 2. Change back to true
    # ...
  }
}
```
**Result**: `reboot_requested` trigger changes → Resource replaced → Ansible runs → Hosts reboot

### How It Works
The `terraform_data.k8s_ansible` resource uses `triggers_replace`:
- `reboot_requested = ansible_reboot_hosts ? timestamp() : null`
- When `ansible_reboot_hosts` is `true`: a timestamp is captured, which changes only when the resource is recreated
- When `ansible_reboot_hosts` is `false`: value is `null`, no trigger
- Changing from `false` → `true` or VMs being recreated will trigger a new Ansible run with reboot

### Disable multipath
```yaml
roles:
  - role: prep
    disable_multipath: false
```

## Notes

- The reboot tasks use `throttle: 1` to ensure hosts are rebooted one at a time, regardless of the playbook's `serial` setting
- When used with Terraform, the reboot is triggered by changing the `ansible_reboot_hosts` variable value
- The Terraform resource uses `timestamp()` in triggers to detect when `ansible_reboot_hosts` changes from `false` to `true`
- The reboot task includes a post-reboot delay of 30 seconds to allow services to stabilize
- After reboot, the role waits for SSH connectivity before proceeding
- The `throttle` directive only affects the reboot and wait tasks, allowing other prep tasks to run in parallel
