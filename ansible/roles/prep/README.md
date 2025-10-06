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

### Disable multipath
```yaml
roles:
  - role: prep
    disable_multipath: false
```

## Notes

- The reboot tasks use `throttle: 1` to ensure hosts are rebooted one at a time, regardless of the playbook's `serial` setting
- The reboot task includes a post-reboot delay of 30 seconds to allow services to stabilize
- After reboot, the role waits for SSH connectivity before proceeding
- The `throttle` directive only affects the reboot and wait tasks, allowing other prep tasks to run in parallel
