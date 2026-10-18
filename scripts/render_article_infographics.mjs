import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync } from "node:fs";
import path from "node:path";
import puppeteer from "puppeteer-core";

const EDGE_CANDIDATES = [
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
];

function getTodayYYMMDD() {
  const d = new Date();
  const yy = String(d.getFullYear()).slice(-2);
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yy}${mm}${dd}`;
}

function findTopLevelInfographics(html) {
  const list = [];
  const tagStartRegex = /<div\b[^>]*?(?:class=["'][^"']*?\binfographic-[^"']*?["']|data-infographic)[^>]*?>/gi;
  let match;
  let cursor = 0;

  while ((match = tagStartRegex.exec(html)) !== null) {
    const startIdx = match.index;
    if (startIdx < cursor) continue;

    let depth = 0;
    let i = startIdx;
    let endIdx = -1;
    while (i < html.length) {
      if (
        html.slice(i, i + 4).toLowerCase() === "<div" &&
        (html[i + 4] === " " || html[i + 4] === ">" || html[i + 4] === "/")
      ) {
        depth++;
        i += 4;
      } else if (html.slice(i, i + 6).toLowerCase() === "</div>") {
        depth--;
        i += 6;
        if (depth === 0) {
          endIdx = i;
          break;
        }
      } else {
        i++;
      }
    }

    if (endIdx !== -1) {
      list.push({
        startIdx,
        endIdx,
        content: html.substring(startIdx, endIdx),
        openTag: match[0],
      });
      cursor = endIdx;
      tagStartRegex.lastIndex = endIdx;
    }
  }
  return list;
}

function getOrderedFiles(outputDir) {
  const indexPath = path.join(outputDir, "index.html");
  const ordered = [];
  if (existsSync(indexPath)) {
    const indexHtml = readFileSync(indexPath, "utf-8");
    const hrefMatches = indexHtml.matchAll(/href=["']([^"']+\.html)["']/g);
    for (const m of hrefMatches) {
      const target = path.basename(m[1]);
      if (target !== "index.html" && !ordered.includes(target)) {
        if (existsSync(path.join(outputDir, target))) {
          ordered.push(target);
        }
      }
    }
  }

  const allFiles = readdirSync(outputDir).filter(f => f.endsWith(".html") && f !== "index.html");
  for (const f of allFiles) {
    if (!ordered.includes(f)) {
      ordered.push(f);
    }
  }
  return ordered;
}

async function main() {
  const args = process.argv.slice(2);
  const targetDate = args.find(a => !a.startsWith("-")) || getTodayYYMMDD();
  console.log(`\n======================================================`);
  console.log(`🎨 동적 다채널 인포그래픽 카드 자동 렌더링 & 치환 (날짜: ${targetDate})`);
  console.log(`======================================================`);

  const outputDir = path.resolve("output", targetDate);
  const imagesDir = path.resolve("images", targetDate);

  if (!existsSync(outputDir)) {
    console.error(`[ERROR] 출력 디렉터리를 찾을 수 없습니다: ${outputDir}`);
    process.exit(1);
  }

  if (!existsSync(imagesDir)) {
    mkdirSync(imagesDir, { recursive: true });
    console.log(`[INFO] 이미지 디렉터리 생성: ${imagesDir}`);
  }

  const browserPath = process.env.INSTA_BROWSER || EDGE_CANDIDATES.find(p => existsSync(p));
  if (!browserPath) {
    console.error("[ERROR] Edge 또는 Chrome 브라우저 실행 파일을 찾을 수 없습니다.");
    process.exit(1);
  }
  console.log(`[INFO] 사용 브라우저: ${browserPath}`);

  const files = getOrderedFiles(outputDir);
  console.log(`[INFO] 대상 원고 수: ${files.length}건\n`);

  const browser = await puppeteer.launch({
    executablePath: browserPath,
    headless: true,
    args: ["--no-sandbox", "--disable-gpu", "--force-color-profile=srgb", "--hide-scrollbars"],
  });

  let totalImagesRendered = 0;
  let totalHtmlsUpdated = 0;
  const auditResults = [];

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1000, height: 1600, deviceScaleFactor: 2 });

    for (let idx = 0; idx < files.length; idx++) {
      const file = files[idx];
      const seq = idx + 1;
      const slug = file.replace(/\.html$/, "");
      const filePath = path.join(outputDir, file);
      let html = readFileSync(filePath, "utf-8");

      console.log(`[${seq}/${files.length}] 검사 중: ${file}`);

      const ranges = findTopLevelInfographics(html);
      if (ranges.length === 0) {
        console.log(`   ℹ️ 변환할 인포그래픽 박스가 없거나 이미 이미지로 치환되어 있습니다.`);
        continue;
      }

      console.log(`   ✨ 발견된 인포그래픽 카드: ${ranges.length}개 (자동 렌더링 시작)`);

      const fileUrl = "file:///" + filePath.replace(/\\/g, "/");
      await page.goto(fileUrl, { waitUntil: "networkidle0" });
      await page.addStyleTag({
        content: `
          body, button, input, select, textarea {
            font-family: -apple-system, BlinkMacSystemFont, "Malgun Gothic", "맑은 고딕", "Noto Sans KR", sans-serif !important;
            -webkit-font-smoothing: antialiased;
          }
        `,
      });

      const elements = await page.$$(
        "[class*='infographic-']:not([class*='infographic-'] [class*='infographic-']), [data-infographic]"
      );

      if (elements.length !== ranges.length) {
        console.warn(
          `   ⚠️ DOM 엘리먼트 수(${elements.length})와 정규식 파싱 수(${ranges.length})가 다릅니다. DOM 기준 처리.`
        );
      }

      const replacements = [];

      for (let i = 0; i < ranges.length; i++) {
        const imgNum = i + 2;
        const imgFileName = `${seq}_${slug}_${imgNum}.png`;
        const imgPath = path.join(imagesDir, imgFileName);
        const el = elements[i];

        let captionText = `인포그래픽 카드 ${imgNum}`;
        let archetypeInfo = { id: "custom", label: "진화형 커스텀 카드" };
        let boxDimensions = { width: 0, height: 0, aspectRatio: "1.00" };

        if (el) {
          // 1. 캡션 & 아키타입 추출 로직
          const cardMeta = await page.evaluate(target => {
            const dataCap = target.getAttribute("data-caption");
            let cap = "";
            if (dataCap && dataCap.trim()) {
              cap = dataCap.trim();
            } else {
              const header = target.querySelector(".infographic-header, .infographic-title, h3");
              if (header && header.textContent.trim()) {
                cap = header.textContent.replace(/\s+/g, " ").trim();
              } else {
                const firstDiv = target.querySelector("div");
                if (firstDiv && firstDiv.textContent.trim()) {
                  cap = firstDiv.textContent.replace(/\s+/g, " ").trim().slice(0, 50);
                }
              }
            }

            const cls = (target.className || "").toLowerCase();
            const inner = (target.innerHTML || "").toLowerCase();
            let arc = "custom";
            let arcName = "진화형 커스텀 카드";

            if (cls.includes("compare") || inner.includes("compare-grid")) {
              arc = "compare"; arcName = "비교 매트릭스";
            } else if (cls.includes("timeline") || inner.includes("timeline-list")) {
              arc = "timeline"; arcName = "타임라인/동선 로드맵";
            } else if (cls.includes("strategy") || inner.includes("strategy-grid")) {
              arc = "strategy"; arcName = "코스/전술 공략도";
            } else if (cls.includes("receipt") || inner.includes("receipt-table")) {
              arc = "receipt"; arcName = "비용/견적 영수증";
            } else if (cls.includes("checklist") || inner.includes("checklist-grid")) {
              arc = "checklist"; arcName = "점검 체크리스트";
            } else if (cls.includes("flow") || inner.includes("flow-steps")) {
              arc = "flow"; arcName = "단계별 절차 플로우";
            } else if (cls.includes("scorecard") || inner.includes("scorecard-list")) {
              arc = "scorecard"; arcName = "평가지표 스코어카드";
            } else if (cls.includes("procon") || inner.includes("procon-grid")) {
              arc = "procon"; arcName = "장단점/추천 대조표";
            } else if (cls.includes("faq") || inner.includes("faq-list")) {
              arc = "faq"; arcName = "핵심 Q&A 매트릭스";
            } else if (cls.includes("stat") || inner.includes("stat-grid")) {
              arc = "stat"; arcName = "핵심 수치 매트릭스";
            }

            return { caption: cap, archetype: arc, archetypeName: arcName };
          }, el);

          captionText = cardMeta.caption || `핵심 인포그래픽 가이드 ${imgNum}`;
          archetypeInfo = { id: cardMeta.archetype, label: cardMeta.archetypeName };

          // 2. 고품질 렌더링 & 바운딩 박스 검증
          const box = await el.boundingBox();
          if (box) {
            boxDimensions = {
              width: Math.round(box.width),
              height: Math.round(box.height),
              aspectRatio: (box.width / (box.height || 1)).toFixed(2),
            };
          }

          await el.screenshot({ path: imgPath });
          totalImagesRendered++;
          console.log(`   ✅ [${imgNum}번 PNG 저장 | ${archetypeInfo.label}] ${imgFileName} (${boxDimensions.width}x${boxDimensions.height}px) - "${captionText}"`);

          auditResults.push({
            article: file,
            slug,
            imgNum,
            fileName: imgFileName,
            archetype: archetypeInfo.id,
            archetypeName: archetypeInfo.label,
            caption: captionText,
            dimensions: boxDimensions,
          });
        } else {
          console.warn(`   ⚠️ 엘리먼트 ${i}을(를) DOM에서 찾지 못했습니다.`);
        }

        const replacementHtml = `\n<!-- ${imgNum}번째 이미지: 자동 렌더링 인포그래픽 카드 -->\n<div class="img-area">\n<img alt="${captionText} / 인포그래픽 카드" src="../../images/${targetDate}/${imgFileName}" style="width:100%; border-radius:8px; display:block; margin:0 auto;"/>\n<div class="img-caption">${captionText} / 인포그래픽 카드</div>\n</div>\n`;

        replacements.push({
          startIdx: ranges[i].startIdx,
          endIdx: ranges[i].endIdx,
          html: replacementHtml,
        });
      }

      // 역순 치환 (문자열 인덱스 왜곡 방지)
      for (let i = replacements.length - 1; i >= 0; i--) {
        const rep = replacements[i];
        html = html.substring(0, rep.startIdx) + rep.html + html.substring(rep.endIdx);
      }

      writeFileSync(filePath, html, "utf-8");
      totalHtmlsUpdated++;
      console.log(`   📝 HTML 원고 치환 완료: ${file} (총 ${replacements.length}개 카드 이미지화)\n`);
    }
  } finally {
    await browser.close();
  }

  // 아키타입 다양성 통계 집계
  const archetypeCounts = {};
  for (const item of auditResults) {
    archetypeCounts[item.archetypeName] = (archetypeCounts[item.archetypeName] || 0) + 1;
  }
  const distinctArchetypes = Object.keys(archetypeCounts).length;
  const avgCards = totalHtmlsUpdated > 0 ? (totalImagesRendered / totalHtmlsUpdated).toFixed(1) : 0;

  // JSON 감사 리포트 저장
  const auditReportPath = path.join(outputDir, "infographic_audit.json");
  const auditReportData = {
    targetDate,
    auditTimestamp: new Date().toISOString(),
    totalArticlesInspected: files.length,
    articlesUpdated: totalHtmlsUpdated,
    totalCardsRendered: totalImagesRendered,
    averageCardsPerArticle: avgCards,
    distinctArchetypesUsed: distinctArchetypes,
    archetypeDistribution: archetypeCounts,
    cards: auditResults,
  };
  writeFileSync(auditReportPath, JSON.stringify(auditReportData, null, 2), "utf-8");

  console.log(`======================================================`);
  console.log(`🚀 지속 진화형 인포그래픽 렌더링 & 품질 감사 리포트`);
  console.log(`======================================================`);
  console.log(`   - 렌더링된 PNG 이미지 수: 총 ${totalImagesRendered}개 (글당 평균 ${avgCards}장)`);
  console.log(`   - 치환된 HTML 원고 수: ${totalHtmlsUpdated}건`);
  console.log(`   - 활성화된 시각 아키타입 다양성 지표: ${distinctArchetypes}개 유형 적용`);
  for (const [name, count] of Object.entries(archetypeCounts)) {
    console.log(`     • ${name.padEnd(16, " ")}: ${count}장`);
  }
  console.log(`   - 감사 리포트 저장: ${path.relative(process.cwd(), auditReportPath)}`);
  console.log(`   - 이미지 렌더링 해상도: 2x Retina (DPI 192 최적화)`);
  console.log(`======================================================\n`);
}

main().catch(err => {
  console.error("[FATAL ERROR]", err);
  process.exit(1);
});
