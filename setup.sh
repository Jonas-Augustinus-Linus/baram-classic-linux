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
echo "[2/8] DXVK 설치..."
if file "$WINEPREFIX/drive_c/windows/system32/d3d11.dll" 2>/dev/null | grep -q "PE32+"; then
  echo "  DXVK 이미 설치됨"
else
  if command -v winetricks &>/dev/null; then
    WINEPREFIX="$WINEPREFIX" winetricks -q dxvk
  else
    echo "  [!] winetricks가 필요합니다: sudo apt install winetricks"
    exit 1
  fi
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
