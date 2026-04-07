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

# Tracker 인덱서 중지 (I/O 경쟁 방지)
systemctl --user stop tracker-miner-fs-3.service 2>/dev/null

# 게임 실행
if command -v gamemoderun &>/dev/null; then
    gamemoderun "$WINE" "$NGM_EXE" "$NGM_URL"
else
    "$WINE" "$NGM_EXE" "$NGM_URL"
fi

# 게임 종료 후 Tracker 복구
systemctl --user start tracker-miner-fs-3.service 2>/dev/null
