# 바람의나라 클래식 - Linux Wine 실행 가이드

Ubuntu Linux에서 Wine을 통해 바람의나라 클래식(MapleStory Worlds)을 실행하기 위한 스크립트 및 설정 모음입니다.

## 시스템 요구사항

- Ubuntu 24.04+ (Wayland/X11)
- Wine 10.6+ Staging (TkG Esync Fsync 권장)
- Vulkan 지원 GPU (AMD RADV / NVIDIA)
- DXVK 2.7.1+
- Google Chrome (CDP 자동화용)
- Python 3 + websockets 모듈

## 구성 파일

| 파일 | 설명 |
|------|------|
| `launch.sh` | 원클릭 게임 런처 (Chrome CDP 자동화) |
| `ngm-handler.desktop` | ngm:// 프로토콜 핸들러 (브라우저 연동) |
| `dxvk.conf` | DXVK 성능 최적화 설정 |
| `gamemode.ini` | Feral GameMode 설정 |
| `setup.sh` | 초기 환경 설정 스크립트 |

## 설치 방법

### 1. Wine 설치

[Wine TkG Staging](https://github.com/Frogging-Family/wine-tkg-git)을 `~/.local/share/wine-runners/`에 설치합니다.

```bash
# 또는 Lutris, Bottles 등의 Wine 매니저 사용
```

### 2. 초기 설정

```bash
chmod +x setup.sh launch.sh
./setup.sh
```

`setup.sh`가 다음을 수행합니다:
- Wine prefix (`~/.wine-msworlds`) 생성
- DXVK 설치 (winetricks)
- Wine 레지스트리 최적화 (키보드 입력, 그래픽)
- ntsync 커널 모듈 로드
- 커널 파라미터 최적화
- ngm:// 프로토콜 핸들러 등록
- NGM(Nexon Game Manager) 설치

### 3. 자격 증명 설정

`launch.sh`의 상단에 넥슨 계정 정보를 입력합니다:

```bash
NEXON_ID="your_nexon_id@example.com"
NEXON_PW="your_password"
```

또는 환경변수로 전달:

```bash
NEXON_ID="id@example.com" NEXON_PW="password" ./launch.sh
```

### 4. 게임 실행

```bash
./launch.sh
```

## 적용된 최적화

### 키보드 입력
- IBus 충돌 방지 (`XMODIFIERS=''`)
- `UseTakeFocus=N` (Alt-Tab 후 키보드 복구)
- `GrabFullscreen=Y` (풀스크린 입력 캡처)
- `MouseWarpOverride=force` (마우스 고정)

### 성능
- DXVK 비동기 셰이더 컴파일 (`DXVK_ASYNC=1`)
- DXVK `maxFrameLatency=1` (입력 지연 감소)
- Fsync/Esync 동기화
- ntsync 커널 모듈
- Mesa/RADV 최적화 (`mesa_glthread`, `MESA_NO_ERROR`)
- `vm.max_map_count=2147483642`
- GameMode (`softrealtime=auto`, `ioprio=0`)

### 시스템
- `vm.swappiness=10`
- Feral GameMode 자동 적용

## 알려진 이슈

- Vuplex WebView 크래시 (`OpenSharedResource E_INVALIDARG`) — DXVK로 해결, 게임 플레이에 영향 없음
- 첫 실행 시 셰이더 컴파일로 인한 스터터링 — DXVK 캐시가 쌓이면 해소
- Chrome CDP를 위해 Chrome 프로파일 복사 필요 (CDP는 non-default 프로파일 경로 필요)

## 참고 자료

- [Wine TkG](https://github.com/Frogging-Family/wine-tkg-git)
- [DXVK](https://github.com/doitsujin/dxvk)
- [Feral GameMode](https://github.com/FeralInteractive/gamemode)
- [Arch Wiki - Wine](https://wiki.archlinux.org/title/Wine)
- [ntsync](https://wiki.debian.org/Wine/NtsyncHowto)

## 라이선스

MIT
