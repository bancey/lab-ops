# Harden Ubuntu Role

Baseline hardening for internet-facing Ubuntu hosts (written for Ubuntu 26.04 on the
OVH VPS front door, `vps01`). Applied by `ansible/vps-hardening.yaml`.

## Tasks

- Dist-upgrades all packages and installs `fail2ban`, `ufw`, `auditd`, `apparmor`,
  `unattended-upgrades`, `needrestart`
- **SSH**: drop-in `/etc/ssh/sshd_config.d/00-hardening.conf` — key-only auth, no root
  login, `AllowUsers`, short grace time, no forwarding/X11, verbose logging. Validated
  with `sshd -t` before the restart handler runs
- Locks the root password
- **UFW**: default deny incoming, SSH allowed, plus `harden_ufw_allowed_ports`
- **fail2ban**: `sshd` jail (systemd backend, aggressive mode) and `recidive` jail,
  banning via UFW with incremental ban times
- **unattended-upgrades**: security + updates pockets, optional automatic reboot
- **sysctl**: kernel pointer/dmesg/BPF restrictions, redirect/source-route rejection,
  martian logging. `ip_forward` and `rp_filter` are left alone deliberately
- **journald**: caps persistent journal size
- **auditd**: watches identity, sudoers, SSH, firewall, cron/systemd config and module loading
- Reboots if `/var/run/reboot-required` exists

In check mode, config for packages not yet installed on the host is skipped (its
directories don't exist until the package is installed), so a first-run PR check is
a partial preview.

## Variables

See `defaults/main.yaml`. The ones most likely to change:

| Variable | Default | Purpose |
| --- | --- | --- |
| `harden_ssh_allowed_users` | `[ubuntu]` | sshd `AllowUsers` — anyone not listed is locked out |
| `harden_ssh_port` | `22` | Changing it also needs the OVH edge firewall rules updated |
| `harden_ufw_allowed_ports` | `[]` | Extra `{port, proto}` entries to open in UFW |
| `harden_fail2ban_ignoreip` | loopback | Addresses fail2ban never bans |
| `harden_auto_reboot` / `harden_auto_reboot_time` | `true` / `04:00` | unattended-upgrades reboot behaviour |
