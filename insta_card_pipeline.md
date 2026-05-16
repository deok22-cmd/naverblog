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

### 3.2 1회 셋업
1. Google AI Studio / Cloud에서 결제 활성화 후 API 키 발급.
2. 키를 환경변수로만 보관 (git 커밋 금지):
   ```powershell
   setx GEMINI_API_KEY "발급키"
   ```
3. Node 패키지: `npm i @google/genai`
4. 아래 스크립트를 `scripts/insta_render.mjs`로 저장.

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

### 3.4 (선택) PNG 래스터화
완성 SVG를 업로드용 PNG로: **Playwright(headless Chromium) + Pretendard 웹폰트 임베드** 방식을 권장(한글 폰트 안정). `sharp`/`resvg`는 시스템에 Pretendard 미설치 시 한글 깨짐 위험.

### 3.5 품질 게이트 (권장)
완전 무인 발행은 표지 리스크가 있으므로: 스크립트 실행 → `*_done.svg` 10장을 사람이 1초씩 훑고 OK → 업로드. 불량 카드만 해당 프롬프트 재실행(인덱스 지정).

### 3.6 비용 인지
이미지 1장당 수 센트(모델별 상이). 원고 1건=10장, 일 N건이면 일일 비용 ≈ 10·N·단가. AI Studio에서 일일 쿼터·예산 알림 설정 권장.

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
- [ ] **(다음) 프로토타입 4종 디자인 검수 → 을지로 card_01~10 완성** ← 표준 확정
- [ ] Phase A 1~2주 수동 운영 안정화
- [ ] Phase B: Google API 키 + `scripts/insta_render.mjs` 가동
