# CLAUDE.md

This file provides guidance to Claude Code (or similar AI assistants) when working with this codebase.

## Project Overview

Ansible-based development environment automation project for provisioning development machines. Primarily targets **Ubuntu 24.04** with partial support for Fedora and macOS.

## Directory Structure

```
dev-machines/
├── ansible.cfg              # Main Ansible configuration
├── requirements.yml         # Ansible Galaxy dependencies
├── inventories/
│   ├── inventory.yaml       # Inventory definition (localhost)
│   └── group_vars/all.yml   # Group variables (encrypted become password)
├── playbooks/
│   └── setup.yml            # Main playbook entry point
└── roles/                   # 17 Ansible roles
    ├── ai/                  # AI tools (OpenCode, Claude Code)
    ├── android/             # Android SDK platform tools
    ├── apt-update/          # APT package manager update
    ├── bw/                  # Bitwarden CLI
    ├── chezmoi/             # Dotfiles manager
    ├── docker/              # Docker and Docker Compose
    ├── gui-apps/            # GUI applications (Flatpak + Snap)
    ├── kubernetes/          # Kubernetes tools (kubectl, k9s, helm, etc.)
    ├── neovim/              # Neovim editor + dependencies
    ├── node/                # Node.js ecosystem (Bun, pnpm, Deno)
    ├── python/              # Python and pipx
    ├── rust/                # Rust/Cargo installation
    ├── setup-flatpak/       # Flatpak package manager setup
    ├── setup-homebrew/      # Homebrew (Linuxbrew) setup
    ├── setup-snap/          # Snap package manager setup
    ├── tmux/                # Terminal multiplexer + TPM
    └── zsh/                 # Zsh shell + utilities (direnv, fzf)
```

## Key Commands

```bash
# Install Ansible Galaxy requirements
ansible-galaxy role install --role-file ./requirements.yml --force

# Run the main setup playbook
ansible-playbook ./playbooks/setup.yml

# Run with GUI applications enabled
ansible-playbook ./playbooks/setup.yml -e "gui=true"
```

## Requirements

- `.vault_pass` file must exist in project root (contains Ansible Vault password)
- Ansible installed on the local machine

## Key Configuration Files

| File | Purpose |
|------|---------|
| `ansible.cfg` | Defines inventory path, collections path, roles paths, vault password file |
| `inventories/inventory.yaml` | Target hosts (localhost) |
| `inventories/group_vars/all.yml` | Contains encrypted `ansible_become_password` |
| `playbooks/setup.yml` | Main entry point orchestrating all roles |

## Role Structure

Each role follows standard Ansible structure:
```
roles/<name>/
└── tasks/
    └── main.yml
```

Some roles include additional directories:
- `files/` - Static files (e.g., chezmoi config)

## Coding Conventions

### Ansible Patterns
- Use `when` clauses for conditional role execution
- Check for existing installations before installing (idempotency)
- Use `register` to capture command results
- Use `changed_when` to properly report state changes
- Define `is_linux` and `is_macos` convenience variables in playbooks

### Variable Naming
- Role-specific prefixes (e.g., `ai_claude_exists`, `rust_cargo_exists`)
- Use `ansible_facts` for OS detection

### Package Manager Strategy
- **Homebrew/Linuxbrew**: CLI tools (cross-platform)
- **APT**: System-level packages on Ubuntu
- **Flatpak**: GUI applications
- **Snap**: Select applications

### Security
- Ansible Vault for sensitive data (sudo password)
- Age encryption for dotfiles secrets (chezmoi)
- Never commit `.vault_pass` or `.become_pass`

## What Each Role Installs

| Role | Tools |
|------|-------|
| apt-update | Updates APT cache, dist-upgrade |
| setup-snap | snapd |
| setup-flatpak | Flatpak + Flathub repository |
| setup-homebrew | Prerequisites for Homebrew |
| chezmoi | Dotfiles manager with remote repo init |
| rust | Rustup + Cargo |
| python | Python3, pipx, build-essential |
| ai | OpenCode, Claude Code CLI |
| zsh | Zsh, direnv, fzf; sets as default shell |
| tmux | tmux, TPM (Tmux Plugin Manager) |
| bw | Bitwarden CLI |
| neovim | Neovim, lazygit, ripgrep, lua, luarocks, fd, clipboard tools |
| kubernetes | kubectl, age, sops, k9s, kubeseal, talosctl, talhelper, helm, flux |
| docker | docker.io, docker-compose-v2 |
| node | Bun, pnpm, Deno |
| android | Android SDK platform-tools |
| gui-apps | 21 Flatpak apps + 3 Snap apps |

## OS Support

- **Ubuntu 24.04**: Full support (primary target)
- **Fedora**: Partial support (uses DNF5)
- **macOS**: Partial support (uses Homebrew)
