from ansible.module_utils.common.text.converters import to_bytes
from ansible.plugins.become.sudo import BecomeModule as SudoBecomeModule


DOCUMENTATION = '\n    name: sudo_wrapped\n    short_description: Substitute User DO\n    description:\n        - This become plugin allows your remote/login user to execute commands as another user via the sudo utility.\n    author: ansible (@core)\n    version_added: "2.8"\n    options:\n        become_user:\n            description: User you \'become\' to execute the task\n            default: root\n            ini:\n              - section: privilege_escalation\n                key: become_user\n              - section: sudo_become_plugin\n                key: user\n            vars:\n              - name: ansible_become_user\n              - name: ansible_sudo_user\n            env:\n              - name: ANSIBLE_BECOME_USER\n              - name: ANSIBLE_SUDO_USER\n            keyword:\n              - name: become_user\n        become_exe:\n            description: Sudo executable\n            default: sudo\n            ini:\n              - section: privilege_escalation\n                key: become_exe\n              - section: sudo_become_plugin\n                key: executable\n            vars:\n              - name: ansible_become_exe\n              - name: ansible_sudo_exe\n            env:\n              - name: ANSIBLE_BECOME_EXE\n              - name: ANSIBLE_SUDO_EXE\n            keyword:\n              - name: become_exe\n        become_flags:\n            description: Options to pass to sudo\n            default: -H -S -n\n            ini:\n              - section: privilege_escalation\n                key: become_flags\n              - section: sudo_become_plugin\n                key: flags\n            vars:\n              - name: ansible_become_flags\n              - name: ansible_sudo_flags\n            env:\n              - name: ANSIBLE_BECOME_FLAGS\n              - name: ANSIBLE_SUDO_FLAGS\n            keyword:\n              - name: become_flags\n        become_pass:\n            description: Password to pass to sudo\n            required: False\n            vars:\n              - name: ansible_become_password\n              - name: ansible_become_pass\n              - name: ansible_sudo_pass\n            env:\n              - name: ANSIBLE_BECOME_PASS\n              - name: ANSIBLE_SUDO_PASS\n            ini:\n              - section: sudo_become_plugin\n                key: password\n        sudo_chdir:\n            description: Directory to change to before invoking sudo; can avoid permission errors when dropping privileges.\n            type: string\n            required: False\n            version_added: \'2.19\'\n            vars:\n              - name: ansible_sudo_chdir\n            env:\n              - name: ANSIBLE_SUDO_CHDIR\n            ini:\n              - section: sudo_become_plugin\n                key: chdir\n'


class BecomeModule(SudoBecomeModule):
    name = "sudo_wrapped"

    def check_password_prompt(self, b_output: bytes) -> bool:
        """Accept sudoers passprompt wrappers around Ansible's sudo prompt."""
        if self.prompt:
            b_prompt = to_bytes(self.prompt).strip()
            return any(b_prompt in line.strip() for line in b_output.splitlines())

        return False
