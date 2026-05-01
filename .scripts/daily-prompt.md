# Naverblog 일일 자동 발행 작업 (placeholder 모드)

매일 새벽 4시(KST) Windows 작업 스케줄러가 실행하는 자동 발행 파이프라인이다. 본 프롬프트만으로 컨텍스트가 자기완결되도록 구성되어 있으며, 시작 시 이미 작업 디렉터리는 `D:\lightsail\naverblog`이다.

---

## 1. 사전 컨텍스트 로드 (필수, 순서 준수)

다음 파일을 모두 Read 도구로 읽어 운영 규칙을 정확히 이해한다.

1. `Naverblog.md` — 운영 지침 v5 (Platinum 표준 템플릿, 6:3:1 전략 등)
2. `국내여행지.md` — 국내여행 주제 데이터베이스
3. `sub_topic_tracker.md` — 서브 주제 순환 트래커 (`NEXT_TOPIC`)
4. `spreadsheet.md` — 스프레드시트 주제 로드맵
5. `receipt.md` — 레시피 주제 로드맵

또한 오늘 날짜를 `date +%y%m%d` (Bash) 또는 `Get-Date -Format yyMMdd` (PowerShell)로 확인하여 `YYMMDD` 변수를 확보한다. 이 변수가 본 작업의 기준 폴더명이 된다.

전날 폴더(`output/<yesterday_yymmdd>/`)도 확인해 내부 링크 후보 2개를 추출한다.

---

## 2. 모드 판별 및 주제 선정 (Idempotent)

### 2.1 모드 판별 — Resume vs Fresh
먼저 `output/YYMMDD/index.html`이 **이미 존재하는지** Glob으로 확인한다.

- **Resume 모드** (대시보드 이미 존재): 해당 `index.html`을 Read로 읽어 5개 행을 파싱한다.
  - `✔️ 작성 완료` 상태인 행은 **재작성 절대 금지**(이미 사용자가 수동으로 만들었거나 이전 실행에서 완성됨)
  - `⏳ 작성 대기` 상태인 행만 본 실행에서 작성한다
  - 주제 텍스트와 카테고리는 기존 대시보드의 값을 그대로 사용
  - 이 모드에서는 새로운 주제 선정을 수행하지 않으며 4의 단계로 곧장 진입
- **Fresh 모드** (대시보드 없음): 아래 2.2의 절차로 5개 신규 주제를 선정하고 대시보드를 신규 작성

### 2.2 신규 주제 선정 (Fresh 모드 전용)
`Naverblog.md` 02조의 Strict 4+1 Rule을 따른다.

- **여행 4건**: `국내여행지.md`의 `02 | 향후 작성 예정 테마` 섹션에서 상태값이 `작성대기중`인 주제 중 가장 위에서부터 4개를 선택한다.
- **서브 1건**: `sub_topic_tracker.md`의 `NEXT_TOPIC` 값(`SPREADSHEET` 또는 `RECIPE`)을 확인하여:
  - `SPREADSHEET`: `spreadsheet.md`에서 상태 `⏳ 대기` 중 최상단 항목 선택
  - `RECIPE`: `receipt.md`에서 상태 `⏳ 대기` 중 최상단 항목 선택

만약 `국내여행지.md`의 `작성대기중` 항목이 5개 미만으로 남으면, 작성 시작 전에 운영 지침 10.5조에 따라 **시즈널 주제 20개를 새로 발굴해 리스트 하단에 추가**한다(중복 검수 필수).

---

## 3. 대시보드 처리

### Fresh 모드의 경우
`output/YYMMDD/index.html`을 신규 생성한다. 형식은 직전일(`output/<yesterday>/index.html`)의 구조를 참조하여 동일한 CSS와 마크업으로 작성하되, 모든 항목의 상태는 일단 `⏳ 작성 대기`로 둔다.

| No | 카테고리 | 주제 | 상태 |
|---|---|---|---|
| 1~4 | 국내여행/축제 | (선정된 여행 주제) | ⏳ 작성 대기 |
| 5 | 스프레드시트 또는 요리 레시피 | (선정된 서브 주제) | ⏳ 작성 대기 |

### Resume 모드의 경우
대시보드는 이미 존재하므로 신규 생성하지 않는다. 다만 기존 `✔️ 작성 완료` 상태인 행에 대해 다음을 수행한다.

- 해당 행의 주제명·슬러그를 식별하고, 그 슬러그가 `국내여행지.md` 또는 `spreadsheet.md`/`receipt.md`의 어느 항목에 매칭되는지 추적
- 추적이 되면 본 단계 5.2의 트래커 갱신 작업 시 해당 항목을 `작성완료(MM.DD)` 또는 `✅ 완료`로 함께 마킹
- 만약 트래커 파일에서 해당 슬러그가 발견되지 않더라도 강제 추가하지는 않는다(orphan 허용)

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
- **꼭지(h2) 9개 이상**, 각 꼭지 본문 15~20행 이상의 압도적 서술
- 마크다운 `**` 금지, `<strong>` 강제
- 문단 분할 시 `<br><br>` 사용 (CSS margin 대신)

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

---

## 5. 작성 완료 후 데이터 갱신

### 5.1 대시보드 갱신
`output/YYMMDD/index.html`의 5개 행 모두 상태를 `✔️ 작성 완료`로 바꾸고 각 주제명을 해당 원고 파일로의 상대경로 `<a href>` 링크로 감싼다.

### 5.2 트래커 파일 갱신 (조건부 — 본 실행에서 실제로 작성한 원고에 한정)

본 실행에서 새로 작성한 원고가 어떤 카테고리·항목에 해당하는지 명확히 식별한 뒤, **해당하는 트래커만** 갱신한다. Resume 모드에서 일부 행만 작성한 경우 나머지 트래커는 절대 손대지 않는다.

**`국내여행지.md`** (조건: 이번 실행에서 작성한 여행 원고가 1건 이상일 때):
- 본 실행에서 작성한 여행 주제의 상태값만 `작성대기중` → `작성완료(MM.DD)`로 변경
- 본 실행에서 작성하지 않은 다른 행은 절대 건드리지 않는다

**`sub_topic_tracker.md`** (조건: 이번 실행에서 서브 카테고리 원고를 작성했을 때만):
- 작성하지 않았다면 본 파일을 일체 수정하지 않는다(이미 이전 실행에서 갱신된 내역이 보존되도록)
- 작성했다면:
  - 히스토리 표 마지막에 `| YYYY-MM-DD | <SPREADSHEET 또는 RECIPE> | <주제 요약> |` 행 추가 (단, 동일 일자·동일 카테고리 행이 이미 존재하면 추가하지 않음)
  - `NEXT_TOPIC` 값을 반대 카테고리로 토글 (`SPREADSHEET` ↔ `RECIPE`)
  - `LAST_UPDATED`를 오늘 날짜로 갱신

**`spreadsheet.md` 또는 `receipt.md`** (조건: 이번 실행에서 해당 카테고리 원고를 작성했을 때만):
- 작성한 항목 상태만 `⏳ 대기` → `✅ 완료`로 변경
- 작성일 칼럼에 오늘 날짜(`YYYY-MM-DD`) 기입
- 다른 행은 절대 건드리지 않는다

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
[DAILY OK YYYY-MM-DD] 5 articles created in output/YYMMDD/, trackers updated, 0 git commits
```

오류 발생 시:
```
[DAILY FAIL YYYY-MM-DD] <단계명>: <에러 요약>
```
