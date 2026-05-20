# Naverblog 일일 자동 발행 작업

매일 새벽 4시 KST 작업 스케줄러가 실행. 작업 디렉터리는 이미 `D:\lightsail\naverblog`.

**큰 틀**: 네이버 원고 5건 → 티스토리 미러 5건 → 인스타 카드 5건.

---

## 1. 컨텍스트 로드

다음 두 파일만 Read:

1. `Naverblog.md` — 운영 지침 (Platinum 템플릿·티스토리 규칙·팩트체크)
2. `국내여행지.md` — 주제 DB (§02 발행 후보가 선정 대상)

오늘 날짜를 `Get-Date -Format yyMMdd` 또는 `date +%y%m%d`로 확인해 `YYMMDD` 변수 사용. 전날 폴더 `output/<yesterday>/`에서 내부 링크 후보 2개 추출.

---

## 2. 주제 5건 선정

먼저 `output/YYMMDD/index.html` 존재 여부 확인:

- **Resume 모드** (대시보드 있음): 기존 행 중 `⏳ 작성 대기`인 것만 작성. `✔️ 작성 완료` 행은 절대 손대지 않는다.
- **Fresh 모드** (대시보드 없음): `국내여행지.md §02 발행 후보` 표에서 상태 `작성대기중`인 행을 **위에서부터 5건** 순서대로 선정. 트랙·비율·prefix 없음. `§03 발행 완료 로그`·`§01`은 선정 대상 아님.

**큐 부족** (§02 작성대기중 < 8건): 본 실행은 중단하지 말고 5건을 작성하되, 완료 출력에 `[QUEUE LOW: N]`을 덧붙여 사용자 리필을 알린다. 본 실행이 신규 주제를 `국내여행지.md`에 자동 추가하지 않는다.

---

## 3. 대시보드 (`output/YYMMDD/index.html`)

- **Fresh**: 직전일 `output/<yesterday>/index.html` 구조를 답습해 5개 행을 일단 `⏳ 작성 대기` 상태로 생성.
- **Resume**: 신규 생성 X, 기존 그대로.

작성 완료 후 각 행 상태를 `✔️ 작성 완료`로 바꾸고 제목을 원고 파일 상대경로 `<a>`로 감싼다.

---

## 4. 네이버 원고 5건 (`output/YYMMDD/<slug>.html`)

- **템플릿**: `Naverblog.md` 04조 Platinum v5 그대로.
- **분량**: 본문(태그·공백 제외) 약 **7,500~8,000자**, h2 꼭지 **9개 이상**, 각 꼭지 12~16행.
- **문장**: 존대말(`~합니다`/`~하세요`), 마크다운 `**` 금지(`<strong>` 사용), 문단 사이 `<br><br>` 강제.
- **제목** (`Naverblog.md` 03조 3.1): 클리셰(`완전 가이드`·`완벽 가이드`·`총정리`·`끝판왕`·`A to Z`) 금지. `2026`은 검색어 핵심일 때만(같은 날 5건 중 최대 1~2건). 자연스러운 한 문장.
- **가격 표기** (Naverblog.md 2.2): 품목별 단가 나열 지양, 공식 고정 요금만(입장료·주차료 등). 먹거리는 "1만 원 안팎" 식 대략 범위.
- **이미지**: placeholder 모드 — `<img>` 태그 사용 절대 금지. 원고당 3개 영역을 다음 구조로 삽입:

  ```html
  <div class="img-area">
    <div class="img-placeholder">
      <div class="ph-head">
        <span>📷 AI 이미지 생성 영역</span>
        <span class="ph-file">images/YYMMDD/<seq>_<slug>_<idx>.png</span>
      </div>
      <pre class="prompt-text" id="prompt-<seq>-<idx>">[영문 프롬프트 80~150 단어, photorealistic, ultra high detail, 1:1 aspect ratio]</pre>
      <button class="copy-btn" onclick="copyPrompt('prompt-<seq>-<idx>')">📋 프롬프트 복사하기</button>
    </div>
    <div class="img-caption">[한글 캡션] / AI 제작 이미지</div>
  </div>
  ```
  - 파일명 강제 `{원고seq:1~5}_{keyword}_{이미지seq:1~3}.png` (정규식 `^images/\d{6}/[1-5]_.+_[1-3]\.png$`). 저장 직전 모든 placeholder의 `ph-file`이 이 형식인지 확인.

- **팩트체크**: 일정·요금·운영시간 등은 `WebSearch`로 2026년 값 확인. **음력 명절(단오·추석·설·정월대보름·초파일·한식 등)은 양력 환산을 반드시 WebSearch로 검증** (예: 2026 단오 = 6/19). 확인 못 하면 구체 날짜 단정 금지(시즌 표기로 회피).
- **내부 링크**: 최하단 `recommend-area`에 전날 원고 2건(무작위)을 상대경로 링크.

---

## 5. 티스토리 미러 5건 (`output_tistory/YYMMDD/<slug>.html`)

> ⛔ 티스토리는 **글을 새로 쓰는 일**이다. 네이버 HTML을 CSS만 바꿔 옮기는 것이 아니다. 제목·본문이 네이버와 그대로 같으면 중복 콘텐츠 저품질 위험.

- **폴더·파일명**: 네이버와 동일 slug.
- **제목** (필수): 네이버 제목과 글자 그대로 같으면 FAIL. 앵글 전환·키워드 재배치·수식어 교체로 단어 일치율 ≤ 60%.
- **본문** (필수): 동일 팩트(시간·가격·주소·날짜·전화)는 그대로, 문장 구조와 어휘는 90%+ paraphrase. h2 순서·소제목 문구도 다르게.
- **분량**: 네이버와 동등(본문 약 7,500~8,000자, h2 9+).
- **출력 형식**: **인라인 `style="..."` 전용**. `<style>` 블록·`class=` 속성·`<script>` 절대 금지(티스토리 에디터가 스트립). 외곽 래퍼 div 강제:
  ```html
  <div style="font-family: 'Apple SD Gothic Neo', sans-serif; font-size: 16px; line-height: 1.9; color: #222; max-width: 780px; margin: 0 auto; padding: 16px;">
  ```
- **표 행 배경**: 각 `<td>`에 직접 `background: #f1faf9;`(여행 짝수행) / `#fff`(홀수행). `nth-child` 안 됨.
- **이미지 (핵심·반복 사고 지점)**: 네이버에서 만든 이미지(`images/YYMMDD/<seq>_<slug>_<idx>.png`)를 **표준 `<img>` 1줄 블록 3개로 재사용한다.** 새 이미지 안 만들고, **네이버의 `img-placeholder` 박스(`📷 AI 이미지 생성 영역`·`📋 프롬프트 복사하기` 등)는 절대 carry over하지 않는다.** 표준 블록:
  ```html
  <div style="margin:30px 0;text-align:center;"><img alt="캡션" src="../../images/YYMMDD/<seq>_<slug>_<idx>.png" style="max-width:100%;height:auto;border-radius:8px;"/><div style="font-size:0.9em;color:#666;margin-top:10px;font-style:italic;">캡션 / AI 제작 이미지</div></div>
  ```
  - `<img>`는 원고당 정확히 **3개**(네이버 3개와 1:1). 같은 `src` 중복 금지.
  - `alt`·캡션은 네이버와 다른 문구로 재작성(라벨 `/ AI 제작 이미지`는 유지).

- **내부 링크**: `recommend-area`는 `../<yesterday>/` 폴더(같은 티스토리 채널) 2건. 없으면 같은날 미러 중 2건.
- **해시태그**: 본문 끝에 태그 칩 **10개** (네이버 원본 `.tag` 그대로 또는 동등):
  ```html
  <span style="display:inline-block; background:#f0f0f0; padding:3px 10px; border-radius:5px; margin:3px; font-size:0.85em; color:#666; border:1px solid #ddd;">#키워드</span>
  ```
- **대시보드**: `output_tistory/YYMMDD/index.html` — `<title>`·`<h1>` 글자가 네이버 대시보드와 그대로 같으면 안 된다.

**저장 직전 자가검증** (5건 각각):
- [ ] 외곽 래퍼 1개, Platinum h1 1개, 번호 h2 9+, `<style>·class=` 0
- [ ] `<img>` 정확히 3개·같은 src 중복 0·placeholder 박스 0
- [ ] 추천 박스 1개, 태그 칩 10개
- [ ] 제목 글자 일치 0·본문 문장 paraphrase 90%+

> 게이트(`.scripts/tistory-gate.ps1`)가 push 직전 자동 검수한다. FAIL이면 wrapper가 commit/push를 차단한다. 위 자가검증을 통과시키면 게이트도 자동 통과.

---

## 6. 인스타 카드 5건

`insta-card-builder` 에이전트가 별도 단계(`daily-run.ps1` Step 1.6)에서 호출된다. 본 프롬프트 단계에선 작성하지 않음.

---

## 7. 트래커 갱신

본 실행에서 작성한 주제만 `국내여행지.md §02`에서 상태 `작성대기중` → `작성완료(MM.DD)`로 변경. 다른 행은 절대 손대지 않는다. `sub_topic_tracker.md`·`spreadsheet.md`·`receipt.md`는 동결 — 일체 수정 금지.

---

## 8. 금지

- **git 명령 일체** (`add`/`commit`/`push`) — wrapper(`daily-run.ps1`)가 수행
- 네이버 원고에 `<img>` 실삽입 (placeholder만)
- 인스타 이미지 생성 시도 (별도 단계 담당)
- 사용자 확인 요청 (무인 실행)
- 메모리 저장

---

## 9. 완료 출력

성공:
```
[DAILY OK YYYY-MM-DD] 5 naver + 5 tistory created in output/YYMMDD/, trackers updated, 0 git commits
```

오류:
```
[DAILY FAIL YYYY-MM-DD] <단계>: <에러 요약>
```
