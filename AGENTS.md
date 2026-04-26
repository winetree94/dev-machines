# Gemini Instructional Context - ansible-for-dev

This project is an Ansible-based automation suite designed to bootstrap and configure development environments, primarily targeting Ubuntu 24.04, with support for Fedora and macOS (via Homebrew).

## Project Overview

- **Purpose:** Automate the installation and configuration of developer tools, CLI utilities, and GUI applications.
- **Main Technologies:** 
  - **Ansible:** Orchestration and configuration management.
  - **Package Managers:** APT (Ubuntu), DNF (Fedora), Homebrew (macOS/Linux), Snap, Flatpak.
  - **Key Tools Managed:** Docker, Mise (runtime manager), Neovim, Kubernetes (kubectl), Zsh, Tmux, Git, and various AI CLI tools.
- **Architecture:** 
  - **Playbooks:** Entry point is `playbooks/setup.yml`.
  - **Roles:** Modular logic organized under `roles/`.
  - **Inventories:** Configuration for targets in `inventories/`.
  - **Group Vars:** Encrypted secrets (like `ansible_become_password`) stored in `inventories/group_vars/all.yml` using Ansible Vault.

## Key Commands

### Setup and Requirements
Before running the playbooks, ensure you have the required collections and a vault password file.

```bash
# Install required Ansible collections
ansible-galaxy role install --role-file ./requirements.yml --force

# Ensure .vault_pass exists with the vault decryption password
echo "your_password" > .vault_pass
```

### Applying the Configuration
To set up the local machine:

```bash
# Run the main setup playbook
ansible-playbook ./playbooks/setup.yml
```

### Configuration Options
- **GUI Apps:** GUI applications are automatically installed if a desktop environment is detected (excluding WSL and server environments). To manually enable or disable them, set the `gui` variable:
  ```bash
  # Force enable GUI apps
  ansible-playbook ./playbooks/setup.yml -e "gui=true"
  # Force disable GUI apps
  ansible-playbook ./playbooks/setup.yml -e "gui=false"
  ```

## Development Conventions

- **Role Structure:** Each role in `roles/` follows the standard Ansible structure, with tasks defined in `tasks/main.yml`.
- **Cross-Distribution Support:** Many roles use `ansible_facts['distribution']` or `ansible_facts['os_family']` to differentiate between Ubuntu, Fedora, and macOS.
- **Homebrew on Linux:** Several roles (like `ai`, `mise`) prefer Homebrew for managing CLI tools even on Linux.
- **AI Tools:** The `ai` role installs modern AI assistants including `gemini-cli`, `copilot-cli`, and `claude-code`.
- **Vault Usage:** Sensitive data must be encrypted with Ansible Vault. The `ansible.cfg` is configured to look for the vault password in `.vault_pass`.

## Directory Structure Highlights

- `ansible.cfg`: Configures inventory path, roles path, and vault password file.
- `inventories/inventory.yaml`: Defines `localhost` as the primary target using `ansible_connection: local`.
- `roles/`: Contains 20+ specialized roles for different tools and configurations.
- `playbooks/setup.yml`: The master playbook that orchestrates the execution of roles.
