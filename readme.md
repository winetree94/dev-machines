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
`gui` 는 `GUI applications` 플레이(데스크톱 앱 20개)와 Linux 의 tailscale systray
자동 시작을 함께 제어한다. 참이면 호스트가 `gui_enabled` 그룹에 들어가고, 그 플레이가
그룹을 대상으로 돈다.

# 사람이 수동으로 해야 하는 작업

ansible 로 최대한 자동화했지만 머신별 초기 설정은 사람이 해야 한다.

**공통**: `winetree94_id_rsa.pub` 를 대상 계정의 `~/.ssh/authorized_keys` 에 등록.

**Ubuntu**
- `sudo apt install -y openssh-server && sudo systemctl enable --now ssh`
- sudo 비밀번호를 vault 의 `vault_<host>_become_password` 에 저장

**macOS**
- 시스템 설정 → 일반 → 공유 → 원격 로그인 켜기
- 계정 비밀번호를 vault 의 `vault_<host>_become_password` 에 저장
- App Store 에 Apple ID 로 로그인하고, WireGuard 와 Xcode 를 한 번씩 받아
  구매 이력에 넣어 둔다. `wireguard` 롤이 `mas` 로 WireGuard GUI 앱을,
  `xcode` 롤이 같은 방식으로 Xcode.app 을 설치하는데, 로그인이 안 되어
  있거나 구매 이력에 앱이 없으면 설치가 실패한다. 두 경우 모두 플레이는 죽지
  않고 안내 메시지만 남기고 넘어간다.
- Homebrew 는 미리 설치되어 있어야 한다. Command Line Tools 는 `xcode`
  롤이 알아서 설치하므로 수동 작업이 아니다.

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
- macOS (Homebrew must be installed beforehand; the Xcode Command Line Tools are handled by `xcode`)
- Windows 10/11 (via winget, over OpenSSH)

# Role structure

Each role's `tasks/main.yml` is a dispatcher that includes the first matching file:

- `debian.yml` — Ubuntu (apt/snap/flatpak/homebrew)
- `darwin.yml` — macOS (homebrew)
- `windows.yml` — Windows (winget)
- `default.yml` — fallback shared by Ubuntu/macOS (homebrew-only roles)

If no file matches, the role is a no-op for that OS.

**알려진 제약:** `graphite` 는 아직 winget 커뮤니티 저장소에 패키지가
없어서 `windows.yml` 이 no-op 이다. 이 파일이 존재하는 이유는 dispatcher 가
Homebrew 기반 `default.yml` 로 폴백하는 것을 막기 위해서다. 패키지가 올라오면
공용 `winget` 롤을 include 하도록 채워 넣는다.

앱 하나당 롤 하나가 원칙이다. `default.yml` 은 **Windows 를 포함한 모든 OS 의 폴백**
이라, `windows.yml` 이 없는 롤에서는 Homebrew 태스크가 Windows 에서 돌아버린다.
그래서 새로 추가하는 롤은 `default.yml` 을 두지 않고 지원하는 OS 마다 파일을 하나씩
둔다 - 파일이 없는 OS 가 no-op 이라는 사실 자체가 OS별 큐레이션이다.
`tests/validate_app_roles.yml` 이 파일의 존재와 부재를 양쪽 다 검사한다.

OS-exclusive roles (`apt_update`, `snap`, `flatpak`, `homebrew`, `xcode`,
`winget`) are instead gated by OS-targeted plays in
`playbooks/setup.yml`.

## xcode (macOS 부트스트랩)

`xcode` 는 `MacOS bootstrap` 플레이에서 `Common tooling` 보다 **먼저** 돈다.
Command Line Tools 는 Homebrew 와, 무언가를 컴파일하는 모든 롤의 전제 조건이기
때문이다. dispatcher 가 없는 평평한 롤이고 macOS 전용이며, OS 판별은 롤 안이 아니라
플레이 타게팅으로 한다.

**Command Line Tools**

- `xcode-select --install` 은 **쓰지 않는다.** GUI 다이얼로그를 띄우고 즉시
  리턴하므로 SSH 세션에서는 클릭할 사람이 없고, 도구 없이 실행이 그냥 이어진다.
- 대신 GUI 인스톨러가 만드는 센티넬 파일
  `/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress` 를 직접 만든다.
  이 파일이 있는 동안에만 `softwareupdate --list` 가 Command Line Tools 를 노출한다.
- 목록에서 라벨을 뽑아 `softwareupdate --install` 로 헤드리스 설치한다. 라벨은
  **불릿 줄에서만** 뽑는다(`^\s*\*.*Command Line Tools`) — 바로 아래의 들여쓴
  `Title: ... Size: ...` 줄이 같은 이름을 반복하므로 걸러야 한다. 정규식 하나로
  불릿과 선택적 `Label:` 을 떼어내 macOS 10.15+ 형식
  (`* Label: Command Line Tools for Xcode-16.2`) 과 그 이전 형식
  (`* Command Line Tools (macOS ...) for Xcode-10.1`) 을 모두 처리한다.
- 센티넬은 설치 실패 여부와 무관하게 `always:` 블록에서 지운다. 남겨두면 이후
  이 호스트의 모든 `softwareupdate --list` 가 계속 이 패키지를 광고한다.
- 설치 후 `xcode-select --print-path` 로 다시 확인하고 실패하면 여기서
  명확한 메시지와 함께 죽는다. 뒤늦게 Homebrew 안에서 터지는 것보다 낫다.

**Xcode.app**

- Mac App Store id `497799835` 를 `community.general.mas` 로 설치한다. `mas` formula
  는 이 롤이 직접 깐다 — `wireguard` 롤도 `mas` 를 설치하지만 `Common tooling`
  후반부라 부트스트랩 시점에는 아직 없다.
- `mas install` 은 root 권한을 요구하므로 이 작업만 `become: true`, Homebrew 작업은
  `become: false` 다.
- WireGuard 와 같은 `block`/`rescue` 형태다. Apple ID 로그인이 안 되어 있으면 안내
  메시지만 남기고 넘어가며, Command Line Tools 는 어느 쪽이든 설치되어 있다.
- Xcode.app 은 10GB 가 넘어서 첫 실행에서는 다운로드에 아주 오래 걸린다.

**설치 후 설정** — `mas` 작업이 아니라 `/Applications/Xcode.app/Contents/Developer`
의 `stat` 결과로 게이팅한다. 이미 Xcode 가 깔려 있던 호스트는 `mas` 가 실패해도
설정이 돌아야 하기 때문이다.

- `xcode-select --switch` — 활성 경로가 이미 Xcode.app 이면 건너뛴다.
- `xcodebuild -license accept` — 라이선스 미동의 상태에서는 `xcodebuild -version`
  이 non-zero 로 죽는다. 그 종료 코드가 곧 멱등성 판정이다.
- `xcodebuild -runFirstLaunch` — `xcodebuild -checkFirstLaunchStatus` 가 non-zero 일
  때만 돈다.

App Store 로그인은 계속 수동이며, Apple ID 자격증명은 리포에도 vault 에도 들어가지
않는다.

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
- winget 은 Windows 10 1809+ / 11 에 기본 탑재라 설치할 게 없다. 존재 여부
  assert 는 `winget` 롤 자체에 들어 있고, `Windows bootstrap` 플레이는 패키지
  없이 (`winget_packages` 기본값이 `[]`) 이 롤을 포함해 assert 만 돌린다. 없는
  호스트가 패키지 롤마다 하나씩 깨지는 대신 맨 앞에서 한 번 명확하게 실패한다.
  체크는 `winget_available` 팩트로 게이팅해서, 롤을 포함할 때마다가 아니라
  호스트당 한 번만 WinRM 왕복이 발생한다.
- **winget 전용 모듈은 만들지 않았다.** 공식/커뮤니티 모듈이 없고, 캡슐화할 로직이
  종료 코드 검사 한 줄뿐이며, Windows 모듈은 PowerShell 이라 yamllint /
  ansible-lint / `tests/validate_*.yml` 안전망 밖에 놓이기 때문이다.

**알려진 후퇴:** winget 에는 부동 Python ID 가 없어서(마이너별로만 존재)
`roles/python/tasks/windows.yml` 이 `Python.Python.3.14` 로 고정돼 있다. 마이너
릴리스마다 손으로 올려야 한다. Chocolatey 의 `python3` 메타패키지는 자동
추종했으므로 이 한 가지는 후퇴다.

## AI CLI 도구

`claude_code` / `codex` / `copilot_cli` / `opencode` 네 롤로 나뉘어 있다. 예전에는 `ai`
롤 하나였는데, Windows 에서는 아무것도 설치되지 않는 스텁이었고 `codex` / `copilot-cli`
를 formula 모듈로 설치하려 했지만 둘 다 실제로는 cask 다.

| 롤 | Ubuntu | macOS | Windows |
| --- | --- | --- | --- |
| `claude_code` | 공식 `claude.ai/install.sh` | cask `claude-code` | `Anthropic.ClaudeCode` |
| `codex` | 공식 `chatgpt.com/codex/install.sh` | cask `codex` | `OpenAI.Codex` |
| `copilot_cli` | 공식 `gh.io/copilot-install` | cask `copilot-cli` | `GitHub.Copilot` |
| `opencode` | brew `anomalyco/tap/opencode` | 같음 | `SST.opencode` |

- 앞의 셋은 Homebrew 패키지가 **cask** 이고 cask 는 macOS 전용이라 Ubuntu 에서 쓸 수 없다.
  그래서 벤더 공식 설치 스크립트를 쓴다. `curl … | bash` 로 파이프하지 않고 `get_url` 로
  받아서 별도 태스크로 실행하며, `~/.local/bin/<tool>` 을 `stat` 으로 검사해 멱등성을 지킨다.
  Claude Code 는 공식 APT 저장소도 있지만 서드파티 apt 저장소를 늘리지 않는 방침이라 쓰지 않는다.
- `opencode` 만 Linux 에서도 도는 formula 라서 `brew.yml` 하나를 `debian.yml` 과
  `darwin.yml` 이 함께 include 한다. tap 은 `trust: true` 로 등록해야 한다(Homebrew 6 은
  신뢰하지 않은 서드파티 tap 을 로드하지 않는다). homebrew-core 에도 같은 이름의 formula 가
  생겨 brew 가 shadow 경고를 내므로 토큰은 `anomalyco/tap/opencode` 로 정규화해서 쓴다.
  `sst/tap` 은 `anomalyco/tap` 으로 이름이 바뀌었고, winget 퍼블리셔만 예전 `SST` 로 남아 있다.
- winget ID 는 `GitHub.Copilot` 이다. **`GitHub.CopilotCLI` 는 존재하지 않고**,
  `GitHub.CopilotApp` 은 별개의 데스크톱 앱이다.

**자동 업데이트 주의.** Copilot CLI 는 백그라운드 자동 업데이트가 있어 패키지 매니저와
어긋난다(`--no-auto-update` 또는 `CI=1` 로 끈다). Claude Code 는 스크립트/npm 설치본만
자동 업데이트한다(`DISABLE_AUTOUPDATER=1`). 이 롤들은 해당 환경변수를 강제하지 않는다.

## GUI 앱

데스크톱 앱 20개가 각각 롤 하나다. `GUI applications` 플레이가 `gui_enabled` 그룹을
대상으로 돌리므로, 롤마다 `when: gui | bool` 을 붙이지 않는다.

Ubuntu 는 전부 Flathub, macOS 는 homebrew-cask, Windows 는 공용 `winget` 롤을 쓴다.
24개 이름을 전부 조회해 본 결과 **Linux 에서 도는 Homebrew formula 가 있는 것은
`opencode` 뿐**이라, GUI 앱은 Flathub 가 유일한 선택지다.

`bottles`, `flatseal`, `xclicker`, `remmina` 네 개는 macOS/Windows 패키지가 아예 없는
Linux 전용 프로젝트다. `debian.yml` 만 두고 나머지는 만들지 않는다 - 비슷한 다른 앱으로
대체하지 않는다.

`parsec` 만 pkg 기반 cask 라 `sudo_password` 를 넘긴다. 나머지 15개는 `.app` 드래그 설치라
sudo 가 필요 없다.

**Microsoft Edge 는 Windows 에서 설치하지 않는다.** winget 매니페스트는 Edge Enterprise
MSI(`InstallerType: wix`, machine scope)인데 Windows 11 기본 탑재 Edge 는 설치 기술이 다른
소비자 빌드다. 버전이 어긋나면 `the install technology is different from the current
version installed` 로 실패하고([winget-cli#4159](https://github.com/microsoft/winget-cli/issues/4159)),
Edge 는 자체 업데이터로 갱신되므로 winget 이 기록한 버전이 계속 어긋난다.

패키지 ID 중 직관에 어긋나서 매니페스트로 확인한 것들:

- `Pinta.Pinta` — `PintaProject.Pinta` 가 아니다(Flathub ID 는 반대로
  `com.github.PintaProject.Pinta` 다).
- `RedisInsight.RedisInsight` — `Redis.RedisInsight` 는 없고 `Redis.Redis` 는 무관한
  2015년경 Redis 서버다. macOS cask 토큰은 하이픈이 들어간 `redis-insight` 다.
- `Headlamp.Headlamp` — `Kinvolk.*` 퍼블리셔는 없다. Flathub 만 예전 `io.kinvolk.Headlamp`
  네임스페이스를 유지하고 있다.
- macOS 의 Telegram 은 cask `telegram`(네이티브 빌드)이다. `telegram-desktop` 은 Qt
  크로스플랫폼판이라 Flathub `org.telegram.desktop` 과 짝이지만 macOS 에서는 권장되지 않는다.

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
