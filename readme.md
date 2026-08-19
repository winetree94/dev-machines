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
| localhost | – | (런타임 판별) | 컨트롤 머신 (macOS / Ubuntu) |

원격 머신은 `inventories/hosts.yml` 의 정적 OS 그룹에 들어있다. `group_vars/<group>.yml` 의
접속 변수(`ansible_shell_type`, `ansible_become_method`)가 첫 접속 *이전*에 결정되어야 하기
때문이다. `localhost` 만 그룹 없이 두고 `playbooks/setup.yml` 의 `Group hosts by OS` 플레이가
런타임에 분류한다.

`localhost` 는 macOS 나 Ubuntu 만 될 수 있다. ansible 은 네이티브 Windows 를 컨트롤
노드로 지원하지 않기 때문에, Windows 머신은 WSL 안에서 ansible 을 돌리더라도 `localhost`
는 WSL 리눅스 게스트를 가리킨다. Windows 본체는 `desktop` 처럼 SSH 원격 호스트로 잡아야
한다.

지원하지 않는 OS 는 롤이 하나라도 돌기 전에 걸러진다. `Group hosts by OS` 플레이의
`Assert the host runs a supported OS` 가 Windows / macOS / **Ubuntu** 가 아닌 호스트를
즉시 실패시킨다. 그 아래 `group_by` 가 Windows·macOS 가 아닌 모든 호스트를 `ubuntu`
그룹으로 몰아넣기 때문에, 예컨대 Fedora 를 그냥 두면 apt/snap 태스크를 맞고 실행 도중에
깨진다. 해당 호스트만 실패하고 나머지 호스트는 계속 진행한다.

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
`gui` 는 `gui_apps` 롤과 Linux 의 tailscale systray 자동 시작을 함께 제어한다.

# 사람이 수동으로 해야 하는 작업

ansible 로 최대한 자동화했지만 머신별 초기 설정은 사람이 해야 한다.

**공통**: `winetree94_id_rsa.pub` 를 대상 계정의 `~/.ssh/authorized_keys` 에 등록.

**Ubuntu**
- `sudo apt install -y openssh-server && sudo systemctl enable --now ssh`
- sudo 비밀번호를 vault 의 `vault_<host>_become_password` 에 저장

**macOS**
- 시스템 설정 → 일반 → 공유 → 원격 로그인 켜기
- 계정 비밀번호를 vault 의 `vault_<host>_become_password` 에 저장
- App Store 에 Apple ID 로 로그인하고, WireGuard 를 한 번 받아 구매 이력에
  넣어 둔다. `wireguard` 롤이 `mas` 로 WireGuard GUI 앱을 설치하는데,
  로그인이 안 되어 있거나 구매 이력에 앱이 없으면 설치가 실패한다.
  이 경우 플레이는 죽지 않고 안내 메시지만 남기고 넘어간다.

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
- 접속 기본값(SSH + PowerShell)은 `inventories/group_vars/windows.yml` 에 있고,
  WinRM 대안이 주석으로 함께 들어있다.
- SSH 키를 설치할 수 없는 상황의 탈출구로 `ansible_password` (SSH 비밀번호 인증)를 쓸 수도
  있지만 기본적으로 **비활성**이다. 컨트롤러에 `sshpass` 가 필요하고 macOS 에는 기본 설치되어
  있지 않다.

# Supported Targets

- Ubuntu 24.04+
- macOS (Homebrew must be installed beforehand)
- Windows 10/11 (via winget, over OpenSSH)

# Role structure

Each role's `tasks/main.yml` is a dispatcher that includes the first matching file:

- `debian.yml` — Ubuntu (apt/snap/flatpak/homebrew)
- `darwin.yml` — macOS (homebrew)
- `windows.yml` — Windows (winget)
- `default.yml` — fallback shared by Ubuntu/macOS (homebrew-only roles)

If no file matches, the role is a no-op for that OS.

**알려진 제약:** `ai`, `graphite` 는 아직 winget 커뮤니티 저장소에 패키지가
없어서 `windows.yml` 이 no-op 이다. 이 파일들이 존재하는 이유는 dispatcher 가
Homebrew 기반 `default.yml` 로 폴백하는 것을 막기 위해서다. 패키지가 올라오면
공용 `winget` 롤을 include 하도록 채워 넣는다.

OS-exclusive roles (`apt_update`, `setup_snap`, `setup_flatpak`, `setup_homebrew`,
`setup_winget`) are instead gated by OS-targeted plays in `playbooks/setup.yml`.

## tailscale

`tailscale` 롤은 OS 별로 설치 형태가 다르다.

- `debian.yml` — 공식 stable APT 저장소 + `tailscaled` 서비스. `gui` 가 참인
  호스트에서는 systray 의존 패키지(`gnome-shell-extension-appindicator`,
  `xsel`, `wl-clipboard`)를 설치하고
  `tailscale configure systray --enable-startup=freedesktop` 로 로그인 시
  자동 시작 항목(`~/.config/autostart/tailscale-systray.desktop`)을 만든다.
  systray 하위 명령은 Tailscale 1.96 이상에서만 존재하므로 버전이 낮으면 건너뛴다.
- `darwin.yml` — Homebrew cask `tailscale-app` (GUI 클라이언트). cask 는 CLI 를
  앱 번들 안에 두므로 `/usr/local/bin/tailscale` 래퍼 스크립트를 함께 만든다.
  심볼릭 링크는 쓸 수 없다 — 바이너리가 자기 실행 경로로 번들을 찾기 때문에
  링크로 실행하면 `The current bundleIdentifier is unknown to the registry` 로
  죽는다. 앱의 "Install CLI" 메뉴가 하는 것과 같은 `exec` 래퍼를 쓴다.
  또한 `tailscale-app` 은 pkg 기반 cask 라 Homebrew 가 내부적으로 `sudo` 를
  호출한다. ansible 실행에는 터미널이 없으므로 vault 의 become 비밀번호를
  일회용 `SUDO_ASKPASS` 헬퍼로 넘겨준다(작업 후 즉시 삭제).
- `windows.yml` — winget `Tailscale.Tailscale`. 트레이 GUI 가 포함되어 있다.

롤은 절대 `tailscale up` 을 실행하지 않는다. 각 머신의 최초 인증은 수동이다.
macOS 는 cask 앱을 한 번 실행해 네트워크 확장을 승인해야 한다.

## wireguard

`wireguard` 롤은 **설치만** 담당한다. 터널 설정(`wg0.conf`)과 개인키는
리포에도 vault 에도 들어가지 않으며, 각 머신에서 수동으로 넣는다.

- `debian.yml` — apt 로 `wireguard-tools` 설치. 커널 모듈은 Linux 5.6 이상에
  내장되어 있으므로 DKMS 패키지는 필요 없다. `network-manager` 는 일부러
  설치하지 않는다 — netplan/systemd-networkd 로 도는 헤드리스 호스트에
  NetworkManager 를 밀어넣으면 네트워크가 끊길 수 있다.
- `darwin.yml` — Homebrew formula `wireguard-tools`(CLI) 와 `mas`, 그리고
  `mas` 로 Mac App Store GUI 클라이언트(id `1451685025`)를 설치한다.
  WireGuard 는 macOS 용 Homebrew cask 가 없어서 App Store 가 유일한 경로다.
  `mas install` 은 root 권한을 요구하므로 이 작업만 `become: true` 로 돈다.
- `windows.yml` — winget `WireGuard.WireGuard`. 공식 GUI 클라이언트가 포함된다.

### 터널 설정 (수동)

- **Ubuntu (데스크톱, NetworkManager)** — conf 파일을 NetworkManager 에 import 하면
  GNOME/KDE 네트워크 메뉴에 VPN 토글로 뜬다. NetworkManager 1.16 부터 WireGuard 를
  기본 지원하므로 별도 플러그인은 필요 없다.

  ```bash
  sudo nmcli connection import type wireguard file /path/to/wg0.conf
  nmcli connection up wg0     # 내리기: nmcli connection down wg0
  ```

- **Ubuntu (헤드리스)** — NetworkManager 가 없는 호스트는 `wg-quick` 을 쓴다.

  ```bash
  sudo install -m 600 wg0.conf /etc/wireguard/wg0.conf
  sudo wg-quick up wg0
  sudo systemctl enable --now wg-quick@wg0   # 부팅 시 자동 연결이 필요하면
  ```

- **macOS** — WireGuard 앱에서 conf 파일을 import 한다.
- **Windows** — WireGuard GUI 의 "Import tunnel(s) from file".

## doppler

`doppler` 롤은 OS 마다 Doppler 공식 배포 경로를 그대로 쓴다.

- `debian.yml` — 공식 APT 저장소(`packages.doppler.com/public/cli/deb/debian`,
  `any-version` suite). 서명 키는 ASCII armored 로 배포되므로 `.asc` 그대로
  `/usr/share/keyrings` 에 두고 `signed_by` 로 참조한다. 별도 변환 명령이나
  파이프 설치 스크립트는 쓰지 않는다.
- `darwin.yml` — Homebrew tap `dopplerhq/doppler` + cask. 주의할 점이 두 개 있다.
  - Homebrew 6 은 신뢰하지 않는 서드파티 탭의 formula/cask 를 아예 로드하지
    않으므로 `homebrew_tap` 에 `trust: true` 가 필요하다.
  - cask 토큰은 반드시 `dopplerhq/doppler/doppler` 로 정규화해서 쓴다. 짧은
    `doppler` 는 homebrew-cask 의 무관한 음악 앱 `doppler-app` 으로 해석된다.
    `community.general.homebrew_cask` 는 설치 여부를 `brew list --cask <name>`
    으로 판단하는데 정규화된 토큰에서 실패하므로, `brew info --json=v2` 로
    가드한 `brew install --cask` 를 쓴다.
- `windows.yml` — winget `Doppler.doppler`. Chocolatey 에는 Doppler 패키지가
  아예 없다.

## winget (Windows 패키지 관리)

Windows 의 모든 패키지 설치는 공용 `winget` 롤 하나를 거친다. 각 롤의
`windows.yml` 은 winget ID 목록만 넘긴다.

```yaml
- name: Install Docker Desktop (winget)
  ansible.builtin.include_role:
    name: winget
  vars:
    winget_packages:
      - Docker.DockerDesktop
```

**왜 Chocolatey 를 버렸나.** choco 는 자기가 설치한 것만 추적해서, 다른 경로로
설치된 앱 위에 벤더 MSI 를 얹으려다 `1603` 으로 죽는다. `desktop` 에서 tailscale
(choco 패키지가 구버전이라 다운그레이드 시도), docker-desktop, python3(동일 버전
이미 설치됨) 세 건이 모두 이 이유로 실패했고, 재부팅해도 그대로였다. Scoop 은
Add/Remove Programs 에 등록하지 않아 winget 이 인식하지 못한다.

winget 은 설치 여부를 **Add/Remove Programs 레지스트리**로 판단하므로 누가
설치했든 알아본다. 멱등성은 종료 코드 하나로 끝난다 — `winget list --id <id>
--exact` 가 설치돼 있으면 `0`, 없으면 `-1978335212`(`0x8A150014`).

- `--source winget` 을 항상 고정한다. msstore 소스는 별도 약관 동의가 필요하고
  자동화에 쓸 수 없는 ID 를 돌려준다.
- winget 은 Windows 10 1809+ / 11 에 기본 탑재라 설치할 게 없다. `setup_winget`
  롤은 존재 여부만 assert 해서, 없는 호스트가 패키지 롤마다 하나씩 깨지는 대신
  맨 앞에서 한 번 명확하게 실패하게 한다.
- **winget 전용 모듈은 만들지 않았다.** 공식/커뮤니티 모듈이 없고, 캡슐화할 로직이
  종료 코드 검사 한 줄뿐이며, Windows 모듈은 PowerShell 이라 yamllint /
  ansible-lint / `tests/validate_*.yml` 안전망 밖에 놓이기 때문이다.

**알려진 후퇴:** winget 에는 부동 Python ID 가 없어서(마이너별로만 존재)
`roles/python/tasks/windows.yml` 이 `Python.Python.3.14` 로 고정돼 있다. 마이너
릴리스마다 손으로 올려야 한다. Chocolatey 의 `python3` 메타패키지는 자동
추종했으므로 이 한 가지는 후퇴다.

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
검사 대상 호스트 목록은 `groups['all']` 에서 `localhost` 를 뺀 것으로 **인벤토리에서 유도**한다.
호스트를 추가·삭제·주석 처리해도 테스트를 같이 고칠 필요가 없다.

To preview changes before applying the playbook:

```bash
make check
```

`make check` runs `ansible-playbook --check --diff ./playbooks/setup.yml`. Some modules may report predicted changes in check mode even when a normal run is already idempotent. Notably, homebrew tap packages can fail in check mode until the tap has actually been installed by a real run.

# Apply

```bash
make apply
```
