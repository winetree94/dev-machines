# ansible for dev

install requirements

```bash
make install-requirements
```

# Supported Targets

- Ubuntu 24.04+
- macOS (Homebrew must be installed beforehand)
- Windows 10/11 (via Chocolatey, over OpenSSH)

Hosts are automatically classified into the `ubuntu` / `macos` / `windows` groups
at runtime based on gathered facts (`group_by` play in `playbooks/setup.yml`).
`localhost` works out of the box on any control machine.

# Multi-host usage

Add remote hosts to the matching static group in `inventories/inventory.yaml`
so the connection variables in `inventories/group_vars/<group>.yml` apply:

```yaml
all:
  hosts:
    localhost:
      ansible_connection: local
  children:
    ubuntu:
      hosts:
        my-ubuntu-box:
          ansible_host: 192.168.0.10
          ansible_user: winetree94
    macos:
      hosts: {}
    windows:
      hosts:
        my-windows-box:
          ansible_host: 192.168.0.11
          ansible_user: winetree94
```

Per-host overrides (e.g. `gui: false`) go in `inventories/host_vars/<host>.yml`.

## Windows host preparation (one-time, elevated PowerShell)

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service sshd -StartupType Automatic; Start-Service sshd
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
  -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
```

Connection defaults (SSH + PowerShell + Chocolatey) live in
`inventories/group_vars/windows.yml`. A commented WinRM alternative is included there.

# Requirements

- .vault_pass: password for ansible vault

# Role structure

Each role's `tasks/main.yml` is a dispatcher that includes the first matching file:

- `debian.yml` — Ubuntu (apt/snap/flatpak/homebrew)
- `darwin.yml` — macOS (homebrew)
- `windows.yml` — Windows (chocolatey)
- `default.yml` — fallback shared by Ubuntu/macOS (homebrew-only roles)

If no file matches, the role is a no-op for that OS.
OS-exclusive roles (`apt_update`, `setup_snap`, `setup_flatpak`, `setup_homebrew`,
`tailscale`, `setup_chocolatey`) are instead gated by OS-targeted plays in
`playbooks/setup.yml`.

# Validation

Install validation tools and Ansible collections before running checks:

```bash
make install-tools
make install-requirements
```

Run all pre-apply validation:

```bash
make verify
```

This runs:

- `ansible-playbook --syntax-check ./playbooks/setup.yml`
- all static validation playbooks matching `tests/validate_*.yml`
- `yamllint .`
- `ansible-lint`

To preview changes before applying the playbook:

```bash
make check
```

`make check` runs `ansible-playbook --check --diff ./playbooks/setup.yml`. Some modules may report predicted changes in check mode even when a normal run is already idempotent. Notably, homebrew tap packages can fail in check mode until the tap has actually been installed by a real run.

# Apply

```bash
make apply
```
