.PHONY: install-tools install-requirements syntax validate lint check verify apply

ANSIBLE_PLAYBOOK ?= ansible-playbook
ANSIBLE_GALAXY ?= ansible-galaxy
YAMLLINT ?= yamllint
ANSIBLE_LINT ?= ansible-lint
PIPX ?= pipx

PLAYBOOK ?= ./playbooks/setup.yml
VALIDATE_PLAYBOOKS := $(sort $(wildcard tests/validate_*.yml))

install-tools:
	$(PIPX) install ansible-lint || $(PIPX) upgrade ansible-lint
	$(PIPX) install yamllint || $(PIPX) upgrade yamllint

install-requirements:
	$(ANSIBLE_GALAXY) collection install -r ./requirements.yml --force

syntax:
	$(ANSIBLE_PLAYBOOK) --syntax-check $(PLAYBOOK)

validate:
	@if [ -z "$(VALIDATE_PLAYBOOKS)" ]; then \
		printf '%s\n' "No validation playbooks found matching tests/validate_*.yml"; \
		exit 1; \
	fi
	@for playbook in $(VALIDATE_PLAYBOOKS); do \
		printf '%s\n' "Running $$playbook"; \
		$(ANSIBLE_PLAYBOOK) "$$playbook" || exit $$?; \
	done

lint:
	@command -v $(YAMLLINT) >/dev/null 2>&1 || { printf '%s\n' "yamllint is not installed; run 'make install-tools' or install it in your environment."; exit 127; }
	@command -v $(ANSIBLE_LINT) >/dev/null 2>&1 || { printf '%s\n' "ansible-lint is not installed; run 'make install-tools' or install it in your environment."; exit 127; }
	$(YAMLLINT) .
	$(ANSIBLE_LINT)

check:
	$(ANSIBLE_PLAYBOOK) --check --diff $(PLAYBOOK)

verify: syntax validate lint

apply:
	$(ANSIBLE_PLAYBOOK) $(PLAYBOOK)
