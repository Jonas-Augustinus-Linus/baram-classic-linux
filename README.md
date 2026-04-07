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

| 항목 | 사양 |
|------|------|
| OS | Ubuntu 24.04 LTS (Wayland) |
| CPU | AMD Ryzen 7 7840U |
| GPU | AMD Radeon 780M (내장) |
| Kernel | 6.17+ |
| Wine | 10.6 Staging TkG (Esync/Fsync) |
| DXVK | 2.7.1 |

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
- **Wine 10.6+ Staging** — [Wine TkG](https://github.com/Frogging-Family/wine-tkg-git) 또는 Lutris/Bottles에서 설치
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
| NexonLauncher64.exe 크래시 | Wine 호환성 부족 | 넥슨 런처 대신 브라우저 방식 사용 |
| CDP 모드에서 NGM URL 캡처 실패 | Chrome 프로파일 복사 시 넥슨 로그인 세션 미보존 | `--cdp` 대신 기본 브라우저 로그인 방식 사용 |
| Vuplex WebView 크래시 로그 | `OpenSharedResource` 미지원 | DXVK 설치로 완화. 게임 플레이에 영향 없음 |
| 첫 실행 시 끊김 | 셰이더 컴파일 | DXVK 캐시 축적 후 해소 |
| 보안 모듈 변경 에러 | 게임 파일 무결성 검사 | 재실행하면 해결 |

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
