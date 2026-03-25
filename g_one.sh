#!/bin/bash
# ============================================================
# 블로그 자동생성 메인 스크립트 v2.0
# cron: 0 4 * * * /path/to/generate_blog.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE=$(date +%y%m%d)
DATE_FULL=$(date +%Y-%m-%d)
OUTPUT_DIR="$SCRIPT_DIR/output/$DATE"
LOG_FILE="$SCRIPT_DIR/logs/generate_$DATE.log"
GITHUB_REPO="https://github.com/deok22-cmd/naverblog"

mkdir -p "$SCRIPT_DIR/logs"
log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

log "======================================================"
log "블로그 자동생성 시작 — $DATE_FULL"
log "======================================================"

mkdir -p "$OUTPUT_DIR"
log "출력 폴더 생성: $OUTPUT_DIR"
log "Claude Code 원고 생성 시작..."

claude --dangerously-skip-permissions -p "
오늘 날짜: $DATE_FULL (폴더명: $DATE)
저장 경로: $OUTPUT_DIR

## 필수 전제
CLAUDE.md 파일의 모든 지침을 완전히 숙지하고 엄격히 따를 것.
내용 축약·생략 절대 금지. 각 원고는 실제 네이버 블로그에 바로 올릴 수 있는 완성도여야 한다.

---

## STEP 1. 당일 이슈 웹 검색 (카테고리별 반드시 실행)

아래 키워드로 각각 웹 검색하여 $DATE_FULL 기준 실제 최신 정보를 수집한다.
절대 추측하거나 학습 데이터 기반으로 작성하지 말 것. 모르면 롱테일 스테디로 대체.

검색 목록:
- \"중국 여행 최신 정보 비자\"

---

## STEP 2. 주제 선정 (총:1개)

CLAUDE.md의 주제 선정 5대 기준을 우선순위대로 적용.
각 주제마다 아래를 정리:
- 빅키워드 / 미들키워드 / 롱테일키워드
- 최종 제목 (키워드 3단 구조 반영)
- 선정 근거 1줄

---

## STEP 3. HTML 원고 1개 작성

CLAUDE.md의 HTML 구조를 100% 따라 작성. 아래 사항 전부 적용:

### 공통 필수사항
- 배경색 #ffffff 고정
- 카테고리별 메인 컬러 A/B 정확히 적용
- h2에 border-left 4px solid 메인컬러A 반드시 적용
- .lead 리드 문단: 구어체 2~3문장 (\"오늘 이 소식 보고 저도 놀랐는데요\" 류)
- .point-box 최소 1개 포함
- .closing-box 맺음말 (응원형/질문형/요약형/예고형 중 매번 다르게)
- 해시태그 15개 내외
- 출처 주의사항 .source-notice 필수 포함

### 카테고리별 레이아웃
- 스포츠(야구/골프/축구/기타): card-grid 성적 카드 + 결과 테이블, 분량 1,000~1,500자
- 여행(일본/중국/해외/국내): 시간순 코스 + tip-box 2~3개, 분량 1,500~2,000자
- 레시피: 재료 테이블 + recipe-step 단계 박스, 분량 1,200~1,800자
- 연예/Kpop: 스토리 흐름 중심, 분량 1,000~1,500자

### AI 판별 회피 기법 (6가지 전부 적용)
1. 소제목 형태 혼재: 질문형 / 단언형 / 숫자형 섞기
2. 문단 길이 불규칙: 1줄 임팩트 ↔ 4~5줄 상세 번갈아
3. 도입부 2~3문장 구어체
4. 1인칭 주관 표현 중간 삽입 (\"솔직히\", \"이건 좀 의외였는데\")
5. 테이블 1~2개로 제한
6. 맺음말 스타일 매번 교체

---

## STEP 4. 파일 저장 (20개 전부)

저장 경로: $OUTPUT_DIR/
파일명: {카테고리ID}_{순번}_{빅키워드}.html

카테고리ID 목록:
baseball / golf / soccer / sports_etc /
japan_travel / china_travel / overseas_travel / domestic_travel /
recipe / kpop

파일 저장 시 Write 도구를 사용하여 실제 파일로 저장할 것.
1개 전부 빠짐없이 저장. 누락 절대 금지.

---

## STEP 5. 완료 보고

생성 완료 후 아래 형식으로 보고:
| 파일명 | 제목 | 빅키워드 | 분량(자) |
각 개 행으로 출력.
" 2>&1 | tee -a "$LOG_FILE"

log "Claude Code 원고 생성 완료"

# ── 생성 파일 수 확인 ────────────────────────────────────────
GENERATED=$(find "$OUTPUT_DIR" -name "*.html" | wc -l)
log "생성된 HTML 파일 수: $GENERATED / 1"


# ── GitHub Push ──────────────────────────────────────────────
log "GitHub Push 시작..."
cd "$SCRIPT_DIR"

if [ ! -d ".git" ]; then
  git init
  git remote add origin "$GITHUB_REPO.git"
  git branch -M main
fi

git fetch origin main 2>/dev/null || true
git checkout main 2>/dev/null || git checkout -b main
git add "output/$DATE/"
COMMIT_MSG="📝 블로그 원고 자동생성 — $DATE_FULL (${GENERATED}개)"
git commit -m "$COMMIT_MSG"
git push origin main 2>&1 | tee -a "$LOG_FILE"

log "======================================================"
log "✅ 완료: $GENERATED개 파일 생성 및 GitHub Push 성공"
log "   저장소: $GITHUB_REPO"
log "   경로: output/$DATE/"
log "======================================================"
