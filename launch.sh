#!/bin/bash
# 바람의나라 클래식 런처
#
# 사용법:
#   ./launch.sh          브라우저에서 로그인 후 "클라이언트 실행" 클릭
#   ./launch.sh --cdp    Chrome CDP 자동 로그인 (환경변수 NEXON_ID, NEXON_PW 필요)
#
# 기본 방식은 브라우저 직접 로그인입니다.
# ngm:// 프로토콜 핸들러(ngm-launch.sh)가 등록되어 있어야 합니다.

MSW_URL="https://maplestoryworlds.nexon.com/ko/play/f396568ea33348bf8730b129e6b42dba"

# ==========================================
# 방법 1: 브라우저 직접 로그인 (기본)
# ==========================================
if [ "$1" != "--cdp" ]; then
    echo "=========================================="
    echo "  바람의나라 클래식"
    echo "=========================================="
    echo ""
    echo "  브라우저에서 로그인 후 '클라이언트 실행'을 클릭하세요."
    echo "  ngm:// 핸들러가 자동으로 게임을 실행합니다."
    echo ""
    echo "=========================================="
    xdg-open "$MSW_URL"
    exit 0
fi

# ==========================================
# 방법 2: Chrome CDP 자동 로그인 (--cdp)
# ==========================================
set -e
trap 'systemctl --user start tracker-miner-fs-3.service 2>/dev/null' EXIT

NEXON_ID="${NEXON_ID:-}"
NEXON_PW="${NEXON_PW:-}"

if [ -z "$NEXON_ID" ] || [ -z "$NEXON_PW" ]; then
    echo "[!] NEXON_ID와 NEXON_PW 환경변수를 설정하세요."
    echo "    NEXON_ID='아이디' NEXON_PW='비밀번호' ./launch.sh --cdp"
    exit 1
fi

WINE_DIR="${WINE_DIR:-$HOME/.local/share/wine-runners/wine-10.6-staging-tkg-amd64-wow64}"
WINE="$WINE_DIR/bin/wine"
WINEPREFIX="${WINEPREFIX:-$HOME/.wine-msworlds}"
NGM_EXE="$WINEPREFIX/drive_c/ProgramData/Nexon/NGM/NGM64.exe"
CDP_PROFILE="/tmp/chrome-msw-profile"
CDP_PORT=9222
CHROME_PROFILE_DIR="${CHROME_PROFILE_DIR:-Profile 1}"

# Wine/DXVK/Mesa 환경변수
export XMODIFIERS='@im=fcitx'
export GTK_IM_MODULE='fcitx'
export QT_IM_MODULE='fcitx'
export SDL_IM_MODULE='fcitx'
export INPUT_METHOD='fcitx'
export WINEPREFIX WINEFSYNC=1 WINEESYNC=1 STAGING_SHARED_MEMORY=1
export DXVK_ASYNC=1 DXVK_STATE_CACHE_PATH="$WINEPREFIX"
export DXVK_CONFIG_FILE="$WINEPREFIX/drive_c/dxvk.conf"
export mesa_glthread=true MESA_NO_ERROR=1
export MESA_SHADER_CACHE_DIR="$HOME/.cache/mesa_shader_cache"
export MESA_SHADER_CACHE_MAX_SIZE=4G
export RADV_DEBUG=nozerovram AMD_VULKAN_ICD=RADV RADV_PERFTEST=gpl
export __GL_SHADER_DISK_CACHE=1 __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
export WINEDEBUG=-all WINE_LARGE_ADDRESS_AWARE=1

echo "=========================================="
echo "  바람의나라 클래식 런처 (CDP 모드)"
echo "=========================================="

systemctl --user stop tracker-miner-fs-3.service 2>/dev/null && echo "[*] Tracker 인덱서 중지"

echo "[1/5] Chrome 종료 중..."
pkill -9 -f '/opt/google/chrome' 2>/dev/null || true
sleep 2

echo "[2/5] Chrome 프로파일 준비 중..."
rm -rf "$CDP_PROFILE" 2>/dev/null
cp -a "$HOME/.config/google-chrome" "$CDP_PROFILE"
rm -f "$CDP_PROFILE/SingletonLock" "$CDP_PROFILE/SingletonCookie" "$CDP_PROFILE/SingletonSocket" 2>/dev/null

echo "[3/5] Chrome 시작 중..."
nohup google-chrome \
  --remote-debugging-port=$CDP_PORT \
  --remote-allow-origins=* \
  --user-data-dir="$CDP_PROFILE" \
  --profile-directory="$CHROME_PROFILE_DIR" \
  --no-first-run \
  "$MSW_URL" \
  >/dev/null 2>&1 &

for i in $(seq 1 30); do
  sleep 1
  if ss -tlnp 2>/dev/null | grep -q $CDP_PORT; then
    echo "  CDP 준비 완료 (${i}초)"
    break
  fi
  [ "$i" -eq 30 ] && echo "[!] CDP 시작 실패" && exit 1
done

echo "[4/5] 게임 URL 캡처 중..."

python3 << PYEOF
import asyncio, json, sys, os, subprocess
import websockets
import urllib.request

CDP_PORT = $CDP_PORT
WINE = "$WINE"
WINEPREFIX = "$WINEPREFIX"
NGM_EXE = "$NGM_EXE"
NEXON_ID = "$NEXON_ID"
NEXON_PW = "$NEXON_PW"

def get_ws_url(url_filter=None):
    data = urllib.request.urlopen(f"http://127.0.0.1:{CDP_PORT}/json").read()
    tabs = json.loads(data)
    for t in tabs:
        if t['type'] == 'page' and not t['url'].startswith('chrome://'):
            if url_filter is None or url_filter in t['url']:
                return t['webSocketDebuggerUrl']
    return None

async def run():
    ws_url = None
    for _ in range(30):
        ws_url = get_ws_url()
        if ws_url:
            break
        await asyncio.sleep(1)
    if not ws_url:
        print("[!] 페이지 로드 실패")
        sys.exit(1)

    async with websockets.connect(ws_url, max_size=10*1024*1024) as ws:
        msg_id = 0

        async def send_cdp(method, params={}):
            nonlocal msg_id
            msg_id += 1
            await ws.send(json.dumps({"id": msg_id, "method": method, "params": params}))
            while True:
                resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=15))
                if resp.get('id') == msg_id:
                    return resp

        async def js(expr):
            r = await send_cdp("Runtime.evaluate", {"expression": expr, "returnByValue": True})
            return r.get('result',{}).get('result',{}).get('value','')

        await asyncio.sleep(3)
        url = await js("window.location.href")
        print(f"  현재 URL: {url[:80]}")

        if 'nxlogin' in url or 'accounts.nexon' in url:
            print("  로그인 진행 중...")
            await js(f"""
            (function(){{
                var setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
                var idField = document.querySelector('input[type="text"]');
                var pwField = document.querySelector('input[type="password"]');
                if(idField) {{ setter.call(idField, '{NEXON_ID}'); idField.dispatchEvent(new Event('input', {{bubbles:true}})); }}
                if(pwField) {{ setter.call(pwField, '{NEXON_PW}'); pwField.dispatchEvent(new Event('input', {{bubbles:true}})); }}
            }})()
            """)
            await asyncio.sleep(0.5)
            await js("""(function(){var btns=document.querySelectorAll('button');for(var b of btns){if(b.textContent.includes('로그인')){b.click();return;}}})()""")
            await asyncio.sleep(6)
            for _ in range(20):
                if get_ws_url('maplestoryworlds'): break
                await asyncio.sleep(1)

        msw_ws = get_ws_url('maplestoryworlds')
        if msw_ws and msw_ws != ws_url:
            await ws.close()
            ws = await websockets.connect(msw_ws, max_size=10*1024*1024)
            msg_id = 0

        await asyncio.sleep(3)

        print("  클라이언트 실행 버튼 대기...")
        has_btn = 'no'
        for _ in range(30):
            has_btn = await js("""(function(){var b=document.querySelectorAll('button');for(var x of b){if(x.textContent.trim()==='클라이언트 실행')return 'yes';}return 'no';})()""")
            if has_btn == 'yes': break
            await asyncio.sleep(1)

        if has_btn != 'yes':
            print("[!] 클라이언트 실행 버튼을 찾을 수 없습니다")
            print("    로그인이 필요할 수 있습니다. --cdp 없이 직접 로그인을 시도하세요.")
            sys.exit(1)

        await js("""window.__ngm_url='';var o=NGM.ExecuteNGM;NGM.ExecuteNGM=function(a){window.__ngm_url=NGM.GenerateURI(a);};""")
        await js("""(function(){var b=document.querySelectorAll('button');for(var x of b){if(x.textContent.trim()==='클라이언트 실행'){x.click();return;}}})()""")
        print("  클라이언트 실행 클릭!")

        ngm_url = None
        for _ in range(100):
            await asyncio.sleep(0.3)
            c = await js("window.__ngm_url||''")
            if c and c.startswith('ngm://'):
                ngm_url = c
                break

        if not ngm_url:
            ngm_url = await js("typeof NgmLayerHelper!=='undefined'&&NgmLayerHelper.argument?NGM.GenerateURI(NgmLayerHelper.argument):''")

        if ngm_url and ngm_url.startswith('ngm://'):
            print("  NGM URL 캡처 성공!")
            use_gm = os.path.exists("/usr/bin/gamemoderun") or os.path.exists("/usr/games/gamemoderun")
            cmd = (["gamemoderun"] if use_gm else []) + [WINE, NGM_EXE, ngm_url]
            subprocess.Popen(cmd, env=os.environ.copy())
            print(f"[5/5] 게임 실행! (GameMode: {'ON' if use_gm else 'OFF'})")
        else:
            print("[!] NGM URL 캡처 실패")
            print("    CDP 세션이 로그인되지 않았을 수 있습니다.")
            print("    --cdp 없이 브라우저에서 직접 로그인을 시도하세요.")
            sys.exit(1)

asyncio.run(run())
PYEOF

echo "=========================================="
echo "  완료! 게임이 시작됩니다."
echo "=========================================="
