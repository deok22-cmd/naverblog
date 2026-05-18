# 인스타 카드 채널 자동 생성 (Phase C-1 — 카드 SVG/프롬프트/캡션만)

매일 새벽 자동 실행. 시작 시 작업 디렉터리는 `D:\lightsail\naverblog`. 본 단계는 **오늘 작성된 네이버 원고 5건**을 인스타 카드뉴스 세트로 변환하는 작업이며, **SVG·prompts.md·caption.txt 생성까지만** 한다. 이미지 생성·node 실행·git·대시보드는 본 단계에서 절대 하지 않는다(래퍼 PowerShell이 별도 수행).

---

## 1. 컨텍스트 로드 (필수)

1. `output_insta/_layouts/README.md` — 레이아웃 라이브러리 v2(절대 표준): 카탈로그·슬롯별 허용 풀·결정 규칙·slug 회전 시드.
2. 오늘 날짜 `YYMMDD` 를 `Get-Date -Format yyMMdd`(PowerShell) 또는 `date +%y%m%d`(Bash)로 확인.

## 2. 대상 식별

- `output/YYMMDD/` 폴더에서 `*.html` 중 `index.html`을 **제외한 모든 원고**가 대상이다(보통 5건, `travel_*.html` 등).
- 각 원고의 슬러그 `<slug>` = 파일명에서 `.html`을 뺀 전체 문자열 (예: `travel_busan_songdo_beach_2026`).
- 출력 폴더 = `output_insta/YYMMDD/<slug>/` (원고 슬러그와 1:1, 폴더명 = 전체 슬러그).

## 3. 멱등 처리 (Resume-safe)

- 각 `<slug>` 에 대해 `output_insta/YYMMDD/<slug>/` 에 **완성 세트**(`caption.txt` + `prompts.md` + `card_01_*.svg`부터 마지막 CTA까지 연속 `card_*.svg` ≥6장, prompts.md 코드블록 수 = svg 수)가 이미 있으면 그 슬러그는 **건너뛴다**(이전 실행/재실행 중복 방지).
- 카드 수는 가변(7~10)이므로 "정확히 10개"를 기준으로 삼지 않는다. 세트가 없거나 불완전(파일 누락·블록 수 불일치, 또는 카드 7장 미만)하면 생성 대상.

## 4. 생성 (insta-card-builder 서브에이전트)

생성 대상 슬러그 각각에 대해 **`insta-card-builder` 서브에이전트**를 호출한다. 독립 작업이므로 **한 번에 병렬 호출**한다. 각 호출에 다음을 전달:

- 원고(사실 진실원천) 절대경로: `D:\lightsail\naverblog\output\YYMMDD\<slug>.html`
- 출력 폴더(정확히): `D:\lightsail\naverblog\output_insta\YYMMDD\<slug>\`
- 표준: `output_insta/_layouts/` 라이브러리 + `README.md` **§2–3 가변 길이 규칙**을 그대로 적용. slug 문자코드 합 시드로 **카드 총수(7~10, 하한 7 엄수)·중간 역할 선택·순서·그룹타입**을 결정(콘텐츠 형태 최우선 = info/course/tips/caution 소스 없으면 그 카드 미생성하되 원고 h2 point로 보충해 최소 7장, 인접 비동일, 여러 point는 서로 다른 타입, 장수·순서가 글마다 다르게). `card_01`=커버 고정, **마지막 카드**=CTA 고정, 파일번호 연속(빈 번호 없음). 같은 날 5슬러그의 (장수·역할순서)가 최소 3종 이상 달라야 함.
- 카테고리 팔레트: 원고 카테고리로 판별(국내여행 `#00796b/#004d40/#e0f2f1/#80cbc4/#b2dfdb/#cfd8d6`).
- 산출 3종만: `card_01_*.svg`~`card_NN_*.svg`(연속 7~10장, BG 슬롯+주석 보존, viewBox 1080x1350, 한글 살아있는 `<text>`), `prompts.md`(README §5 규칙, 코드블록 수 = svg 수), `caption.txt`(해시태그 15개).
- 수치는 원고 값만, 없으면 칩/행/타일 제외(창작 금지). 배경 SVG/프롬프트에 글자 렌더 요청 금지.

## 5. 금지 사항 (절대 준수)

1. **node/스크립트 실행 금지**: `insta_render.mjs`·`insta_rasterize.mjs` 등 어떤 node 명령도 실행하지 않는다(래퍼가 함).
2. **이미지 생성 금지**: nano-banana·Gemini 등 어떤 이미지 생성 도구도 호출하지 않는다. 배경은 슬롯(`BG__REPLACE_WITH_IMAGE`)으로 비워 둔다.
3. **git 금지**: add/commit/push 일체 금지.
4. **사용자 확인 요청 금지**: 무인 실행. "확인해 주세요" 류 출력 금지.
5. **메모리 저장 금지**.
6. 트래커·원고·`output/`·`output_tistory/`·대시보드 등 다른 산출물 수정 금지(읽기만).
7. **보너스 적격 박탈 금지** (`insta_card_pipeline.md` §7): 캡션·카드에 협찬/유료파트너십/제3자 브랜드 홍보, 제휴(쿠팡 등) 직접 판매·링크 문구 삽입 금지. 허용 외부 유도는 자기 블로그 정보 가이드 링크 안내뿐. 자동 산출물은 항상 오리지널 정보형(보너스 적격) 상태로 생성한다.

## 6. 완료 출력

작업 종료 시 한 줄 요약:
```
[INSTA OK YYYY-MM-DD] generated=<N> skipped=<M> sets in output_insta/YYMMDD/ (cards+prompts+caption only)
```
오류 시:
```
[INSTA FAIL YYYY-MM-DD] <slug or 단계>: <에러 요약>
```
