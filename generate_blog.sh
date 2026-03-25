#!/bin/bash
# ============================================================
# 블로그 자동생성 메인 스크립트 v4.0
# - 중복 방지 (used_keywords.json)
# - 30일 자동 만료
# - 동명 인물/장소 다른 사건 허용 (세부 판단 로직)
# cron: 0 4 * * * /path/to/generate_blog.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE=$(date +%y%m%d)
DATE_FULL=$(date +%Y-%m-%d)
OUTPUT_DIR="$SCRIPT_DIR/output/$DATE"
LOG_FILE="$SCRIPT_DIR/logs/generate_$DATE.log"
KEYWORDS_FILE="$SCRIPT_DIR/used_keywords.json"
GITHUB_REPO="git@github.com:deok22-cmd/naverblog"

mkdir -p "$SCRIPT_DIR/logs"
log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

log "======================================================"
log "블로그 자동생성 시작 — $DATE_FULL"
log "======================================================"

# ── used_keywords.json 초기화 (없으면 생성) ──────────────────
if [ ! -f "$KEYWORDS_FILE" ]; then
  log "used_keywords.json 초기 생성..."
  cat > "$KEYWORDS_FILE" << 'JSON'
{
  "last_updated": "",
  "keywords": []
}
JSON
fi

# ── 30일 만료 처리 (Python으로 JSON 가공) ────────────────────
log "30일 만료 키워드 정리 중..."
python3 << PYEOF
import json, datetime, os

keywords_file = "$KEYWORDS_FILE"
today = datetime.date.today()
cutoff = today - datetime.timedelta(days=30)

with open(keywords_file, "r", encoding="utf-8") as f:
    data = json.load(f)

# 구버전 포맷(categories 딕셔너리) → 신버전(keywords 배열) 자동 변환
if "categories" in data and "keywords" not in data:
    new_keywords = []
    for cat, kw_list in data["categories"].items():
        for kw in kw_list:
            new_keywords.append({
                "category": cat,
                "keyword": kw,
                "title": "",
                "event": "",
                "date": "2000-01-01"
            })
    data = {"last_updated": data.get("last_updated",""), "keywords": new_keywords}

before = len(data["keywords"])
data["keywords"] = [
    k for k in data["keywords"]
    if datetime.date.fromisoformat(k.get("date","2000-01-01")) >= cutoff
]
after = len(data["keywords"])

with open(keywords_file, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"만료 키워드 제거: {before - after}개 / 유효 키워드: {after}개")
PYEOF

# ── B방법: output/ 파일명 스캔으로 키워드 보완 ───────────────
log "기존 파일명에서 사용 키워드 스캔 중..."
SCANNED_KEYWORDS=""
if [ -d "$SCRIPT_DIR/output" ]; then
  SCANNED_KEYWORDS=$(find "$SCRIPT_DIR/output" -name "*.html" | \
    sed 's/.*\/[a-z_]*_[0-9]*_//' | \
    sed 's/\.html$//' | \
    sort -u | \
    tr '\n' ', ')
fi
log "스캔된 파일명 키워드: $SCANNED_KEYWORDS"

# ── used_keywords.json 내용 읽기 ────────────────────────────
USED_KEYWORDS_JSON=$(cat "$KEYWORDS_FILE")

mkdir -p "$OUTPUT_DIR"
log "출력 폴더 생성: $OUTPUT_DIR"
log "Claude Code 원고 생성 시작..."

# ── Claude Code 실행 ─────────────────────────────────────────
claude --dangerously-skip-permissions -p "
오늘 날짜: $DATE_FULL (폴더명: $DATE)
저장 경로: $OUTPUT_DIR

## 필수 전제
CLAUDE.md 파일의 모든 지침을 완전히 숙지하고 엄격히 따를 것.
내용 축약·생략 절대 금지. 각 원고는 실제 네이버 블로그에 바로 올릴 수 있는 완성도여야 한다.

---

## ⛔ 중복 방지 시스템 (반드시 준수)

### 📋 기사용 키워드 이력 (최근 30일, used_keywords.json):
$USED_KEYWORDS_JSON

### 📋 파일명 스캔 추가 감지 키워드:
$SCANNED_KEYWORDS

---

### 🔍 중복 판단 기준 — 3단계로 판별

**1단계: 빅키워드 일치 여부 확인**
- 빅키워드가 완전히 다르면 → 즉시 허용
- 빅키워드가 같거나 유사하면 → 2단계로

**2단계: 인물/장소가 같은 경우 — 사건(event) 비교**
이력의 event 필드와 오늘 주제의 핵심 사건을 비교:
- 사건이 명확히 다른 경우 → 허용 (추가취재·후속보도·다른대회 등)
- 사건이 동일하거나 거의 같은 경우 → 3단계로

판단 예시:
| 이력 event | 오늘 주제 | 판단 |
|-----------|-----------|------|
| 파운더스컵 우승 | 쉐브론챔피언십 우승 | ✅ 허용 (다른 대회) |
| 파운더스컵 우승 | 파운더스컵 우승 소감 인터뷰 | ⛔ 차단 (같은 사건 재탕) |
| 도쿄 벚꽃 명소 | 도쿄 라멘 맛집 | ✅ 허용 (다른 주제) |
| 도쿄 벚꽃 명소 | 도쿄 벚꽃 개화 시기 | ⛔ 차단 (같은 주제 재탕) |
| 손흥민 골 장면 | 손흥민 부상 복귀 소식 | ✅ 허용 (다른 사건) |
| 아이브 신곡 | 아이브 뮤직비디오 분석 | ⛔ 차단 (같은 컨텐츠 재탕) |
| 된장찌개 레시피 | 된장찌개 다이어트 버전 | ✅ 허용 (다른 앵글) |
| 오사카 3박4일 | 오사카 당일치기 코스 | ✅ 허용 (다른 일정) |

**3단계: 최종 판정**
- 차단 판정 시 → 해당 카테고리에서 완전히 다른 주제로 교체
- 대체 주제도 이력과 비교 후 선정

---

## STEP 1. 당일 이슈 웹 검색 (카테고리별 반드시 실행)

아래 키워드로 각각 웹 검색하여 $DATE_FULL 기준 실제 최신 정보를 수집한다.
추측하거나 학습 데이터 기반으로 작성하지 말 것.

검색 목록:
- \"KBO 오늘 경기 $DATE_FULL\" + \"MLB 한국선수 오늘\"
- \"KLPGA LPGA PGA 이번주 대회 결과\"
- \"K리그 오늘 경기\" + \"손흥민 이강인 최신 소식\"
- \"오늘 스포츠 뉴스 $DATE_FULL\" (배드민턴·수영·육상 등)
- \"일본 여행 $DATE_FULL 벚꽃 엔화\"
- \"중국 여행 최신 정보 비자\"
- \"해외여행 항공권 특가 $DATE_FULL\"
- \"국내여행 주말 추천 $DATE_FULL\"
- \"제철 음식 레시피 $DATE_FULL\"
- \"Kpop 신곡 드라마 넷플릭스 $DATE_FULL\"

---

## STEP 2. 주제 선정 (카테고리별 2개, 총 20개)

CLAUDE.md의 주제 선정 5대 기준 우선순위대로 적용.
반드시 위 중복 판단 3단계를 거친 후 선정.

각 주제마다 아래를 정리:
- 빅키워드 / 미들키워드 / 롱테일키워드
- 핵심 사건(event): 이 글의 핵심 사건을 15자 이내로 요약 (예: \"파운더스컵 우승\", \"도쿄 벚꽃 명소\")
- 최종 제목
- 중복 판단 결과: \"신규\" / \"동명 허용 — 사건: OOO (이력: OOO)\"

---

## STEP 3. HTML 원고 20개 작성

CLAUDE.md의 HTML 구조를 100% 따라 작성. 아래 사항 전부 적용:

공통 필수사항:
- 배경색 #ffffff 고정
- 카테고리별 메인 컬러 A/B 정확히 적용
- h2에 border-left 4px solid 메인컬러A 반드시 적용
- .lead 리드 문단: 구어체 2~3문장
- .point-box 최소 1개
- .closing-box 맺음말 (응원형/질문형/요약형/예고형 중 매번 다르게)
- 해시태그 15개 내외
- .source-notice 출처 주의사항 필수

카테고리별 레이아웃:
- 스포츠(야구/골프/축구/기타): card-grid + 결과 테이블, 1,000~1,500자
- 여행(일본/중국/해외/국내): 시간순 코스 + tip-box 2~3개, 1,500~2,000자
- 레시피: 재료 테이블 + recipe-step, 1,200~1,800자
- 연예/Kpop: 스토리 흐름, 1,000~1,500자

AI 판별 회피 기법 (6가지 전부):
1. 소제목 형태 혼재: 질문형/단언형/숫자형
2. 문단 길이 불규칙: 1줄 ↔ 4~5줄
3. 도입부 구어체 2~3문장
4. 1인칭 주관 표현 삽입 (\"솔직히\", \"이건 좀 의외였는데\")
5. 테이블 1~2개 제한
6. 맺음말 스타일 매번 교체

---

## STEP 4. 파일 저장 (20개 전부)

저장 경로: $OUTPUT_DIR/
파일명: {카테고리ID}_{순번}_{빅키워드}.html

카테고리ID:
baseball / golf / soccer / sports_etc /
japan_travel / china_travel / overseas_travel / domestic_travel /
recipe / kpop

Write 도구로 실제 파일 저장. 20개 전부 빠짐없이.

---

## STEP 5. used_keywords.json 업데이트 (매우 중요)

모든 파일 저장 완료 후 아래 경로의 JSON을 반드시 업데이트:
$KEYWORDS_FILE

업데이트 형식 — 기존 배열에 오늘 항목 추가:
{
  \"last_updated\": \"$DATE_FULL\",
  \"keywords\": [
    // 기존 항목 유지 +
    {
      \"category\": \"카테고리ID\",
      \"keyword\": \"빅키워드\",
      \"title\": \"최종제목\",
      \"event\": \"핵심사건 15자이내\",
      \"date\": \"$DATE_FULL\"
    },
    // ... 오늘 생성한 20개 전부 추가
  ]
}

규칙:
- 기존 데이터 절대 삭제하지 말 것 (만료는 스크립트가 자동 처리)
- event 필드는 반드시 구체적으로 기입 (다음 실행의 중복 판단에 사용)
- 오늘 생성한 20개 항목 전부 추가

---

## STEP 6. 완료 보고

아래 표로 출력:
| 파일명 | 제목 | 빅키워드 | 핵심사건 | 중복판단 | 분량(자) |
20개 행.
" 2>&1 | tee -a "$LOG_FILE"

log "Claude Code 원고 생성 완료"

# ── 생성 파일 수 확인 ────────────────────────────────────────
GENERATED=$(find "$OUTPUT_DIR" -name "*.html" | wc -l)
log "생성된 HTML 파일 수: $GENERATED / 20"

if [ "$GENERATED" -lt 10 ]; then
  log "⚠️  경고: 생성 파일이 10개 미만. GitHub Push 중단."
  exit 1
fi

# ── index.html 생성 ──────────────────────────────────────────
log "index.html 생성 중..."
python3 << PYEOF
import os, re
from collections import defaultdict

output_dir = "$OUTPUT_DIR"
date_full  = "$DATE_FULL"

CATEGORY_NAMES = {
    'baseball':        '⚾ 야구',
    'golf':            '⛳ 골프',
    'soccer':          '⚽ 축구',
    'sports_etc':      '🏅 기타 스포츠',
    'japan_travel':    '🗾 일본 여행',
    'china_travel':    '🇨🇳 중국 여행',
    'overseas_travel': '✈️ 해외 여행',
    'domestic_travel': '🏔️ 국내 여행',
    'recipe':          '🍳 레시피',
    'kpop':            '🎵 연예/Kpop',
}

files = sorted([f for f in os.listdir(output_dir)
                if f.endswith('.html') and f != 'index.html'])

items = []
for fname in files:
    fpath = os.path.join(output_dir, fname)
    try:
        with open(fpath, 'r', encoding='utf-8') as f:
            content = f.read()
        m = re.search(r'<title>(.*?)</title>', content, re.IGNORECASE | re.DOTALL)
        title = m.group(1).strip() if m else fname
    except Exception:
        title = fname
    cat_id   = fname.split('_')[0] if '_' in fname else 'etc'
    cat_name = CATEGORY_NAMES.get(cat_id, cat_id)
    items.append((cat_id, cat_name, fname, title))

by_cat = defaultdict(list)
for cat_id, cat_name, fname, title in items:
    by_cat[cat_id].append((cat_name, fname, title))

total    = len(files)
sections = ""
for cat_id in list(CATEGORY_NAMES.keys()):
    if cat_id not in by_cat:
        continue
    posts    = by_cat[cat_id]
    cat_name = posts[0][0]
    li_items = "".join(
        f'<li><a href="{fname}">{title}</a></li>'
        for _, fname, title in posts
    )
    sections += f"""
    <div class="cat-section">
      <h2>{cat_name}</h2>
      <ul>{li_items}</ul>
    </div>"""

html = f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>블로그 원고 목록 — {date_full}</title>
<style>
  body {{ font-family: 'Noto Sans KR', sans-serif; background:#f5f5f5; margin:0; padding:20px; }}
  .container {{ max-width:900px; margin:0 auto; background:#fff; border-radius:12px;
               box-shadow:0 2px 12px rgba(0,0,0,.08); padding:32px; }}
  h1 {{ color:#1a73e8; border-bottom:3px solid #1a73e8; padding-bottom:12px; margin-top:0; }}
  .meta {{ color:#888; margin-bottom:24px; font-size:14px; }}
  .cat-section {{ margin-bottom:28px; }}
  h2 {{ font-size:17px; color:#333; background:#f0f4ff; padding:8px 14px;
        border-radius:6px; border-left:4px solid #1a73e8; margin:0 0 4px; }}
  ul {{ list-style:none; padding:0; margin:0; }}
  li {{ padding:9px 12px; border-bottom:1px solid #f0f0f0; }}
  li:last-child {{ border-bottom:none; }}
  a {{ color:#222; text-decoration:none; font-size:15px; line-height:1.5; }}
  a:hover {{ color:#1a73e8; text-decoration:underline; }}
  .total {{ display:inline-block; background:#1a73e8; color:#fff;
            border-radius:20px; padding:2px 12px; font-size:14px; }}
</style>
</head>
<body>
<div class="container">
  <h1>📋 블로그 원고 목록</h1>
  <p class="meta">생성일: {date_full} &nbsp;|&nbsp; 총 <span class="total">{total}개</span></p>
  {sections}
</div>
</body>
</html>"""

index_path = os.path.join(output_dir, 'index.html')
with open(index_path, 'w', encoding='utf-8') as f:
    f.write(html)
print(f"index.html 생성 완료 — {total}개 원고 링크 포함")
PYEOF
log "index.html 생성 완료"

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

# used_keywords.json도 함께 커밋
git add "output/$DATE/" "used_keywords.json"
COMMIT_MSG="📝 블로그 원고 자동생성 — $DATE_FULL (${GENERATED}개)"
git commit -m "$COMMIT_MSG"
git push origin main 2>&1 | tee -a "$LOG_FILE"

log "======================================================"
log "✅ 완료: $GENERATED개 파일 생성 및 GitHub Push 성공"
log "   저장소: $GITHUB_REPO"
log "   경로: output/$DATE/"
log "======================================================"
