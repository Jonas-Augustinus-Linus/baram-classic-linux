#!/bin/bash
# 바람의나라 클래식 Linux 초기 설정 스크립트
# Wine prefix 생성, DXVK 설치, 레지스트리 최적화, NGM 설치

set -e

WINE_DIR="${WINE_DIR:-$HOME/.local/share/wine-runners/wine-10.6-staging-tkg-amd64-wow64}"
WINE="$WINE_DIR/bin/wine"
WINEPREFIX="${WINEPREFIX:-$HOME/.wine-msworlds}"

echo "=========================================="
echo "  바람의나라 클래식 초기 설정"
echo "=========================================="

# 0. Wine TkG 10.6 Staging 다운로드 (없으면)
# grap-core64.aes 안티치트가 일반 wine-stable을 감지하므로 Staging 빌드 필수.
if [ ! -f "$WINE" ]; then
  echo "[0/8] Wine TkG 10.6 Staging 다운로드 (~70MB)..."
  mkdir -p "$HOME/.local/share/wine-runners"
  TKG_URL="https://github.com/Kron4ek/Wine-Builds/releases/download/10.6/wine-10.6-staging-tkg-amd64-wow64.tar.xz"
  wget -q --show-progress "$TKG_URL" -O /tmp/wine-tkg.tar.xz || {
    echo "[!] Wine TkG 다운로드 실패."
    echo "    수동 설치: https://github.com/Kron4ek/Wine-Builds/releases"
    exit 1
  }
  tar -xf /tmp/wine-tkg.tar.xz -C "$HOME/.local/share/wine-runners"
  rm -f /tmp/wine-tkg.tar.xz
  if [ ! -f "$WINE" ]; then
    echo "[!] 추출 후에도 Wine 바이너리를 찾을 수 없습니다: $WINE"
    exit 1
  fi
fi
echo "  Wine: $("$WINE" --version)"

# 1. Wine prefix 생성
echo "[1/8] Wine prefix 생성..."
export WINEPREFIX
export WINEARCH=win64
export WINEDEBUG=-all
if [ ! -d "$WINEPREFIX" ]; then
  "$WINE" wineboot --init 2>/dev/null
  sleep 3
else
  echo "  이미 존재합니다: $WINEPREFIX"
fi

# 2. DXVK 설치
# Wine builtin d3d11.dll도 PE32+이므로 file로는 구별 불가.
# DXVK 마커("dxvk-2.")로 판별하고, 누락 시 GitHub 릴리즈에서 직접 받아 설치.
echo "[2/8] DXVK 설치..."
DXVK_VER="2.7.1"
if strings "$WINEPREFIX/drive_c/windows/system32/d3d11.dll" 2>/dev/null | grep -q "DXVK_CONFIG_FILE"; then
  echo "  DXVK 이미 설치됨"
else
  TARBALL="/tmp/dxvk-${DXVK_VER}.tar.gz"
  DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/v${DXVK_VER}/dxvk-${DXVK_VER}.tar.gz"
  if [ ! -s "$TARBALL" ]; then
    echo "  DXVK ${DXVK_VER} 다운로드..."
    wget -q --show-progress "$DXVK_URL" -O "$TARBALL" || curl -fsSL "$DXVK_URL" -o "$TARBALL" || {
      echo "  [!] DXVK 다운로드 실패"; exit 1
    }
  fi
  tar -xzf "$TARBALL" -C /tmp
  # builtin DLL 백업 (.wine-orig)
  for d in system32 syswow64; do
    for f in d3d11.dll d3d10core.dll d3d10.dll d3d9.dll d3d8.dll dxgi.dll; do
      [ -f "$WINEPREFIX/drive_c/windows/$d/$f" ] && \
        cp -n "$WINEPREFIX/drive_c/windows/$d/$f" "$WINEPREFIX/drive_c/windows/$d/$f.wine-orig" 2>/dev/null
    done
  done
  cp /tmp/dxvk-${DXVK_VER}/x64/{d3d11,d3d10core,d3d9,dxgi}.dll "$WINEPREFIX/drive_c/windows/system32/"
  cp /tmp/dxvk-${DXVK_VER}/x32/{d3d11,d3d10core,d3d9,dxgi}.dll "$WINEPREFIX/drive_c/windows/syswow64/"
  # DLL override: native(=DXVK) 우선, 실패 시 builtin(Wine) fallback
  for dll in d3d11 d3d10core d3d10 d3d9 dxgi; do
    "$WINE" reg add 'HKCU\Software\Wine\DllOverrides' /v "$dll" /t REG_SZ /d 'native,builtin' /f 2>/dev/null
  done
  echo "  DXVK ${DXVK_VER} 설치 완료"
fi

# 3. Wine 레지스트리 최적화
echo "[3/8] Wine 레지스트리 최적화..."
"$WINE" reg add 'HKCU\Software\Wine\X11 Driver' /v UseTakeFocus /t REG_SZ /d N /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\X11 Driver' /v GrabFullscreen /t REG_SZ /d Y /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\X11 Driver' /v Managed /t REG_SZ /d Y /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\X11 Driver' /v Decorated /t REG_SZ /d N /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\DirectInput' /v MouseWarpOverride /t REG_SZ /d force /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\X11 Driver' /v InputStyle /t REG_SZ /d root /f 2>/dev/null

# 4-1. fcitx5-hangul 설치 (GNOME의 IBus는 Wine XIM과 호환 불가)
echo "[3-1/8] fcitx5-hangul 설치..."
if ! dpkg -l fcitx5-hangul 2>/dev/null | grep -q "^ii"; then
  sudo apt install -y fcitx5 fcitx5-hangul fcitx5-config-qt 2>/dev/null
fi

# fcitx5 프로필 설정
mkdir -p "$HOME/.config/fcitx5/conf"
cat > "$HOME/.config/fcitx5/profile" << 'FCITXEOF'
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
FCITXEOF

cat > "$HOME/.config/fcitx5/config" << 'FCITXEOF'
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
FCITXEOF

# 오른쪽 Alt를 한/영 키로 매핑
gsettings set org.gnome.desktop.input-sources xkb-options "['korean:ralt_hangul', 'korean:rctrl_hanja']" 2>/dev/null
echo "  fcitx5 설정 완료"

# 한글 폰트 대체 (Noto CJK 심볼릭 링크)
WINE_FONTS="$WINEPREFIX/drive_c/windows/Fonts"
for f in NotoSansCJK-Regular.ttc NotoSansCJK-Bold.ttc NotoSerifCJK-Regular.ttc NotoSerifCJK-Bold.ttc; do
  [ -f "/usr/share/fonts/opentype/noto/$f" ] && ln -sf "/usr/share/fonts/opentype/noto/$f" "$WINE_FONTS/$f"
done

# 한글 폰트 대체 레지스트리
"$WINE" reg add 'HKCU\Software\Wine\Fonts\Replacements' /v Gulim /t REG_SZ /d 'Noto Sans CJK KR' /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\Fonts\Replacements' /v GulimChe /t REG_SZ /d 'Noto Sans CJK KR' /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\Fonts\Replacements' /v Batang /t REG_SZ /d 'Noto Serif CJK KR' /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\Fonts\Replacements' /v BatangChe /t REG_SZ /d 'Noto Serif CJK KR' /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\Fonts\Replacements' /v 'Malgun Gothic' /t REG_SZ /d 'Noto Sans CJK KR' /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\Fonts\Replacements' /v 'MS Gothic' /t REG_SZ /d 'Noto Sans CJK KR' /f 2>/dev/null
echo "  완료"

# 4. DXVK 설정 파일
echo "[4/8] DXVK 설정..."
cat > "$WINEPREFIX/drive_c/dxvk.conf" << 'EOF'
dxvk.maxFrameLatency = 1
dxvk.numCompilerThreads = 0
dxvk.enableGraphicsPipelineLibrary = True
dxvk.enableMemoryDefrag = True
dxvk.enableStateCache = True

d3d11.cachedDynamicResources = "a"

# iGPU에서 DXVK가 1024MB 가짜 VRAM을 보고해 Unity의 RenderTexture 거대 할당이
# 막혀 비정상 종료되는 사례가 있었음. 시스템 RAM 8GB+ 기준으로 한도 상향.
dxgi.maxDeviceMemory = 4096
dxgi.maxSharedMemory = 8192
EOF
echo "  완료"

# 5. ntsync 커널 모듈
echo "[5/8] ntsync 커널 모듈..."
if [ -c /dev/ntsync ]; then
  echo "  이미 로드됨"
else
  if sudo modprobe ntsync 2>/dev/null; then
    echo "ntsync" | sudo tee /etc/modules-load.d/ntsync.conf >/dev/null
    echo 'KERNEL=="ntsync", MODE="0666"' | sudo tee /etc/udev/rules.d/99-ntsync.rules >/dev/null
    sudo udevadm control --reload-rules && sudo udevadm trigger
    echo "  로드 및 영구 설정 완료"
  else
    echo "  [!] ntsync 모듈을 로드할 수 없습니다 (커널 6.14+ 필요)"
  fi
fi

# 6. 커널 파라미터
echo "[6/8] 커널 파라미터 최적화..."
if [ "$(cat /proc/sys/vm/max_map_count)" -lt 2147483642 ]; then
  sudo sysctl -w vm.max_map_count=2147483642 >/dev/null
  sudo sysctl -w vm.swappiness=10 >/dev/null
  echo -e "vm.max_map_count=2147483642\nvm.swappiness=10" | sudo tee /etc/sysctl.d/99-gaming.conf >/dev/null
  echo "  완료"
else
  echo "  이미 설정됨"
fi

# 6-1. GameMode 설정 (CPU/GPU 성능 모드 + 게임 프로세스 우선순위)
echo "[6-1/8] GameMode 설정..."
if ! command -v gamemoderun &>/dev/null; then
  sudo apt install -y gamemode 2>/dev/null || echo "  [!] gamemode 설치 실패 — 수동: sudo apt install gamemode"
fi
GM_SRC="$(cd "$(dirname "$0")" && pwd)/gamemode.ini"
[ -f "$GM_SRC" ] && cp "$GM_SRC" "$HOME/.config/gamemode.ini" && echo "  gamemode.ini → ~/.config/"
# gamemode 그룹 미가입 시 gamemoded가 게임 우선순위(renice)를 못 올리고
# 'Failed to renice ... Permission denied'만 남긴다 (limits.d의 @gamemode nice 규칙 미적용)
if getent group gamemode >/dev/null 2>&1; then
  if id -nG "$USER" | grep -qw gamemode; then
    echo "  gamemode 그룹 OK"
  else
    sudo usermod -aG gamemode "$USER" && echo "  $USER → gamemode 그룹 추가 (재로그인 후 적용)"
  fi
fi

# 7. NGM 설치 및 프로토콜 핸들러
echo "[7/8] NGM 설치 및 프로토콜 핸들러..."
if [ ! -f "$WINEPREFIX/drive_c/ProgramData/Nexon/NGM/NGM64.exe" ]; then
  echo "  NGM 다운로드 중..."
  wget -q -O /tmp/NGM_Setup.exe "https://platform.nexon.com/NGM/Bin/Setup.exe"
  "$WINE" /tmp/NGM_Setup.exe 2>/dev/null &
  sleep 15
  echo "  NGM 설치 완료"
fi

# ngm-launch.sh 설치
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NGM_LAUNCH="$HOME/.local/bin/ngm-launch.sh"
mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/ngm-launch.sh" "$NGM_LAUNCH"
chmod +x "$NGM_LAUNCH"
echo "  ngm-launch.sh → $NGM_LAUNCH"

# ngm:// 프로토콜 핸들러 등록
cat > "$HOME/.local/share/applications/ngm-handler.desktop" << EOF
[Desktop Entry]
Name=Nexon Game Manager
Exec=$NGM_LAUNCH %u
Type=Application
MimeType=x-scheme-handler/ngm;
NoDisplay=true
StartupNotify=false
EOF

xdg-mime default ngm-handler.desktop x-scheme-handler/ngm 2>/dev/null
update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null

# 8. Microsoft Edge WebView2 Runtime 설치
# NexonLauncher64.exe가 Vuplex/WebView2에 의존. 없으면 10초 안에 조용히 크래시함.
echo "[8/8] WebView2 Runtime 설치..."
WEBVIEW_GLOB="$WINEPREFIX/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application"
if ls -d "$WEBVIEW_GLOB"/*/msedgewebview2.exe 2>/dev/null | grep -q .; then
  echo "  이미 설치됨"
else
  echo "  다운로드 중 (~170MB)..."
  WV_URL="https://go.microsoft.com/fwlink/?linkid=2099617"
  wget -q --show-progress "$WV_URL" -O /tmp/WebView2.exe || {
    echo "  [!] 다운로드 실패 — 수동 설치 필요"
    echo "      https://developer.microsoft.com/microsoft-edge/webview2/"
  }
  if [ -s /tmp/WebView2.exe ]; then
    "$WINE" /tmp/WebView2.exe /silent /install 2>/dev/null
    # 백그라운드에 남은 Edge Updater(wine 내부) 정리
    pkill -f 'MicrosoftEdgeUpdate' 2>/dev/null || true
    rm -f /tmp/WebView2.exe
  fi
  if ls -d "$WEBVIEW_GLOB"/*/msedgewebview2.exe 2>/dev/null | grep -q .; then
    echo "  완료"
  else
    echo "  [!] 설치 확인 실패 — NexonLauncher64가 크래시할 수 있음"
  fi
fi

echo ""
echo "=========================================="
echo "  설정 완료!"
echo "=========================================="
echo ""
echo "다음 단계:"
echo "  1. launch.sh 상단에 넥슨 계정 정보 입력"
echo "  2. Chrome에 넥슨 계정으로 로그인 (Profile 1 사용)"
echo "  3. ./launch.sh 실행"
