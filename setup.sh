#!/bin/bash
# 바람의나라 클래식 Linux 초기 설정 스크립트
# Wine prefix 생성, DXVK 설치, 레지스트리 최적화, NGM 설치

set -e

WINE_DIR="${WINE_DIR:-$HOME/.local/share/wine-runners/wine-10.6-staging-tkg-amd64-wow64}"
WINE="$WINE_DIR/bin/wine"
WINEPREFIX="${WINEPREFIX:-$HOME/.wine-msworlds}"

if [ ! -f "$WINE" ]; then
  echo "[!] Wine을 찾을 수 없습니다: $WINE"
  echo "    Wine TkG Staging을 먼저 설치하세요."
  echo "    https://github.com/Frogging-Family/wine-tkg-git"
  exit 1
fi

echo "=========================================="
echo "  바람의나라 클래식 초기 설정"
echo "=========================================="

# 1. Wine prefix 생성
echo "[1/7] Wine prefix 생성..."
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
echo "[2/7] DXVK 설치..."
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
echo "[3/7] Wine 레지스트리 최적화..."
"$WINE" reg add 'HKCU\Software\Wine\X11 Driver' /v UseTakeFocus /t REG_SZ /d N /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\X11 Driver' /v GrabFullscreen /t REG_SZ /d Y /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\X11 Driver' /v Managed /t REG_SZ /d Y /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\X11 Driver' /v Decorated /t REG_SZ /d N /f 2>/dev/null
"$WINE" reg add 'HKCU\Software\Wine\DirectInput' /v MouseWarpOverride /t REG_SZ /d force /f 2>/dev/null
echo "  완료"

# 4. DXVK 설정 파일
echo "[4/7] DXVK 설정..."
cat > "$WINEPREFIX/drive_c/dxvk.conf" << 'EOF'
dxvk.maxFrameLatency = 1
dxvk.numCompilerThreads = 0
dxvk.enableGraphicsPipelineLibrary = True
dxvk.enableMemoryDefrag = True
EOF
echo "  완료"

# 5. ntsync 커널 모듈
echo "[5/7] ntsync 커널 모듈..."
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
echo "[6/7] 커널 파라미터 최적화..."
if [ "$(cat /proc/sys/vm/max_map_count)" -lt 2147483642 ]; then
  sudo sysctl -w vm.max_map_count=2147483642 >/dev/null
  sudo sysctl -w vm.swappiness=10 >/dev/null
  echo -e "vm.max_map_count=2147483642\nvm.swappiness=10" | sudo tee /etc/sysctl.d/99-gaming.conf >/dev/null
  echo "  완료"
else
  echo "  이미 설정됨"
fi

# 7. NGM 설치 및 프로토콜 핸들러
echo "[7/7] NGM 설치 및 프로토콜 핸들러..."
if [ ! -f "$WINEPREFIX/drive_c/ProgramData/Nexon/NGM/NGM64.exe" ]; then
  echo "  NGM 다운로드 중..."
  wget -q -O /tmp/NGM_Setup.exe "https://platform.nexon.com/NGM/Bin/Setup.exe"
  "$WINE" /tmp/NGM_Setup.exe 2>/dev/null &
  sleep 15
  echo "  NGM 설치 완료"
fi

# ngm:// 프로토콜 핸들러 등록
cat > "$HOME/.local/share/applications/ngm-handler.desktop" << EOF
[Desktop Entry]
Name=Nexon Game Manager
Exec=env WINEPREFIX=$WINEPREFIX WINEDEBUG=-all DISPLAY=:0 XMODIFIERS= GTK_IM_MODULE= QT_IM_MODULE= WINEFSYNC=1 WINEESYNC=1 STAGING_SHARED_MEMORY=1 DXVK_ASYNC=1 DXVK_CONFIG_FILE=$WINEPREFIX/drive_c/dxvk.conf mesa_glthread=true MESA_NO_ERROR=1 RADV_DEBUG=nozerovram AMD_VULKAN_ICD=RADV $WINE "$WINEPREFIX/drive_c/ProgramData/Nexon/NGM/NGM64.exe" "%u"
Type=Application
MimeType=x-scheme-handler/ngm;
NoDisplay=true
StartupNotify=false
EOF

xdg-mime default ngm-handler.desktop x-scheme-handler/ngm 2>/dev/null
update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null

echo ""
echo "=========================================="
echo "  설정 완료!"
echo "=========================================="
echo ""
echo "다음 단계:"
echo "  1. launch.sh 상단에 넥슨 계정 정보 입력"
echo "  2. Chrome에 넥슨 계정으로 로그인 (Profile 1 사용)"
echo "  3. ./launch.sh 실행"
