# 바람의나라 클래식 - Linux 실행기

> VM 없이 리눅스에서 바람의나라 클래식을 네이티브에 가깝게 실행합니다.

![Platform](https://img.shields.io/badge/platform-Linux-blue)
![Wine](https://img.shields.io/badge/Wine-10.6%20Staging-red)
![DXVK](https://img.shields.io/badge/DXVK-2.7.1-green)
![License](https://img.shields.io/badge/license-MIT-yellow)

바람의나라 클래식은 메이플스토리 월드(MapleStory Worlds) 플랫폼 위에서 구동되는 게임입니다. 이 프로젝트는 Wine + DXVK를 통해 Ubuntu/Linux에서 가상머신 없이 바로 실행할 수 있도록 자동화한 도구입니다.

## 주요 기능

- **브라우저 로그인 → 원클릭 실행** — 로그인 후 "클라이언트 실행" 클릭하면 ngm:// 핸들러가 자동으로 게임 실행
- **한글 입력** — fcitx5-hangul 기반 (GNOME의 IBus는 Wine XIM과 호환 불가 → fcitx5로 전환)
- **성능 튜닝** — DXVK 비동기 컴파일, ntsync, GameMode 등 윈도우에 가까운 성능
- **CDP 자동 로그인** — Chrome DevTools Protocol으로 자동 로그인도 가능 (선택)
- **ngm:// 프로토콜 핸들러** — 브라우저에서 "클라이언트 실행" 버튼 클릭 시 자동 연동

## 테스트 환경

두 가지 AMD iGPU 환경에서 동작을 확인했습니다.

| 항목 | 구성 A (최초 개발) | 구성 B (추가 검증, 2026-04) |
|------|-------------------|----------------------------|
| 기기 | 데스크탑 | ThinkPad E16 Gen 1 |
| OS | Ubuntu 24.04 LTS (Wayland) | Ubuntu 24.04 LTS |
| CPU | AMD Ryzen 7 7840U | AMD Ryzen 3 7330U |
| GPU | AMD Radeon 780M (RDNA3 iGPU) | AMD Radeon Vega (Barcelo iGPU) |
| Kernel | 6.17+ | 6.17+ |
| Wine | 10.6 Staging TkG (Esync/Fsync) | 10.6 Staging TkG (Esync/Fsync) |
| DXVK | 2.7.1 | 2.7.1 (winetricks 자동 설치) |

## 빠른 시작

```bash
# 1. 저장소 클론
git clone https://github.com/Jonas-Augustinus-Linus/baram-classic-linux.git
cd baram-classic-linux

# 2. 초기 설정 (Wine prefix, DXVK, 레지스트리, 커널 최적화, 프로토콜 핸들러)
chmod +x setup.sh launch.sh ngm-launch.sh
./setup.sh

# 3. 게임 실행
./launch.sh
```

## 실행 방법

### 방법 1: 브라우저 직접 로그인 (기본, 권장)

```bash
./launch.sh
```

1. 브라우저에서 메이플스토리 월드 페이지가 열립니다
2. 넥슨 계정으로 로그인합니다
3. "클라이언트 실행" 버튼을 클릭합니다
4. ngm:// 프로토콜 핸들러가 자동으로 게임을 실행합니다

### 방법 2: Chrome CDP 자동 로그인 (선택)

```bash
NEXON_ID="내_아이디" NEXON_PW="내_비밀번호" ./launch.sh --cdp
```

Chrome DevTools Protocol을 사용하여 로그인을 자동화합니다. CDP 세션에서 넥슨 로그인 쿠키가 만료된 경우 실패할 수 있으므로, 그때는 방법 1을 사용하세요.

## 요구사항

- **Ubuntu 24.04+** (또는 동등한 리눅스 배포판)
- **Wine TkG Staging (필수)** — 일반 `wine-stable`은 안티치트가 감지해 거부함. setup.sh가 [Kron4ek 10.6 빌드](https://github.com/Kron4ek/Wine-Builds/releases)를 자동 다운로드
- **Microsoft Edge WebView2 Runtime (필수)** — NexonLauncher64가 의존. setup.sh가 Wine 프리픽스에 자동 설치
- **Vulkan 지원 GPU** — AMD (RADV) 또는 NVIDIA
- **Google Chrome** — 게임 실행 URL 전달용
- **Python 3** + `websockets` 모듈 — CDP 모드 사용 시 (`pip install websockets`)
- **winetricks** — DXVK 설치용 (`sudo apt install winetricks`)
- **fcitx5-hangul** — 한글 입력용 (`sudo apt install fcitx5 fcitx5-hangul fcitx5-config-qt`)

## 구성 파일

| 파일 | 설명 |
|------|------|
| `launch.sh` | 게임 런처 (기본: 브라우저 로그인, `--cdp`: 자동 로그인) |
| `ngm-launch.sh` | ngm:// 프로토콜 핸들러 래퍼 (Wine 환경변수 + 최적화 적용) |
| `setup.sh` | 초기 환경 설정 (Wine prefix, DXVK, 레지스트리, ntsync, NGM, 프로토콜 핸들러) |
| `dxvk.conf` | DXVK 성능 최적화 (`maxFrameLatency=1` 등) |
| `gamemode.ini` | Feral GameMode 설정 (`~/.config/gamemode.ini`에 복사) |
| `ngm-handler.desktop` | ngm:// 프로토콜 핸들러 (setup.sh가 경로 치환 후 자동 등록) |

## 작동 원리

### 브라우저 방식 (기본)

```
launch.sh 실행
  └─ 브라우저에서 MSW 페이지 열기
       └─ 사용자가 로그인 + "클라이언트 실행" 클릭
            └─ 브라우저가 ngm:// URL 생성
                 └─ ngm-handler.desktop → ngm-launch.sh
                      └─ Wine 환경 세팅 + GameMode 활성화
                           └─ NGM64.exe 실행 → msw.exe (게임 본체) 시작
```

### CDP 방식 (--cdp)

```
launch.sh --cdp 실행
  ├─ Chrome을 CDP(DevTools Protocol) 모드로 시작
  ├─ 넥슨 로그인 자동 처리
  ├─ "클라이언트 실행" 버튼 클릭
  ├─ NGM.GenerateURI()로 ngm:// URL 캡처
  └─ Wine으로 NGM64.exe 실행 → msw.exe (게임 본체) 시작
```

## 적용된 최적화

### 키보드 입력 + 한글 (리눅스에서 가장 흔한 문제)
| 설정 | 효과 |
|------|------|
| `XMODIFIERS=@im=fcitx` | fcitx5 입력기 활성화 (GNOME IBus는 Wine XIM 호환 불가) |
| `InputStyle=root` | Wine X11 입력 스타일 변경 (fcitx5 호환성) |
| `korean:ralt_hangul` | 오른쪽 Alt 키를 한/영 전환키로 매핑 |
| `UseTakeFocus=N` | Alt-Tab 후 키보드 안 먹히는 문제 해결 |
| `GrabFullscreen=Y` | 풀스크린에서 키보드/마우스 캡처 |
| `MouseWarpOverride=force` | 마우스 커서 게임 창 내 고정 |
| 한글 폰트 대체 | Noto CJK → 굴림/바탕/맑은고딕 매핑 |

### 그래픽 성능
| 설정 | 효과 |
|------|------|
| `DXVK_ASYNC=1` | 셰이더 비동기 컴파일 (스터터링 감소) |
| `dxvk.maxFrameLatency=1` | 입력 지연 최소화 |
| `d3d11.cachedDynamicResources` | iGPU 동적 리소스 캐싱 |
| `mesa_glthread=true` | Mesa GL 멀티스레딩 |
| `MESA_NO_ERROR=1` | GL 에러 체크 비활성화 |
| `RADV_DEBUG=nozerovram` | AMD VRAM 제로클리어 비활성화 |
| `RADV_PERFTEST=gpl` | RADV 그래픽 파이프라인 라이브러리 |

### 시스템
| 설정 | 효과 |
|------|------|
| `WINEFSYNC=1` | Wine Fsync 동기화 |
| `ntsync` 모듈 | NT 동기화 커널 지원 (커널 6.14+) |
| `vm.max_map_count` | 메모리 맵 한도 증가 |
| `vm.swappiness=10` | 스왑 최소화 |
| GameMode (`gamemoderun`) | CPU/GPU 성능 모드 자동 전환 |
| Tracker 인덱서 중지 | 게임 중 I/O 경쟁 방지 |
| VRR (가변 주사율) | GNOME Mutter VRR 활성화 |

## 알려진 이슈

| 증상 | 원인 | 해결 |
|------|------|------|
| 게임 내 로그인 화면에서 로그인 불가 | Vuplex WebView(내장 CEF 브라우저)가 Wine에서 정상 작동하지 않음 | msw.exe 직접 실행 대신 반드시 브라우저에서 ngm:// URL을 통해 실행 |
| **NexonLauncher64.exe가 약 10초 만에 조용히 종료** | Microsoft Edge WebView2 런타임 누락. NexonLauncher UI가 WebView2에 의존하는데 Wine 프리픽스에 기본적으로 없음. 크래시 로그 대신 `warn:seh:dispatch_exception "WebView2: Failed to find an installed WebView2 runtime"`만 Wine 로그에 남김 | setup.sh가 자동 설치. 수동: `wget "https://go.microsoft.com/fwlink/?linkid=2099617" -O /tmp/wv.exe && wine /tmp/wv.exe /silent /install` |
| **msw.exe가 약 45초 만에 조용히 종료 (Unity `Player.log` 끝에 `ShutdownInProgress`만 기록)** | `grap-core64.aes` 안티치트가 일반 `wine-stable`을 감지해 `Application.Quit()` 호출. Staging의 esync/fsync 시그니처가 없으면 바로 차단당함 | **Wine TkG Staging(Esync/Fsync) 필수.** setup.sh가 Kron4ek 10.6 빌드를 자동 다운로드. `winehq-stable` 11.0 단독으로는 우회 불가 |
| CDP 모드에서 NGM URL 캡처 실패 | Chrome 프로파일 복사 시 넥슨 로그인 세션 미보존 | `--cdp` 대신 기본 브라우저 로그인 방식 사용 |
| Vuplex WebView 크래시 로그 | `OpenSharedResource` 미지원 | DXVK 설치로 완화. 게임 플레이에 영향 없음 |
| 첫 실행 시 끊김 | 셰이더 컴파일 | DXVK 캐시 축적 후 해소 |
| 보안 모듈 변경 에러 | 게임 파일 무결성 검사 | 재실행하면 해결 |
| `libgamemodeauto.so.0 (i386)` LD_PRELOAD 경고 | i386 gamemode 라이브러리 부재 | 경고만 출력되고 게임은 정상. `sudo apt install libgamemode0:i386`로 제거 가능 |

### 진단 팁 — 조용한 크래시를 추적할 때

위의 앞 두 항목(NexonLauncher64, msw.exe)은 **크래시 다이얼로그 없이** 창이 조용히 닫히는 형태라 원인 파악이 어렵습니다. `ngm-launch.sh`에서 `WINEDEBUG=-all`을 `WINEDEBUG=+err,+seh,+module,fixme-all`로 일시 변경하고 출력을 파일로 리다이렉트하면 실제 원인이 드러납니다:

- **NexonLauncher64 문제**: `warn:seh:dispatch_exception "WebView2: Failed to find..."` 가 로그에 나오면 WebView2 누락
- **msw.exe 문제**: `%USERPROFILE%\AppData\LocalLow\nexon\MapleStory Worlds\Player.log` 끝에 별도 에러 없이 `Input System module state changed to: ShutdownInProgress`만 있으면 안티치트 감지. Wine 버전 문제 유력

## 업데이트 이력 (2026-04)

이 저장소는 처음 Ryzen 7 7840U + Radeon 780M(RDNA3) 조합에서 개발됐습니다. 2026년 4월, **ThinkPad E16 Gen 1 (Ryzen 3 7330U + Radeon Vega Barcelo iGPU)** 환경에서 처음부터 다시 설치해보는 과정에서 기존 README로는 설명되지 않는 두 가지 크래시가 재현됐고, 원인을 추적해 setup.sh에 자동화 단계를 추가했습니다.

### 1. NexonLauncher64가 로드 후 10초 만에 조용히 종료

**증상**: 브라우저에서 "클라이언트 실행"을 누르면 ngm:// 핸들러가 동작해 NGM64.exe → NexonLauncher64.exe까지 정상적으로 스폰되지만, 약 10초 뒤 둘 다 크래시 다이얼로그 없이 사라짐. `msw.exe`는 도달조차 하지 못함. 기존 README는 이 증상을 "Wine 호환성 부족"으로 단정하고 "브라우저 방식을 써라"고 안내했는데, **사실 브라우저 방식도 결국 NexonLauncher64를 호출하므로 우회 수단이 아니었음**.

**실제 원인**: NexonLauncher의 UI가 Microsoft Edge WebView2에 의존합니다. Wine 프리픽스엔 기본적으로 WebView2 런타임이 없어 Vuplex/NGM이 `"WebView2: Failed to find an installed WebView2 runtime or non-stable Microsoft Edge installation"` 예외를 던진 뒤 프로세스가 종료됩니다. `WINEDEBUG=+seh`로 실행하면 로그에서 바로 확인 가능합니다.

**해결**: Microsoft Edge WebView2 Evergreen Standalone Installer(약 170MB)를 Wine으로 실행. setup.sh 단계 8에서 자동화.

### 2. msw.exe가 Unity 초기화 직후 45초 만에 종료

**증상**: WebView2를 설치하자 NexonLauncher64가 살아남고, NGM64가 SIG.exe와 msw.exe(실제 게임)까지 스폰. Unity 엔진이 Direct3D 11.1로 초기화되고 MODStudio(게임 프레임워크)까지 로드되지만, `MOD.Version: win.26.3.5.709` 출력 직후 **별도 에러 없이** `Input System module state changed to: ShutdownInProgress`만 남긴 채 프로세스 종료. Wine 로그에도 SEH 예외·세그폴트 없음.

**실제 원인**: Nexon 전용 안티치트 `grap-core64.aes`가 Wine의 esync/fsync 시그니처를 확인해 스테이징 빌드가 아니면 `Application.Quit()`을 호출하도록 게임에 신호를 보냅니다. 테스트 당시 기본 Wine은 `winehq-stable 11.0`(비-스테이징)이었고, 이전 환경에선 이미 TkG Staging이 설치돼 있어 문제가 드러나지 않았던 것.

**해결**: **Wine TkG Staging(Esync/Fsync)을 필수**로 선언하고, setup.sh 단계 0에서 [Kron4ek Wine-Builds](https://github.com/Kron4ek/Wine-Builds/releases)의 `wine-10.6-staging-tkg-amd64-wow64.tar.xz`를 자동 다운로드/압축해제. 기존 README가 "Wine 10.6+ Staging (TkG 또는 Lutris/Bottles 등에서 설치)" 정도로 느슨하게 표현했던 부분을 강한 필수 요구사항으로 변경.

### setup.sh 변경 요약

- **단계 0 추가**: `$WINE` 바이너리가 없으면 Kron4ek Wine TkG 10.6 Staging 자동 다운로드 → `~/.local/share/wine-runners/`에 압축해제
- **단계 8 추가**: WebView2 Evergreen Runtime을 Wine 프리픽스에 silent install (이미 설치돼 있으면 스킵)
- 기존 1–7 단계 번호를 `/7` → `/8`로 갱신

## 기여

이슈, PR 모두 환영합니다. 다른 배포판(Fedora, Arch 등)에서 테스트해보신 분은 결과를 공유해주세요.

## 참고 자료

- [Wine TkG](https://github.com/Frogging-Family/wine-tkg-git)
- [DXVK](https://github.com/doitsujin/dxvk)
- [Feral GameMode](https://github.com/FeralInteractive/gamemode)
- [ntsync](https://wiki.debian.org/Wine/NtsyncHowto)
- [Arch Wiki - Wine](https://wiki.archlinux.org/title/Wine)

## 라이선스

MIT
