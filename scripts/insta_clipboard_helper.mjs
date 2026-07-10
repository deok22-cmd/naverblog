// 인스타 카드 반자동 클립보드 헬퍼 (무과금)
// 사용:
//   node scripts/insta_clipboard_helper.mjs output_insta/<YYMMDD>/<slug>
//   node scripts/insta_clipboard_helper.mjs output_insta/<YYMMDD>/<slug> 3,7   (특정 카드만)
//
// 동작: prompts.md 코드블록을 순차로 클립보드 복사 → 사용자가 Gemini 웹(gemini.google.com)에
//   Ctrl+V → 이미지 생성 → 다운로드해서 <slug>/img/NN.png 로 저장하면, 스크립트가
//   파일 출현을 폴링 감지해 자동으로 다음 프롬프트를 클립보드에 올려둔다.
//
// ToS 안전: 자동화는 *로컬 OS*(클립보드·브라우저 오픈)만 수행하고, gemini.google.com
//   상의 모든 조작(붙여넣기·생성 클릭·다운로드)은 *사람이 직접* 수행 → Google 컨슈머
//   서비스 약관에 저촉되지 않는다(자동화 도구로 컨슈머 웹 접근 금지 조항 회피).
//
// 후속 단계 (헬퍼 종료 후 자동 안내):
//   node scripts/insta_render.mjs <slug> --reuse       → img/NN.png 를 SVG에 제자리 주입
//   node scripts/insta_rasterize.mjs <slug>            → 1080×1350 PNG 산출

import { readFileSync, readdirSync, existsSync, mkdirSync, unlinkSync } from "node:fs";
import path from "node:path";
import { spawn, exec } from "node:child_process";
import readline from "node:readline";

const dir = process.argv[2];
if (!dir) {
  console.error("사용: node scripts/insta_clipboard_helper.mjs output_insta/<YYMMDD>/<slug> [카드번호 콤마]");
  process.exit(1);
}
const onlyArg = process.argv.slice(3).find(a => !a.startsWith("--"));
const onlySet = onlyArg ? new Set(onlyArg.split(",").map(s => parseInt(s.trim(), 10))) : null;

// 1) prompts.md 코드블록 추출 (CRLF 정규화)
const md = readFileSync(path.join(dir, "prompts.md"), "utf8").replace(/\r\n/g, "\n");
const prompts = [...md.matchAll(/```[a-z]*\n([\s\S]*?)\n```/g)].map(m => m[1].trim());
if (prompts.length === 0) { console.error("prompts.md 에서 코드블록을 찾지 못했습니다."); process.exit(1); }

// 2) card_NN_*.svg 수 (이미 만든 _done.svg 는 제외)
const cards = readdirSync(dir)
  .filter(f => /^card_\d{2}.*\.svg$/.test(f) && !f.endsWith("_done.svg"))
  .sort();
if (cards.length === 0) { console.error("card_NN_*.svg 파일이 없습니다."); process.exit(1); }
if (prompts.length < cards.length) {
  console.error(`프롬프트 수(${prompts.length}) < SVG 수(${cards.length})`); process.exit(1);
}

const imgDir = path.join(dir, "img");
if (!existsSync(imgDir)) mkdirSync(imgDir, { recursive: true });

// 3) 클립보드 복사 (Windows: clip / macOS: pbcopy / Linux: xclip)
function copyToClipboard(text) {
  return new Promise((resolve, reject) => {
    const isWin = process.platform === "win32";
    const isMac = process.platform === "darwin";
    const cmd = isWin ? "clip" : isMac ? "pbcopy" : "xclip";
    const args = !isWin && !isMac ? ["-selection", "clipboard"] : [];
    const child = spawn(cmd, args, { shell: isWin });
    child.on("error", reject);
    child.on("exit", code => code === 0 ? resolve() : reject(new Error(`${cmd} exit ${code}`)));
    child.stdin.end(text, "utf8"); // 프롬프트는 ASCII 영문 (스타일앵커 포함)이라 UTF-8로 안전
  });
}

// 4) 기본 브라우저로 Gemini 웹 열기 (최초 1회)
function openBrowser(url) {
  const cmd = process.platform === "win32" ? `start "" "${url}"`
    : process.platform === "darwin" ? `open "${url}"`
    : `xdg-open "${url}"`;
  exec(cmd, () => {});
}

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
function ask(q) { return new Promise(res => rl.question(q, res)); }

// 5) 파일 출현 자동감지 + 사용자 키 입력 병행 대기
function waitForFileOrInput(pngPath, promptIdx) {
  return new Promise(resolve => {
    let done = false;
    const startedAt = Date.now();

    // fs.watch 는 Windows에서 다운로드 임시파일 처리가 불안정 → 단순 폴링이 더 안정
    const poll = setInterval(() => {
      if (done) return;
      if (existsSync(pngPath)) finish("file");
    }, 700);

    const onLine = async (raw) => {
      if (done) return;
      const c = raw.trim().toLowerCase();
      if (c === "" || c === "n") finish("next");
      else if (c === "s") finish("skip");
      else if (c === "r") {
        await copyToClipboard(prompts[promptIdx]);
        console.log("  ✔ 클립보드 재복사");
      }
      else if (c === "q") { finish("quit"); rl.close(); process.exit(0); }
      else console.log("  ?  [Enter]=다음 | s=skip | r=재복사 | q=종료");
    };
    rl.on("line", onLine);

    function finish(reason) {
      if (done) return;
      done = true;
      clearInterval(poll);
      rl.off("line", onLine);
      const sec = ((Date.now() - startedAt) / 1000).toFixed(1);
      const label = reason === "file" ? `✔ 다운로드 감지 (${sec}s)`
        : reason === "next" ? `→ 수동 진행 (${sec}s)`
        : reason === "skip" ? `↷ skip`
        : `× quit`;
      console.log(`  ${label}`);
      resolve(reason);
    }
  });
}

// === 본문 ===
console.log("\n=== 인스타 카드 반자동 클립보드 헬퍼 ===");
console.log(`대상: ${dir}`);
console.log(`카드 ${cards.length}장 | 프롬프트 ${prompts.length}개`);
console.log("");
console.log("진행: 프롬프트가 클립보드에 자동 복사됩니다 → Gemini에 Ctrl+V → 이미지 생성 →");
console.log(`      다운로드해서 ${path.join(imgDir.replace(process.cwd() + path.sep, ""), "NN.png")} 로 저장 →`);
console.log("      파일이 감지되면 다음 프롬프트로 자동 진행.");
console.log("");
console.log("키 입력 (언제든): Enter=다음(수동진행) | s=skip | r=재복사 | q=종료");
console.log("");

let browserOpened = false;
let processed = 0, skipped = 0;

for (let i = 0; i < cards.length; i++) {
  const cardNo = i + 1;
  if (onlySet && !onlySet.has(cardNo)) continue;

  const nn = String(cardNo).padStart(2, "0");
  const pngPath = path.join(imgDir, `${nn}.png`);

  console.log(`[${cardNo}/${cards.length}] ${cards[i]}`);

  if (existsSync(pngPath)) {
    const ans = await ask(`  img/${nn}.png 이미 존재 → [s]kip(기본) / [o]verwrite: `);
    if (ans.trim().toLowerCase() !== "o") {
      console.log("  ↷ 기존 파일 유지\n");
      skipped++;
      continue;
    }
    try { unlinkSync(pngPath); } catch {}
  }

  await copyToClipboard(prompts[i]);
  const preview = prompts[i].slice(0, 70).replace(/\s+/g, " ");
  console.log(`  ✔ 클립보드 복사 — "${preview}…"`);
  console.log(`  → 저장 위치: img/${nn}.png`);

  if (!browserOpened) {
    openBrowser("https://gemini.google.com/app");
    browserOpened = true;
    console.log("  ✔ Gemini 탭 오픈 (최초 1회 — 로그인 필요 시 진행)");
  }

  const result = await waitForFileOrInput(pngPath, i);
  if (result === "skip") skipped++;
  else processed++;
  console.log("");
}

rl.close();

console.log("=== 헬퍼 종료 ===");
console.log(`처리: ${processed} | 스킵: ${skipped} | 대상: ${onlySet ? onlySet.size : cards.length}`);
console.log("");
console.log("다음 단계 (img/ → _done.svg → PNG 1080×1350):");
console.log(`  node scripts/insta_render.mjs ${dir} --reuse`);
console.log(`  node scripts/insta_rasterize.mjs ${dir}`);
