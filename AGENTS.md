# Instructional Context - ansible-for-dev

This project is an Ansible-based automation suite that bootstraps and configures development machines. Supported targets: Ubuntu 24.04+, macOS (Homebrew), and Windows 10/11 (Chocolatey over OpenSSH). It supports both localhost and multiple remote hosts.

## Project Overview

- **Purpose:** Automate the installation and configuration of developer tools, CLI utilities, and GUI applications.
- **Main Technologies:**
  - **Ansible:** Orchestration and configuration management.
  - **Package Managers:** APT/Snap/Flatpak (Ubuntu), Homebrew (macOS/Linux), Chocolatey (Windows).
  - **Key Tools Managed:** Docker, Mise (runtime manager), Neovim, Kubernetes (kubectl), Zsh, Tmux, Git, and various AI CLI tools.
- **Architecture:**
  - **Playbooks:** Entry point is `playbooks/setup.yml`, a multi-play playbook:
    1. `Group hosts by OS` — `group_by` assigns every host to `ubuntu` / `macos` / `windows` at runtime from facts, so `localhost` works on any control machine.
    2. `Ubuntu bootstrap` — apt_update, snap, flatpak, homebrew deps, tailscale + GUI auto-detection (xsessions/wayland, WSL excluded).
    3. `Windows bootstrap` — setup_chocolatey.
    4. `Common tooling` — all cross-OS roles.
  - **Roles:** Modular logic under `roles/`. Each role's `tasks/main.yml` is a `first_found` dispatcher including `debian.yml` / `darwin.yml` / `windows.yml` / `default.yml` (fallback, used by homebrew-only roles). Missing file = no-op for that OS.
  - **Inventories:** `inventories/inventory.yaml` defines static `ubuntu`/`macos`/`windows` groups. Remote hosts must be added to the correct static group so connection vars from `inventories/group_vars/<group>.yml` apply before connecting. Per-host overrides go in `inventories/host_vars/`.
  - **Group Vars:**
    - `all.yml` — vaulted `ansible_become_password`.
    - `ubuntu.yml` — `ansible_become_method: sudo_wrapped` (custom plugin in `plugins/become/`), `gui: false` (auto-detected).
    - `macos.yml` — `ansible_become_method: sudo`, `gui: true`.
    - `windows.yml` — SSH + `ansible_shell_type: powershell`, `ansible_become_method: runas`, `gui: true`. WinRM alternative documented inline.

## Key Commands

```bash
make install-tools          # yamllint, ansible-lint (pipx)
make install-requirements   # ansible-galaxy collections (requirements.yml)
make verify                 # syntax check + tests/validate_*.yml + yamllint + ansible-lint
make check                  # ansible-playbook --check --diff
make apply                  # ansible-playbook ./playbooks/setup.yml
```

Requires `.vault_pass` with the vault decryption password.

### Configuration Options

- **GUI Apps:** auto-enabled when a desktop environment is detected on Ubuntu (WSL excluded); always enabled on macOS/Windows. Override with `-e "gui=true|false"` or `inventories/host_vars/<host>.yml`.

## Development Conventions

- **Role Structure:** dispatcher `tasks/main.yml` + OS files (`debian.yml`, `darwin.yml`, `windows.yml`, `default.yml`). Never put OS `when:` conditions inline in shared roles; OS-exclusive roles (`apt_update`, `setup_snap`, `setup_flatpak`, `setup_homebrew`, `tailscale`, `setup_chocolatey`) are gated by play targeting in `setup.yml` instead.
- **Homebrew on Linux:** Several roles (like `ai`, `mise`) prefer Homebrew for managing CLI tools even on Linux — these live in `default.yml`.
- **Windows packages:** use `chocolatey.chocolatey.win_chocolatey` (winget is not automation-friendly in headless/SSH contexts).
- **Remote-safe tasks:** never use `lookup('env', ...)` for target-host paths (it evaluates on the controller); use `ansible_env.HOME` / `ansible_user_id` facts instead.
- **Vault Usage:** Sensitive data must be encrypted with Ansible Vault. `ansible.cfg` reads the vault password from `.vault_pass`.
- **Tests:** `tests/validate_*.yml` assert on role file contents; update them in the same change when refactoring the asserted roles.
