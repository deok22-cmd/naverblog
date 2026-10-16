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

function findBalancedDivRange(html, className) {
  const marker = `<div class="${className}"`;
  const startIdx = html.indexOf(marker);
  if (startIdx === -1) return null;
  let depth = 0;
  let i = startIdx;
  let endIdx = -1;
  while (i < html.length) {
    if (html.startsWith("<div", i) && (html[i + 4] === " " || html[i + 4] === ">")) {
      depth++;
      i += 4;
    } else if (html.startsWith("</div>", i)) {
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
    return { startIdx, endIdx, content: html.substring(startIdx, endIdx) };
  }
  return null;
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
  const targetDate = process.argv[2] || getTodayYYMMDD();
  console.log(`\n======================================================`);
  console.log(`🖼️ 인포그래픽 카드 자동 렌더링 & 원고 치환 (날짜: ${targetDate})`);
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

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1000, height: 1400, deviceScaleFactor: 2 });

    for (let idx = 0; idx < files.length; idx++) {
      const file = files[idx];
      const seq = idx + 1;
      const slug = file.replace(/\.html$/, "");
      const filePath = path.join(outputDir, file);
      let html = readFileSync(filePath, "utf-8");

      console.log(`[${seq}/${files.length}] 처리 중: ${file}`);

      const fileUrl = "file:///" + filePath.replace(/\\/g, "/");
      let pageLoaded = false;

      // 1. 코스 인포그래픽 카드 (Image 2)
      const courseRange = findBalancedDivRange(html, "infographic-course-box");
      const img2FileName = `${seq}_${slug}_2.png`;
      const img2Path = path.join(imagesDir, img2FileName);

      if (courseRange) {
        if (!pageLoaded) {
          await page.goto(fileUrl, { waitUntil: "networkidle0" });
          await page.addStyleTag({
            content: `
              body, button, input, select, textarea {
                font-family: -apple-system, BlinkMacSystemFont, "Malgun Gothic", "맑은 고딕", "Noto Sans KR", sans-serif !important;
                -webkit-font-smoothing: antialiased;
              }
            `
          });
          pageLoaded = true;
        }

        const cBox = await page.$(".infographic-course-box");
        let captionText = "추천 코스 안내";
        if (cBox) {
          await cBox.screenshot({ path: img2Path });
          totalImagesRendered++;
          console.log(`   ✅ 2번 PNG 저장 완료: images/${targetDate}/${img2FileName}`);

          const headerEl = await cBox.$(".infographic-header");
          if (headerEl) {
            const rawHeader = await page.evaluate(el => el.textContent, headerEl);
            if (rawHeader && rawHeader.trim()) {
              captionText = rawHeader.replace(/\s+/g, " ").trim();
            }
          }
        }

        const replacementHtml = `\n<!-- 2번째 이미지: 자동 렌더링 인포그래픽 카드 -->\n<div class="img-area">\n<img alt="${captionText} / 인포그래픽 카드" src="../../images/${targetDate}/${img2FileName}" style="width:100%; border-radius:8px; display:block; margin:0 auto;"/>\n<div class="img-caption">${captionText} / 인포그래픽 카드</div>\n</div>\n`;

        html = html.substring(0, courseRange.startIdx) + replacementHtml + html.substring(courseRange.endIdx);
      } else {
        if (existsSync(img2Path)) {
          console.log(`   ℹ️ 2번 이미지가 이미 존재하며 원고에 반영되어 있습니다.`);
        }
      }

      // 2. 핵심 지표/매트릭스 카드 (Image 3)
      const statRange = findBalancedDivRange(html, "infographic-stat-box");
      const img3FileName = `${seq}_${slug}_3.png`;
      const img3Path = path.join(imagesDir, img3FileName);

      if (statRange) {
        if (!pageLoaded) {
          await page.goto(fileUrl, { waitUntil: "networkidle0" });
          await page.addStyleTag({
            content: `
              body, button, input, select, textarea {
                font-family: -apple-system, BlinkMacSystemFont, "Malgun Gothic", "맑은 고딕", "Noto Sans KR", sans-serif !important;
                -webkit-font-smoothing: antialiased;
              }
            `
          });
          pageLoaded = true;
        }

        const sBox = await page.$(".infographic-stat-box");
        let captionText = "핵심 지표 요약";
        if (sBox) {
          await sBox.screenshot({ path: img3Path });
          totalImagesRendered++;
          console.log(`   ✅ 3번 PNG 저장 완료: images/${targetDate}/${img3FileName}`);

          const firstDiv = await sBox.$("div");
          if (firstDiv) {
            const rawStatTitle = await page.evaluate(el => el.textContent, firstDiv);
            if (rawStatTitle && rawStatTitle.trim()) {
              captionText = rawStatTitle.replace(/\s+/g, " ").trim();
            }
          }
        }

        const replacementHtml = `\n<!-- 3번째 이미지: 자동 렌더링 핵심 지표 카드 -->\n<div class="img-area">\n<img alt="${captionText} / 데이터 요약 카드" src="../../images/${targetDate}/${img3FileName}" style="width:100%; border-radius:8px; display:block; margin:0 auto;"/>\n<div class="img-caption">${captionText} / 데이터 요약 카드</div>\n</div>\n`;

        html = html.substring(0, statRange.startIdx) + replacementHtml + html.substring(statRange.endIdx);
      } else {
        if (existsSync(img3Path)) {
          console.log(`   ℹ️ 3번 이미지가 이미 존재하며 원고에 반영되어 있습니다.`);
        }
      }

      if (courseRange || statRange) {
        writeFileSync(filePath, html, "utf-8");
        totalHtmlsUpdated++;
        console.log(`   📝 HTML 원고 치환 완료: ${file}\n`);
      }
    }
  } finally {
    await browser.close();
  }

  console.log(`======================================================`);
  console.log(`🎉 렌더링 완료 요약`);
  console.log(`   - 렌더링된 PNG 이미지 수: ${totalImagesRendered}개`);
  console.log(`   - 치환된 HTML 원고 수: ${totalHtmlsUpdated}건`);
  console.log(`======================================================\n`);
}

main().catch(err => {
  console.error("[FATAL ERROR]", err);
  process.exit(1);
});
