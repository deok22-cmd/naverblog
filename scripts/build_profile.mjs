// 인스타 프로필 사진 빌더 (1080×1080 PNG) — 캐주얼·젊은 감성
// 사용: node scripts/build_profile.mjs
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import path from "node:path";
import puppeteer from "puppeteer-core";

const S = 1080;
const FONT = "Pretendard,'Apple SD Gothic Neo',sans-serif";
const EMOJI = "'Segoe UI Emoji','Apple Color Emoji','Noto Color Emoji',sans-serif";

// 프로필은 인스타에서 원형 크롭 → 중앙 원 안에 핵심 배치, 모서리는 배경만
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">
<defs>
<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
<stop offset="0" stop-color="#ff9a3c"/><stop offset="0.5" stop-color="#ff5a4e"/><stop offset="1" stop-color="#ff3f74"/>
</linearGradient>
<filter id="soft" x="-25%" y="-25%" width="150%" height="150%"><feDropShadow dx="0" dy="6" stdDeviation="16" flood-color="#7a1420" flood-opacity="0.38"/></filter>
</defs>
<rect width="${S}" height="${S}" fill="url(#bg)"/>
<circle cx="205" cy="185" r="22" fill="#fff" opacity="0.16"/>
<circle cx="905" cy="250" r="14" fill="#fff" opacity="0.14"/>
<circle cx="860" cy="835" r="18" fill="#fff" opacity="0.12"/>
<circle cx="225" cy="835" r="12" fill="#fff" opacity="0.15"/>
<circle cx="120" cy="520" r="9" fill="#fff" opacity="0.13"/>
<circle cx="960" cy="560" r="10" fill="#fff" opacity="0.12"/>
<circle cx="540" cy="428" r="252" fill="#fff" opacity="0.15"/>
<text x="540" y="558" font-size="360" text-anchor="middle" font-family="${EMOJI}">🍲</text>
<text x="540" y="808" font-size="146" font-weight="800" letter-spacing="-5" fill="#fff" text-anchor="middle" font-family="${FONT}" filter="url(#soft)">김포맛집</text>
<g filter="url(#soft)"><rect x="446" y="854" width="188" height="76" rx="38" fill="#ffffff"/><text x="540" y="907" font-size="47" font-weight="800" letter-spacing="2" fill="#ff5140" text-anchor="middle" font-family="${FONT}">노트</text></g>
</svg>`;

const outDir = "output_insta/_brand";
mkdirSync(outDir, { recursive: true });
writeFileSync(path.join(outDir, "profile.svg"), svg);

const EDGE = [
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
];
const exe = process.env.INSTA_BROWSER || EDGE.find(p => existsSync(p));
if (!exe) throw new Error("Edge/Chrome 실행 파일을 찾지 못했습니다.");

const browser = await puppeteer.launch({
  executablePath: exe, headless: "new",
  args: ["--no-sandbox", "--disable-setuid-sandbox", "--force-color-profile=srgb"],
});
const page = await browser.newPage();
await page.setViewport({ width: S, height: S, deviceScaleFactor: 1 });
await page.setContent(`<!doctype html><html><body style="margin:0;padding:0">${svg}</body></html>`, { waitUntil: "networkidle0" });
const out = path.join(outDir, "gimpo_matjip_note_profile.png");
await page.screenshot({ path: out, clip: { x: 0, y: 0, width: S, height: S } });
await browser.close();
console.log("✔ 프로필 PNG:", out);
