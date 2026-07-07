# scansnap-paperless Role

Configures a one-button scan-to-Paperless-ngx workflow on a Linux host connected to a Fujitsu ScanSnap iX500 (or compatible) scanner.

Pressing the hardware button on the scanner triggers `scanbd`, which executes a script that:
1. Scans all pages from the ADF (duplex by default)
2. Converts them to a single PDF with `img2pdf`
3. Uploads the PDF directly to the Paperless-ngx API (`/api/documents/post_document/`)
4. Retries on failure and saves the PDF to a local spool directory if all retries fail
5. A systemd timer periodically retries spooled uploads so no document is permanently lost

## Requirements

- Debian-based host (Raspberry Pi OS, Ubuntu, etc.)
- ScanSnap iX500 (or any SANE-supported Fujitsu ADF scanner) connected via USB
- Paperless-ngx instance reachable from the host
- API token for Paperless-ngx

## Packages installed

| Package | Purpose |
|---------|---------|
| `sane-utils` | `scanimage` CLI and SANE backends (includes `fujitsu` backend) |
| `scanbd` | USB button event daemon — triggers scan on hardware button press |
| `img2pdf` | Lossless PNG-to-PDF conversion |
| `curl` | Paperless-ngx API upload |

## Variables

All variables have defaults in `defaults/main.yaml`.

| Variable | Default | Description |
|----------|---------|-------------|
| `paperless_url` | `http://paperless.example.com` | Base URL of the Paperless-ngx instance |
| `paperless_api_token` | `""` | **Required — use Ansible Vault.** Paperless-ngx API token |
| `scansnap_device` | `""` | SANE device string; empty = auto-detect via `scanimage -L` |
| `scansnap_dpi` | `300` | Scan resolution in DPI |
| `scansnap_duplex` | `true` | Enable duplex (double-sided) scanning |
| `scansnap_mode` | `Gray` | Scan mode: `Gray`, `Color`, or `Lineart` |
| `scansnap_source` | `ADF Duplex` | SANE source name; use `ADF Front` for simplex |
| `scansnap_script_dir` | `/usr/local/bin` | Directory for the scan script |
| `scansnap_spool_dir` | `/var/spool/scansnap` | Holds PDFs that failed to upload |
| `scansnap_output_dir` | `/var/lib/scansnap/output` | Temporary working directory for scans |
| `scansnap_log_dir` | `/var/log/scansnap` | Log directory |
| `scansnap_log_file` | `/var/log/scansnap/scan.log` | Log file path |
| `scansnap_retry_count` | `3` | Number of upload retry attempts |
| `scansnap_retry_delay` | `5` | Seconds between upload retry attempts |
| `scansnap_retry_timer_enabled` | `true` | Enable systemd timer to retry spooled uploads |
| `scansnap_retry_timer_interval` | `15min` | How often to retry spooled uploads |
| `scansnap_service_enabled` | `true` | Whether to enable and start the `scanbd` service |
| `scanbd_user` | `saned` | User that runs the scanbd daemon |
| `scanbd_group` | `scanner` | Group that owns SANE device access |
| `scanbd_script_dir` | `/etc/scanbd/scripts.d` | Script directory used by scanbd |
| `scanbd_debug` | `false` | Enable scanbd debug logging |
| `scanbd_debug_level` | `1` | scanbd debug verbosity level |
| `scanbd_timeout` | `500` | scanbd polling interval (milliseconds) |
| `scanbd_button_filter` | `^button.*` | Regex matching SANE option name for the scanner button |
| `scanbd_trigger_from` | `0` | Button option value before press |
| `scanbd_trigger_to` | `1` | Button option value after press |

### Secret handling

`paperless_api_token` **must not** be committed in plaintext.  
Supply it via Ansible Vault or the `lookup('ansible.builtin.file', ...)` pattern:

```yaml
# In playbook (example — see ansible/scansnap.yaml)
roles:
  - role: scansnap-paperless
    paperless_api_token: "{{ lookup('ansible.builtin.file', 'Paperless-API-Token') }}"
```

Store the `Paperless-API-Token` file in the same directory as your Ansible Vault or in the Azure DevOps pipeline secure files.

## Usage

### Deploy the role

```bash
ansible-playbook ansible/scansnap.yaml
```

Or with a custom URL override:

```bash
ansible-playbook ansible/scansnap.yaml \
  -e paperless_url=https://paperless.heimelska.co.uk
```

### Manual scan test (without pressing the button)

```bash
# Run the scan script manually as root on gamora
sudo /usr/local/bin/scan-to-paperless.sh
```

### Check scanbd service status

```bash
sudo systemctl status scanbd
sudo journalctl -u scanbd -f
```

### View scan logs

```bash
tail -f /var/log/scansnap/scan.log
journalctl -t scan-to-paperless -f
```

### Check spool for failed uploads

```bash
ls -lh /var/spool/scansnap/
```

### Manually trigger retry for spooled files

```bash
sudo systemctl start scansnap-retry.service
sudo journalctl -u scansnap-retry -n 50
```

### API connectivity validation

```bash
curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Token <your-token>" \
  https://paperless.example.com/api/
# Expected: 200
```

## Troubleshooting

### No scanner detected (`scanimage -L` shows nothing)

1. Verify USB connection: `lsusb | grep -i fujitsu`
2. Check SANE backend: `sane-find-scanner`
3. Ensure the `fujitsu` backend is loaded: `grep -v "^#" /etc/sane.d/dll.conf | grep fujitsu`
4. Add scanner user to the `scanner` group: `sudo usermod -aG scanner $USER`
5. Reconnect the USB cable after group change

### Button press not detected by scanbd

The button option name varies between scanner models and firmware versions.
Discover the correct SANE option name for your device:

```bash
# List all options including button options
scanimage -d "$(scanimage -L | head -n1 | sed -E "s/device \`([^']+)'.*/\1/")" -A 2>&1 | grep -i "button\|function\|scan"
```

Update `scanbd_button_filter` in your playbook vars to match the option name found.
Common values for Fujitsu scanners:
- ScanSnap iX500: `^Scan button$`, `^Email button$`
- Other Fujitsu models: `^button-0.*`, `^button-1.*`, `^scan-button.*`

Also check trigger direction — some buttons trigger `1→0` rather than `0→1`:

```bash
# Temporarily enable scanbd debug to see option changes in real time
sudo scanbd -f -d 5 2>&1 | grep -i "function\|button"
# Press the scanner button and observe which value changes
```

Then set `scanbd_trigger_from` / `scanbd_trigger_to` accordingly.

### scanbd conflicts with saned or SANE direct access

`scanbd` acts as a SANE proxy. While `scanbd` is running, direct `scanimage` calls
must go through the `net` backend (localhost). For manual testing, stop scanbd first:

```bash
sudo systemctl stop scanbd
scanimage -L
sudo systemctl start scanbd
```

### ADF Duplex source not found

Different Fujitsu firmware versions use different source names. If `ADF Duplex` fails:

```bash
# List supported sources
scanimage -d <device> --source help 2>&1
```

Common alternatives: `Automatic Document Feeder(duplex)`, `ADF Front+Back`.
Set `scansnap_source` accordingly.

### PDF upload rejected by Paperless (non-2xx response)

1. Test API token: `curl -H "Authorization: Token <token>" <url>/api/`
2. Check Paperless logs: `docker logs paperless-webserver`
3. Verify the endpoint path matches your Paperless version (`/api/documents/post_document/`)
4. For older Paperless-ng (not ngx), the endpoint may differ

## Directory layout on the target host

```
/usr/local/bin/scan-to-paperless.sh    # Main scan + upload script
/etc/scanbd/scanbd.conf                # scanbd configuration
/etc/scanbd/scripts.d/scan.sh          # Symlink → scan-to-paperless.sh
/var/spool/scansnap/                   # Failed upload spool (PDFs retained here)
/var/lib/scansnap/output/              # Temporary working directory for scans
/var/log/scansnap/scan.log             # Scan and upload log
/etc/systemd/system/scansnap-retry.service  # Spool retry service
/etc/systemd/system/scansnap-retry.timer    # Spool retry timer (15-min default)
```
