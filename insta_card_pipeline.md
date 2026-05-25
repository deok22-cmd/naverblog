# 인스타 카드뉴스 파이프라인 (원소스 멀티유즈 3번째 채널) v1.0

> 작성일: 2026-05-16
> 출력 폴더: `./output_insta/`
> 소스: `./output/<YYMMDD>/<slug>.html` (Naverblog.md v5 완성 원고)
> 네이버·티스토리에 이은 **3번째 발행 채널**. 기존 시스템과 완전 분리 운영.

---

## 0 | 개요

```
output/<YYMMDD>/<slug>.html  (기존 v5 원고 — 변경 0)
        │  insta-card-builder 서브에이전트
        ▼
output_insta/<YYMMDD>/<slug>/
   ├─ prompts.md      ← Gemini 입력용 배경 프롬프트 10개
   ├─ card_01~10.svg  ← Figma import용 템플릿 SVG (배경 슬롯 비어있음)
   └─ caption.txt     ← 인스타 본문 + 해시태그 15개
        │
        ├─ [Phase A 수동]  Gemini로 배경 생성 → Figma에 드래그 → Export
        └─ [Phase B 자동]  렌더 스크립트가 API 생성 → SVG에 주입 → 완성본
```

---

## 1 | 요청 방법 (치트시트)

| 시점 | 입력 명령어 | 동작 |
|---|---|---|
| 원고 발행 후 | `오늘 발행한 <슬러그> 원고 인스타 카드뉴스 만들어줘` | insta-card-builder 자동 위임 |
| 명시 호출 | `@agent-insta-card-builder output/260520/travel_xxx.html` | 해당 원고 1건 처리 |
| 프로토타입 이어서 | `output_insta/260516/euljiro SVG 검수 끝, card_01~10 전체 생성해줘` | 을지로 10장 완성 |
| Phase B 가동 | `insta 렌더 스크립트로 260520 xxx 배경 자동 생성·주입해줘` | API → 완성 SVG (키 필요) |

서브에이전트가 description 매칭으로 자동 호출되지 않으면 `@agent-insta-card-builder` 또는 `insta-card-builder 에이전트로` 명시.

---

## 2 | Phase A — 수동 운영 (현재 기본, API 불필요)

1. 원고 발행 완료 후 위 명령으로 서브에이전트 호출 → `output_insta/<YYMMDD>/<slug>/` 3종 산출.
2. `prompts.md`의 코드블록 10개를 차례로 Gemini에 붙여넣어 배경 PNG 10장 생성.
   - 카드1 먼저 생성 → 그 컷을 스타일 레퍼런스로 첨부해 2~10 생성(세트감).
3. Figma 템플릿(1회 셋업, `output_insta/260516/euljiro/README.md` 참조)에 SVG import → 각 프레임 `BG__REPLACE_WITH_IMAGE` 사각형 Fill을 Image로 → PNG 드래그(Crop).
4. 1080×1350 PNG ×10 일괄 Export → `caption.txt`와 함께 인스타 캐러셀 업로드.
5. 발행 타이밍: 평일 19~21시 (한국 도달 피크). 블로그 발행과 별도 예약.

---

## 3 | Phase B — 유료 Google API 연결 시 완전 자동

### 3.1 가능 범위
원고 → 프롬프트/SVG/캡션(서브에이전트) → **이미지 생성·주입(스크립트)** → `*_done.svg` 10장. **Figma 없이 완성 SVG 자동 산출.** (선택) PNG 래스터화까지.

### 3.2 1회 셋업  ✅ 2026-05-17 검증 완료
1. Google AI Studio / Cloud에서 **결제(billing) 활성화 후** API 키 발급. — **필수 확인됨**: 무료 티어는 이미지 모델 쿼터 `limit:0`이라 결제 미활성 키는 100% 실패(`RESOURCE_EXHAUSTED`). 결제 활성 후 동일 키 즉시 동작.
2. 키를 환경변수로만 보관 (git 커밋 금지). 실행 시 인라인 전달:
   ```
   GEMINI_API_KEY=<키> node scripts/insta_render.mjs output_insta/<YYMMDD>/<slug>
   ```
3. **SDK·`npm i` 불요.** 구현된 `scripts/insta_render.mjs`는 Node 내장 `fetch`로 REST 호출(모델 `gemini-2.5-flash-image`, `generateContent` + `responseModalities:["IMAGE"]`). 원안의 Imagen SDK(`@google/genai`)는 결제 외 추가 제약이 있어 채택하지 않음.
4. 스크립트는 이미 저장돼 있음(아래 3.3은 설계 참고용 원안 — 실제 동작본은 리포의 `scripts/insta_render.mjs`).
   - 산출: 각 `card_NN_*_done.svg`(base64 `<image>` 자체완결) + `img/NN.png`(원본, Figma 수동 경로 겸용). 원본 `card_NN_*.svg`는 무변형.
   - `node scripts/insta_render.mjs <dir> 3,7` 처럼 2번째 인자로 특정 카드만 재생성 가능.
   - prompts.md가 CRLF여도 처리(스크립트가 개행 정규화).

### 3.3 렌더 스크립트 (`scripts/insta_render.mjs`)
```js
// 사용: node scripts/insta_render.mjs output_insta/260520/travel_xxx
import { GoogleGenAI } from "@google/genai";
import { readFileSync, writeFileSync, readdirSync } from "node:fs";
import path from "node:path";

const dir = process.argv[2];
if (!dir) throw new Error("대상 폴더 경로를 인자로 주세요");
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

// 1) prompts.md의 코드블록 10개 추출 (카드 순서대로)
const md = readFileSync(path.join(dir, "prompts.md"), "utf8");
const prompts = [...md.matchAll(/```[a-z]*\n([\s\S]*?)\n```/g)].map(m => m[1].trim());

// 2) card_*.svg 정렬
const svgs = readdirSync(dir).filter(f => /^card_\d{2}.*\.svg$/.test(f)).sort();
if (prompts.length < svgs.length) throw new Error("프롬프트 수 < SVG 수");

for (let i = 0; i < svgs.length; i++) {
  // 3) 이미지 생성 (Imagen은 4:5 미지원 → 3:4 받아 SVG가 slice-crop)
  const res = await ai.models.generateImages({
    model: "imagen-4.0-generate-001",
    prompt: prompts[i],
    config: { numberOfImages: 1, aspectRatio: "3:4" },
  });
  const b64 = res.generatedImages[0].image.imageBytes;

  // 4) 배경 슬롯을 base64 이미지로 치환 → 자체완결 완성 SVG
  const svgPath = path.join(dir, svgs[i]);
  let svg = readFileSync(svgPath, "utf8");
  svg = svg.replace(
    /<rect id="BG__REPLACE_WITH_IMAGE"[^>]*\/>/,
    `<image id="BG" x="0" y="0" width="1080" height="1350" preserveAspectRatio="xMidYMid slice" href="data:image/png;base64,${b64}"/>`
  );
  const out = svgPath.replace(/\.svg$/, "_done.svg");
  writeFileSync(out, svg);
  console.log("완성:", path.basename(out));
}
```

### 3.4 PNG 래스터화  ✅ 2026-05-17 검증 완료
`_done.svg` → 업로드용 PNG(정확히 1080×1350):
```
node scripts/insta_rasterize.mjs output_insta/<YYMMDD>/<slug> [3,7]
```
- 엔진: **시스템 설치 Microsoft Edge(Chromium)를 `puppeteer-core`로 헤드리스 구동**. 브라우저 다운로드 불요(Win10 내장 Edge 사용). `npm i puppeteer-core` 1회만.
- 한글: **Pretendard가 OS에 설치돼 있어**(`%LOCALAPPDATA%/Microsoft/Windows/Fonts/PretendardVariable.ttf`) 디자인 의도 폰트 그대로, 가변폰트 weight(800/600)까지 정확. 미설치 시 Malgun Gothic 폴백.
- 산출: `<dir>/png/card_NN_*.png` (1080×1350, deviceScaleFactor 1).
- `sharp`/`resvg-js`는 가변폰트 weight 처리 불안정으로 미채택. Edge 경로 변경 시 `INSTA_BROWSER` 환경변수로 지정 가능.

### 3.5 품질 게이트 (권장)
완전 무인 발행은 표지 리스크가 있으므로: 스크립트 실행 → `*_done.svg` 10장을 사람이 1초씩 훑고 OK → 업로드. 불량 카드만 해당 프롬프트 재실행(인덱스 지정).

### 3.6 비용 인지
이미지 1장당 수 센트(모델별 상이). 원고 1건=10장, 일 N건이면 일일 비용 ≈ 10·N·단가. AI Studio에서 일일 쿼터·예산 알림 설정 권장.

### 3.7 비용 절감 정책 — 첫 번째 원고만 자동 렌더 (2026-05-22, 못박음)
> 배경: 인스타 채널이 아직 미수익화라 원고 1건당 ~3,000–4,000원의 이미지 자동생성 비용을 매일 5건 전부 지불하는 것은 부담. **별도 지시가 있을 때까지** 다음 정책을 적용한다.

- **첫 번째 원고(원고 seq 1) 1건만** 기존 풀 프로세스 — Phase B 자동 이미지 생성 → `_done.svg` 주입 → PNG 래스터까지.
- **2~5번 원고**는 `insta-card-builder` 산출물(`card_NN_*.svg` + `prompts.md` + `caption.txt`)까지만 두고, **운영자가 수동으로 이미지를 제작·삽입**한다(과금 0).
- '첫 번째 원고' 판별 = `output/<YMD>/`의 네이버 HTML 중 **`CreationTime`이 가장 이른 것**(`index.html` 제외) = 원고 seq 1. `daily-run.ps1` Step 1.6 Phase C-2가 그 슬러그의 insta 폴더에만 `insta_render.mjs`+`insta_rasterize.mjs`를 실행하고, 나머지 슬러그는 `SKIP` 로그만 남긴다.
- Phase C-1(서브에이전트의 SVG/프롬프트/캡션 생성)은 **변함없이 5건 전부** 수행한다 — 줄어드는 것은 Phase C-2(유료 렌더)뿐이다.
- 정책 해제 시: `daily-run.ps1` Phase C-2의 `if ($slugName -ne $firstSlug) { ... return }` 가드를 제거하면 전 슬러그 자동 렌더로 복귀.

### 3.8 우하단 브랜드 워터마크 (2026-05-22)
- 전 카드 SVG는 우하단 코너에 `<g id="brand-watermark">` 배지(불투명 코너 탭 + 흰 `travelkorea_365`)를 가진다. `_layouts/` 전 템플릿 + 커버 템플릿에 내장 — 에이전트는 차용만 한다.
- 목적: 수동(운영자가 Gemini 앱에서 받은 이미지)·자동 어느 경로든 배경 우하단에 찍히는 Gemini 로고를 불투명하게 가리고, 동시에 채널을 각인. 좌표·구조·표준은 `_layouts/README.md` §0 참조.

---

## 4 | 폴더·명명 규칙
- `output_insta/<YYMMDD>/<slug>/` — 원고 슬러그와 1:1
- `card_NN_<역할>.svg` (NN=01~10), Phase B 완성본은 `card_NN_<역할>_done.svg`
- 배경 PNG 수동 보관 시 `output_insta/<YYMMDD>/<slug>/img/NN.png`

---

## 5 | 트러블슈팅
- **서브에이전트 미호출**: `.claude/agents/insta-card-builder.md` 존재 확인 → 세션 재시작 → `@agent-insta-card-builder` 명시.
- **SVG 한글 깨짐(Figma)**: Pretendard 폰트 설치. 텍스트는 살아있어 폰트만 잡으면 복구.
- **이미지에 글자가 박혀 나옴**: 프롬프트 끝 `no text...` 유지 확인 후 재생성.
- **카드 색이 원고와 불일치**: 서브에이전트가 카테고리 컬러표(에이전트 3절) 적용했는지 확인, 슬러그/제목으로 카테고리 재판별 요청.
- **`aspectRatio` 에러**: Imagen은 4:5 미지원. `3:4` 또는 `9:16` 사용(SVG `slice`가 1080×1350로 크롭).

---

## 6 | 도입 순서 (현재 위치)
- [x] 프로토타입 4종 SVG + prompts + caption (`output_insta/260516/euljiro/`)
- [x] `insta-card-builder` 서브에이전트
- [x] 본 파이프라인 문서
- [x] 을지로 `card_01~10` 전 10장 완성 (2026-05-17, 빠진 6장 02·04·06·07·08·09 아키타입 그대로 생성)
- [x] 10장 디자인 검수 → 표준 확정 (2026-05-17 사용자 OK)
- [x] **Phase B end-to-end 검증 완료 (2026-05-17)**: 결제 활성 키 + `scripts/insta_render.mjs`로 을지로 10장 `_done.svg` + `img/01~10.png` 자동 산출, 품질 게이트 통과
- [x] PNG 래스터화 검증 완료 (2026-05-17): `scripts/insta_rasterize.mjs`, Edge+puppeteer-core, 을지로 10장 1080×1350 PNG 산출 — **Figma 수동 단계 완전 제거**
- [x] **레이아웃 라이브러리 v2 (2026-05-17)**: 단일 표준이 `output_insta/_layouts/`로 이전(README = 카탈로그+회전 규칙). 콘텐츠 6종(A~F)+정보 4종(P1~P4)+고정 북엔드, 슬롯별 회전+콘텐츠형태 하드제약+slug 시드. `insta_render.mjs`에 배경 재사용 모드(`INSTA_REUSE=1`/`--reuse`) 추가 → 레이아웃 교체 시 무과금. 260517 5세트 v2 전환 완료(무과금). `260516/euljiro`는 폐기 프로토타입.
- [x] **자동발행 파이프라인 통합 완료 (2026-05-17, 2026-05-18 04:00 첫 자동실행)**: `\NaverblogDaily`(매일 04:00) → `daily-run.ps1` Step 1.6 신설. Phase C-1 = 별도 `claude -p`(`insta-prompt.md`, 예산 분리)로 insta-card-builder ×5(카드/프롬프트/캡션). Phase C-2 = PowerShell이 `insta_render.mjs`+`insta_rasterize.mjs` 슬러그별 실행(순수 node, 멱등: png 10장이면 스킵). 키는 `.scripts/secret.env.ps1`(gitignore) dot-source. 콘텐츠 실패 시 인스타 스킵·실패 비치명적. **인스타 산출물 git 정책 (2026-05-19)**: `.gitignore`는 `img/`·`*_done.svg`·**`png/` 모두 기본 제외**(과거 누적 png가 `git add -A`로 휩쓸리는 사고 방지). 단 png는 인스타 즉시 업로드용 최종본이라 원격 필요 → `daily-run.ps1` Step2가 ① 원본(prompts/caption/card SVG)은 일반 `git add`, ② **당일 폴더 png만 `git add -f`로 강제 포함**해 커밋·푸시. 과거 날짜 png는 계속 제외돼 status 오염 없음. **+ png retention(2026-05-19)**: Step2가 매 실행 시 추적 png 중 **날짜 폴더가 오늘−3일 미만인 것을 `git rm`**(인덱스+워킹트리) → 최신 트리에 항상 최근 ~3일치 png만 유지(원격 무한 누적 정지, 인스타 업로드엔 최근분만 필요하므로 충분). 옛 png는 git 히스토리 blob엔 남지만 신규 clone·working tree는 안 커짐.

---

## 7 | Instagram 시즌 보너스 적격성 규칙 (필수 — 못박음, 2026-05-17)

> 근거: Meta "Instagram 시기별 보너스 프로그램 규정"(초대제·테스트). **사진·슬라이드 시즌 보너스 — 한국 기준: 3개월 연속 매월 최소 조회수 100만**, 만 19세+·한국 거주/납세·프로페셔널 계정·수익화 정책 준수. 보너스 제외: **브랜디드/홍보/콜라보 콘텐츠**, 정책 미준수 콘텐츠. 사진·슬라이드 보너스는 **음악 포함 게시물만** 집계.

### 7.1 원천 분리 (Hard Rule)
- **본 자동 파이프라인은 오직 "오리지널 정보형 카드뉴스"만 생성한다.** 협찬·광고·제휴(쿠팡 등) 게시물은 **이 파이프라인으로 만들지 않으며**, 파이프라인 밖에서 별도 수동 제작·운영한다. (원천에서 섞지 않음 → 자동 산출물은 항상 보너스 적격 상태 유지)

### 7.2 보너스 적격 불변식 (자동 산출물 = 적격, 이 상태를 깨지 말 것)
- 전체 공개 / 오리지널 / **비(非)브랜디드 / 비콜라보**.
- 보너스 대상 게시물에 다음 **금지**: ① 인스타 "유료 파트너십(브랜디드 콘텐츠)" 라벨 ② Collab(공동 게시) ③ 캡션·카드 내 제3자 브랜드 홍보·제휴 직접 판매/링크. (※ **자기 블로그 정보 가이드 링크는 허용** — 제휴 판매 문구만 금지)
- **댓글 리드마그넷 불변식 (2026-05-18)**: 캡션의 "댓글에 [키워드] 남기면 링크 전달" 문구가 약속하는 전달물은 **그 원고가 발행된 자기 블로그 글 링크(원고 실재 정보)뿐**이다. 제3자 예약 대행·판매 링크, 또는 원고에 없는 가상의 무료 자료(PDF·지도파일·쿠폰 등) 약속은 **금지**(전달 불가 약속 = 신뢰·팩트 위반이며 보너스 적격도 해침). 키워드는 글마다 주제 맞춤으로 달라야 한다. 상세 작성 규칙은 `.claude/agents/insta-card-builder.md` §6.

### 7.3 협찬·광고 게시물 운영 (분리 관리)
- 자동 파이프라인 밖에서 **수동 제작**한다.
- 인스타 **"유료 파트너십" 라벨을 정확히 표기**(법적 고지 의무).
- **보너스 수익 기대 대상에서 제외**하고, 적격 게시물과 **명확히 분리**해 관리(가능하면 발행 슬롯/표기 구분).
- 자동 캡션(`caption.txt`)에는 협찬/제휴 판매 문구를 절대 넣지 않는다 → `.claude/agents/insta-card-builder.md` 캡션 규칙에 반영.

### 7.4 게시(업로드) 시 수동 필수 체크 — 운영자 책임 (파이프라인이 못 함)
- **음악 추가**: 사진·슬라이드 보너스는 음악 포함분만 집계 → 업로드 시 인앱에서 직접 선택(운영자 수행).
- **전체 공개**로 게시.
- **정기 발행 유지**: 최신 150개/2주 보너스 기간, 게시 후 최대 28일 수익 윈도우 → 자동 일발행과 정합.
- 집계 조회 = 로그인 사용자·일정 화질·피드/탐색(프로필 조회 미집계) → 저장·공유 최적화가 보너스에도 직결.

### 7.5 전략 위치
블로그 광고/제휴 = 즉시·확실한 베이스라인(유지). 인스타 슬라이드 보너스 = **초대제 업사이드**(월 100만×3개월 충족 시 자격). 사업을 보너스에만 걸지 않되, 자동 산출물은 항상 7.2를 만족시켜 초대 시 즉시 수익화 가능 상태를 유지한다.
