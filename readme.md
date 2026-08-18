# ansible for dev

# 프로젝트 셋업

작업에 필요한 모든 secret 은 `ansible-vault` 로 암호화되어 `git` 에 들어있다.
SSH 개인키까지 vault 안에 있으므로 **하나의 비밀번호만 설정해주면 모든 secret 준비가 끝난다.**
저장소 루트에 `.vault_pass` 파일을 만들고 Bitwarden 의 `dev-machines (ansible vault)`
비밀번호를 넣으면 된다.

이후 다음의 명령어로 저장소에 등록된 비밀값들을 확인하거나 수정할 수 있다.

```bash
ansible-vault edit inventories/group_vars/all/vault.yml
```

비밀 설정이 완료됐다면 다음의 명령어로 의존성을 설치한다.

```bash
make install-tools
make install-requirements
```

# 연동된 머신들

| host | IP | group | OS |
|---|---|---|---|
| desktop | 10.132.247.31 | windows | Windows 10/11 |
| ubuntu-dev | 10.132.247.36 | ubuntu | Ubuntu 24.04+ |
| macmini | 10.132.245.38 | macos | macOS |
| localhost | – | (런타임 판별) | 컨트롤 머신 |

원격 머신은 `inventories/hosts.yml` 의 정적 OS 그룹에 들어있다. `group_vars/<group>.yml` 의
접속 변수(`ansible_shell_type`, `ansible_become_method`)가 첫 접속 *이전*에 결정되어야 하기
때문이다. `localhost` 만 그룹 없이 두고 `playbooks/setup.yml` 의 `Group hosts by OS` 플레이가
런타임에 분류한다 — 컨트롤 머신은 mac/linux/windows 무엇이든 될 수 있다.

`make apply` 를 `--limit` 없이 돌리면 이제 **4대 전부**를 건드린다. 범위를 좁히려면
`ANSIBLE_ARGS` 를 쓴다.

```bash
make ping  ANSIBLE_ARGS="--limit macmini"
make check ANSIBLE_ARGS="--limit ubuntu-dev"
make apply ANSIBLE_ARGS="--limit ubuntu-dev,macmini"
```

# Secret 구조

모든 secret 은 `inventories/group_vars/all/vault.yml` **한 파일**에만 있고, 그 안에는
`vault_` 접두사가 붙은 변수만 둔다. 실제 이름으로의 연결은 평문 파일에서 한다.

- `inventories/hosts.yml` — 호스트별 `ansible_user`, `ansible_become_password`
- `inventories/group_vars/all/main.yml` — `ansible_private_key`

즉 secret 의 *이름과 용도*는 git 에서 보이고, *값*만 감춰진다.

SSH 개인키는 파일 경로가 아니라 **내용**으로 `vault_ssh_private_key` 에 들어있다.
`ansible.cfg` 의 `[connection] ssh_agent = auto` 가 실행 단위 임시 ssh-agent 를 띄우고
거기에 키를 적재하므로, 개인키는 **디스크에 절대 기록되지 않는다.**
따라서 `~/.ssh/config` 나 미리 로드된 ssh-agent 없이도 저장소만으로 동작한다.

대응하는 공개키는 평문으로 커밋되어 있다(`winetree94_id_rsa.pub`). 용도는 아래 수동
부트스트랩뿐이다. 이 키는 개인 `~/.ssh/winetree94_id_rsa` 와 **동일한 신원**이므로
로테이션할 때는 이 저장소 바깥에도 영향이 간다는 점을 유의할 것.

# 새 머신 추가

1. `inventories/hosts.yml` 의 해당 OS 그룹에 호스트를 추가한다.
   ```yaml
   ubuntu:
     hosts:
       my-box:
         ansible_host: 10.132.247.99
         ansible_user: "{{ vault_my_box_username }}"
         ansible_become_password: "{{ vault_my_box_become_password }}"
   ```
2. `ansible-vault edit inventories/group_vars/all/vault.yml` 로
   `vault_my_box_username` / `vault_my_box_become_password` 를 추가한다.
   (호스트명의 하이픈은 밑줄로 바꾼다: `ubuntu-dev` → `vault_ubuntu_dev_*`)
3. 대상 머신에 공개키를 설치한다(아래 참고).

per-host 오버라이드(예: `gui: false`)는 `inventories/host_vars/<host>.yml` 에 둔다.

# 사람이 수동으로 해야 하는 작업

ansible 로 최대한 자동화했지만 머신별 초기 설정은 사람이 해야 한다.

**공통**: `winetree94_id_rsa.pub` 를 대상 계정의 `~/.ssh/authorized_keys` 에 등록.

**Ubuntu**
- `sudo apt install -y openssh-server && sudo systemctl enable --now ssh`
- sudo 비밀번호를 vault 의 `vault_<host>_become_password` 에 저장

**macOS**
- 시스템 설정 → 일반 → 공유 → 원격 로그인 켜기
- 계정 비밀번호를 vault 의 `vault_<host>_become_password` 에 저장

**Windows** (관리자 PowerShell)

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service sshd -StartupType Automatic; Start-Service sshd
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
  -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force

# 관리자 그룹 계정은 ~/.ssh/authorized_keys 가 아니라 아래 경로를 사용한다
$k = "C:\ProgramData\ssh\administrators_authorized_keys"
icacls $k /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
```

- `become_method: runas` 는 계정의 **대화형 비밀번호**를 요구한다.
  Microsoft 계정이면 MSA 비밀번호이며, **Windows Hello PIN 은 동작하지 않는다.**
- 접속 기본값(SSH + PowerShell + Chocolatey)은 `inventories/group_vars/windows.yml` 에 있고,
  WinRM 대안이 주석으로 함께 들어있다.
- SSH 키를 설치할 수 없는 상황의 탈출구로 `ansible_password` (SSH 비밀번호 인증)를 쓸 수도
  있지만 기본적으로 **비활성**이다. 컨트롤러에 `sshpass` 가 필요하고 macOS 에는 기본 설치되어
  있지 않다.

# Supported Targets

- Ubuntu 24.04+
- macOS (Homebrew must be installed beforehand)
- Windows 10/11 (via Chocolatey, over OpenSSH)

# Role structure

Each role's `tasks/main.yml` is a dispatcher that includes the first matching file:

- `debian.yml` — Ubuntu (apt/snap/flatpak/homebrew)
- `darwin.yml` — macOS (homebrew)
- `windows.yml` — Windows (chocolatey)
- `default.yml` — fallback shared by Ubuntu/macOS (homebrew-only roles)

If no file matches, the role is a no-op for that OS.

**알려진 제약:** `ai`, `bw`, `doppler`, `graphite`, `mise`, `node`, `rclone` 은 아직
Windows 패키지가 없어서 `windows.yml` 이 no-op 이다. 이 파일들이 존재하는 이유는
dispatcher 가 Homebrew 기반 `default.yml` 로 폴백하는 것을 막기 위해서다.
실제 설치는 후속 작업으로 `chocolatey.chocolatey.win_chocolatey` 를 채워 넣는다.

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

`tests/validate_inventory_secrets.yml` 은 인벤토리의 모든 자격증명이 `vault_*` 참조인지,
SSH 키가 디스크 경로가 아닌 vault 내용으로 오는지, 호스트가 정적 OS 그룹에 있는지 검사한다.

To preview changes before applying the playbook:

```bash
make check
```

`make check` runs `ansible-playbook --check --diff ./playbooks/setup.yml`. Some modules may report predicted changes in check mode even when a normal run is already idempotent. Notably, homebrew tap packages can fail in check mode until the tap has actually been installed by a real run.

# Apply

```bash
make apply
```
