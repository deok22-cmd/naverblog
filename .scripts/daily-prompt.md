# Naverblog 일일 자동 발행 작업 (placeholder 모드 + 티스토리 미러, v2 트랙 룰)

매일 새벽 4시(KST) Windows 작업 스케줄러가 실행하는 자동 발행 파이프라인이다. 본 프롬프트만으로 컨텍스트가 자기완결되도록 구성되어 있으며, 시작 시 이미 작업 디렉터리는 `D:\lightsail\naverblog`이다.

**작업 흐름 요약 (2026-05-14 v2 트랙 룰 도입)**:
- **Phase A (네이버)**: 5건의 네이버 블로그 원고를 `output/YYMMDD/`에 작성, 트래커 갱신.
  - 발행 구성: **`국내여행지.md` §02 발행 후보 표 위에서부터 5건** (근시일 단일 리스트 — A/B/C 트랙·비율 폐기, 2026-05-19 단순화. `Naverblog.md` 02조)
  - 서브 카테고리(스프레드시트/레시피) 발행 **중단** — 관련 트래커 파일 동결
- **Phase B (티스토리 미러)**: 동일 5건 주제를 **제목·본문 완전 재작성**하여 `output_tistory/YYMMDD/`에 미러 작성 (트래커 재갱신 X).

---

## 1. 사전 컨텍스트 로드 (필수, 순서 준수)

다음 파일을 모두 Read 도구로 읽어 운영 규칙을 정확히 이해한다.

1. `Naverblog.md` — 운영 지침 v5 (Platinum 표준 템플릿, 02조·02-bis조 v2 트랙 룰 포함)
2. `국내여행지.md` — 국내여행 주제 DB (`## 02 발행 후보`=근시일 단일 리스트에서 선정 / `## 03 발행 완료 로그`·`## 01`=과거 기록)
3. `trackabc.md` — v2 트랙 체계 운영 가이드 및 주제 추가 표준 절차 (§6)

**※ 동결 파일** — 본 단계에서 로드하지 않는다 (2026-05-14 서브 카테고리 발행 중단):
- ~~`sub_topic_tracker.md`~~ (NEXT_TOPIC 토글 미사용)
- ~~`spreadsheet.md`~~ (신규 발행 중단)
- ~~`receipt.md`~~ (신규 발행 중단)

또한 오늘 날짜를 `date +%y%m%d` (Bash) 또는 `Get-Date -Format yyMMdd` (PowerShell)로 확인하여 `YYMMDD` 변수를 확보한다. 이 변수가 본 작업의 기준 폴더명이 된다.

전날 폴더(`output/<yesterday_yymmdd>/`)도 확인해 내부 링크 후보 2개를 추출한다.

---

## 2. 모드 판별 및 주제 선정 (Idempotent)

### 2.1 모드 판별 — Resume vs Fresh
먼저 `output/YYMMDD/index.html`이 **이미 존재하는지** Glob으로 확인한다.

- **Resume 모드** (대시보드 이미 존재): 해당 `index.html`을 Read로 읽어 5개 행을 파싱한다.
  - `✔️ 작성 완료` 상태인 행은 **재작성 절대 금지**(이미 사용자가 수동으로 만들었거나 이전 실행에서 완성됨)
  - `⏳ 작성 대기` 상태인 행만 본 실행에서 작성한다
  - 주제 텍스트와 트랙(`[A]/[B]/[C]`)은 기존 대시보드의 값을 그대로 사용
  - 이 모드에서는 새로운 주제 선정을 수행하지 않으며 4의 단계로 곧장 진입
- **Fresh 모드** (대시보드 없음): 아래 2.2의 절차로 5개 신규 주제를 선정하고 대시보드를 신규 작성

### 2.2 신규 주제 선정 (Fresh 모드 전용) — 근시일 단일 리스트 (2026-05-19 전면 단순화 / A·B·C 트랙·비율 폐기)

서브 카테고리(스프레드시트/레시피)는 발행하지 않는다. 핵심 원칙 하나: **지금부터 약 2~3주 안에 사람들이 실제로 검색·관심 가질 글만 올린다**(목적은 분류가 아니라 "최대한 많이 읽히는 글"). 트랙(A/B/C)·일 비율·대량 리저버 개념은 모두 폐기됐다.

**선정 방법 (단순)**: `국내여행지.md` **`## 02 | 발행 후보` 표**에서 상태가 `작성대기중`인 행을 **위에서부터 5건** 순서대로 선택한다. 이 표는 이미 발행 타이밍(임박 순)으로 정렬돼 있으므로 위 5건 = 지금 올릴 5건이다. `## 03 | 발행 완료 로그`(과거 기록)와 `## 01`은 선정 대상이 아니다. 트랙 prefix(`[A]/[B]/[C]`)·`보류` 개념은 더 이상 쓰지 않는다.

**잘 읽히는 글 가이드 (할당 아님·참고만)**: 임박한 시즌 이벤트·제철 명소 + 강한 단일 고유명사 + D-7~D-14 선점이 조회수에 가장 유리(근거 `조회수분석.md`). 수도권 주말 나들이는 가까워 검색 수요가 꾸준하므로 자연히 섞인다. 비율을 억지로 맞추지 말고 "지금 가장 읽힐 5개"를 위에서부터 고른다.

**큐 부족 시**: `작성대기중`이 5건 미만이면 본 실행을 **중단하지 말고** 있는 만큼 작성한다. 작성대기중 총량이 **8건 미만**이면 완료 출력에 `[QUEUE LOW: N]`을 덧붙여, `국내여행지.md` §02 맨 아래 *월별 시즌 치트시트* 기준 **그 시점의 다음 2~3주 시즌만** 리필하도록 사용자에게 알린다(멀리 있는 시즌은 적재 금지).

**금지**:
- 본 실행에서 **`국내여행지.md`에 신규 주제를 자동 추가하지 않는다**(리필은 사용자 주도). 단 발행한 주제의 상태를 `작성완료`로 바꾸는 마킹은 수행한다.
- `## 03 발행 완료 로그`·`## 01` 등 과거 기록 행은 신규 선정 대상이 아니다.

---

## 3. 대시보드 처리

### Fresh 모드의 경우
`output/YYMMDD/index.html`을 신규 생성한다. 형식은 직전일(`output/<yesterday>/index.html`)의 구조를 참조하여 동일한 CSS와 마크업으로 작성하되, 모든 항목의 상태는 일단 `⏳ 작성 대기`로 둔다.

| No | 주제 (국내여행지.md §02 발행 후보 위에서부터) | 상태 |
|---|---|---|
| 1 | (발행 후보 1) | ⏳ 작성 대기 |
| 2 | (발행 후보 2) | ⏳ 작성 대기 |
| 3 | (발행 후보 3) | ⏳ 작성 대기 |
| 4 | (발행 후보 4) | ⏳ 작성 대기 |
| 5 | (발행 후보 5) | ⏳ 작성 대기 |

### Resume 모드의 경우
대시보드는 이미 존재하므로 신규 생성하지 않는다. 다만 기존 `✔️ 작성 완료` 상태인 행에 대해 다음을 수행한다.

- 해당 행의 주제명·슬러그를 식별하고, 그 슬러그가 `국내여행지.md`의 어느 항목에 매칭되는지 추적
- 추적이 되면 본 단계 5.2의 트래커 갱신 작업 시 `국내여행지.md` §02 발행 후보의 해당 행 상태를 `작성완료(MM.DD)`로 마킹(행은 §02에 둔 채 표시만; 별도 정리 시 §03 로그로 이동)
- 만약 `국내여행지.md`에서 해당 슬러그가 발견되지 않더라도 강제 추가하지는 않는다(orphan 허용)
- ~~`spreadsheet.md`/`receipt.md` 매칭~~ 동결 (서브 카테고리 발행 중단)

---

## 4. 원고 작성 (placeholder 모드 강제)

대상은 모드별로 다르다.

- **Fresh 모드**: 선정된 5개 원고를 모두 새로 작성한다.
- **Resume 모드**: 대시보드의 `⏳ 작성 대기` 상태 행만 작성한다. `✔️ 작성 완료` 행은 절대 손대지 않는다.

**본 프롬프트는 사용자가 명시적으로 일괄 작성을 요청한 경우에 해당하므로 `Naverblog.md` 10.1.3의 "지양" 규정에 우선한다.**

### 4.1 파일 경로 및 명명
- 원고 파일: `output/YYMMDD/<slug>.html` (직전일 명명 규칙 답습. 예: `travel_imsil_cheese_2026.html`, `spreadsheet_filter_sort_2026.html`, `recipe_xxxx_2026.html`)
- 이미지 폴더: `images/YYMMDD/` (빈 폴더로 생성, 이미지는 사용자가 Antigravity로 별도 생성)

### 4.2 본문 표준 (Platinum v5)
- `Naverblog.md` 04조의 표준 템플릿 v5를 그대로 적용
- 카테고리 컬러: 국내여행 `#00796b`, 스프레드시트 `#1565c0` 또는 가이드 컬러, 요리 레시피 `#e64a19`
- **꼭지(h2) 9개 이상** 유지, 각 꼭지 본문 약 12~16행 (Naverblog.md 04조 2항 분량 캘리브레이션 — 2026-05-17 발행분의 약 80%, 본문 약 7,500~8,000자. 2026-05-18 발행분부터 적용)
- 마크다운 `**` 금지, `<strong>` 강제
- 문단 분할 시 `<br><br>` 사용 (CSS margin 대신)
- **제목 작성 — `Naverblog.md` 03조 3.1 준수 (2026-05-18 발행분부터)**: 제목에 `2026`을 기계적으로 넣지 않는다(5건 중 최대 1~2건, 연도가 검색어 핵심일 때만). `완전 가이드`·`완벽 가이드`·`총정리`·`끝판왕` 등 클리셰 수식어 금지. 제목 전체는 키워드 나열이 아닌 자연스러운 한 문장. (※ 2026-05-19: 가운뎃점·/쉼표 강제 규칙 삭제됨 — 구분자 자유)
- **개별 메뉴 단가 나열 금지 — `Naverblog.md` 2.2 준수 (2026-05-18 발행분부터)**: "떡볶이 ○○원, 순대 ○○원" 식 품목별 가격표/단가 리스트는 넣지 않는다(사후 팩트체크 불가). 공식 입장료·주차료 등 고정 요금만 명시하고, 먹거리는 "1만 원 안팎으로 한 끼" 식 대략 범위로 대체. 네이버·티스토리 미러 공통.

### 4.3 이미지는 무조건 placeholder (`<img>` 태그 절대 사용 금지)

원고당 3개의 이미지 영역을 다음 구조로 삽입한다. 실제 PNG 파일은 사용자가 추후 Antigravity로 생성하므로 본 작업에서는 절대 `<img>` 태그를 쓰지 않는다.

```html
<div class="img-area">
  <div class="img-placeholder">
    <div class="ph-head">
      <span>📷 AI 이미지 생성 영역</span>
      <span class="ph-file">images/YYMMDD/<seq>_<slug>_<idx>.png</span>
    </div>
    <pre class="prompt-text" id="prompt-<seq>-<idx>">[영문 프롬프트, 1:1 정사각, photorealistic, ultra detailed]</pre>
    <button class="copy-btn" onclick="copyPrompt('prompt-<seq>-<idx>')">📋 프롬프트 복사하기</button>
  </div>
  <div class="img-caption">[한글 캡션] / AI 제작 이미지</div>
</div>
```

**중요 규칙**:
- `<seq>`: 원고 순번 (1~5)
- `<idx>`: 이미지 순번 (1~3)
- `<slug>`: 원고 슬러그의 핵심 키워드 (예: `imsil_cheese`, `filter_sort`)

> ### 🔒 이미지 파일 네이밍 — 강제 규칙 (2026-05-19 발행분부터, `Naverblog.md` 10.2.2)
>
> placeholder의 `ph-file` 표기와 추후 실제 생성되는 PNG 파일명은 **반드시** 다음 형식이다:
>
> **`{원고seq}_{keyword}_{이미지seq}.png`** — 즉 `<seq>_<slug>_<idx>.png`
>
> - 정상 예: 1번 원고의 첫 이미지 = `1_seoul_songni_seokchon_1.png`, 3번 원고의 2번째 = `3_jeonju_hanok_dano_2.png`
> - **❌ 금지(2026-05-18까지 실제로 발생한 오류)**: `bonghwa_1.png`, `songni_2.png` 처럼 **원고seq 접두(`1_`~`5_`)가 빠진** 형태. keyword만 쓰고 원고 순번을 생략하면 규칙 위반이다.
> - keyword는 원고 슬러그의 핵심부(여행지·주제명)를 쓰되, 5건 간 충돌하지 않으면 짧게 줄여도 되나 **`{원고seq}_` 접두와 `_{이미지seq}` 접미는 생략 불가**.
> - `prompt-<seq>-<idx>` id, 캡션, 본문 `<img src>`(이미지 주입 단계) 모두 동일 파일명 규칙을 따른다.
> - 적용: **2026-05-19 발행분부터**. 그 이전 날짜(260518 포함) 산출물의 기존 파일명은 **소급 변경 금지**(기존 `<img src>` 참조가 깨짐).
> - 자가 검증: 모든 placeholder의 `ph-file`이 정규식 `^images/\d{6}/[1-5]_.+_[1-3]\.png$`에 맞는지 저장 직전 확인. 안 맞으면 수정 후 저장.
- 영문 프롬프트는 약 80~150단어, 다음 요소를 반드시 포함:
  - 구체적 피사체 묘사 (장소·인물·사물)
  - 시간대·조명 (golden hour, soft window light 등)
  - 카메라 워크 (wide aerial, close-up macro 등)
  - 색감·분위기
  - `Photorealistic, ultra high detail, 1:1 aspect ratio` 끝맺음
- 캡션은 무조건 `... / AI 제작 이미지` 형식이며, "쿼터 소진" 등 운영 메타 정보는 절대 본문에 노출 금지

### 4.4 placeholder 전용 CSS 및 스크립트

각 원고의 `<style>` 블록에 다음을 포함한다(직전일 작성된 `output/260502/travel_imsil_cheese_2026.html` 참조).

```css
.img-area { margin: 30px 0; text-align: center; }
.img-caption { font-size: 0.9em; color: #666; margin-top: 10px; font-style: italic; }
.img-placeholder { background: [컬러-연하게]; border: 2px dashed [컬러]; border-radius: 10px; padding: 28px 22px; text-align: left; color: [컬러-다크]; }
.img-placeholder .ph-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px; font-weight: 700; font-size: 0.95em; color: [컬러-다크]; }
.img-placeholder .ph-file { font-family: Consolas, monospace; background: #fff; border: 1px solid [컬러-연하게]; padding: 4px 10px; border-radius: 4px; font-size: 0.85em; color: [컬러]; }
.img-placeholder .prompt-text { background: #fff; border: 1px solid [컬러-연하게]; border-radius: 6px; padding: 14px; font-family: Consolas, 'Courier New', monospace; font-size: 0.85em; line-height: 1.55; color: #333; white-space: pre-wrap; word-break: break-word; margin: 0 0 12px 0; max-height: 220px; overflow: auto; }
.copy-btn { background: [컬러]; color: #fff; border: none; padding: 8px 18px; border-radius: 5px; cursor: pointer; font-size: 0.88em; font-weight: 600; transition: background 0.2s; }
.copy-btn:hover { background: [컬러-다크]; }
```

`</body>` 직전에 다음 스크립트를 반드시 삽입.

```html
<script>
function copyPrompt(id) {
  const text = document.getElementById(id).innerText;
  navigator.clipboard.writeText(text).then(() => {
    const btn = document.querySelector(`button[onclick="copyPrompt('${id}')"]`);
    const originalText = btn.innerText;
    btn.innerText = "복사 완료!";
    btn.style.background = "#27ae60";
    setTimeout(() => { btn.innerText = originalText; btn.style.background = "[컬러]"; }, 2000);
  });
}
</script>
```

### 4.5 내부 링크 (T-1 낙수전략)
- 각 원고 최하단에 `recommend-area` 박스를 두고, **전날 폴더의 원고 중 무작위 2개**를 선정해 상대경로 링크(`../<yesterday>/...html`)로 연결한다.

### 4.6 팩트체크
- 여행 원고: 축제 일정·입장료·운영시간·개화 시기 등은 반드시 `WebSearch` 도구로 2026년 최신 정보를 검증한 뒤 기재
- 스프레드시트 원고: 함수 문법은 Google 공식 문서 기준
- 레시피 원고: 계량은 "약 한 꼬집", "종이컵 1/2컵" 등 구체적 표현 사용

#### 4.6-A 날짜·음양력·일정 정확성 — 강제 (2026-05-18 신설, `Naverblog.md` 2.2-4·7.2-0)
> 날짜 오류 1건은 네이버+티스토리+인스타 카드 수십 곳으로 전파돼 대량 재작업을 부른다. 날짜는 본문 쓰기 *전에* 확정한다.
- **음력 기반 명절·절기(단오·설·추석·정월대보름·초파일·한식·동지 등)의 양력 날짜는 매년 다르다.** 관습·기억·직전 연도 값으로 추정 절대 금지 → **반드시 `WebSearch`로 2026년 양력 환산을 확인**.
  - ❌ 실제 사고: 2026 단오(음력 5/5)를 `양력 6월 5일`로 단정 → 정답 **2026년 6월 19일(금)**. 같은 실수 재발 금지.
- 연도별로 바뀌는 축제·행사 일정과 그 날짜의 **요일**은 2026년 공식 일정/달력으로만 기재(회차 "제N회" 금지).
- **검증 실패 시 단정 금지**: 양력 날짜·요일 확인 불가 시 구체 날짜를 적지 말고 "음력 5월 5일 단오(2026 양력 날짜는 공식 일정 확인)"처럼 회피. **틀린 날짜를 쓰느니 비운다.**
- 출력 직전 자가검증: 본문의 모든 날짜·요일·기간이 2026년 실제 값으로 `WebSearch` 검증됐는가? 추정 날짜를 사실처럼 단정한 곳이 없는가? → 하나라도 불확실하면 해당 날짜 표현을 안전형으로 교체 후 저장.

---

## 5. 작성 완료 후 데이터 갱신

### 5.1 대시보드 갱신
`output/YYMMDD/index.html`의 5개 행 모두 상태를 `✔️ 작성 완료`로 바꾸고 각 주제명을 해당 원고 파일로의 상대경로 `<a href>` 링크로 감싼다.

### 5.2 트래커 파일 갱신 (조건부 — 본 실행에서 실제로 작성한 원고에 한정)

본 실행에서 새로 작성한 원고가 `국내여행지.md`의 어느 항목에 해당하는지 명확히 식별한 뒤 갱신한다. Resume 모드에서 일부 행만 작성한 경우 나머지 항목은 절대 손대지 않는다.

**`국내여행지.md`** (조건: 이번 실행에서 작성한 원고가 1건 이상일 때):
- `## 02 발행 후보`에서 본 실행이 작성한 주제 행의 상태만 `작성대기중` → `작성완료(MM.DD)`로 변경(트랙 prefix 개념 없음)
- 본 실행에서 작성하지 않은 다른 행은 절대 건드리지 않는다

**큐 잔여 알림** (조건: 작성 완료 후 `## 02 발행 후보`의 `작성대기중` 총량이 8건 미만일 때):
- 완료 출력에 `[QUEUE LOW: N]` 메시지 추가 — 사용자가 `국내여행지.md` §02 *월별 시즌 치트시트* 기준으로 **그 시점 다음 2~3주 시즌만** 10~15건 리필하도록 안내(멀리 있는 시즌 적재 금지)

**~~`sub_topic_tracker.md`~~** — 동결 (서브 카테고리 발행 중단으로 본 파일을 일체 수정하지 않는다)

**~~`spreadsheet.md` / `receipt.md`~~** — 동결 (신규 발행 중단으로 본 파일들을 일체 수정하지 않는다)

---

## 5.5 Phase B — 티스토리 미러 생성 (필수)

Phase A(1~5단계)에서 작성한 원고와 동일한 주제로 **티스토리용 미러 원고 5건**을 생성한다. 본 단계는 `Naverblog.md` 11조(티스토리 동시 발행 규정)에 따라 수행한다.

> ## ⛔ 절대 규칙 — Phase B는 "글 새로 쓰기"다, "CSS 바꾸기"가 아니다 (2026-05-18 신설)
>
> **과거 사고**: 2026-05-17·05-18 자동 발행에서 Phase B가 네이버 HTML을 그대로 복사한 뒤 `<style>`만 인라인으로 바꿔 저장했다. 그 결과 **제목·본문이 네이버와 100% 동일**한 미러가 발행되어 양 플랫폼 중복 콘텐츠 패널티 위험에 노출됐다. 이 사고를 두 번 다시 내지 않기 위한 강제 규칙이다.
>
> 1. **인라인 스타일 변환은 Phase B의 *부수* 작업일 뿐, 본질이 아니다.** Phase B의 본질은 5.5.3(제목)·5.5.4(본문)의 **완전 재작성**이다. 네이버 원고의 `<body>` 텍스트를 한 문장이라도 그대로 옮겨 붙이면 그 파일은 **즉시 폐기·재작성 대상**이다.
> 2. **제목 글자 일치 = 0 허용.** 티스토리 `<title>`/`<h1>` 텍스트가 네이버와 **문자열 그대로 같으면** 그 산출물은 실패다. (단어 일치율 ≤ 60%는 그 다음 기준)
> 3. **본문은 문장 단위로 새로 쓴다.** 태그를 제거한 평문 기준으로 네이버와 문장이 줄줄이 일치하면 실패다. 팩트(시간·가격·주소·날짜·전화번호)는 절대 바꾸지 말되, 문장 구조와 어휘는 90% 이상 교체한다.
> 4. **Phase D(commit) 직전 5.5.9-bis 자동 차단 검증을 반드시 통과**해야 한다. 검증 실패 시 commit·push 금지, 해당 파일 재작성 후 재검증.
>
> 요약: *"네이버 파일을 열어 스타일만 인라인화한 결과물"은 Phase B 산출물로 인정하지 않는다. 반드시 백지에서 다시 쓴 글이어야 한다.*

### 5.5.1 작성 대상 식별
- 본 실행에서 새로 작성한 `output/YYMMDD/<slug>.html` 파일들을 모두 미러 대상으로 한다.
- Resume 모드에서 이미 `✔️ 작성 완료` 상태이던 행은 미러 작성 여부를 다음 규칙으로 결정:
  - `output_tistory/YYMMDD/<같은-slug>.html`이 **존재하지 않으면** 미러 생성 (이전 실행에서 빠진 것).
  - 이미 존재하면 건드리지 않는다.

### 5.5.2 폴더 및 파일명
- 폴더: `output_tistory/YYMMDD/` (없으면 생성).
- 파일명: 네이버 원고와 **동일한 슬러그** 사용 (예: `travel_imsil_cheese_2026.html`).
- 대시보드: `output_tistory/YYMMDD/index.html` (네이버 대시보드와 동일 구조, 5개 슬롯 모두 티스토리 변형 제목으로 표시).

### 5.5.3 제목 변형 (필수)
네이버 제목과 단어 단위 일치율 60% 이하가 되도록 다음 중 최소 2개 기법을 조합한다.
1. 앵글 전환 (정보형 ↔ 후기형 ↔ 가이드형 ↔ 큐레이션형)
2. 키워드 순서 재배치 (빅키워드/미들/롱테일 위치 변경)
3. 숫자·연도 위치 변경
4. 수식어 교체 ('정밀 분석' → '리얼 후기' → '코스 추천' 등 / '완전·완벽 가이드'·'총정리' 등 클리셰 수식어는 네이버·티스토리 어디에도 사용 금지 — 03조 3.1)

### 5.5.4 본문 재작성 (필수)
네이버 본문을 그대로 옮기는 행위는 절대 금지. 다음을 모두 준수:
1. **꼭지 순서·소제목 재구성**: `h2` 9개 이상 유지하되 순서·그루핑·소제목 문구를 모두 다르게 작성.
2. **도입부(`intro-box`) 완전 교체**: 리드문을 1인칭 시점·다른 문장 구조로 재작성.
3. **문장 paraphrase 90% 이상**: 동일 팩트(시간/가격/날짜)도 어휘와 문장 구조를 바꿔 재작성.
4. **표·체크리스트 변형**: 동일 정보라도 행 순서, 헤더명, 보조 설명 위치 다르게 표시.
5. **레이아웃 박스 변형**: Platinum v5 골격은 유지하되 `info-card` 배치, `step-box` ↔ `intro-box` 스왑 등 가능.
6. **분량 유지 (Strict)**: 네이버 원고와 **동일 수준의 분량**을 확보한다. Naverblog.md 04조 2항 캘리브레이션 기준(2026-05-17 발행분의 약 80% = 본문 약 7,500~8,000자, 꼭지 `h2` 9개 이상, 각 꼭지 약 12~16행)을 적용한다. 임의 축소·요약 우회는 금지하되, 네이버 원고보다 현저히 짧으면 폐기·재작성 대상.
7. **문장 간 `<br><br>` 강제 (2026-05-15 시행)**: 본문 단락 내에서 **문장이 끝날 때마다(마침표·물음표·느낌표 뒤) 다음 문장 사이에 `<br><br>`를 삽입**해 가독성을 높인다. 적용 위치는 `<p>` 본문, `intro-box`/`step-box`/`tip-box` 내부 서술, `info-card` 본문 등 **모든 산문 단락**. 표 셀, 리스트 항목, 제목 태그, 코드 박스 등 단일 항목성 텍스트는 예외.
   - 예) `<p style="margin: 1em 0;">첫 번째 문장입니다.<br><br>두 번째 문장이 이어집니다.<br><br>세 번째 문장으로 마무리합니다.</p>`

### 5.5.4-bis HTML 출력 형식 — **인라인 스타일 강제 (티스토리 에디터 호환)**

티스토리 HTML 에디터는 `<style>` 블록의 클래스 셀렉터(`.intro-box`, `.h2`, `.info-table` 등)를 거의 모두 스트립한다. 본 폴더의 출력은 **인라인 `style="..."` 속성만으로 모든 시각 표현이 결정**되어야 한다. (네이버 폴더 `output/YYMMDD/`는 기존 Platinum v5 클래스 기반 그대로 유지)

**필수 규칙**:
1. **`<style>` 블록을 출력에 포함하지 않는다.** `<head>`에는 `<meta charset>`, `<meta viewport>`, `<title>`만 둔다.
2. **모든 표현 요소에 인라인 스타일을 박는다**: `<h1>`, `<h2>`, `<p>`, `<div>`(intro/step/tip/caution box), `<table>`, `<th>`, `<td>`, `<img>`, `<span>` (태그·뱃지), `<a>` (링크 색상) 등.
3. **표의 짝/홀 행 색상 분기**: `tr:nth-child(even)` 의사클래스는 인라인으로 옮기지 못한다. **각 `<tr>` 내부의 `<td>`마다 짝수 행은 `background: #f1faf9;`(여행) 또는 `#fff8f6;`(레시피), 홀수 행은 `background: #fff;`**로 직접 지정.
4. **링크 색상**: `<a style="color: #00796b; text-decoration: none;">` (여행 카테고리) / `#e64a19` (레시피). 티스토리 기본 링크 색을 덮어쓰기 위해 반드시 인라인 명시.
5. **외곽 래퍼**: 전체 본문을 `<div style="font-family: 'Apple SD Gothic Neo', sans-serif; font-size: 16px; line-height: 1.9; color: #222; max-width: 780px; margin: 0 auto; padding: 16px;">`로 감싼다.
6. **단락 간격**: 본문 단락은 `<p style="margin: 1em 0;">`로 감싸 티스토리가 단락 간격을 줄이는 것을 방지.
7. **카테고리별 인라인 컬러 팔레트**:
    - 여행: `#00796b` (border/accent), `#004d40` (제목 색), `#e0f2f1` (h2 배경), `#f1faf9` (intro/표 짝수행), `#b2dfdb` (intro 보더)
    - 레시피: `#e64a19` (border/accent), `#bf360c` (제목 색), `#fbe9e7` (h2 배경), `#fff8f6` (intro/표 짝수행), `#ffccbc` (intro 보더)
    - 박스 색은 카테고리 공통: 팁박스 `background: #fffde7; border: 1px solid #f9a825;`, 주의박스 `background: #fce4ec; border: 1px solid #e57373;`, 코드/공식 박스 `background: #263238; color: #80cbc4;`

**참고 템플릿**: 인라인 스타일 적용 예시는 `output_tistory/260511/travel_seoul_hyunchungwon_memorial_2026.html`을 참고한다. 새로 작성하는 모든 티스토리 미러는 이 파일과 동일한 구조 패턴을 따른다.

**금지**:
- `<style>...</style>` 블록 출력 (어떤 셀렉터도 포함하지 말 것)
- `class="..."` 속성 사용 (시각 표현용 클래스는 사용 금지, ID는 스크립트용에 한해 허용)
- `<script>` 블록 (티스토리 에디터가 스크립트를 차단하는 경우가 많아 placeholder/copy 기능은 미러 작성 시 생략)

### 5.5.5 이미지 — 재활용 (캡션·alt만 재작성)
- 이미지 파일은 **복사하지 않는다**. 네이버와 동일한 `images/YYMMDD/` 폴더를 상대경로로 참조.
  - 티스토리 원고 위치: `output_tistory/YYMMDD/<slug>.html`
  - 이미지 참조 경로: `../../images/YYMMDD/<seq>_<slug>_<idx>.png` (네이버와 동일한 경로 구조)
- placeholder 모드인 경우에도 동일한 영문 프롬프트 재활용 OK.
- 단, **`<img alt="">` 텍스트와 한글 캡션(`img-caption`) 문구는 반드시 재작성**한다 (마지막 `AI 제작 이미지` 라벨은 유지).

### 5.5.6 내부 링크 (티스토리 내부 순환)
- `recommend-area` 박스의 '같이 볼만한 글' 링크는 **`output_tistory/<yesterday_yymmdd>/` 폴더**의 원고를 가리킨다.
  - 상대경로 예: `<a href="../<yesterday>/<slug>.html">`
- 전날 티스토리 폴더가 없으면(초기 도입 시점 등), 당일 다른 4건의 티스토리 미러 중 2개를 무작위로 선정해 같은 폴더 내 링크(`./<slug>.html`)로 처리.

### 5.5.7 대시보드 작성
`output_tistory/YYMMDD/index.html` 생성. 네이버 대시보드와 동일 CSS·마크업을 사용하되, '주제' 컬럼에는 **티스토리 변형 제목**을 표시하고 각 셀의 `<a href>`는 동일 폴더 내 미러 파일을 가리킨다. 상태는 모두 `✔️ 작성 완료`.
- **대시보드 자체의 `<title>`·`<h1>`도 네이버와 문자열이 같으면 안 된다.** 네이버는 `2026-05-18 일일 발행 대시보드` 형식을 쓰므로, 티스토리는 표현을 바꿔(예: `티스토리 발행 노트 — 2026년 5월 18일 글 5건 정리` / `🗂️ 티스토리 발행 노트 · 2026년 5월 18일`) 작성한다. (대시보드 페이지도 중복 콘텐츠 신호가 되므로 11.0조 적용 대상.)

### 5.5.8 트래커 비건드림
Phase B에서는 `국내여행지.md`, `sub_topic_tracker.md`, `spreadsheet.md`, `receipt.md` 등 **어떤 트래커도 수정하지 않는다**. 주제가 동일하므로 Phase A의 마킹을 재사용한다.

### 5.5.9 자가 검증
각 티스토리 파일 저장 직전, 다음을 확인:
- [ ] 제목 단어 일치율 ≤ 60%
- [ ] 인트로 박스 첫 3문장 완전 재작성
- [ ] `h2` 순서·소제목 문구가 네이버와 다름
- [ ] 동일 팩트의 문장 구조 paraphrase 완료
- [ ] '같이 볼만한 글' 박스가 `output_tistory` 내부를 가리킴
- [ ] **`<style>` 블록과 `class` 속성이 없으며 모든 시각 표현이 인라인 `style="..."`로만 구현됨**
- [ ] 표의 모든 `<td>`에 행별 배경색이 명시되어 있음 (nth-child 의존 금지)
- [ ] **본문 분량이 04조 2항 캘리브레이션 기준(본문 약 7,500~8,000자, `h2` 9개 이상, 각 꼭지 약 12~16행)으로 네이버 원고와 동등**
- [ ] **모든 산문 단락 내 문장 사이에 `<br><br>` 삽입 완료** (표·리스트·제목·코드 박스는 예외)

### 5.5.9-bis 자동 차단 검증 (Phase D commit 직전 필수 · 통과 못 하면 발행 중단)

자가 검증(체크리스트)은 사람이 눈으로 보는 항목이라 자동 실행 시 누락될 수 있다. 그래서 **Phase D(git stage/commit) 직전, 5건 전부에 대해 아래 프로그램 검증을 반드시 실행**한다. 하나라도 `FAIL`이면 **commit·push를 하지 말고** 해당 파일을 5.5.3/5.5.4 기준으로 재작성한 뒤 본 검증을 다시 통과시킨다.

판정 기준 (산문 본문만 비교 — 태그·`<style>`·`<script>` 및 '같이 볼만한 글' 박스 이후의 추천링크·태그 영역은 제외):
- **TITLE FAIL**: 네이버와 티스토리의 `<title>` 텍스트가 **문자열 그대로 동일** (0건 허용).
- **BODY FAIL**: 태그 제거 평문에서 길이 20자 이상 문장 중 네이버와 글자 그대로 일치하는 문장의 **비율이 25% 이상**, 또는 **절대 개수가 20개 이상**. (CSS만 바꾼 복사본은 ≈100%·100건 이상으로 명백히 걸리고, 정상 재작성본은 0~수 % 수준이라 안전 마진이 매우 크다. 같은 장소를 다루므로 가격·교통 등 사실 문장 몇 개가 겹치는 것은 정상이며 BODY FAIL이 아니다.)
- ⚠️ **인코딩 주의**: 산출물은 UTF-8(BOM 없음)이고 Windows PowerShell 5.1의 `Get-Content`는 이를 cp949로 잘못 읽는다. 반드시 아래처럼 `[System.IO.File]::ReadAllText(path,[Text.Encoding]::UTF8)`로 읽는다.

```powershell
# Phase D 직전 실행. 작업 디렉터리 = D:\lightsail\naverblog, $d = 오늘 YYMMDD
$enc=[System.Text.Encoding]::UTF8; $fail=$false
Get-ChildItem "output\$d\*.html" | Where-Object Name -ne 'index.html' | ForEach-Object {
  $slug=$_.Name; $t=Join-Path (Resolve-Path "output_tistory\$d") $slug
  if(-not(Test-Path -LiteralPath $t)){ "MISSING $slug"; $script:fail=$true; return }
  $nc=[System.IO.File]::ReadAllText($_.FullName,$enc); $tc=[System.IO.File]::ReadAllText($t,$enc)
  $nT=[regex]::Match($nc,'<title>(.*?)</title>').Groups[1].Value.Trim()
  $tT=[regex]::Match($tc,'<title>(.*?)</title>').Groups[1].Value.Trim()
  $titleFail=($nT -eq $tT)
  # 산문만: script/style 제거 + '같이 볼만한' 이후(추천링크·태그) 절단
  $cut={ param($h) $h=$h -replace '(?s)<script.*?</script>','' -replace '(?s)<style.*?</style>',''; $i=$h.IndexOf('같이 볼만한'); if($i -ge 0){$h=$h.Substring(0,$i)}; ($h -replace '<[^>]+>',' ' -replace '\s+',' ') }
  $nL=(& $cut $nc)-split '(?<=[.!?])\s+'|ForEach-Object{$_.Trim()}|Where-Object{$_.Length -ge 20}
  $tL=(& $cut $tc)-split '(?<=[.!?])\s+'|ForEach-Object{$_.Trim()}|Where-Object{$_.Length -ge 20}
  $nH=[System.Collections.Generic.HashSet[string]]::new(); $nL|ForEach-Object{[void]$nH.Add($_)}
  $dups=$tL|Where-Object{$nH.Contains($_)}|Select-Object -Unique
  $tcount=($tL|Select-Object -Unique).Count
  $ratio=[math]::Round(100*$dups.Count/[math]::Max($tcount,1),1)
  $bodyFail=($ratio -ge 25 -or $dups.Count -ge 20)
  if($titleFail -or $bodyFail){$script:fail=$true}
  "{0,-46} title={1} dup={2}/{3} ({4}%) => {5}" -f $slug,$(if($titleFail){'SAME!'}else{'ok'}),$dups.Count,$tcount,$ratio,$(if($titleFail -or $bodyFail){'FAIL'}else{'PASS'})
  if($titleFail -or $bodyFail){ $dups | Select-Object -First 8 | ForEach-Object { "    · $_" } }
}
if($fail){ Write-Host "`n[BLOCK] Phase B 검증 실패 — FAIL 슬러그를 5.5.3/5.5.4대로 재작성 후 재검증. commit 금지." } else { Write-Host "`n[OK] Phase B 검증 통과 — Phase D 진행 가능." }
```

> **검증 이력**: 본 스크립트는 2026-05-18 사고 복구 시 실측 보정했다. CSS-only 복사본(사고 당시) = 비율 ≈ 100%로 `[BLOCK]`, 문장 단위로 재작성한 정상본 = 0~5%로 `[OK]`. 임계값 25%/20건은 그 사이 넓은 안전 구간에 둔 값이다.

- `[BLOCK]`이 출력되면 **절대 commit하지 않는다.** FAIL 슬러그를 5.5.3/5.5.4대로 다시 쓰고, 위 스크립트가 전부 `PASS` + `[OK]`가 될 때까지 반복한다.
- 자동 실행이 FAIL을 끝내 해소하지 못하면, commit을 생략하고 7장 완료 출력에 `tistory-verify: BLOCKED (<slug 목록>)`을 덧붙여 사람이 개입하도록 남긴다.

### 5.5.9-ter 파이프라인 강제 게이트 (2026-05-19 신설 — honor-system 탈피)

§5.5.9-bis는 본래 *모델이 세션 안에서 스스로 실행*하는 검증이었다. 그러나 실제 commit/push는 `daily-run.ps1`이 수행하고 모델은 git 금지(§6)이므로, 모델이 검증을 건너뛰어도 wrapper는 무조건 push했다(2026-05-19 #4·#5 서식 이탈이 그대로 발행될 뻔한 사고의 근본 원인). 또 §5.5.9-bis는 네이버↔티스토리 **중복만** 보고 **템플릿 구조 이탈은 검사하지 않았다**.

이를 해소하기 위해 `daily-run.ps1` **Step 1.7(git push 직전)**에서 `.scripts/tistory-gate.ps1`을 강제 실행한다. 이 스크립트는 모델과 무관하게 wrapper가 돌리는 **하드 게이트**이며 두 검사를 모두 수행한다:

1. **구조 적합성** — 외곽 래퍼 div, Platinum h1 시그니처, `<style>`/`class` 부재, 이미지-프롬프트 placeholder 박스 누출, 추천 박스 존재, 비표준 `작성일` 줄, 팔레트 이탈색.
2. **중복 차단** — §5.5.9-bis의 TITLE/BODY 산문 일치 로직 이식(동일 임계값 25%/20건).

하나라도 FAIL이면 게이트가 exit 1 → `daily-run.ps1`이 `$gateBlocked`로 **commit/push를 건너뛰고 exit 2**(작업 트리는 보존, 로그에 `[BLOCK]`). 모델은 여전히 §5.5.9 자가검증을 수행하되, **최종 안전망은 이 wrapper 게이트**다. FAIL 슬러그는 §5.5.4-bis 표준(정상본 #1 구조)으로 재작성하면 다음 실행에서 자동 통과한다.

---

## 6. 금지 사항 (절대 준수)

1. **git 명령 금지**: `git add`, `git commit`, `git push` 등 일체 실행하지 않는다. 모든 변경은 작업 디렉터리에만 남긴다.
2. **`<img>` 태그 금지**: 본 작업은 placeholder 모드이므로 어떠한 이미지도 직접 임베드하지 않는다.
3. **사용자 확인 요청 금지**: 본 세션은 무인 자동 실행이므로 "확인해 주세요" 같은 대기 응답을 출력하지 않는다.
4. **이미지 생성 시도 금지**: nano-banana MCP 등 어떤 이미지 생성 도구도 호출하지 않는다.
5. **메모리 저장 금지**: 본 자동 작업의 일시적 상태를 `~/.claude/projects/.../memory/`에 저장하지 않는다.

---

## 7. 완료 시 출력

작업이 모두 끝나면 다음 형식의 한 줄 요약을 출력하고 종료한다.

```
[DAILY OK YYYY-MM-DD] 5 naver + 5 tistory articles created in output/YYMMDD/ and output_tistory/YYMMDD/, trackers updated, 0 git commits
```

오류 발생 시:
```
[DAILY FAIL YYYY-MM-DD] <단계명>: <에러 요약>
```
