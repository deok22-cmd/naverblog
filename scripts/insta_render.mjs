// 인스타 카드뉴스 Phase B 렌더러
// 사용:
//   node scripts/insta_render.mjs output_insta/260516/euljiro
//   node scripts/insta_render.mjs output_insta/260516/euljiro 3,7   (특정 카드만 재생성)
//
// 동작: prompts.md의 코드블록 10개 추출 → Gemini 이미지 생성 →
//       각 card_NN_*.svg의 BG__REPLACE_WITH_IMAGE 슬롯을 base64 <image>로 치환 →
//       card_NN_*_done.svg 저장 + img/NN.png 원본 저장(Figma 수동 경로 겸용).
//
// 키는 환경변수 GEMINI_API_KEY 로만 받는다 (스크립트/깃에 절대 하드코딩 금지).
// 모델: gemini-2.5-flash-image (generateContent, responseModalities:["IMAGE"]).
//   ※ insta_card_pipeline.md §3.3 원안은 Imagen SDK였으나, 이 환경에서
//     검증된 REST 경로(결제 불요·SDK 불요)로 구현. 비율은 SVG가 slice-crop.

import { readFileSync, writeFileSync, readdirSync, mkdirSync, existsSync } from "node:fs";
import path from "node:path";

const dir = process.argv[2];
if (!dir) throw new Error("대상 폴더 경로를 인자로 주세요 (예: output_insta/260516/euljiro)");

// "3,7" → 1-based 카드 번호만 처리 (플래그 토큰은 제외)
const onlyArg = process.argv.slice(3).find(a => !a.startsWith("--"));
const onlySet = onlyArg ? new Set(onlyArg.split(",").map(s => parseInt(s.trim(), 10))) : null;

// 배경 재사용 모드: img/NN.png 가 있으면 Gemini 미호출·디스크 재주입
// (레이아웃만 바꿔 재생성할 때 과금 0). 캐시 없는 카드만 API 호출(부분 폴백).
const REUSE = process.env.INSTA_REUSE === "1" || process.argv.includes("--reuse");

const KEY = process.env.GEMINI_API_KEY;
if (!KEY && !REUSE) throw new Error("환경변수 GEMINI_API_KEY 가 설정되어 있지 않습니다. (재사용만 하려면 INSTA_REUSE=1)");

const MODEL = process.env.INSTA_IMAGE_MODEL || "gemini-2.5-flash-image";
const ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${KEY}`;

// 1) prompts.md 코드블록 10개 추출 (카드 순서대로)
const md = readFileSync(path.join(dir, "prompts.md"), "utf8").replace(/\r\n/g, "\n");
const prompts = [...md.matchAll(/```[a-z]*\n([\s\S]*?)\n```/g)].map(m => m[1].trim());
if (prompts.length === 0) throw new Error("prompts.md 에서 코드블록을 찾지 못했습니다.");

// 2) card_NN_*.svg 정렬 (이미 만든 _done.svg 는 제외)
const svgs = readdirSync(dir)
  .filter(f => /^card_\d{2}.*\.svg$/.test(f) && !f.endsWith("_done.svg"))
  .sort();
if (svgs.length === 0) throw new Error("card_NN_*.svg 파일이 없습니다.");
if (prompts.length < svgs.length)
  throw new Error(`프롬프트 수(${prompts.length}) < SVG 수(${svgs.length})`);

const imgDir = path.join(dir, "img");
if (!existsSync(imgDir)) mkdirSync(imgDir, { recursive: true });

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function genImage(prompt, tries = 3) {
  for (let t = 1; t <= tries; t++) {
    try {
      const res = await fetch(ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { responseModalities: ["IMAGE"] },
        }),
      });
      const j = await res.json();
      if (j.error) throw new Error(`${j.error.status}: ${j.error.message}`);
      const parts = j?.candidates?.[0]?.content?.parts || [];
      const img = parts.find(p => p.inlineData?.data);
      if (!img) throw new Error("응답에 이미지 파트 없음: " + JSON.stringify(parts).slice(0, 200));
      return { b64: img.inlineData.data, mime: img.inlineData.mimeType || "image/png" };
    } catch (e) {
      if (t === tries) throw e;
      console.log(`  재시도 ${t}/${tries - 1}: ${e.message}`);
      await sleep(2500 * t);
    }
  }
}

let okCount = 0;
const failed = [];

for (let i = 0; i < svgs.length; i++) {
  const cardNo = i + 1;
  if (onlySet && !onlySet.has(cardNo)) continue;

  const svgFile = svgs[i];
  const svgPath = path.join(dir, svgFile);
  let svg = readFileSync(svgPath, "utf8");

  if (!/<rect id="BG__REPLACE_WITH_IMAGE"[^>]*\/>/.test(svg)) {
    console.log(`✗ ${svgFile}: BG 슬롯을 찾지 못해 건너뜀`);
    failed.push(svgFile);
    continue;
  }

  try {
    const nn = String(cardNo).padStart(2, "0");
    const cachePath = path.join(imgDir, `${nn}.png`);
    let b64, mime;

    if (REUSE && existsSync(cachePath)) {
      b64 = readFileSync(cachePath).toString("base64");
      mime = "image/png";
      console.log(`▶ [${cardNo}/${svgs.length}] ${svgFile} — 배경 재사용 img/${nn}.png`);
    } else {
      if (!KEY) throw new Error(`img/${nn}.png 없음 & GEMINI_API_KEY 미설정 — 생성 불가`);
      console.log(`▶ [${cardNo}/${svgs.length}] ${svgFile} 생성 중...`);
      ({ b64, mime } = await genImage(prompts[i]));
      writeFileSync(cachePath, Buffer.from(b64, "base64"));
    }

    // BG 슬롯 → base64 <image> 치환 → 자체완결 완성 SVG
    svg = svg.replace(
      /<rect id="BG__REPLACE_WITH_IMAGE"[^>]*\/>/,
      `<image id="BG" x="0" y="0" width="1080" height="1350" preserveAspectRatio="xMidYMid slice" href="data:${mime};base64,${b64}"/>`
    );
    const out = svgPath.replace(/\.svg$/, "_done.svg");
    writeFileSync(out, svg);
    console.log(`✔ 완성: ${path.basename(out)}  (img/${nn}.png)`);
    okCount++;
  } catch (e) {
    console.log(`✗ ${svgFile} 실패: ${e.message}`);
    failed.push(svgFile);
  }
  if (!REUSE) await sleep(1200); // 레이트리밋 완화 (재사용 모드는 불필요)
}

console.log(`\n=== 결과: 성공 ${okCount} / 대상 ${onlySet ? onlySet.size : svgs.length} ===`);
if (failed.length) {
  console.log("실패:", failed.join(", "));
  process.exitCode = 1;
}
