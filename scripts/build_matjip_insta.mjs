// 김포맛집 인스타 카드뉴스 빌더 (실사진 배경 + 임팩트 카피)
// 사용: node scripts/build_matjip_insta.mjs <설정JSON경로>
//   설정 JSON: { outDir, handle, photosDir, cards:[{photo, role, scrim, kicker, lines[], name, cta, handle}] }
// 동작: 각 카드의 실사진을 base64(jpeg)로 BG에 임베드 → card_NN_role_done.svg 저장.
//   이후 scripts/insta_rasterize.mjs 로 PNG(1080×1350) 래스터화.
// 하우스 표준: 1080×1350, Pretendard, 그라데이션 스크림만(불투명 밴드 금지),
//   좌측 brand-bar 14px, 우하단 brand-watermark 코너 탭(핸들).

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import path from "node:path";

const cfgPath = process.argv[2];
if (!cfgPath) throw new Error("설정 JSON 경로를 인자로 주세요.");
const cfg = JSON.parse(readFileSync(cfgPath, "utf8"));

const W = 1080, H = 1350;
const P = cfg.palette || {};
const RED = P.primary || "#b53a2e", DARKRED = P.dark || "#6e2018", GOLD = P.accent || "#f2a341", INK = "#fff";
const HLW = P.hlWeight || 600;  // 헤드라인 굵기(얇게 = 사진 가림 최소, 2026-07-09 조정)
const FONT = "Pretendard, 'Apple SD Gothic Neo', sans-serif";

const outDir = cfg.outDir;
mkdirSync(outDir, { recursive: true });

function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

function b64image(photoPath) {
  const buf = readFileSync(photoPath);
  const ext = path.extname(photoPath).toLowerCase();
  const mime = ext === ".png" ? "image/png" : "image/jpeg";
  return `<image id="BG" x="0" y="0" width="${W}" height="${H}" preserveAspectRatio="xMidYMid slice" href="data:${mime};base64,${buf.toString("base64")}"/>`;
}

// 하단 앵커 텍스트 블록: lines를 아래에서 위로 쌓음
function bottomBlock({ kicker, name, lines = [], baseSize = 84, gap = 1.16, bottom = 1180 }) {
  let out = "";
  // 본문 라인들(아래→위)
  const n = lines.length;
  const lineH = baseSize * gap;
  let y = bottom - (n - 1) * lineH;
  const startY = y;
  out += `<text x="76" y="${startY}" font-family="${FONT}" font-weight="${HLW}" font-size="${baseSize}" fill="${INK}" filter="url(#sh)">`;
  lines.forEach((ln, i) => {
    out += `<tspan x="76" dy="${i === 0 ? 0 : lineH}">${esc(ln)}</tspan>`;
  });
  out += `</text>`;
  // kicker (본문 위)
  if (kicker) {
    out += `<text x="80" y="${startY - baseSize - 26}" font-family="${FONT}" font-weight="700" font-size="30" letter-spacing="4" fill="${GOLD}" filter="url(#sh)">${esc(kicker)}</text>`;
  }
  // name chip (본문 아래 강조)
  if (name) {
    out += `<text x="76" y="${bottom + 62}" font-family="${FONT}" font-weight="680" font-size="46" fill="${GOLD}" filter="url(#sh)">${esc(name)}</text>`;
  }
  return out;
}

// info 카드: 팩트 라인 + 얇은 강조 틱
function infoBlock({ kicker, facts = [], bottom = 1150 }) {
  let out = "";
  const lineH = 96;
  const startY = bottom - (facts.length - 1) * lineH;
  if (kicker) out += `<text x="80" y="${startY - 96}" font-family="${FONT}" font-weight="700" font-size="32" letter-spacing="4" fill="${GOLD}" filter="url(#sh)">${esc(kicker)}</text>`;
  facts.forEach((f, i) => {
    const y = startY + i * lineH;
    out += `<rect x="76" y="${y - 34}" width="10" height="42" rx="2" fill="${GOLD}"/>`;
    out += `<text x="108" y="${y}" font-family="${FONT}" font-weight="700" font-size="44" fill="${INK}" filter="url(#sh)">${esc(f)}</text>`;
  });
  return out;
}

// CTA 카드
function ctaBlock({ lines = [], cta, handle }) {
  let out = "";
  out += `<text x="76" y="820" font-family="${FONT}" font-weight="${HLW}" font-size="86" fill="${INK}" filter="url(#sh)">`;
  lines.forEach((ln, i) => out += `<tspan x="76" dy="${i === 0 ? 0 : 100}">${esc(ln)}</tspan>`);
  out += `</text>`;
  out += `<text x="76" y="1080" font-family="${FONT}" font-weight="700" font-size="52" fill="${GOLD}" filter="url(#sh)">${esc(cta)}</text>`;
  out += `<text x="76" y="1150" font-family="${FONT}" font-weight="700" font-size="40" fill="${INK}" filter="url(#sh)">${esc(handle)}</text>`;
  return out;
}

function scrim(strength) {
  // strength: 'cover'|'mid'|'strong'
  const stops = strength === "strong"
    ? `<stop offset="0" stop-color="#140805" stop-opacity="0.15"/><stop offset="0.4" stop-color="#140805" stop-opacity="0.35"/><stop offset="1" stop-color="#140805" stop-opacity="0.9"/>`
    : strength === "mid"
    ? `<stop offset="0" stop-color="#140805" stop-opacity="0"/><stop offset="0.45" stop-color="#140805" stop-opacity="0.1"/><stop offset="1" stop-color="#140805" stop-opacity="0.86"/>`
    : `<stop offset="0" stop-color="#140805" stop-opacity="0"/><stop offset="0.5" stop-color="#140805" stop-opacity="0.05"/><stop offset="1" stop-color="#140805" stop-opacity="0.82"/>`;
  return `<linearGradient id="scrim" x1="0" y1="0" x2="0" y2="1">${stops}</linearGradient>`;
}

function watermark(handle) {
  const wfs = handle.length > 14 ? 26 : 30;
  return `<g id="brand-watermark"><path d="M822 1251 H1080 V1350 H792 V1281 A30 30 0 0 1 822 1251 Z" fill="${DARKRED}"/><text x="936" y="1312" font-family="${FONT}" font-weight="800" font-size="${wfs}" fill="#fff" text-anchor="middle">${esc(handle)}</text></g>`;
}

function buildCard(card, idx) {
  const nn = String(idx + 1).padStart(2, "0");
  const photoPath = path.join(cfg.photosDir, card.photo);
  let body = "";
  if (card.role === "info") body = infoBlock(card);
  else if (card.role === "cta") body = ctaBlock(card);
  else body = bottomBlock(card);

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
<defs>
${scrim(card.scrim || "cover")}
<filter id="sh" x="-10%" y="-10%" width="120%" height="120%"><feDropShadow dx="0" dy="2" stdDeviation="10" flood-color="#000" flood-opacity="0.66"/></filter>
</defs>
${b64image(photoPath)}
<rect x="0" y="0" width="${W}" height="${H}" fill="url(#scrim)"/>
<rect x="0" y="0" width="14" height="${H}" fill="${RED}"/>
${body}
${watermark(card.handle || cfg.handle)}
</svg>`;
  const out = path.join(outDir, `card_${nn}_${card.role}_done.svg`);
  writeFileSync(out, svg);
  console.log(`✔ ${path.basename(out)}  (bg: ${card.photo})`);
}

cfg.cards.forEach(buildCard);
console.log(`\n=== ${cfg.cards.length}장 완성: ${outDir} ===\n다음: node scripts/insta_rasterize.mjs ${outDir}`);
