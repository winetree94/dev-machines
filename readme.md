# ansible for dev

install requirements

```bash
make install-requirements
```


# Supported Targets

- Ubuntu 24.04

# Requirements

- .vault_pass: password for ansible vault

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

`make check` runs `ansible-playbook --check --diff ./playbooks/setup.yml`. Some modules may report predicted changes in check mode even when a normal run is already idempotent.

# Apply

```bash
make apply
```

