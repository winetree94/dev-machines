# ansible for dev

install requirements

```bash
ansible-galaxy role install --role-file ./requirement.yaml --force
```


# Supported Targets

- Ubuntu 24.04

# Requirements

- .vault_pass: password for ansible vault


# Apply

```bash
ansible-playbook ./playbooks/setup.yml
```


