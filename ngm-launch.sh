#!/bin/bash
# ngm:// 프로토콜 핸들러 래퍼 — 바람의나라 클래식 (MapleStory Worlds)
# 브라우저에서 "클라이언트 실행" 클릭 시 자동 호출됩니다.
#
# 절전 차단 동작 (2026-05-31 수정):
#   게임이 도는 동안만 systemd-inhibit으로 idle/sleep을 막는다.
#   [핵심] 과거엔 `wineserver --wait`로 "모든 wine 종료"를 기다렸으나,
#   게임 본체(msw.exe)를 닫아도 MicrosoftEdgeUpdate/winedevice/plugplay 등
#   백그라운드가 안 죽어 --wait가 영원히 안 끝나고 inhibit 락이 잔존 →
#   절전/모니터OFF가 막혀 재부팅해야 했음.
#   이제는 게임 본체(msw.exe)만 폴링해서, 닫히면 wineserver -k로 잔존 wine을
#   강제 정리하고 즉시 락을 해제한다. trap으로 어떤 종료 경로든 정리 보장.

NGM_URL="$1"
if [ -z "$NGM_URL" ]; then
    echo "Usage: $0 <ngm://...>"
    exit 1
fi

WINE_DIR="${WINE_DIR:-$HOME/.local/share/wine-runners/wine-10.6-staging-tkg-amd64-wow64}"
WINE="$WINE_DIR/bin/wine"
WINEPREFIX="${WINEPREFIX:-$HOME/.wine-msworlds}"
NGM_EXE="$WINEPREFIX/drive_c/ProgramData/Nexon/NGM/NGM64.exe"
WINESERVER="$WINE_DIR/bin/wineserver"

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

export WINESERVER

# 게임 종료/중단 시 정리 (정상/Ctrl-C/종료 시그널 모두) — 잔존 wine 강제 종료 → 락 해제
cleanup() {
    echo ""
    echo "[*] cleanup 시작 — 잔존 wine 정리..."
    if [ -x "$WINESERVER" ]; then
        WINEPREFIX="$WINEPREFIX" "$WINESERVER" -k 2>/dev/null || true
        WINEPREFIX="$WINEPREFIX" timeout 5 "$WINESERVER" -w 2>/dev/null || true
    fi
    pkill -KILL -f "${WINEPREFIX}/" 2>/dev/null || true
    systemctl --user start tracker-miner-fs-3.service 2>/dev/null || true
    echo "[*] cleanup 완료"
}
trap cleanup EXIT INT TERM HUP

# Tracker 인덱서 중지 (I/O 경쟁 방지)
systemctl --user stop tracker-miner-fs-3.service 2>/dev/null

# 게임 실행 명령 (gamemoderun 있으면 사용)
GAME_CMD=("$WINE" "$NGM_EXE" "$NGM_URL")
if command -v gamemoderun &>/dev/null; then
    GAME_CMD=(gamemoderun "${GAME_CMD[@]}")
fi

# 게임 본체/작업 프로세스 판별 패턴 (env로 전달 → bash -c cmdline에 안 박힘 → pgrep 자기매칭 방지)
# 본체 = msw.exe (Unity 게임 클라이언트, Player.log가 C:/Nexon/MapleStory Worlds/msw.exe 확인)
# 작업 = 게임 등장 전 다운로더/런처(NGM64/NexonLauncher) 활동 여부
export GAME_RE='msw\.exe'
export WORK_RE='NGM64|NexonLauncher|msw\.exe'

# systemd-inhibit으로 감싼 감시 루프. 이 bash -c 가 끝나면 inhibit 락이 풀린다.
# (NGM64는 게임을 스폰하고 곧 종료되므로, NGM64 대기가 아니라 msw.exe 본체를 감시)
systemd-inhibit \
    --what=idle:sleep \
    --who="Baram Classic" \
    --why="게임 실행 중" \
    bash -c '
        set +e
        game_running() { pgrep -f "$GAME_RE" >/dev/null 2>&1; }
        work_running() { pgrep -f "$WORK_RE" >/dev/null 2>&1; }

        # 1) NGM64 실행 (게임 스폰 후 자신은 곧 종료)
        "$@"
        echo "[*] NGM 런처 종료, 게임 본체(msw.exe) 등장 대기..."

        # 2) 게임 본체 등장 대기 — 다운로더/런처가 도는 동안엔 기다리고,
        #    아무 작업도 없는 상태가 60초 지속되면 등장 실패로 보고 탈출
        idle=0
        while ! game_running; do
            if work_running; then idle=0; else idle=$((idle + 1)); fi
            [ "$idle" -ge 30 ] && break    # 2초 * 30 = 60초 무활동
            sleep 2
        done

        if game_running; then
            echo "[*] 게임 본체 가동 — 종료까지 절전 차단 유지"
            # 3) 본체가 살아있는 동안만 대기 (몇 시간이든)
            while game_running; do sleep 5; done
            echo "[*] 게임 본체 종료 감지"
        else
            echo "[*] 게임 본체 미탐지 (런처 실패/즉시 종료)"
        fi
        # 4) 여기서 bash -c 종료 → systemd-inhibit 락 해제 → 바깥 trap cleanup 실행
    ' _ "${GAME_CMD[@]}"
