# 바람의나라 클래식 — 설치 세팅 레퍼런스 (스냅샷)

> **작성일**: 2026-05-21
> **기준 머신**: Lenovo ThinkPad E16 Gen 1 — 정상 동작 확인됨 (DXVK·안티치트·한글입력 모두 통과)
> **용도**: 다른 리눅스에 동일 환경을 구축할 때 대조·검증용 스냅샷
> **레포**: https://github.com/Jonas-Augustinus-Linus/baram-classic-linux.git

---

## 이 문서 사용법

- Ubuntu/Debian 계열이면 **레포의 `setup.sh` 실행이 정석**입니다. 이 문서는 그것을 대체하지 않습니다.
- 이 문서가 필요한 경우:
  1. `setup.sh`가 어딘가에서 실패해 **단계별 실제 값**을 보고 수동 진행할 때
  2. 새 머신이 이 머신과 **일치하는지 검증**할 때 (→ §8 체크리스트)
  3. **Ubuntu가 아닌 배포판**에서 구축할 때 (→ §10)
- `ngm-launch.sh` 전문이 §6에 들어있습니다 — 레포에 이미 반영돼 있지만, 수동 비교·포팅 시 대조용입니다.

---

## 1. 기준 머신 환경

| 항목 | 값 |
|------|-----|
| 기기 | Lenovo ThinkPad E16 Gen 1 |
| CPU | AMD Ryzen 3 7330U (Zen3 Barcelo, 4C/8T) |
| GPU | AMD Radeon iGPU (RENOIR) — Vulkan 드라이버 **RADV** |
| RAM | 16 GB |
| OS | Ubuntu 26.04 LTS (resolute) |
| 커널 | 7.0.0-14-generic |
| 세션 | Wayland (GNOME Shell 50.1) |

> 참고: 레포 README의 테스트 매트릭스(구성 B)는 같은 기기를 Ubuntu 24.04 / 커널 6.17에서 검증한 기록입니다. 현재 머신은 26.04 / 커널 7.0으로 업그레이드된 상태이며 동일하게 동작합니다. ntsync는 커널 6.14+ 필요 — 7.0은 충족.

---

## 2. 버전 매트릭스 (한눈에)

| 컴포넌트 | 버전 | 설치 방법 |
|----------|------|-----------|
| Wine | `wine-10.6.r0.g81425de3` (**TkG Staging Esync Fsync**) | Kron4ek 빌드 tarball |
| DXVK | **2.7.1** | GitHub 릴리즈 tarball 직접 설치 (winetricks 아님 — §4-2 주의) |
| WebView2 Runtime | 147.0.3912.72 | MS Evergreen 인스톨러를 Wine 안에 설치 |
| NGM (Nexon Game Manager) | platform.nexon.com 배포본 | Setup.exe를 Wine 안에 설치 |
| gamemode | 1.8.2-2build1 | apt |
| Mesa (RADV) | 26.0.3-1ubuntu1 | apt (`mesa-vulkan-drivers`, amd64+i386) |
| libvulkan1 | 1.4.341.0-1 | apt (amd64+i386) |
| vulkan-tools | 1.4.341.0 | apt |
| fcitx5-hangul | 5.1.9-1 | apt |
| ntsync | 커널 7.0 내장 모듈 | `modprobe ntsync` |

---

## 3. 경로 맵

| 항목 | 경로 |
|------|------|
| Wine 런너 디렉터리 | `~/.local/share/wine-runners/wine-10.6-staging-tkg-amd64-wow64` |
| wine 바이너리 | `~/.local/share/wine-runners/wine-10.6-staging-tkg-amd64-wow64/bin/wine` |
| wineserver | `~/.local/share/wine-runners/wine-10.6-staging-tkg-amd64-wow64/bin/wineserver` |
| Wine prefix | `~/.wine-msworlds` (WINEARCH=win64, wow64 모드) |
| 게임 본체 | `~/.wine-msworlds/drive_c/Nexon/MapleStory Worlds/msw.exe` |
| NGM 런처 | `~/.wine-msworlds/drive_c/ProgramData/Nexon/NGM/NGM64.exe` |
| WebView2 | `~/.wine-msworlds/drive_c/Program Files (x86)/Microsoft/EdgeWebView/` |
| dxvk.conf | `~/.wine-msworlds/drive_c/dxvk.conf` **그리고** 게임 폴더에도 1부 |
| 프로젝트 레포 | `~/baram-classic-linux` |
| ngm-launch.sh (설치본) | `~/.local/bin/ngm-launch.sh` |
| ngm:// 프로토콜 핸들러 | `~/.local/share/applications/ngm-handler.desktop` |
| GameMode 설정 | `~/.config/gamemode.ini` |
| fcitx5 설정 | `~/.config/fcitx5/{profile,config}` |
| Mesa 셰이더 캐시 | `~/.cache/mesa_shader_cache` |
| DXVK state 캐시 | `~/.wine-msworlds/` (prefix 루트) |

---

## 4. 설치 절차 — `setup.sh` 단계별 실제 적용값

### 4-0. Wine TkG 10.6 Staging 런너 — **필수**

```
URL : https://github.com/Kron4ek/Wine-Builds/releases/download/10.6/wine-10.6-staging-tkg-amd64-wow64.tar.xz
설치: ~/.local/share/wine-runners/ 에 tar -xf 로 압축 해제
검증: ~/.local/share/wine-runners/wine-10.6-staging-tkg-amd64-wow64/bin/wine --version
       → wine-10.6.r0.g81425de3 ( TkG Staging Esync Fsync )
```

**왜 필수인가**: 안티치트 `grap-core64.aes`가 Wine의 esync/fsync 시그니처를 검사해, **Staging 빌드가 아니면** `msw.exe`가 초기화 직후 ~45초 만에 `Application.Quit()`로 조용히 종료됩니다. 일반 `wine-stable`/`winehq-stable`로는 우회 불가.

### 4-1. Wine prefix 생성

```bash
export WINEPREFIX="$HOME/.wine-msworlds"
export WINEARCH=win64
"$WINE" wineboot --init
```

- 아키텍처: **win64** (wow64 — 64비트 + 32비트 호환 동시 지원)
- Windows 버전: **Windows 10 Pro, 빌드 19045** (Wine 기본값 그대로 — `winecfg`로 별도 변경하지 않음)

### 4-2. DXVK 2.7.1 설치

```
tarball: https://github.com/doitsujin/dxvk/releases/download/v2.7.1/dxvk-2.7.1.tar.gz
```

1. **builtin DLL 백업** — `system32`·`syswow64`의 `d3d11 d3d10core d3d10 d3d9 d3d8 dxgi` 를 `*.wine-orig`로 `cp -n` 보존
2. **DXVK DLL 복사**
   - `x64/{d3d11,d3d10core,d3d9,dxgi}.dll` → `~/.wine-msworlds/drive_c/windows/system32/`
   - `x32/{d3d11,d3d10core,d3d9,dxgi}.dll` → `~/.wine-msworlds/drive_c/windows/syswow64/`
3. **DLL override** — `HKCU\Software\Wine\DllOverrides` 에 각각 REG_SZ `native,builtin`:
   ```
   d3d11   = native,builtin
   d3d10core = native,builtin
   d3d10   = native,builtin
   d3d9    = native,builtin
   dxgi    = native,builtin
   ```

> ⚠️ **winetricks의 `dxvk` verb는 쓰지 말 것.** wow64 prefix에서 `wine cmd.exe` 호출이 깨져 실패합니다. 반드시 위처럼 GitHub tarball을 직접 풀어 복사하세요. (이 머신도 winetricks 미경유 — `winetricks.log` 없음)

**현재 설치 검증 결과** (정상):
```
d3d9.dll   : DXVK v2.7.1
d3d10core.dll : DXVK v2.7.1 (151 KB, builtin 79 KB와 크기 다름 — 교체됨)
d3d11.dll  : DXVK v2.7.1
dxgi.dll   : DXVK v2.7.1
```

### 4-3. Wine 레지스트리 최적화

`HKCU\Software\Wine\X11 Driver`:
| 키 | 값 | 효과 |
|----|-----|------|
| `UseTakeFocus` | `N` | Alt-Tab 후 키 입력 먹통 방지 |
| `GrabFullscreen` | `Y` | 풀스크린에서 키보드/마우스 캡처 |
| `Managed` | `Y` | WM 관리 창 |
| `Decorated` | `N` | 창 장식 제거 |
| `InputStyle` | `root` | fcitx5 호환 입력 스타일 |

`HKCU\Software\Wine\DirectInput`:
| 키 | 값 |
|----|-----|
| `MouseWarpOverride` | `force` |

`HKCU\Software\Wine\Fonts\Replacements` (한글 폰트 대체):
| 키 | 값 |
|----|-----|
| `Gulim`, `GulimChe`, `MS Gothic`, `Malgun Gothic` | `Noto Sans CJK KR` |
| `Batang`, `BatangChe` | `Noto Serif CJK KR` |

### 4-3-1. 한글 입력 (fcitx5) — **필수**

> GNOME 기본 입력기 **IBus는 Wine XIM과 호환되지 않습니다.** 반드시 fcitx5로 전환.

설치: `sudo apt install fcitx5 fcitx5-hangul fcitx5-config-qt`

`~/.config/fcitx5/profile`:
```ini
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=hangul

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=hangul
Layout=

[GroupOrder]
0=Default
```

`~/.config/fcitx5/config`:
```ini
[Hotkey]
EnumerateWithTriggerKeys=True
EnumerateSkipFirst=False

[Hotkey/TriggerKeys]
0=Hangul
1=Alt_R
2=Super+space

[Hotkey/EnumerateForwardKeys]
0=Super+space

[Hotkey/EnumerateBackwardKeys]
0=Shift+Super+space

[Behavior]
DefaultPageSize=5
ShareInputState=All
```

GNOME 키 매핑 (오른쪽 Alt = 한/영):
```bash
gsettings set org.gnome.desktop.input-sources xkb-options "['korean:ralt_hangul', 'korean:rctrl_hanja']"
```

폰트 심볼릭 링크 — `/usr/share/fonts/opentype/noto/` 의 `NotoSansCJK-{Regular,Bold}.ttc`, `NotoSerifCJK-{Regular,Bold}.ttc` 를 `~/.wine-msworlds/drive_c/windows/Fonts/` 에 `ln -sf`.

> 로그인 세션 환경에서 fcitx5가 입력기로 활성화돼 있어야 하며, 실행 시 `XMODIFIERS=@im=fcitx` 등(→§5)이 함께 적용돼야 합니다.

### 4-4. dxvk.conf

아래 내용을 **두 곳**에 둡니다 — `~/.wine-msworlds/drive_c/dxvk.conf` 와 게임 폴더(`drive_c/Nexon/MapleStory Worlds/dxvk.conf`). 실행 시 `DXVK_CONFIG_FILE` 환경변수가 전자를 가리킵니다.

```ini
dxvk.maxFrameLatency = 1
dxvk.numCompilerThreads = 0
dxvk.enableGraphicsPipelineLibrary = True
dxvk.enableMemoryDefrag = True
dxvk.enableStateCache = True

d3d11.cachedDynamicResources = "a"

# iGPU에서 DXVK가 1024MB 가짜 VRAM을 보고해 Unity RenderTexture 거대 할당이
# 막혀 비정상 종료된 이력이 있어 한도 상향.
dxgi.maxDeviceMemory = 4096
dxgi.maxSharedMemory = 8192
```

> `dxgi.maxDeviceMemory`/`maxSharedMemory`가 이 설정의 핵심. 빼면 플레이 중 `RenderTexture.Create failed`로 크래시할 수 있습니다 (→ §9).

### 4-5. ntsync 커널 모듈

```bash
sudo modprobe ntsync
echo "ntsync" | sudo tee /etc/modules-load.d/ntsync.conf
echo 'KERNEL=="ntsync", MODE="0666"' | sudo tee /etc/udev/rules.d/99-ntsync.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```
검증: `/dev/ntsync` 가 `crw-rw-rw-` 로 존재. (커널 6.14+ 필요)

### 4-6. 커널 sysctl 파라미터

`/etc/sysctl.d/99-gaming.conf`:
```
vm.max_map_count=2147483642
vm.swappiness=10
```

### 4-7. NGM 설치 + ngm:// 프로토콜 핸들러

```
NGM Setup.exe: https://platform.nexon.com/NGM/Bin/Setup.exe   → wine 로 실행
```
- `ngm-launch.sh` → `~/.local/bin/ngm-launch.sh` 로 복사 (`chmod +x`)
- `~/.local/share/applications/ngm-handler.desktop` 생성:
  ```ini
  [Desktop Entry]
  Name=Nexon Game Manager
  Exec=/home/<사용자>/.local/bin/ngm-launch.sh %u
  Type=Application
  MimeType=x-scheme-handler/ngm;
  NoDisplay=true
  StartupNotify=false
  ```
  > `Exec`은 **절대경로**여야 합니다. setup.sh가 heredoc으로 직접 생성하며, 레포의 `ngm-handler.desktop`(플레이스홀더 `NGM_LAUNCH_PATH` 포함)은 사용하지 않습니다.
- 등록:
  ```bash
  xdg-mime default ngm-handler.desktop x-scheme-handler/ngm
  update-desktop-database ~/.local/share/applications/
  ```
  검증: `xdg-mime query default x-scheme-handler/ngm` → `ngm-handler.desktop`

### 4-8. Microsoft Edge WebView2 Runtime — **필수**

```
URL: https://go.microsoft.com/fwlink/?linkid=2099617   (~170MB, Evergreen Standalone)
설치: wine /tmp/WebView2.exe /silent /install
```
검증: `~/.wine-msworlds/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application/<버전>/msedgewebview2.exe` 존재 (현재: `147.0.3912.72`)

**왜 필수인가**: `NexonLauncher64.exe`의 UI가 WebView2에 의존합니다. 없으면 실행 ~10초 만에 크래시 다이얼로그 없이 조용히 종료됩니다.

---

## 5. 실행 시 환경변수 (전체)

`ngm-launch.sh`와 `launch.sh --cdp`가 게임 실행 직전 export하는 전체 목록:

| 분류 | 변수 | 값 |
|------|------|-----|
| 한글 | `XMODIFIERS` | `@im=fcitx` |
| 한글 | `GTK_IM_MODULE` / `QT_IM_MODULE` / `SDL_IM_MODULE` | `fcitx` |
| 한글 | `INPUT_METHOD` | `fcitx` |
| Wine | `WINEPREFIX` | `~/.wine-msworlds` |
| Wine | `WINEFSYNC` / `WINEESYNC` | `1` |
| Wine | `STAGING_SHARED_MEMORY` | `1` |
| Wine | `WINEDEBUG` | `-all` |
| Wine | `WINE_LARGE_ADDRESS_AWARE` | `1` |
| DXVK | `DXVK_ASYNC` | `1` |
| DXVK | `DXVK_STATE_CACHE_PATH` | `$WINEPREFIX` |
| DXVK | `DXVK_CONFIG_FILE` | `$WINEPREFIX/drive_c/dxvk.conf` |
| Mesa/RADV | `mesa_glthread` | `true` |
| Mesa/RADV | `MESA_NO_ERROR` | `1` |
| Mesa/RADV | `MESA_SHADER_CACHE_DIR` | `~/.cache/mesa_shader_cache` |
| Mesa/RADV | `MESA_SHADER_CACHE_MAX_SIZE` | `4G` |
| Mesa/RADV | `RADV_DEBUG` | `nozerovram` |
| Mesa/RADV | `AMD_VULKAN_ICD` | `RADV` |
| Mesa/RADV | `RADV_PERFTEST` | `gpl` |
| 셰이더 | `__GL_SHADER_DISK_CACHE` | `1` |
| 셰이더 | `__GL_SHADER_DISK_CACHE_SKIP_CLEANUP` | `1` |

> `AMD_VULKAN_ICD=RADV`는 AMD 전용입니다. NVIDIA GPU 머신이면 이 줄을 제거하고, `RADV_*` 변수도 무시됩니다.

---

## 6. `ngm-launch.sh` — 핵심 구성 (참조용 전문)

레포의 `ngm-launch.sh`에는 다음 세 가지가 모두 반영돼 있습니다. 새 머신은 `git clone` → `setup.sh` 실행만으로 그대로 들어갑니다.

1. **`systemd-inhibit`** — 게임 중 자동 절전/idle suspend 차단 (절전 진입 시 세션 끊김·캐릭터 손해)
2. **`cleanup` 트랩** — 비정상 종료 시 wine 잔존 프로세스 정리
3. **`wineserver --wait`** — NGM64.exe는 게임 본체(msw.exe)를 스폰하고 즉시 종료하는 *런처*이므로, 이게 없으면 cleanup 트랩이 방금 띄운 게임을 `wineserver -k`로 죽임 → Player.log 0바이트 + 즉시 종료

아래는 수동 비교·타 배포판 포팅 시 대조용 전문입니다.

```bash
#!/bin/bash
# ngm:// 프로토콜 핸들러 래퍼
# 브라우저에서 "클라이언트 실행" 클릭 시 자동 호출됩니다.
# 모든 Wine/DXVK/Mesa 최적화 환경변수를 설정하고 NGM64.exe를 실행합니다.

NGM_URL="$1"
if [ -z "$NGM_URL" ]; then
    echo "Usage: $0 <ngm://...>"
    exit 1
fi

WINE_DIR="${WINE_DIR:-$HOME/.local/share/wine-runners/wine-10.6-staging-tkg-amd64-wow64}"
WINE="$WINE_DIR/bin/wine"
WINEPREFIX="${WINEPREFIX:-$HOME/.wine-msworlds}"
NGM_EXE="$WINEPREFIX/drive_c/ProgramData/Nexon/NGM/NGM64.exe"

# 한글 입력 (fcitx5)
export XMODIFIERS='@im=fcitx'
export GTK_IM_MODULE='fcitx'
export QT_IM_MODULE='fcitx'
export SDL_IM_MODULE='fcitx'
export INPUT_METHOD='fcitx'

# Wine
export WINEPREFIX
export WINEFSYNC=1
export WINEESYNC=1
export STAGING_SHARED_MEMORY=1
export WINEDEBUG=-all
export WINE_LARGE_ADDRESS_AWARE=1

# DXVK
export DXVK_ASYNC=1
export DXVK_STATE_CACHE_PATH="$WINEPREFIX"
export DXVK_CONFIG_FILE="$WINEPREFIX/drive_c/dxvk.conf"

# AMD Mesa/RADV
export mesa_glthread=true
export MESA_NO_ERROR=1
export MESA_SHADER_CACHE_DIR="$HOME/.cache/mesa_shader_cache"
export MESA_SHADER_CACHE_MAX_SIZE=4G
export RADV_DEBUG=nozerovram
export AMD_VULKAN_ICD=RADV
export RADV_PERFTEST=gpl

# 셰이더 캐시
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1

# 게임 종료 후 정리 (정상/비정상 종료 모두 처리)
cleanup() {
    echo ""
    echo "[*] cleanup 시작..."
    if [ -x "$WINE_DIR/bin/wineserver" ]; then
        WINEPREFIX="$WINEPREFIX" "$WINE_DIR/bin/wineserver" -k 2>/dev/null || true
        WINEPREFIX="$WINEPREFIX" timeout 5 "$WINE_DIR/bin/wineserver" -w 2>/dev/null || true
    fi
    pkill -KILL -f "${WINEPREFIX}/" 2>/dev/null || true
    systemctl --user start tracker-miner-fs-3.service 2>/dev/null || true
    echo "[*] cleanup 완료"
}
trap cleanup EXIT INT TERM HUP

# Tracker 인덱서 중지 (I/O 경쟁 방지)
systemctl --user stop tracker-miner-fs-3.service 2>/dev/null

# 게임 실행 (systemd-inhibit으로 게임 중 자동 절전/idle 차단)
# NGM64.exe는 실제 게임(msw.exe)을 스폰하고 즉시 종료하므로, wineserver --wait으로
# 본체 종료까지 대기해야 cleanup 트랩이 게임을 죽이지 않는다.
GAME_CMD=("$WINE" "$NGM_EXE" "$NGM_URL")
if command -v gamemoderun &>/dev/null; then
    GAME_CMD=(gamemoderun "${GAME_CMD[@]}")
fi

WINESERVER="$WINE_DIR/bin/wineserver"
export WINESERVER WINEPREFIX

systemd-inhibit \
    --what=idle:sleep \
    --who="Baram Classic" \
    --why="게임 실행 중" \
    bash -c '"$@"; echo "[*] NGM 런처 종료, 게임 본체 종료 대기..."; "$WINESERVER" --wait; echo "[*] 게임 본체 종료"' \
    _ "${GAME_CMD[@]}"
```

> `--what`에 `handle-lid-switch`는 일부러 넣지 않습니다 — 사용자가 의도적으로 노트북 덮개를 닫으면 절전은 동작해야 하므로.

---

## 7. GameMode 설정

`gamemode.ini` → `~/.config/gamemode.ini` 로 복사:

```ini
[general]
renice=10
desiredgov=performance
igpu_desiredgov=performance
defaultgov=schedutil
softrealtime=auto
ioprio=0
inhibit_screensaver=1
disable_splitlock=1

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high

[custom]
start=notify-send "GameMode 활성화" "최고 성능 모드" -i applications-games
end=notify-send "GameMode 비활성화" "일반 모드로 복귀" -i applications-games
```

> `inhibit_screensaver=1`만으로는 sleep 차단을 보장하지 못합니다 → §6의 `systemd-inhibit`과 병행해야 안전.
> 32비트 경고(`libgamemodeauto.so.0 (i386)`)가 거슬리면 `sudo apt install libgamemode0:i386`.

**`gamemode` 그룹 가입 — 필수**: `gamemoded`가 게임 프로세스 우선순위(`renice`)를 올리려면 사용자가 `gamemode` 그룹 멤버여야 합니다. 미가입 시 `gamemoded`는 `Failed to renice ... Permission denied`만 남기고 우선순위 부스트가 통째로 빠집니다 (`limits.d`의 `@gamemode - nice -10` 규칙 미적용).

```bash
sudo usermod -aG gamemode "$USER"   # 재로그인 후 적용
id -nG | grep -qw gamemode && echo OK
```

`setup.sh`의 [6-1/8] 단계가 자동으로 그룹 가입을 시도합니다 (이미 멤버면 skip).

---

## 8. 새 머신 검증 체크리스트

설치 후 아래를 순서대로 확인하세요. 모두 통과하면 정상입니다.

```bash
# 1) Wine — "TkG Staging Esync Fsync" 문자열이 보여야 함
~/.local/share/wine-runners/wine-10.6-staging-tkg-amd64-wow64/bin/wine --version

# 2) DXVK — 출력이 있어야 함 (없으면 builtin = DXVK 미설치)
strings ~/.wine-msworlds/drive_c/windows/system32/d3d11.dll | grep -m1 DXVK_CONFIG_FILE

# 3) ntsync — crw-rw-rw- 로 존재해야 함
ls -l /dev/ntsync

# 4) sysctl — 2147483642 / 10
sysctl vm.max_map_count vm.swappiness

# 5) ngm:// 핸들러 — ngm-handler.desktop 출력
xdg-mime query default x-scheme-handler/ngm

# 6) WebView2 — 버전 폴더가 보여야 함
ls -d ~/.wine-msworlds/drive_c/Program\ Files\ \(x86\)/Microsoft/EdgeWebView/Application/*/

# 7) ngm-launch.sh — 아래 두 줄 모두 grep 되어야 함 (§6 반영 확인)
grep -c 'systemd-inhibit\|wineserver --wait' ~/.local/bin/ngm-launch.sh   # → 2 이상

# 8) gamemode 그룹 — 출력에 gamemode 가 보여야 함 (없으면 §7 그룹 가입 후 재로그인)
id -nG | tr ' ' '\n' | grep -w gamemode || echo "(gamemode 그룹 아님 — renice Permission denied 발생)"

# 9) [게임 1회 실행 후] DXVK 작동 — Renderer가 실제 GPU여야 함
grep -A4 'Direct3D:' "~/.wine-msworlds/drive_c/users/$USER/AppData/LocalLow/nexon/MapleStory Worlds/Player.log"
```

**9번 정상 출력 예시 (이 머신)**:
```
Direct3D:
    Version:  Direct3D 11.0 [level 11.1]
    Renderer: AMD Radeon Graphics (RADV RENOIR) (ID=0x15e7)
    VRAM:     4096 MB
```
→ `Renderer`에 실제 GPU명, `VRAM: 4096 MB`이면 정상.
→ 만약 `ATI Radeon HD 5600 Series` / `VRAM: 1024 MB`가 보이면 **DXVK 미설치**(WineD3D fallback) 신호 — §4-2 재확인.

---

## 9. 크래시 트러블슈팅 빠른 참조

| 증상 | 원인 | 확인 / 해결 |
|------|------|-------------|
| NexonLauncher64가 ~10초 후 조용히 종료 | WebView2 런타임 없음 | §4-8 — EdgeWebView 폴더 확인 후 재설치 |
| msw.exe가 ~45초 후 종료, `Player.log` 끝에 `ShutdownInProgress`만 | 안티치트가 비-staging Wine 감지 | §4-0 — `wine --version`에 `Staging Esync Fsync` 있는지 |
| 플레이 중 종료, `Player.log`에 `RenderTexture.Create failed` + Renderer `ATI Radeon HD 5600`/VRAM 1024MB | DXVK 미설치 (WineD3D fallback) | §4-2 — DXVK 재설치, §8-2 검증 |
| 플레이 중 종료, DXVK는 정상인데 `RenderTexture.Create failed` | `dxgi.maxDeviceMemory` 미설정 | §4-4 — dxvk.conf 두 곳에 배치 |
| `Player.log`가 0바이트 + 직후 `[*] cleanup 시작` 로그 | 구버전 `ngm-launch.sh` (NGM64를 본체로 오인) | §6 — `wineserver --wait` 포함 버전으로 교체 |
| 게임 중 시스템이 절전 진입 | 구버전 `ngm-launch.sh` (`systemd-inhibit` 없음) | §6 — 전문으로 교체 |
| GameMode 알림은 뜨는데 CPU 우선순위 부스트 누락 / journal에 `Failed to renice ... Permission denied` | `gamemode` 그룹 미가입 — `gamemoded`가 renice 권한 없음 | §7 — `sudo usermod -aG gamemode $USER` 후 재로그인 (§8-8 검증) |
| 한글 입력이 전혀 안 됨 | IBus 사용 중 / fcitx5 미구성 | §4-3-1 — fcitx5로 전환, `XMODIFIERS` 확인 |

**조용한 크래시 디버깅**: `ngm-launch.sh`의 `WINEDEBUG=-all`을 일시적으로 `WINEDEBUG=+err,+seh,+module,fixme-all`로 바꾸고 출력을 파일로 리다이렉트하면 원인이 드러납니다. 디버깅이 끝나면 **반드시 `-all`로 되돌릴 것** — trace 로그가 초당 수십 줄 쌓이면 SEH 캐스케이드를 가속합니다.

---

## 10. Ubuntu가 아닌 배포판일 때

`setup.sh`는 `apt`/`dpkg`를 쓰므로 다른 배포판에선 패키지 설치만 수동으로 합니다. 나머지 단계(Wine/DXVK tarball, 레지스트리, 환경변수)는 배포판 무관하게 동일합니다.

| Ubuntu (apt) | Fedora (dnf) | Arch (pacman) |
|--------------|--------------|----------------|
| `fcitx5 fcitx5-hangul fcitx5-config-qt` | `fcitx5 fcitx5-hangul fcitx5-configtool` | `fcitx5 fcitx5-hangul fcitx5-configtool` |
| `gamemode` | `gamemode` | `gamemode lib32-gamemode` |
| `mesa-vulkan-drivers` | `mesa-vulkan-drivers vulkan-tools` | `vulkan-radeon lib32-vulkan-radeon vulkan-tools` |
| `winetricks` | `winetricks` | `winetricks` |

- **ntsync**: 커널 6.14+ 내장. 배포판 무관하게 `modprobe ntsync` + udev 규칙(§4-5).
- **Noto CJK 폰트** 경로는 배포판마다 다릅니다 — `fc-list | grep -i "noto.*cjk"`로 실제 경로를 찾아 §4-3-1의 심볼릭 링크 대상을 맞추세요.
- **GameMode iGPU 최적화**(`apply_gpu_optimisations`)는 AMD/Mesa 기준입니다.
