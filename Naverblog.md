# 블로그 운영 지침 v3 (하이엔드 송파 골드 스탠다드 적용)

---

## 01 | 카테고리 구조 (총 10개 메인, 상세 서브 구성)

### 🗺️ 국내여행
- 수도권·경기 / 경상도 / 전라·충청·강원 / 제주도

### ✈️ 해외여행
- 🇯🇵 일본 / 🇨🇳 중국 / 동남아·기타

### 🎪 축제·이벤트
- 봄·여름 축제 / 가을·겨울 축제

### 🏨 숙박·여행팁
- 호텔·펜션 추천 / 항공·교통 꿀팁

### 🍜 맛집·음식
- 국내 맛집 / 해외 맛집 / 레시피·요리

### ⚾ 스포츠
- 야구 KBO·MLB / 골프 / 축구·기타 스포츠

### 🎬 OTT·드라마·영화
- 넷플릭스·OTT 신작 / 드라마 리뷰 / 영화 리뷰

### 🎤 음악·연예·Kpop
- Kpop·아이돌 / 공연·전시

### 💡 생활·정보
- AI·앱 사용법 / 카드·금융 혜택 / 정부지원·복지

### ☕ 일상·이야기
- 여행 후기 / 일상·생각

---

### 카테고리별 메인 컬러 (CSS 테마 색상)

| 메인 카테고리 | 컬러 | HEX |
|---|---|---|
| 국내여행 | `성내천 청록` | `#00796b` |
| 해외여행 | `스카이 블루` | `#1e88e5` |
| 축제·이벤트 | `앰버 오렌지` | `#ff8f00` |
| 숙박·여행팁 | `블루 그레이` | `#546e7a` |
| 맛집·음식 | `핫 오렌지` | `#e64a19` |
| 스포츠 | `스포츠 그린` | `#1a4731` |
| OTT·드라마·영화 | `넷플 레드` | `#d32f2f` |
| 음악·연예·Kpop | `로열 퍼플` | `#6a1b9a` |
| 생활·정보 | `리프 그린` | `#388e3c` |
| 일상·이야기 | `슬레이트 그레이` | `#616161` |

---

## 02 | 주제 선정 5대 기준 (우선순위 순)

1. **실시간 로컬 정보 (최우선 ★★★)** — `[지역명 + 축제/행사 + 실시간/주차/웨이팅 꿀팁]` 조합. 
2. **인물명 + 대기록 스포츠 이슈 (★★★)** — 한국 선수 우승 임박·국가대표 경기 등.
3. **당일 이슈·연예 가십 (★★)** — 트래픽용으로만 활용.
4. **시즌 키워드 (★★)** — 날짜별로 쪼개 경쟁 감소. 예: "경주 벚꽃 오늘이 절정"
5. **고단가 롱테일 (★★)** — IT/의료/금융 정보성. 광고단가 최적화.

---

## 03 | 제목 — 키워드 3단 구조

**빅키워드(앞 10자 이내) + 미들키워드 + 롱테일키워드**를 하나의 자연스러운 문장으로 구성

---

## 04 | [골드 스탠다드] 포맷 & 디자인 v3

### 핵심 원칙
**"송파구 숨은 명소" 원고 포맷을 100% 계승하여, 압도적인 전문성과 가시성을 확보한다.**

1. **디테일한 CSS**: `.course-step`, `.step-num`, `.highlight` 등 시각적 보조 도구를 적극 활용.
2. **분량 및 내용**: 공백 포함 15,000자 내외의 하이엔드 정보성 원고 지향 (절대 후략/생략 금지)
- **주제 선정 소스**: 국내 여행 및 축제 정보는 반드시 **`festival.md`**(전국 축제 일정)와 **`관광공사.md`**(한국관광공사 공식 추천 데이터)를 상호 참조하여 선정한다. 실시간성과 공신력을 동시에 확보한다.
- **[Narrative Master 2.0] 섹션 구성**: 원고 내 소제목(h2, h3 등)으로 구분되는 '꼭지'를 반드시 9개 이상 유지하되, 각 꼭지별 본문은 **최소 8~12행 이상의 압도적이고 밀도 높은 서술**을 지향한다. 단순 요약이 아닌, 현장의 온도, 질감, 전문가적 식견이 고도로 농축된 스토리텔링 형태여야 한다. 독자가 정보의 깊이에 완전히 매료되도록 서술 밀도를 극대화한다.
- **[Visual Diversity] 가독성 강화**: 압도적인 본문 텍스트 사이사이에 **`.course-step`**, **`.point-box`**, **`.tip`**, **`<table>`** 등을 전략적으로 배치하여 시각적 리듬감을 부여한다. 긴 단락은 의미 단위로 2~3개로 나누되, 전체적인 텍스트의 총량은 절대 줄어들지 않도록 주의한다.
- **메타텍스트 노출 금지**: 내부 운영 기준이나 버전 정보를 절대 포함하지 않는다. 독자가 읽기에 가장 자연스러운 매거진 포맷을 유지한다.
3. **강조**: 마크다운 `**` 절대 금지. 반드시 **`<strong>`** 태그만 사용.
4. **이미지**: 원고당 3장 필수. 쿼터 소진 시 **국내여행·해외여행은 상세 영문 프롬프트 3개(`ratio 1:1` 명시)**, **기타 카테고리는 상세 영문 프롬프트 2개(`ratio 1:1` 명시)**와 촬영 가이드를 반드시 제공한다.
5. **데이터 시각화**: 비교 테이블(`<table>`)을 본문 중간에 1~2개 배치하여 정보 요약 제공.
6. **로컬 데이터**: 단순 정보가 아닌 "주민만 아는 맛집", "주차 지옥 피하는 시간대" 등 실전 데이터 포함.

### [표준 템플릿 v3]

```html
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>제목</title>
<style>
  body { margin: 0; padding: 16px; background: #fff; font-family: 'Apple SD Gothic Neo', 'Noto Sans KR', sans-serif; font-size: 16px; line-height: 1.9; color: #222; max-width: 780px; margin: 0 auto; }
  p { margin-bottom: 24px; }
  h1 { font-size: 1.6em; font-weight: 800; border-bottom: 3px solid [컬러]; padding-bottom: 10px; margin-bottom: 20px; color: [컬러]; }
  h2 { font-size: 1.15em; font-weight: 700; border-left: 4px solid [컬러]; padding-left: 10px; margin-top: 48px; margin-bottom: 16px; color: [컬러-다크]; }
  h3 { font-size: 1.1em; font-weight: 700; margin-top: 32px; margin-bottom: 12px; color: [컬러-미들]; }
  .lead { background: [컬러-연하게]; border-left: 4px solid [컬러]; padding: 20px; margin: 24px 0; font-size: 1.05em; color: [컬러-다크]; border-radius: 0 8px 8px 0; }
  .point-box { border: 1px solid [컬러-연하게]; border-radius: 8px; padding: 20px; margin: 24px 0; background: #f5fcfb; }
  .tip { background: #fffbea; border-left: 3px solid #fb8c00; padding: 14px 18px; margin: 20px 0; font-size: 0.95em; color: #5d4037; }
  .closing-box { border-top: 2px solid [컬러]; margin-top: 60px; padding-top: 24px; font-size: 0.92em; color: #555; line-height: 1.8; }
  .tag { display: inline-block; background: #f0f0f0; border-radius: 4px; padding: 2px 10px; margin: 3px; font-size: 0.85em; color: #616161; border: 1px solid #e0e0e0; }
  img { width: 100%; border-radius: 12px; margin: 24px 0; display: block; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
  .img-cap { text-align: center; font-size: 0.85em; color: #757575; margin-top: -12px; margin-bottom: 32px; font-style: italic; }
  table { width: 100%; border-collapse: collapse; margin: 24px 0; font-size: 0.92em; table-layout: fixed; }
  th { background: [컬러]; color: #fff; padding: 12px; text-align: center; border: 1px solid [컬러-다크]; }
  td { border: 1px solid #eee; padding: 12px; text-align: center; }
  .highlight { color: #d32f2f; font-weight: bold; }
  .course-step { display: flex; align-items: flex-start; margin-bottom: 16px; }
  .step-num { flex-shrink: 0; width: 28px; height: 28px; background: [컬러]; color: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: bold; margin-right: 12px; margin-top: 4px; }
</style>
</head>
<body>
  <h1>[Catchy Title]</h1>
  <div class="lead">
    📸 <strong>실시간 상황</strong>: ...<br>
    🛑 <strong>현장 주의</strong>: ...<br>
    ✅ <strong>핵심 추천</strong>: ...
  </div>
  <!-- 본문 시작 -->
  <!-- 1. H2와 문단 -->
  <!-- 2. .course-step 기반 상세 경로 -->
  <!-- 3. .point-box 기반 전문 정보 -->
  <!-- 4. .tip 기반 로컬 맛집/꿀팁 -->
  <!-- 5. <table> 기반 비교 분석 -->
  <!-- 6. .closing-box 마무리 -->
</body>
</html>
```

---

## 05 | AI 판별 회피 및 전문성 강화

- **입체적 도입부**: 1인칭 관점과 감탄사, 질문을 섞어 실제 기자가 답사한 느낌을 준다.
- **데이터 분석**: 단순 일정 안내가 아닌 과거 기록과 비교하거나, 해당 이슈의 사회적/경제적 파급력을 분석한다.
- **풍부한 로컬 데이터**: 해당 지역의 주말 날씨, 주차장 빈자리 확률, 인근 주민만 아는 지름길 등을 포함한다.

---

1. **최신 데이터 검색**: `search_web` 및 공식 홈페이지(홈택스, 기상청 등)를 통해 실시간 상황 및 일정 100% 검증.
2. **분량 확보**: 모든 조사 내용을 플레이스홀더 없이 1.5만 자 내외로 상세 서술.
3. **이미지 제작**: 원고당 3장 고정. 쿼터 소진 시 1:1 비율 프롬프트 가이드 필수.
4. **HTML 정답지 작성**: 표준 템플릿 v3 적용.
5. **수익형 믹스 검토**: 여행 정보 하단에 IT/경제/건강 원고 링크를 배치하여 '낙수 효과'가 발생하는지 확인.

---

## 07 | [Z.E.P 1.0] 무결점 원고 생산 프로토콜 (Zero-Error Protocol)

최초 원고에서 사용자의 팩트체크 개입을 0%에 수렴하게 만들기 위한 강제 규범이다. 모든 카테고리 기사 작성 전 이 프로토콜을 1회 자가 실행한다.

### 7.1. 카테고리별 필수 검증 앵커 (Anchor points)
*   **[국내/해외 여행 & 축제]**: 
    - **실시간성**: 기상청 예보 및 공식 홈페이지의 '2026년 공지' 확인 필수. (평균값이 아닌 올해 실측치 사용)
    - **정보 정합성**: 개장일, 입장료, 주차장 현황, 인근 공사 여부 등 독자가 헛걸음하지 않도록 현시점 데이터를 교차 검증.
*   **[IT/테크/가전]**: 
    - **스펙 정확도**: 브랜드별 고유 측정 단위(Pa vs Watt 등)를 명확히 구분. Hallucination 수치 생성 금지.
    - **실존 인격 확보**: 가칭(Tentative) 모델명 사용 금지. 실존 모델과 공식 사양서를 기반으로만 작성.
*   **[경제/세무/금융]**: 
    - **세법/조례**: 2026년 기준 최신 법령 및 조세특례제한법 확인. (과거 한시 규정 혼용 절대 금지)
    - **일정**: 홈택스, 은행 앱 등 서비스 가능 여부를 현재 날짜(2026-04-07) 기준으로 대조.
*   **[건강/의학/시즌]**: 
    - **메커니즘**: 의학적 원리(기온/습도에 따른 반응)를 변수와 함께 설명하되, "100%", "반드시" 등 극단적 표현 배제.

### 7.2. 3대 원고 생성 금지 원칙 (Forbidden Rules)
1.  **Hallucination 수치 금지**: "15,000Pa" 등 구체적 수치는 반드시 공식 사양서 검색 후 기재. 불확실할 경우 범위를 넓게 잡거나 검색이 필요함을 명시.
2.  **절대값 확신 금지**: "100% 꽃가루다", "일주일이면 다 망가진다" 등 변수가 많은 현상에 대한 절대적 단정 금지. (대신: "높은 확률로", "환경에 따라 수일 내에도" 등 객관적 표현 사용)
3.  **경쟁사 평가절하 금지**: 비교표 작성 시 타 업체를 일방적으로 폄하하여 법적/도덕적 리스크를 만들지 않음. (대신: "전문 공법 차이에 따른 주의 필요" 등으로 완화)

### 7.3. 원고 생성 전 '자가 점검' 리스트 (Self-Check Note)
모든 원고 출력 전, AI는 다음 질문에 스스로 답한 뒤 작성을 시작한다:
- "이 수치(Pa/Watt/세율/날짜)는 2026년 공식 데이터인가?"
- "이 내용은 제조사/정부기관의 오피셜 공지인가?"
- "독자가 내 글을 보고 행동했을 때 금전적/건강상 리스크가 없는가?"

---

## 08 | 수익형 믹스 & 낙수 효과 (Waterfall Strategy)

1. **유입 채널**: 실시간 여행/축제 정보로 대량의 트래픽을 확보한다.
2. **체류 연장**: 여행 정보 중간/하단에 관련 IT 세팅(갤럭시 카메라), 건강(꽃가루 케어), 경제(나들이 비용 절세) 원고를 링크한다.
3. **비즈니스 전환**: 텐트 세척, 장비 관리 등 직접적인 수익 모델인 **'텐트깔끄미'** 서비스로의 마지막 연결을 완성한다.

---

## 09 | [필수] 내부 링크 및 운영 가이드
- **가두리 전략**: `.closing-box` 내 관련 포스팅 2개 이상 필수 링크.
- **이미지 정책**: 쿼터 소진 시 카테고리에 맞는 상세 영문 프롬프트(기타는 ratio 1:1) 제공.
- **마크다운 금지**: 강조 시 `**` 대신 반드시 `<strong>` 태그 사용.
