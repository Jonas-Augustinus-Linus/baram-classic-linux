# 바람의나라 클래식 - Linux 실행기

> VM 없이 리눅스에서 바람의나라 클래식을 네이티브에 가깝게 실행합니다.

![Platform](https://img.shields.io/badge/platform-Linux-blue)
![Wine](https://img.shields.io/badge/Wine-10.6%20Staging-red)
![DXVK](https://img.shields.io/badge/DXVK-2.7.1-green)
![License](https://img.shields.io/badge/license-MIT-yellow)

바람의나라 클래식은 메이플스토리 월드(MapleStory Worlds) 플랫폼 위에서 구동되는 게임입니다. 이 프로젝트는 Wine + DXVK를 통해 Ubuntu/Linux에서 가상머신 없이 바로 실행할 수 있도록 자동화한 도구입니다.

## 주요 기능

- **원클릭 실행** — `./launch.sh` 한 번으로 로그인부터 게임 실행까지 자동 처리
- **키보드 입력 최적화** — IBus 충돌 방지, 포커스 문제 해결 등 리눅스 특유의 입력 문제 해결
- **성능 튜닝** — DXVK 비동기 컴파일, ntsync, GameMode 등 윈도우에 가까운 성능
- **자동 로그인** — Chrome DevTools Protocol(CDP)을 활용한 넥슨 로그인 자동화
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

# 2. 초기 설정 (Wine prefix, DXVK, 레지스트리, 커널 최적화)
chmod +x setup.sh launch.sh
./setup.sh

# 3. 넥슨 계정 설정 후 실행
NEXON_ID="내_아이디" NEXON_PW="내_비밀번호" ./launch.sh
```

## 요구사항

- **Ubuntu 24.04+** (또는 동등한 리눅스 배포판)
- **Wine 10.6+ Staging** — [Wine TkG](https://github.com/Frogging-Family/wine-tkg-git) 또는 Lutris/Bottles에서 설치
- **Vulkan 지원 GPU** — AMD (RADV) 또는 NVIDIA
- **Google Chrome** — CDP 자동화용
- **Python 3** + `websockets` 모듈 (`pip install websockets`)
- **winetricks** — DXVK 설치용 (`sudo apt install winetricks`)
- **ibus-hangul** — 한글 입력용 (`sudo apt install ibus-hangul`)

## 구성 파일

| 파일 | 설명 |
|------|------|
| `launch.sh` | 원클릭 게임 런처 (Chrome CDP 자동 로그인 + NGM URL 캡처) |
| `setup.sh` | 초기 환경 설정 (Wine prefix, DXVK, 레지스트리, ntsync, NGM) |
| `dxvk.conf` | DXVK 성능 최적화 (`maxFrameLatency=1` 등) |
| `gamemode.ini` | Feral GameMode 설정 (`~/.config/gamemode.ini`에 복사) |
| `ngm-handler.desktop` | ngm:// 프로토콜 핸들러 (setup.sh가 자동 등록) |

## 작동 원리

```
launch.sh 실행
  ├─ Chrome을 CDP(DevTools Protocol) 모드로 시작
  ├─ 넥슨 로그인 자동 처리
  ├─ "클라이언트 실행" 버튼 클릭
  ├─ NGM.GenerateURI()로 ngm:// URL 생성
  └─ Wine으로 NGM64.exe 실행 → msw.exe (게임 본체) 시작
```

## 적용된 최적화

### 키보드 입력 + 한글 (리눅스에서 가장 흔한 문제)
| 설정 | 효과 |
|------|------|
| `XMODIFIERS=@im=ibus` | IBus 입력기 활성화 (한글 입력 지원) |
| `InputStyle=root` | Wine X11 입력 스타일 변경 (IBus 호환성) |
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
| Vuplex WebView 크래시 | `OpenSharedResource` 미지원 | DXVK 설치로 해결. 게임 플레이에 영향 없음 |
| 첫 실행 시 끊김 | 셰이더 컴파일 | DXVK 캐시 축적 후 해소 |
| 보안 모듈 변경 에러 | 게임 파일 무결성 검사 | 재실행하면 해결 |
| Chrome CDP 연결 실패 | 기존 Chrome 실행 중 | launch.sh가 자동으로 Chrome 재시작 |

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
