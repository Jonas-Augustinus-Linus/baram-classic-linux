#!/bin/bash
# 바람의나라 클래식 원클릭 런처
# Chrome CDP를 통해 자동으로 로그인하고 게임을 실행합니다

set -e

# 종료 시 Tracker 재시작
trap 'systemctl --user start tracker-miner-fs-3.service 2>/dev/null' EXIT

# ==========================================
# 사용자 설정 (환경변수로도 전달 가능)
# ==========================================
NEXON_ID="${NEXON_ID:-your_nexon_id@example.com}"
NEXON_PW="${NEXON_PW:-your_password}"

# ==========================================
# 경로 설정
# ==========================================
WINE_DIR="${WINE_DIR:-$HOME/.local/share/wine-runners/wine-10.6-staging-tkg-amd64-wow64}"
WINE="$WINE_DIR/bin/wine"
WINEPREFIX="${WINEPREFIX:-$HOME/.wine-msworlds}"
NGM_EXE="$WINEPREFIX/drive_c/ProgramData/Nexon/NGM/NGM64.exe"
CDP_PROFILE="/tmp/chrome-msw-profile"
MSW_URL="https://maplestoryworlds.nexon.com/ko/play/f396568ea33348bf8730b129e6b42dba"
CDP_PORT=9222
CHROME_PROFILE_DIR="${CHROME_PROFILE_DIR:-Profile 1}"

# ==========================================
# 키보드 입력 + 한글 입력 (fcitx5 + InputStyle=root)
# GNOME은 IBus를 강제 실행하여 Wine XIM과 충돌하므로 fcitx5 사용
# ==========================================
export XMODIFIERS='@im=fcitx'
export GTK_IM_MODULE='fcitx'
export QT_IM_MODULE='fcitx'
export SDL_IM_MODULE='fcitx'
export INPUT_METHOD='fcitx'

# ==========================================
# Wine 동기화
# ==========================================
export WINEFSYNC=1
export WINEESYNC=1
export STAGING_SHARED_MEMORY=1

# ==========================================
# DXVK 최적화
# ==========================================
export DXVK_ASYNC=1
export DXVK_STATE_CACHE_PATH="$WINEPREFIX"
export DXVK_CONFIG_FILE="$WINEPREFIX/drive_c/dxvk.conf"

# ==========================================
# AMD Mesa/RADV 최적화
# ==========================================
export mesa_glthread=true
export MESA_NO_ERROR=1
export MESA_SHADER_CACHE_DIR="$HOME/.cache/mesa_shader_cache"
export MESA_SHADER_CACHE_MAX_SIZE=4G
export RADV_DEBUG=nozerovram
export AMD_VULKAN_ICD=RADV

# ==========================================
# 셰이더 캐시
# ==========================================
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1

# ==========================================
# Wine 디버그 끄기 (성능)
# ==========================================
export WINEDEBUG=-all
export DISPLAY="${DISPLAY:-:0}"

# ==========================================
# RADV 파이프라인 캐시 + 기타
# ==========================================
export RADV_PERFTEST=gpl
export WINE_LARGE_ADDRESS_AWARE=1

echo "=========================================="
echo "  바람의나라 클래식 런처"
echo "=========================================="

# Step 0: 백그라운드 인덱서 일시정지
systemctl --user stop tracker-miner-fs-3.service 2>/dev/null && echo "[0] Tracker 인덱서 중지"

# Step 1: Chrome 종료
echo "[1/5] Chrome 종료 중..."
pkill -9 -f '/opt/google/chrome' 2>/dev/null || true
sleep 2

# Step 2: Chrome 프로파일 복사 (CDP는 non-default 경로 필요)
echo "[2/5] Chrome 프로파일 준비 중..."
rm -rf "$CDP_PROFILE" 2>/dev/null
cp -a "$HOME/.config/google-chrome" "$CDP_PROFILE"
rm -f "$CDP_PROFILE/SingletonLock" "$CDP_PROFILE/SingletonCookie" "$CDP_PROFILE/SingletonSocket" 2>/dev/null

# Step 3: Chrome 시작 (CDP + 지정 프로파일)
echo "[3/5] Chrome 시작 중..."
nohup google-chrome \
  --remote-debugging-port=$CDP_PORT \
  --remote-allow-origins=* \
  --user-data-dir="$CDP_PROFILE" \
  --profile-directory="$CHROME_PROFILE_DIR" \
  --no-first-run \
  "$MSW_URL" \
  >/dev/null 2>&1 &
CHROME_PID=$!

# CDP 준비 대기
for i in $(seq 1 30); do
  sleep 1
  if ss -tlnp 2>/dev/null | grep -q $CDP_PORT; then
    echo "  CDP 준비 완료 (${i}초)"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "[!] CDP 시작 실패"
    exit 1
  fi
done

# Step 4: NGM URL 캡처 및 게임 실행
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
        events = []

        async def send_cdp(method, params={}):
            nonlocal msg_id
            msg_id += 1
            await ws.send(json.dumps({"id": msg_id, "method": method, "params": params}))
            while True:
                resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=15))
                if resp.get('id') == msg_id:
                    return resp
                events.append(resp)

        async def js(expr):
            r = await send_cdp("Runtime.evaluate", {"expression": expr, "returnByValue": True})
            return r.get('result',{}).get('result',{}).get('value','')

        await asyncio.sleep(3)
        url = await js("window.location.href")
        print(f"  현재 URL: {url[:80]}")

        # 로그인 필요 여부 확인
        if 'nxlogin' in url or 'accounts.nexon' in url:
            print("  로그인 진행 중...")
            await js(f"""
            (function(){{
                var setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
                var idField = document.querySelector('input[type="text"]');
                var pwField = document.querySelector('input[type="password"]');
                if(idField) {{
                    setter.call(idField, '{NEXON_ID}');
                    idField.dispatchEvent(new Event('input', {{bubbles:true}}));
                    idField.dispatchEvent(new Event('change', {{bubbles:true}}));
                }}
                if(pwField) {{
                    setter.call(pwField, '{NEXON_PW}');
                    pwField.dispatchEvent(new Event('input', {{bubbles:true}}));
                    pwField.dispatchEvent(new Event('change', {{bubbles:true}}));
                }}
            }})()
            """)
            await asyncio.sleep(0.5)
            await js("""(function(){var btns=document.querySelectorAll('button');for(var b of btns){if(b.textContent.includes('넥슨')&&b.textContent.includes('로그인')){b.click();return;}}})()""")
            await asyncio.sleep(6)

            for _ in range(20):
                new_ws = get_ws_url('maplestoryworlds')
                if new_ws:
                    break
                await asyncio.sleep(1)

        # Reconnect to MSW page if needed
        msw_ws = get_ws_url('maplestoryworlds')
        if msw_ws and msw_ws != ws_url:
            await ws.close()
            ws = await websockets.connect(msw_ws, max_size=10*1024*1024)
            msg_id = 0
            events = []

        await asyncio.sleep(3)

        # 클라이언트 실행 버튼 대기
        print("  클라이언트 실행 버튼 대기...")
        has_btn = 'no'
        for _ in range(30):
            has_btn = await js("""(function(){var b=document.querySelectorAll('button');for(var x of b){if(x.textContent.trim()==='클라이언트 실행')return 'yes';}return 'no';})()""")
            if has_btn == 'yes':
                break
            await asyncio.sleep(1)

        if has_btn != 'yes':
            print("[!] 클라이언트 실행 버튼을 찾을 수 없습니다")
            sys.exit(1)

        # NGM.ExecuteNGM 훅 설치 후 버튼 클릭
        await js("""
        window.__ngm_url='';
        var origExec=NGM.ExecuteNGM.bind(NGM);
        NGM.ExecuteNGM=function(arg,game){var uri=NGM.GenerateURI(arg);window.__ngm_url=uri;};
        """)

        coords = await js("""(function(){var btn=Array.from(document.querySelectorAll('button')).find(b=>b.textContent.trim()==='클라이언트 실행');if(!btn)return'';var r=btn.getBoundingClientRect();return JSON.stringify({x:r.x+r.width/2,y:r.y+r.height/2});})()""")
        if coords:
            c = json.loads(coords)
            await send_cdp("Input.dispatchMouseEvent", {"type": "mousePressed", "x": c['x'], "y": c['y'], "button": "left", "clickCount": 1})
            await asyncio.sleep(0.05)
            await send_cdp("Input.dispatchMouseEvent", {"type": "mouseReleased", "x": c['x'], "y": c['y'], "button": "left", "clickCount": 1})
        print("  클라이언트 실행 클릭!")

        # ngm:// URL 캡처
        ngm_url = None
        for i in range(100):
            await asyncio.sleep(0.3)
            captured = await js("window.__ngm_url||''")
            if captured and captured.startswith('ngm://'):
                ngm_url = captured
                break

        # fallback: NgmLayerHelper에서 직접 생성
        if not ngm_url:
            ngm_url = await js("typeof NgmLayerHelper!=='undefined'&&NgmLayerHelper.argument?NGM.GenerateURI(NgmLayerHelper.argument):''")

        if ngm_url and ngm_url.startswith('ngm://'):
            print("  NGM URL 캡처 성공!")
            env = os.environ.copy()
            use_gamemode = os.path.exists("/usr/bin/gamemoderun") or os.path.exists("/usr/games/gamemoderun")
            cmd = (["gamemoderun"] if use_gamemode else []) + [WINE, NGM_EXE, ngm_url]
            subprocess.Popen(cmd, env=env)
            print(f"[5/5] 게임 실행! (GameMode: {'ON' if use_gamemode else 'OFF'})")
        else:
            print("[!] NGM URL 캡처 실패")
            sys.exit(1)

asyncio.run(run())
PYEOF

echo "=========================================="
echo "  완료! 게임이 시작됩니다."
echo "=========================================="
