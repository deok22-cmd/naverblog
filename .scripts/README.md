# Naverblog 일일 자동 발행 시스템

매일 새벽 4시(KST) Windows 작업 스케줄러가 Claude Code CLI를 비대화 모드로 호출하여 그날의 5개 원고를 자동 작성합니다. 이미지는 placeholder로 남겨두어 사용자가 Antigravity로 별도 생성합니다.

---

## 구성 파일

| 파일 | 역할 |
|---|---|
| `daily-prompt.md` | 매일 실행될 자기완결적 작업 지시문 (Naverblog 운영 규칙 포함) |
| `daily-run.ps1` | Claude Code CLI를 호출하는 PowerShell 래퍼 |
| `logs/daily-YYYYMMDD-HHMMSS.log` | 매 실행마다 생성되는 실행 로그 |

---

## 최초 1회 등록 (Windows 작업 스케줄러)

PowerShell을 **관리자 권한으로 열 필요는 없으며**, 일반 사용자 권한 PowerShell에서 다음 명령을 실행합니다.

```powershell
schtasks /Create `
  /TN "NaverblogDaily" `
  /SC DAILY /ST 04:00 `
  /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\lightsail\naverblog\.scripts\daily-run.ps1" `
  /F
```

옵션 설명:
- `/TN "NaverblogDaily"`: 작업 이름
- `/SC DAILY /ST 04:00`: 매일 04:00 실행
- `/TR ...`: 실행할 명령. PowerShell이 래퍼 스크립트를 호출
- `/F`: 같은 이름이 있으면 강제 덮어쓰기

---

## 운영 명령

```powershell
# 작업 상태 확인
schtasks /Query /TN NaverblogDaily /V /FO LIST

# 즉시 1회 시험 실행
schtasks /Run /TN NaverblogDaily

# 비활성화 (일시 중단)
schtasks /Change /TN NaverblogDaily /DISABLE

# 재활성화
schtasks /Change /TN NaverblogDaily /ENABLE

# 완전 삭제
schtasks /Delete /TN NaverblogDaily /F

# 실행 시간 변경 (예: 새벽 5시로)
schtasks /Change /TN NaverblogDaily /ST 05:00
```

---

## 노트북이 새벽에 절전/꺼짐 상태일 때

기본 등록만으로는 PC가 꺼져 있으면 작업이 누락됩니다. 작업 스케줄러 GUI(`taskschd.msc`)에서 **NaverblogDaily** 항목 → 속성 → 조건 탭에서:

1. **"이 작업을 실행하기 위해 컴퓨터를 절전 모드에서 깨우기"** 체크
2. 전원 옵션의 **"AC 전원 사용 시에만 작업 실행"** 체크 해제(노트북이라면)

또는 등록 명령에 `/RL HIGHEST` 추가 후 GUI에서 추가 옵션 설정.

---

## 비용 안전망

- `daily-run.ps1` 안에서 `--max-budget-usd 5`로 1회 실행 비용 상한 5달러
- `--model claude-sonnet-4-6` 기본값. Opus가 필요하면 `daily-run.ps1`의 `--model` 값을 `claude-opus-4-7`로 변경
- 예상 비용: Sonnet 기준 1회당 $1~2, 월 $30~60

---

## 로그 확인

```powershell
# 가장 최근 로그
Get-ChildItem D:\lightsail\naverblog\.scripts\logs\daily-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 80

# 특정 날짜 검색
Get-ChildItem D:\lightsail\naverblog\.scripts\logs\daily-20260502*.log | ForEach-Object { Get-Content $_ }
```

성공: 로그 끝에 `[DAILY OK YYYY-MM-DD] ...` 한 줄
실패: `[DAILY FAIL YYYY-MM-DD] ...` 한 줄

---

## 트러블슈팅

| 증상 | 원인 / 조치 |
|---|---|
| 로그에 "Workspace trust" 관련 메시지 | 비대화 모드(`-p`)에서는 자동 우회됨. 무시 가능 |
| 권한 프롬프트로 멈춤 | `daily-run.ps1`의 `--permission-mode bypassPermissions` 확인 |
| 새벽에 실행되지 않음 | PC 절전/종료 상태. 위의 "절전 모드에서 깨우기" 설정 확인 |
| 로그가 깨짐 | PowerShell 인코딩. `Get-Content` 시 `-Encoding utf8` 명시 |
| 비용 초과 알림 | `--max-budget-usd` 값 조정 또는 모델을 lite로 교체 |
| Claude CLI 미인식 | `claude.cmd` 경로가 PATH에 있는지 확인 (`where claude`) |

---

## 워크플로우 요약

1. **04:00 (자동)** — 작업 스케줄러가 `daily-run.ps1` 실행
2. **04:00~04:15 (자동)** — Claude가 5개 주제 선정, 대시보드, 5개 원고(placeholder 모드) 생성
3. **기상 후 (수동)** — Antigravity에 다음과 같이 지시:
   > `D:\lightsail\naverblog\output\YYMMDD\` 의 모든 HTML 파일을 읽고, 각 `.img-placeholder` 안의 영문 프롬프트와 `.ph-file` 경로를 사용해 이미지 15장을 생성·저장해줘
4. **이미지 생성 후 (수동)** — `output/YYMMDD/` 의 각 HTML에서 placeholder를 `<img>` 태그로 치환 (Claude에게 "오늘 5개 원고 placeholder를 img 태그로 변환" 요청 또는 직접 작업)
5. **발행** — 완성된 HTML을 네이버 블로그 에디터에 복사·붙여넣기

---
