# Instructional Context - ansible-for-dev

This project is an Ansible-based automation suite that bootstraps and configures development machines. Supported targets: Ubuntu 24.04+, macOS (Homebrew), and Windows 10/11 (winget over OpenSSH). It supports both localhost and multiple remote hosts.

## Project Overview

- **Purpose:** Automate the installation and configuration of developer tools, CLI utilities, and GUI applications.
- **Main Technologies:**
  - **Ansible:** Orchestration and configuration management.
  - **Package Managers:** APT/Snap/Flatpak (Ubuntu), Homebrew (macOS/Linux), winget (Windows).
  - **Key Tools Managed:** Docker, Mise (runtime manager), Neovim, Kubernetes (kubectl), Zsh, Tmux, Git, and various AI CLI tools.
- **Architecture:**
  - **Playbooks:** Entry point is `playbooks/setup.yml`, a multi-play playbook (`playbooks/ping.yml` is a connectivity check split by OS):
    1. `Group hosts by OS` — an `assert` fails the host up front unless it is Windows, macOS or `distribution == 'Ubuntu'` (the `group_by` below funnels every other Linux into `ubuntu`, so an unsupported distro has to be rejected before any role runs); `group_by` then assigns each host to `ubuntu` / `macos` / `windows` at runtime from facts, so `localhost` works on any supported control machine.
    2. `Ubuntu bootstrap` — apt_update, snap, flatpak, homebrew deps + GUI auto-detection (xsessions/wayland, WSL excluded).
    3. `Windows bootstrap` — setup_winget (assert only; winget ships with the OS).
    4. `Common tooling` — all cross-OS roles.
  - **Roles:** Modular logic under `roles/`. Each role's `tasks/main.yml` is a `first_found` dispatcher including `debian.yml` / `darwin.yml` / `windows.yml` / `default.yml` (fallback, used by homebrew-only roles). Missing file = no-op for that OS.
  - **Inventories:** `inventories/hosts.yml` holds connection identity only, for four machines: `desktop` (windows), `ubuntu-dev` (ubuntu), `macmini` (macos) and `localhost`. Remote hosts sit in a static OS group so connection vars from `inventories/group_vars/<group>.yml` apply before connecting; `localhost` is deliberately ungrouped and classified at runtime, because the control machine may be macOS or Ubuntu. It can never be Windows: ansible-core does not run as a control node on native Windows, and under WSL `localhost` is the WSL Linux guest — the Windows side is managed as the remote `desktop` host over SSH. Per-host overrides go in `inventories/host_vars/`.
  - **Group Vars:**
    - `all/main.yml` — plaintext: `gui` default and the `ansible_private_key` vault indirection.
    - `all/vault.yml` — the single ansible-vault encrypted file; `vault_*` variables only.
    - `ubuntu.yml` — `ansible_become_method: sudo_wrapped` (custom plugin in `plugins/become/`), `gui: false` (auto-detected).
    - `macos.yml` — `ansible_become_method: sudo`, `gui: true`.
    - `windows.yml` — SSH + `ansible_shell_type: powershell`, `ansible_become_method: runas`, `gui: true`. WinRM alternative documented inline.

## Key Commands

```bash
make install-tools          # yamllint, ansible-lint (pipx)
make install-requirements   # ansible-galaxy collections (requirements.yml)
make verify                 # syntax check + tests/validate_*.yml + yamllint + ansible-lint
make ping                   # ansible-playbook ./playbooks/ping.yml (win_ping on Windows)
make check                  # ansible-playbook --check --diff
make apply                  # ansible-playbook ./playbooks/setup.yml
```

Every target passes `$(ANSIBLE_ARGS)` through, which is how scope is narrowed:
`make check ANSIBLE_ARGS="--limit macmini"`. Without `--limit` these now target all four machines.

Requires `.vault_pass` with the vault decryption password - that one file is the only
secret setup step, since the SSH private key is in the vault too.

### Configuration Options

- **GUI Apps:** auto-enabled when a desktop environment is detected on Ubuntu (WSL excluded); always enabled on macOS/Windows. Override with `-e "gui=true|false"` or `inventories/host_vars/<host>.yml`.
- **`gui` consumers:** the `gui_apps` role (whole role, via `when:` in `setup.yml`) and the Linux systray tasks in `roles/tailscale/tasks/debian.yml`.

## Development Conventions

- **Role Structure:** dispatcher `tasks/main.yml` + OS files (`debian.yml`, `darwin.yml`, `windows.yml`, `default.yml`). Never put OS `when:` conditions inline in shared roles; OS-exclusive roles (`apt_update`, `setup_snap`, `setup_flatpak`, `setup_homebrew`, `setup_winget`) are gated by play targeting in `setup.yml` instead.
- **Homebrew on Linux:** Several roles (like `ai`, `mise`) prefer Homebrew for managing CLI tools even on Linux — these live in `default.yml`.
- **Windows packages:** every Windows install goes through the shared `winget` role - `include_role: winget` with a `winget_packages` list of winget IDs. Never call a package manager module directly in a `windows.yml`. Chocolatey and Scoop were both retired: choco only tracks installs it made itself and dies with a generic MSI 1603 when it tries to lay a package over an install it did not make (measured on `desktop` for tailscale, docker-desktop and python3), while Scoop does not register in Add/Remove Programs so winget cannot see what it installed. winget decides installed-state from Add/Remove Programs, so it recognises software installed by any means. Idempotency is one exit code: `winget list --id <id> --exact` returns 0 when installed and -1978335212 (`0x8A150014`) when not. Always pin `--source winget`; the msstore source needs separate agreement handling and returns IDs that cannot be automated. winget itself ships with Windows 10 1809+/11, so `setup_winget` only asserts it is present.
- **Pinned winget IDs:** winget has no floating Python ID, so `roles/python/tasks/windows.yml` pins `Python.Python.3.14` and has to be bumped by hand each minor release. This is the one thing Chocolatey's `python3` meta-package did better.
- **Tailscale:** a normal dispatcher role - APT repo + `tailscaled` + GUI-gated systray autostart on Debian, the `tailscale-app` Homebrew cask plus a `/usr/local/bin/tailscale` exec wrapper on macOS, and `Tailscale.Tailscale` through the shared winget role on Windows. The macOS CLI must be a wrapper, not a symlink: the binary resolves its own bundle from the path it is executed as and aborts with "The current bundleIdentifier is unknown to the registry". It never runs `tailscale up`; authenticating each machine stays a manual step.
- **WireGuard:** a normal dispatcher role that installs only - `wireguard-tools` from apt on Debian, the `wireguard-tools` formula plus the Mac App Store GUI client (id `1451685025`) via `community.general.mas` on macOS (there is no Homebrew cask for it), and `WireGuard.WireGuard` through the shared winget role on Windows. The mas task runs with `become: true` - `mas install` refuses to run unprivileged - and sits in a `block`/`rescue` because it still fails when no Apple ID is signed in. Tunnel config and private keys are never deployed by the role and never enter the vault.
- **Doppler:** a normal dispatcher role, one native install path per OS - the official APT repository on Debian, the `dopplerhq/doppler` Homebrew tap on macOS, `Doppler.doppler` through the shared winget role on Windows (Chocolatey has no Doppler package at all). Two macOS gotchas are load-bearing: the tap must be tapped with `trust: true` (Homebrew 6 refuses to load anything from an untrusted third-party tap), and the cask token must stay fully qualified as `dopplerhq/doppler/doppler`, because the bare `doppler` token resolves to homebrew-cask's unrelated `doppler-app`. That rules out `community.general.homebrew_cask`, whose installed-check runs `brew list --cask <name>` and fails on a qualified token, so the install is a `brew install --cask` gated on `brew info --json=v2`.
- **Remote-safe tasks:** never use `lookup('env', ...)` for target-host paths (it evaluates on the controller); use `ansible_env.HOME` / `ansible_user_id` facts instead.
- **Vault Usage:** Every secret lives in `inventories/group_vars/all/vault.yml`, the single encrypted file, and that file contains `vault_`-prefixed names only. Roles and playbooks must never reference a `vault_*` name directly - map it onto the real variable in `inventories/hosts.yml` or `inventories/group_vars/all/main.yml`. Never add a second encrypted file and never use inline `!vault` scalars. `ansible.cfg` reads the vault password from `.vault_pass`. A new vault file must also be added to the `.yamllint` ignore list, since yamllint cannot parse ciphertext.
- **Per-host credentials:** named `vault_<host>_username` / `vault_<host>_become_password`, with hyphens in the hostname replaced by underscores (`ubuntu-dev` -> `vault_ubuntu_dev_*`).
- **SSH auth:** the private key comes from `vault_ssh_private_key` via `ansible_private_key` (key *contents*) plus `ssh_agent = auto` under `[connection]` in `ansible.cfg`, which loads it into a per-run ephemeral agent. Never use `ansible_ssh_private_key_file`, never write a key to disk, and never enable `ansible_password`.
- **Privilege escalation:** `become` is intentionally not enabled globally in `ansible.cfg`. Tasks opt in individually - many are deliberately unprivileged because Homebrew refuses to run as root.
- **Never prompt for a password:** every host's sudo password comes from the vault, so no run may stop at a terminal prompt. Tools that shell out to `sudo` themselves need help, because an Ansible run has no terminal: pkg-based Homebrew casks (macOS) get the become password through a throwaway `SUDO_ASKPASS` helper - Homebrew adds `sudo -A` when that variable is set, and it scrubs unknown variables out of the child environment, so the password has to be written into the helper (`no_log: true`, deleted in an `always:` block) rather than passed through `environment:`. Anything that merely needs root, like `mas`, should use `become: true` instead.
- **Tests:** `tests/validate_*.yml` assert on role file contents; update them in the same change when refactoring the asserted roles. `tests/validate_inventory_secrets.yml` additionally asserts that the inventory sources every credential from the vault; its host list is derived from `groups['all']` minus `localhost`, so editing `inventories/hosts.yml` never requires editing the test.
