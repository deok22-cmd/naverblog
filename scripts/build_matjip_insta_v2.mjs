// 김포맛집 인스타 카드뉴스 빌더 v2 — PHOTO-FIRST (2026-07-10 벤치마킹 개편)
// 사용: node scripts/build_matjip_insta_v2.mjs <설정JSON경로>
//
// 철학(인기 맛집 계정 벤치마킹 결과):
//   · 사진이 주인공. 텍스트는 커버에 집중, 본문은 무텍스트거나 얇은 대화체 한 줄.
//   · 제거: 좌측 브랜드바 · 골드 키커 칩 · 하단 불투명 스크림 밴드 · 3줄 볼드 블록.
//   · 스크림은 '텍스트 있는 카드'에만 부드럽게. 무텍스트 카드는 사진 원본 그대로.
//   · 워터마크는 작고 흐리게(중앙 하단 점선 핸들, Type2 스타일).
//
// 카드 role:
//   cover   : 풀블리드 1컷 + 후킹 헤드라인(외곽선). kicker/name 선택.
//   collage : 4분할 콜라주 커버 + 중앙 후킹(외곽선) + badge 선택. photos:[4].
//   photo   : 순수 사진(텍스트 0).
//   caption : 사진 + 얇은 대화체 캡션(중앙, 얇게).
//   info    : 사진 + 최소 정보(주소/가격/전화). 딱 1장.
//   cta     : 사진 + 짧은 CTA + 핸들.
//
// 이후 scripts/insta_rasterize.mjs 로 PNG(1080×1350) 래스터화.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import path from "node:path";

const cfgPath = process.argv[2];
if (!cfgPath) throw new Error("설정 JSON 경로를 인자로 주세요.");
const cfg = JSON.parse(readFileSync(cfgPath, "utf8"));

const W = 1080, H = 1350;
const FONT = "Pretendard, 'Apple SD Gothic Neo', sans-serif";
const ACCENT = cfg.accent || "#ffd39a";   // 따뜻한 크림(아주 절제해서만)
const INK = "#fff";

const outDir = cfg.outDir;
mkdirSync(outDir, { recursive: true });

function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

function b64(photo) {
  const p = path.join(cfg.photosDir, photo);
  const buf = readFileSync(p);
  const ext = path.extname(p).toLowerCase();
  const mime = ext === ".png" ? "image/png" : "image/jpeg";
  return `data:${mime};base64,${buf.toString("base64")}`;
}
function fullImage(photo) {
  return `<image x="0" y="0" width="${W}" height="${H}" preserveAspectRatio="xMidYMid slice" href="${b64(photo)}"/>`;
}

// 부드러운 하단 그라데이션(텍스트 카드에만). strength: soft|mid|strong
function scrimDefs(id, strength) {
  const stops = strength === "strong"
    ? `<stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="0.45" stop-color="#000" stop-opacity="0.28"/><stop offset="1" stop-color="#000" stop-opacity="0.82"/>`
    : strength === "mid"
    ? `<stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="0.55" stop-color="#000" stop-opacity="0.12"/><stop offset="1" stop-color="#000" stop-opacity="0.66"/>`
    : `<stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="0.6" stop-color="#000" stop-opacity="0.06"/><stop offset="1" stop-color="#000" stop-opacity="0.5"/>`;
  return `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1">${stops}</linearGradient>`;
}

// 흐릿한 중앙 하단 워터마크(있는 듯 없는 듯)
function watermark(handle) {
  const y = 1306;
  const half = Math.min(230, 40 + handle.length * 7);
  const cx = W / 2;
  const gap = handle.length * 8 + 30;
  return `<g opacity="0.66" filter="url(#sh)">
  <line x1="${cx - gap - 70}" y1="${y - 9}" x2="${cx - gap}" y2="${y - 9}" stroke="#fff" stroke-width="2" stroke-dasharray="1.5 7" opacity="0.7"/>
  <line x1="${cx + gap}" y1="${y - 9}" x2="${cx + gap + 70}" y2="${y - 9}" stroke="#fff" stroke-width="2" stroke-dasharray="1.5 7" opacity="0.7"/>
  <text x="${cx}" y="${y}" text-anchor="middle" font-family="${FONT}" font-weight="700" font-size="25" letter-spacing="1" fill="#fff">${esc(handle)}</text>
  </g>`;
}

// 후킹 헤드라인(외곽선 + 그림자). anchor: 'start'|'middle'
// stroke: 외곽선 두께(px). 0이면 외곽선 없이 부드러운 그림자만(Type4식 — 배경이 차분할 때).
function hookText(lines, { x, lastBaseline, size, weight = 750, anchor = "start", stroke = 6 }) {
  const lineH = size * 1.14;
  const topBaseline = lastBaseline - (lines.length - 1) * lineH;
  const strokeAttr = stroke > 0 ? ` paint-order="stroke" stroke="#1a0d06" stroke-width="${stroke}" stroke-linejoin="round"` : "";
  let out = `<text x="${x}" y="${topBaseline}" text-anchor="${anchor}" font-family="${FONT}" font-weight="${weight}" font-size="${size}" fill="${INK}"${strokeAttr} filter="url(#sh)">`;
  lines.forEach((ln, i) => { out += `<tspan x="${x}" dy="${i === 0 ? 0 : lineH}">${esc(ln)}</tspan>`; });
  out += `</text>`;
  return { svg: out, topBaseline, lineH };
}

function coverCard(card) {
  const size = card.size || 92;
  const st = card.stroke ?? 6;   // 0이면 소프트섀도만(Type4식)
  const nameStroke = st > 0 ? ` paint-order="stroke" stroke="#1a0d06" stroke-width="5" stroke-linejoin="round"` : "";
  const B = 1188;
  let cursor = B;
  let body = "";
  // name(상호) — 큰 텍스트 아래 크림색 강조
  if (card.name) {
    body += `<text x="72" y="${cursor}" font-family="${FONT}" font-weight="800" font-size="52" fill="${ACCENT}"${nameStroke} filter="url(#sh)">${esc(card.name)}</text>`;
    cursor -= (52 + 26);
  }
  const hk = hookText(card.lines || [], { x: 72, lastBaseline: cursor, size, stroke: st });
  body += hk.svg;
  // kicker(작은 라벨) — 후킹 위
  if (card.kicker) {
    body += `<text x="76" y="${hk.topBaseline - size - 22}" font-family="${FONT}" font-weight="700" font-size="30" letter-spacing="3" fill="#fff" opacity="0.92" filter="url(#sh)">${esc(card.kicker)}</text>`;
  }
  return { defs: scrimDefs("scrim", "mid"), layers: `<rect x="0" y="0" width="${W}" height="${H}" fill="url(#scrim)"/>`, body, image: fullImage(card.photo) };
}

function collageCard(card) {
  const photos = card.photos || [];
  const quads = [[0, 0], [W / 2, 0], [0, H / 2], [W / 2, H / 2]];
  let clips = "", imgs = "";
  quads.forEach((q, i) => {
    const ph = photos[i] || photos[photos.length - 1];
    clips += `<clipPath id="q${i}"><rect x="${q[0]}" y="${q[1]}" width="${W / 2}" height="${H / 2}"/></clipPath>`;
    imgs += `<image x="${q[0]}" y="${q[1]}" width="${W / 2}" height="${H / 2}" preserveAspectRatio="xMidYMid slice" clip-path="url(#q${i})" href="${b64(ph)}"/>`;
  });
  // 중앙 후킹이 읽히도록 전체 살짝 어둡게 + 중앙 밴드
  const dim = `<rect x="0" y="0" width="${W}" height="${H}" fill="#000" opacity="0.26"/>`;
  const size = card.size || 84;
  let body = "";
  let badgeH = 0;
  if (card.badge) {
    badgeH = 60;
    body += `<g filter="url(#sh)"><rect x="${W / 2 - 150}" y="470" width="300" height="52" rx="26" fill="#d9342b"/><text x="${W / 2}" y="505" text-anchor="middle" font-family="${FONT}" font-weight="800" font-size="26" fill="#fff">${esc(card.badge)}</text></g>`;
  }
  const hk = hookText(card.lines || [], { x: W / 2, lastBaseline: 720, size, anchor: "middle" });
  body += hk.svg;
  if (card.name) {
    body += `<text x="${W / 2}" y="${720 + 78}" text-anchor="middle" font-family="${FONT}" font-weight="800" font-size="46" fill="${ACCENT}" paint-order="stroke" stroke="#1a0d06" stroke-width="5" stroke-linejoin="round" filter="url(#sh)">${esc(card.name)}</text>`;
  }
  return { defs: `${clips}`, layers: dim, body, image: imgs };
}

function photoCard(card) {
  return { defs: "", layers: "", body: "", image: fullImage(card.photo) };
}

function captionCard(card) {
  // 중앙 정렬 얇은 대화체 1~2줄, 하단 60% 지점
  const size = card.size || 46;
  const lines = card.lines || [];
  const lineH = size * 1.34;
  const bottom = card.bottom || 1120;
  const top = bottom - (lines.length - 1) * lineH;
  let t = `<text x="${W / 2}" y="${top}" text-anchor="middle" font-family="${FONT}" font-weight="500" font-size="${size}" fill="${INK}" filter="url(#sh)">`;
  lines.forEach((ln, i) => { t += `<tspan x="${W / 2}" dy="${i === 0 ? 0 : lineH}">${esc(ln)}</tspan>`; });
  t += `</text>`;
  return { defs: scrimDefs("scrim", "soft"), layers: `<rect x="0" y="0" width="${W}" height="${H}" fill="url(#scrim)"/>`, body: t, image: fullImage(card.photo) };
}

function infoCard(card) {
  const facts = card.facts || [];
  const lineH = 86;
  const bottom = 1150;
  const startY = bottom - (facts.length - 1) * lineH;
  let body = "";
  if (card.kicker) {
    body += `<text x="80" y="${startY - 84}" font-family="${FONT}" font-weight="700" font-size="30" letter-spacing="2" fill="${ACCENT}" filter="url(#sh)">${esc(card.kicker)}</text>`;
  }
  facts.forEach((f, i) => {
    const y = startY + i * lineH;
    body += `<circle cx="86" cy="${y - 13}" r="6" fill="${ACCENT}"/>`;
    body += `<text x="108" y="${y}" font-family="${FONT}" font-weight="600" font-size="40" fill="${INK}" filter="url(#sh)">${esc(f)}</text>`;
  });
  return { defs: scrimDefs("scrim", "strong"), layers: `<rect x="0" y="0" width="${W}" height="${H}" fill="url(#scrim)"/>`, body, image: fullImage(card.photo) };
}

function ctaCard(card) {
  const size = card.size || 74;
  const lines = card.lines || [];
  const lineH = size * 1.2;
  let body = `<text x="72" y="900" font-family="${FONT}" font-weight="750" font-size="${size}" fill="${INK}" paint-order="stroke" stroke="#1a0d06" stroke-width="5" stroke-linejoin="round" filter="url(#sh)">`;
  lines.forEach((ln, i) => { body += `<tspan x="72" dy="${i === 0 ? 0 : lineH}">${esc(ln)}</tspan>`; });
  body += `</text>`;
  if (card.cta) body += `<text x="72" y="1070" font-family="${FONT}" font-weight="800" font-size="48" fill="${ACCENT}" filter="url(#sh)">${esc(card.cta)}</text>`;
  const handle = card.handle || cfg.handle;
  body += `<text x="72" y="1140" font-family="${FONT}" font-weight="700" font-size="38" fill="#fff" opacity="0.95" filter="url(#sh)">${esc(handle)}</text>`;
  return { defs: scrimDefs("scrim", "strong"), layers: `<rect x="0" y="0" width="${W}" height="${H}" fill="url(#scrim)"/>`, body, image: fullImage(card.photo) };
}

const RENDER = { cover: coverCard, collage: collageCard, photo: photoCard, caption: captionCard, info: infoCard, cta: ctaCard };

function build(card, idx) {
  const nn = String(idx + 1).padStart(2, "0");
  const fn = RENDER[card.role] || photoCard;
  const r = fn(card);
  // CTA는 워터마크 대신 핸들이 크게 있으므로 생략, 그 외 카드엔 흐린 워터마크
  const wm = card.role === "cta" ? "" : watermark(card.handle || cfg.handle);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
<defs>
${r.defs || ""}
<filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="2" stdDeviation="9" flood-color="#000" flood-opacity="0.62"/></filter>
</defs>
${r.image}
${r.layers || ""}
${r.body || ""}
${wm}
</svg>`;
  const out = path.join(outDir, `card_${nn}_${card.role}_done.svg`);
  writeFileSync(out, svg);
  console.log(`✔ ${path.basename(out)}  (${card.role}${card.photo ? " · " + card.photo : card.photos ? " · collage" : ""})`);
}

cfg.cards.forEach(build);
console.log(`\n=== ${cfg.cards.length}장 완성(photo-first): ${outDir} ===\n다음: node scripts/insta_rasterize.mjs ${outDir}`);
