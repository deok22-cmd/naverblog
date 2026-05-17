// 인스타 카드 _done.svg → 업로드용 PNG(1080×1350) 래스터화
// 사용:
//   node scripts/insta_rasterize.mjs output_insta/260516/euljiro
//   node scripts/insta_rasterize.mjs output_insta/260516/euljiro 3,7
//
// 엔진: 시스템 설치된 Microsoft Edge(Chromium)를 puppeteer-core로 헤드리스 구동.
//   → 가변폰트 weight·그라데이션·base64 <image> 모두 브라우저 동급으로 정확.
//   → Pretendard가 OS에 설치돼 있어 디자인 의도 폰트 그대로 렌더(없으면 Malgun 폴백).
// 입력: <dir>/card_NN_*_done.svg  (insta_render.mjs 산출물)
// 출력: <dir>/png/card_NN_*.png   (정확히 1080×1350)

import { readFileSync, readdirSync, mkdirSync, existsSync } from "node:fs";
import path from "node:path";
import puppeteer from "puppeteer-core";

const dir = process.argv[2];
if (!dir) throw new Error("대상 폴더 경로를 인자로 주세요 (예: output_insta/260516/euljiro)");

const onlyArg = process.argv[3];
const onlySet = onlyArg ? new Set(onlyArg.split(",").map(s => parseInt(s.trim(), 10))) : null;

const EDGE_CANDIDATES = [
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
];
const browserPath = process.env.INSTA_BROWSER || EDGE_CANDIDATES.find(p => existsSync(p));
if (!browserPath) throw new Error("Edge/Chrome 실행 파일을 찾지 못했습니다. INSTA_BROWSER 환경변수로 경로 지정 가능.");

const svgs = readdirSync(dir)
  .filter(f => /^card_\d{2}.*_done\.svg$/.test(f))
  .sort();
if (svgs.length === 0) throw new Error("card_NN_*_done.svg 파일이 없습니다. 먼저 insta_render.mjs를 실행하세요.");

const outDir = path.join(dir, "png");
if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });

const W = 1080, H = 1350;
const browser = await puppeteer.launch({
  executablePath: browserPath,
  headless: true,
  args: ["--no-sandbox", "--force-color-profile=srgb", "--hide-scrollbars"],
});

let ok = 0;
const failed = [];
try {
  const page = await browser.newPage();
  await page.setViewport({ width: W, height: H, deviceScaleFactor: 1 });

  for (let i = 0; i < svgs.length; i++) {
    const cardNo = i + 1;
    if (onlySet && !onlySet.has(cardNo)) continue;

    const file = svgs[i];
    try {
      const svg = readFileSync(path.join(dir, file), "utf8");
      const html = `<!doctype html><html><head><meta charset="utf-8">
<style>html,body{margin:0;padding:0;background:#fff}svg{display:block}</style>
</head><body>${svg}</body></html>`;
      await page.setContent(html, { waitUntil: "load" });
      await page.evaluateHandle("document.fonts.ready"); // 폰트 로드 완료 대기
      await new Promise(r => setTimeout(r, 250));         // 이미지 디코드 여유

      const out = path.join(outDir, file.replace(/_done\.svg$/, ".png"));
      await page.screenshot({ path: out, clip: { x: 0, y: 0, width: W, height: H } });
      console.log(`✔ ${path.basename(out)}`);
      ok++;
    } catch (e) {
      console.log(`✗ ${file} 실패: ${e.message}`);
      failed.push(file);
    }
  }
} finally {
  await browser.close();
}

console.log(`\n=== PNG 래스터: 성공 ${ok} / 대상 ${onlySet ? onlySet.size : svgs.length}  (${W}×${H}) ===`);
console.log(`출력: ${path.join(dir, "png")}`);
if (failed.length) { console.log("실패:", failed.join(", ")); process.exitCode = 1; }
