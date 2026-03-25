# 블로그 자동생성 시스템

매일 새벽 4시, 10개 카테고리 × 2개 = **20개 HTML 원고**를 자동 생성하고 GitHub에 Push합니다.

---

## 📁 파일 구성

```
blog_automation/
├── CLAUDE.md            ← 블로그 운영 지침 (Claude Code 자동 참조)
├── generate_blog.sh     ← 메인 실행 스크립트
├── setup.sh             ← 최초 1회 환경 설정
├── README.md            ← 이 파일
├── output/              ← 생성된 HTML 파일
│   └── 260325/
│       ├── baseball_01_키워드.html
│       ├── baseball_02_키워드.html
│       └── ... (총 20개)
└── logs/                ← 실행 로그
    └── generate_260325.log
```

---

## 🚀 설치 & 최초 설정 (3단계)

### 1단계 — 사전 준비물 확인

| 항목 | 확인 방법 |
|------|-----------|
| Node.js 18+ | `node --version` |
| Git | `git --version` |
| GitHub 계정 | https://github.com/deok22-cmd/naverblog 접근 가능 여부 |

### 2단계 — 이 폴더를 PC에 복사 후 설정 실행

```bash
# 프로젝트 폴더로 이동
cd blog_automation

# 설정 스크립트 실행 (최초 1회)
bash setup.sh
```

`setup.sh`가 자동으로 처리하는 것:
- Claude Code 설치 (`npm install -g @anthropic-ai/claude-code`)
- Git 사용자 정보 설정
- GitHub 인증 가이드
- cron 등록 (매일 새벽 4:00)

### 3단계 — Claude Code 로그인

```bash
claude login
```

브라우저가 열리면 Anthropic 계정으로 로그인합니다.

---

## ▶️ 수동 실행 (테스트)

```bash
bash generate_blog.sh
```

실행 흐름:
1. Claude Code가 웹 검색으로 당일 이슈 수집
2. 10개 카테고리 × 2개 주제 선정
3. HTML 원고 20개 작성
4. `./output/YYMMDD/` 에 저장
5. GitHub `deok22-cmd/naverblog` 에 Push

---

## ⏰ 자동 실행 확인

```bash
# 등록된 cron 확인
crontab -l

# 실행 로그 실시간 확인
tail -f logs/cron.log
```

---

## 🔧 GitHub 인증 설정 (SSH 방식 권장)

```bash
# SSH 키 생성
ssh-keygen -t ed25519 -C "your@email.com"

# 공개키 출력 → GitHub에 등록
cat ~/.ssh/id_ed25519.pub
```

GitHub → Settings → SSH and GPG keys → New SSH key 에 붙여넣기

```bash
# remote URL을 SSH 방식으로 변경
cd blog_automation
git remote set-url origin git@github.com:deok22-cmd/naverblog.git
```

---

## ❓ 자주 묻는 문제

| 문제 | 해결 방법 |
|------|-----------|
| `claude: command not found` | `npm install -g @anthropic-ai/claude-code` 재실행 |
| GitHub Push 실패 | SSH 키 등록 확인, `ssh -T git@github.com` 테스트 |
| 파일 10개 미만 생성 | 로그 확인: `cat logs/generate_YYMMDD.log` |
| cron이 실행 안 됨 | `crontab -l`로 등록 확인, PC가 켜져 있는지 확인 |

> **참고:** cron은 PC가 켜져 있어야 작동합니다. 서버(VPS/클라우드)에서 실행하면 24시간 안정적으로 운영할 수 있습니다.

---

## 📊 생성 결과 구조 (예시)

```
output/260325/
├── baseball_01_류현진등판.html
├── baseball_02_KBO개막전.html
├── golf_01_KLPGA대회.html
├── golf_02_마스터스프리뷰.html
├── soccer_01_손흥민골.html
├── soccer_02_K리그결과.html
├── sports_etc_01_배드민턴안세영.html
├── sports_etc_02_수영국제대회.html
├── japan_travel_01_오사카벚꽃.html
├── japan_travel_02_도쿄맛집.html
├── china_travel_01_상하이여행.html
├── china_travel_02_장자제코스.html
├── overseas_travel_01_유럽항공권.html
├── overseas_travel_02_동남아추천.html
├── domestic_travel_01_제주봄여행.html
├── domestic_travel_02_경주벚꽃.html
├── recipe_01_된장찌개황금레시피.html
├── recipe_02_봄나물비빔밥.html
├── kpop_01_아이브신곡.html
└── kpop_02_넷플릭스신작.html
```
