# 블로그 운영 지침 v2 (CSS 최소화 버전)

---

## 01 | 카테고리 (10개, 매일 각 1개 발행)

⚾ 스포츠/야구 | ⛳ 골프 | ⚽ 축구 | 🏅 스포츠/기타 | 🇯🇵 일본여행 | 🇨🇳 중국여행 | ✈️ 해외여행 | 🗺️ 국내여행 | 🍳 음식레시피 | 🎤 연예/Kpop/영화/드라마/넷플릭스

---

## 02 | 주제 선정 5대 기준 (우선순위 순)

1. **인물명 검색** — 실명 검색되는 인물이 있으면 최우선. 제목 앞부분에 반드시 배치
2. **당일 이슈** — 사건·우승·발표·논란. 오전 발행이 골든타임
3. **진행형 이벤트** — 1R→2R→결과 시리즈로 연속 유입
4. **시즌 키워드** — 도시별·날짜별로 쪼개 경쟁 감소 (예: "도쿄 벚꽃 D-6")
5. **롱테일 스테디** — 레시피·제품 비교·정보성. 장기 트래픽 자산

> 주제 선정 후 자체적으로 팩트 체크해서 확인 후 제시

---

## 03 | 제목 — 키워드 3단 구조

**빅키워드(앞 10자 이내) + 미들키워드 + 롱테일키워드**를 하나의 자연스러운 문장으로 구성

**3대 규칙**
- 빅키워드는 제목 앞 10자 안에 배치
- 키워드 나열 금지 → 자연스러운 문장으로
- 제목 = 검색자의 질문에 대한 정확한 답

| ❌ 나쁜 예 | ✅ 좋은 예 |
|---|---|
| "김효주 LPGA 우승 파운더스컵 통산8승 넬리코다" | "김효주 파운더스컵 우승 — 16언더파, 넬리코다 1타 차 제압" |
| "김효주, 또 해냈다! 감동의 우승 스토리" | "김효주 LPGA 통산 8승 — 파운더스컵 와이어투와이어 우승" |

---

## 04 | 포맷 & 디자인 — HTML CSS 최소화 원칙

### 핵심 원칙
**인라인 스타일 대신 HTML 시맨틱 태그 + 최소한의 `<style>` 블록만 사용한다.**

- `<style>` 블록은 문서 최상단에 1개만 작성
- 인라인 `style=""` 속성은 **색상 강조 1~2곳**에만 허용
- 클래스는 5개 이하로 제한: `.lead`, `.point-box`, `.closing-box`, `.tip`, `.tag`
- **분량 및 내용: 공백 포함 5,000자 내외, 단순 정보 나열을 넘어선 심층 분석 포함**
- 레이아웃은 HTML 기본 흐름(block/inline)에 최대한 맡기고, Flexbox는 카드 나열 시에만 허용
- 폰트 임포트 금지 (시스템 폰트 사용: `font-family: 'Apple SD Gothic Neo', 'Noto Sans KR', sans-serif`)
- 애니메이션·transition 금지
- 배경색 `#ffffff` 고정

### 카테고리별 메인 컬러 (border-left 강조 색상으로만 사용)

| 카테고리 | 컬러 |
|---|---|
| 야구 | `#1a4731` (딥 그린) |
| 골프 | `#2d5a27` (포레스트 그린) |
| 축구 | `#1a2f5e` (네이비) |
| 스포츠/기타 | `#2c3e50` (다크 그레이) |
| 일본여행 | `#c0392b` (딥 레드) |
| 중국여행 | `#d32f2f` (차이나 레드) |
| 해외여행 | `#1e88e5` (스카이블루) |
| 국내여행 | `#00796b` (청록) |
| 음식레시피 | `#e64a19` (웜 오렌지) |
| 연예/Kpop | `#6a1b9a` (퍼플) |

### CSS 최소화 표준 템플릿

```html
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>제목</title>
<style>
  /* ── 전역 ── */
  body { margin: 0; padding: 16px; background: #fff; font-family: 'Apple SD Gothic Neo', 'Noto Sans KR', sans-serif; font-size: 16px; line-height: 1.8; color: #222; max-width: 780px; margin: 0 auto; }

  /* ── 제목 ── */
  h1 { font-size: 1.6em; font-weight: 800; border-bottom: 3px solid [카테고리컬러]; padding-bottom: 10px; margin-bottom: 6px; }
  h2 { font-size: 1.15em; font-weight: 700; border-left: 4px solid [카테고리컬러]; padding-left: 10px; margin-top: 32px; }
  h3 { font-size: 1em; font-weight: 700; margin-top: 20px; }

  /* ── 공통 박스 ── */
  .lead      { background: #f8f8f8; border-left: 4px solid [카테고리컬러]; padding: 12px 16px; margin: 16px 0; font-size: 1.05em; }
  .point-box { border: 1px solid #ddd; border-radius: 6px; padding: 14px 16px; margin: 16px 0; background: #fafafa; }
  .tip       { background: #fffbea; border-left: 3px solid #f0c040; padding: 10px 14px; margin: 12px 0; font-size: 0.95em; }
  .closing-box { border-top: 2px solid [카테고리컬러]; margin-top: 40px; padding-top: 16px; font-size: 0.9em; color: #555; }

  /* ── 해시태그 ── */
  .tag { display: inline-block; background: #f0f0f0; border-radius: 4px; padding: 2px 8px; margin: 2px; font-size: 0.82em; color: #444; }

  /* ── 테이블 ── */
  table { width: 100%; border-collapse: collapse; margin: 16px 0; font-size: 0.95em; }
  th { background: [카테고리컬러]; color: #fff; padding: 8px 10px; text-align: left; }
  td { border-bottom: 1px solid #eee; padding: 8px 10px; }

  /* ── 카드형 (스포츠 선수/팀 나열 시에만) ── */
  .cards { display: flex; flex-wrap: wrap; gap: 12px; margin: 16px 0; }
  .card  { flex: 1 1 220px; border: 1px solid #e0e0e0; border-top: 3px solid [카테고리컬러]; border-radius: 6px; padding: 14px; background: #fff; }
</style>
</head>
<body>
  <!-- 본문 -->
</body>
</html>
```

> **[카테고리컬러]** 자리에 위 색상표의 해당 HEX값을 넣는다. 그 외 추가 스타일 작성 금지.

### 카테고리별 HTML 구조 방향

| 카테고리 | 구조 스타일 |
|---|---|
| 스포츠 | 선수/팀 `.card` 반복 — 매거진 에디토리얼형 |
| 여행 | 시간순 코스 + `.tip` 박스 — 일기체형 |
| 레시피 | 손질 단계 + `.point-box` 레시피 박스 — 일기체형 |
| 연예 | 스토리 흐름 중심 — 에디토리얼형 |

---

## 05 | AI 판별 회피

- 소제목 형태 혼재 (질문형 / 단언형 / 숫자형)
- 문단 길이 불규칙 (1줄 ↔ 4~5줄)
- 도입부 2~3문장 구어체 ("오늘 이 소식 보고 저도 놀랐는데요")
- 1인칭 주관 표현 간간이 삽입 ("솔직히", "이건 좀 의외였는데")
- 테이블 1~2개로 제한 / 맺음말 스타일 매번 교체

---

## 06 | 원고 작성 프로세스

1. **실시간 검색으로 데이터 수집** — 스포츠 일정·결과·기록은 반드시 검색, 추측 금지
2. **분석 및 확장** — 데이터를 기반으로 과거 기록 비교, 전문가 전망, 기술적 분석 등을 추가하여 5,000자 내외의 풍성한 분량 확보
3. **이미지 생성 (3장)** — 각 원고의 주요 부제목 테마에 맞춰 3장의 고품질 이미지를 생성하고 삽입
4. **HTML 초안 작성** — 표준 템플릿 기반, 배경색 `#ffffff` 고정
5. **팩트체크** — 수치·날짜·인명·직함·결과값 전수 검증
6. **제목 3개 옵션 제시** — 키워드 3단 구조 반영
7. **최종본 파일 저장 후 `present_files` 제공**

**HTML 고정 요소**
- `h2` 왼쪽 보더 강조 유지
- `.lead`, `.point-box`, `.closing-box` 유지
- 해시태그 15개 내외 (`.tag` 클래스 사용)
- 출처 및 주의사항 문구 필수 (`.closing-box` 안에 포함)
- 건강·의료 글: 상단 `<div class="lead">` 에 "정보 제공 목적, 전문의 상담 권장" 배너 필수

---

## 07 | 트리거 — "오늘 주제 정해줘"

10개 카테고리 × 각 1개 주제, 각 주제마다 제공:
- 키워드 3단 구조 (빅 / 미들 / 롱테일)
- 제목 시안 2~3개
- 선정 근거
- 추천 포맷
- 시리즈 연결 아이디어 (해당 시)

---

## 08 | 자동화 지침

- 주제 선정 및 원고 작성 요청 시:
  - 원고: `./output/yymmdd/***.html` 파일로 저장
  - 이미지: `./images/yymmdd/***.png` 파일로 저장 (원고당 3장)
  - `Naverblog.md` 지침 엄격 준수

위 내용을 Naverblog.md 에 저장하고 내가 지침을 수정 요청하면 이 file의 내용을 수정해줘.
