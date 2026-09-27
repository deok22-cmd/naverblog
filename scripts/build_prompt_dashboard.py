import os
import sys
import re
import json
import urllib.parse
from bs4 import BeautifulSoup

def get_all_dates(project_root):
    output_dir = os.path.join(project_root, "output")
    if not os.path.exists(output_dir):
        return []
    dirs = [d for d in os.listdir(output_dir) if os.path.isdir(os.path.join(output_dir, d)) and d.isdigit()]
    dirs.sort(reverse=True)
    return dirs

def get_latest_date(project_root):
    dates = get_all_dates(project_root)
    return dates[0] if dates else None

def parse_date_dir(project_root, date_str):
    day_dir = os.path.join(project_root, "output", date_str)
    if not os.path.exists(day_dir):
        return None
        
    index_path = os.path.join(day_dir, "index.html")
    ordered_files = []
    if os.path.exists(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as f_index:
                index_soup = BeautifulSoup(f_index.read(), "html.parser")
            for a in index_soup.find_all("a"):
                href = a.get("href", "")
                if href.endswith(".html") and href != "index.html":
                    filename = os.path.basename(href)
                    if filename not in ordered_files:
                        ordered_files.append(filename)
        except Exception:
            pass

    all_html_files = [f for f in os.listdir(day_dir) if f.endswith(".html") and f != "index.html"]
    
    if ordered_files:
        for f in all_html_files:
            if f not in ordered_files:
                ordered_files.append(f)
        html_files = [f for f in ordered_files if f in all_html_files]
    else:
        html_files = sorted(all_html_files)
        
    articles_data = []
    total_slots = 0
    completed_slots = 0
    pending_slots = 0
    
    # Load json fallback if present
    json_path = os.path.join(project_root, "scripts", f"placeholders_{date_str}.json")
    json_map = {}
    if os.path.exists(json_path):
        try:
            with open(json_path, "r", encoding="utf-8") as jf:
                jdata = json.load(jf)
                for item in jdata:
                    json_map[item.get("filename")] = item
        except Exception:
            pass

    for f in html_files:
        filepath = os.path.join(day_dir, f)
        with open(filepath, "r", encoding="utf-8") as file:
            content = file.read()
            
        soup = BeautifulSoup(content, "html.parser")
        h1_el = soup.find("h1")
        title = h1_el.get_text().strip() if h1_el else f
        
        img_areas = soup.find_all(class_="img-block") + soup.find_all(class_="img-area")
        slots_in_art = []
        seen_filenames = set()
        
        if img_areas:
            for area in img_areas:
                ph = area.find(class_="img-placeholder")
                img = area.find("img")
                caption_el = area.find(class_="img-caption")
                caption_text = caption_el.get_text().strip() if caption_el else ""
                
                ph_file = "Unknown"
                prompt = "Unknown"
                filename = "Unknown"

                if ph:
                    file_el = ph.find(class_="ph-file")
                    prompt_el = ph.find(class_="prompt-text")
                    if file_el:
                        ph_file = file_el.get_text().strip()
                        filename = os.path.basename(ph_file)
                    if prompt_el:
                        prompt = prompt_el.get_text().strip()
                
                if (filename == "Unknown" or ph_file == "Unknown") and img:
                    src = img.get("src", "")
                    if src:
                        filename = os.path.basename(src)
                        ph_file = f"images/{date_str}/{filename}"
                        if not caption_text and img.get("alt"):
                            caption_text = img.get("alt")
                
                if filename in json_map:
                    jitem = json_map[filename]
                    if ph_file == "Unknown":
                        ph_file = jitem.get("ph_file", ph_file)
                    if prompt == "Unknown":
                        prompt = jitem.get("prompt", prompt)
                    if not caption_text:
                        caption_text = jitem.get("caption", caption_text)

                if filename == "Unknown" or filename in seen_filenames:
                    continue
                seen_filenames.add(filename)
                
                abs_img_path = os.path.join(project_root, "images", date_str, filename)
                is_completed = os.path.exists(abs_img_path)
                if not is_completed:
                    stem, ext = os.path.splitext(filename)
                    base_stem = re.sub(r'_(pro|flash)$', '', stem, flags=re.IGNORECASE)
                    for cand in [f"{base_stem}_pro{ext}", f"{base_stem}_flash{ext}"]:
                        cand_path = os.path.join(project_root, "images", date_str, cand)
                        if os.path.exists(cand_path):
                            abs_img_path = cand_path
                            filename = cand
                            ph_file = f"images/{date_str}/{cand}"
                            is_completed = True
                            break
                
                if is_completed:
                    completed_slots += 1
                else:
                    pending_slots += 1
                total_slots += 1
                
                slots_in_art.append({
                    "ph_file": ph_file,
                    "filename": filename,
                    "prompt": prompt,
                    "caption": caption_text,
                    "abs_path": abs_img_path.replace("/", "\\"),
                    "encoded_prompt": urllib.parse.quote(prompt),
                    "is_completed": is_completed
                })
        else:
            ph_divs = soup.find_all(class_="img-placeholder")
            for ph in ph_divs:
                file_el = ph.find(class_="ph-file")
                prompt_el = ph.find(class_="prompt-text")
                parent_area = ph.find_parent(class_="img-block") or ph.find_parent(class_="img-area")
                caption_text = ""
                if parent_area:
                    caption_el = parent_area.find(class_="img-caption")
                    if caption_el:
                        caption_text = caption_el.get_text().strip()
                
                ph_file = file_el.get_text().strip() if file_el else "Unknown"
                prompt = prompt_el.get_text().strip() if prompt_el else "Unknown"
                filename = os.path.basename(ph_file)
                if filename in seen_filenames:
                    continue
                seen_filenames.add(filename)

                abs_img_path = os.path.join(project_root, "images", date_str, filename)
                is_completed = os.path.exists(abs_img_path)
                if not is_completed:
                    stem, ext = os.path.splitext(filename)
                    base_stem = re.sub(r'_(pro|flash)$', '', stem, flags=re.IGNORECASE)
                    for cand in [f"{base_stem}_pro{ext}", f"{base_stem}_flash{ext}"]:
                        cand_path = os.path.join(project_root, "images", date_str, cand)
                        if os.path.exists(cand_path):
                            abs_img_path = cand_path
                            filename = cand
                            ph_file = f"images/{date_str}/{cand}"
                            is_completed = True
                            break
                
                if is_completed:
                    completed_slots += 1
                else:
                    pending_slots += 1
                total_slots += 1
                
                slots_in_art.append({
                    "ph_file": ph_file,
                    "filename": filename,
                    "prompt": prompt,
                    "caption": caption_text,
                    "abs_path": abs_img_path.replace("/", "\\"),
                    "encoded_prompt": urllib.parse.quote(prompt),
                    "is_completed": is_completed
                })
                
        if slots_in_art:
            articles_data.append({
                "filename": f,
                "title": title,
                "placeholders": slots_in_art
            })
            
    return {
        "date": date_str,
        "total_slots": total_slots,
        "completed_slots": completed_slots,
        "pending_slots": pending_slots,
        "articles": articles_data
    }

def build_dashboard(target_date=None):
    project_root = r"d:\lightsail\naverblog"
    all_dates = get_all_dates(project_root)
    
    if not all_dates:
        print("Error: No date directories found in output/.")
        return
        
    if not target_date or target_date not in all_dates:
        target_date = all_dates[0]
        
    all_dates_data = {}
    for d in all_dates:
        parsed = parse_date_dir(project_root, d)
        if parsed:
            all_dates_data[d] = parsed
            
    all_dates_json = json.dumps(all_dates_data, ensure_ascii=False)
    
    html_template = f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AI 이미지 통합 제작 헬퍼 대시보드</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=Outfit:wght@400;600;800&family=Noto+Sans+KR:wght@300;400;500;700&display=swap" rel="stylesheet">
<style>
  :root {{
    --bg-primary: #0b0d10;
    --bg-secondary: #13161c;
    --bg-tertiary: #1a1e27;
    --accent-teal: #00bfa5;
    --accent-teal-hover: #009688;
    --accent-blue: #00d2ff;
    --accent-purple: #a855f7;
    --text-primary: #f3f4f6;
    --text-secondary: #9ca3af;
    --border-color: #262c36;
    --status-pending: #ffab00;
    --status-success: #00e676;
    --accent-chatgpt: #10a37f;
  }}

  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    font-family: 'Inter', 'Noto Sans KR', sans-serif;
    background-color: var(--bg-primary);
    color: var(--text-primary);
    line-height: 1.6;
    padding: 30px 20px;
  }}
  .container {{
    max-width: 1080px;
    margin: 0 auto;
  }}

  header {{
    margin-bottom: 24px;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 20px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 16px;
  }}
  .header-title h1 {{
    font-family: 'Outfit', sans-serif;
    font-size: 2.1rem;
    font-weight: 800;
    background: linear-gradient(135deg, var(--accent-blue), var(--accent-teal));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }}
  .header-subtitle {{
    color: var(--text-secondary);
    font-size: 0.88rem;
    margin-top: 4px;
  }}

  /* Date selector bar */
  .date-control-card {{
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: 14px;
    padding: 16px 20px;
    margin-bottom: 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 14px;
  }}
  .date-selector-group {{
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
  }}
  .date-selector-label {{
    font-weight: 700;
    font-size: 0.95rem;
    color: var(--accent-teal);
    display: flex;
    align-items: center;
    gap: 6px;
  }}
  .date-select-dropdown {{
    background-color: var(--bg-tertiary);
    border: 1px solid #3b4556;
    color: #fff;
    padding: 8px 14px;
    border-radius: 8px;
    font-size: 0.9rem;
    font-weight: 600;
    font-family: 'Outfit', sans-serif;
    cursor: pointer;
    outline: none;
    transition: border-color 0.2s;
  }}
  .date-select-dropdown:hover, .date-select-dropdown:focus {{
    border-color: var(--accent-teal);
  }}

  .date-pills {{
    display: flex;
    gap: 6px;
    overflow-x: auto;
    max-width: 100%;
    padding-bottom: 4px;
  }}
  .date-pill {{
    background-color: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    padding: 6px 12px;
    border-radius: 20px;
    font-size: 0.8rem;
    font-weight: 600;
    font-family: 'Outfit', sans-serif;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.15s;
  }}
  .date-pill:hover {{
    border-color: var(--accent-teal);
    color: #fff;
  }}
  .date-pill.active {{
    background: rgba(0, 191, 165, 0.2);
    border-color: var(--accent-teal);
    color: var(--accent-teal);
  }}

  /* Stats Bar */
  .stats-bar {{
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
    margin-bottom: 24px;
  }}
  .stat-card {{
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 18px 20px;
    text-align: center;
    position: relative;
    overflow: hidden;
  }}
  .stat-card::before {{
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0; height: 3px;
  }}
  .stat-card.total::before {{ background: linear-gradient(90deg, var(--accent-blue), var(--accent-teal)); }}
  .stat-card.completed::before {{ background: var(--status-success); }}
  .stat-card.pending::before {{ background: var(--status-pending); }}

  .stat-label {{
    color: var(--text-secondary);
    font-size: 0.8rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 4px;
  }}
  .stat-value {{
    font-size: 2.2rem;
    font-weight: 800;
    color: var(--accent-blue);
    font-family: 'Outfit', sans-serif;
  }}
  .stat-value.completed {{ color: var(--status-success); }}
  .stat-value.pending {{ color: var(--status-pending); }}

  /* Filter bar */
  .filter-bar {{
    display: flex;
    gap: 10px;
    margin-bottom: 24px;
    flex-wrap: wrap;
  }}
  .filter-btn {{
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    padding: 8px 18px;
    border-radius: 8px;
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }}
  .filter-btn:hover {{
    border-color: #4b5563;
    color: #fff;
  }}
  .filter-btn.active {{
    background-color: var(--bg-tertiary);
    border-color: var(--accent-teal);
    color: var(--accent-teal);
  }}

  /* Workflow guide */
  .instruction-section {{
    background-color: #171821;
    border: 1px solid #2d2f42;
    border-radius: 12px;
    padding: 18px 22px;
    margin-bottom: 24px;
  }}
  .instruction-title {{
    font-size: 0.95rem;
    font-weight: 700;
    color: #e9d5ff;
    margin-bottom: 8px;
    display: flex;
    align-items: center;
    gap: 8px;
  }}
  .instruction-list {{
    font-size: 0.84rem;
    color: #c084fc;
    padding-left: 18px;
    line-height: 1.55;
  }}
  .instruction-list li {{ margin-bottom: 4px; }}
  .code-block {{
    background: #090a0f;
    padding: 10px 14px;
    border-radius: 6px;
    font-family: monospace;
    font-size: 0.85rem;
    color: #a78bfa;
    margin-top: 10px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }}

  /* Batch Actions */
  .batch-actions {{
    margin-bottom: 30px;
    background: rgba(0, 210, 255, 0.04);
    padding: 16px 20px;
    border-radius: 12px;
    border: 1px solid rgba(0, 210, 255, 0.15);
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 12px;
  }}
  .batch-label {{
    font-weight: 700;
    color: var(--accent-blue);
    font-size: 0.9rem;
  }}

  /* Articles and Cards */
  .article-section {{
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: 14px;
    padding: 22px;
    margin-bottom: 24px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.15);
  }}
  .article-header {{
    margin-bottom: 16px;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 12px;
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
  }}
  .article-title {{
    font-size: 1.15rem;
    font-weight: 700;
    color: #fff;
  }}
  .article-meta {{
    font-size: 0.78rem;
    color: var(--text-secondary);
    margin-top: 2px;
    font-family: monospace;
  }}
  
  .placeholder-card {{
    background-color: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: 10px;
    padding: 18px;
    margin-bottom: 16px;
    display: flex;
    gap: 18px;
    transition: border-color 0.2s;
  }}
  .placeholder-card:last-child {{
    margin-bottom: 0;
  }}
  .placeholder-card:hover {{
    border-color: #3b4556;
  }}
  .placeholder-card.completed-card {{
    background-color: rgba(26, 30, 39, 0.6);
  }}
  
  .preview-box {{
    width: 140px;
    height: 140px;
    border-radius: 8px;
    background-color: var(--bg-primary);
    border: 2px dashed var(--border-color);
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    overflow: hidden;
    flex-shrink: 0;
  }}
  .preview-box img {{
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: none;
  }}
  .preview-box.loaded {{
    border-style: solid;
    border-color: var(--status-success);
  }}
  .preview-box.loaded img {{
    display: block;
  }}
  .preview-box .status-icon {{
    font-size: 1.8rem;
    color: var(--text-secondary);
  }}
  .preview-box.loaded .status-icon {{
    display: none;
  }}

  .info-box {{
    flex-grow: 1;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
  }}
  .ph-meta {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 6px;
  }}
  .ph-name {{
    font-weight: 700;
    font-size: 0.9rem;
    color: var(--accent-blue);
    font-family: monospace;
  }}
  .ph-badge {{
    font-size: 0.72rem;
    font-weight: 700;
    padding: 3px 8px;
    border-radius: 4px;
    background-color: rgba(255, 171, 0, 0.15);
    color: var(--status-pending);
    border: 1px solid var(--status-pending);
  }}
  .ph-badge.loaded {{
    background-color: rgba(0, 230, 118, 0.15);
    color: var(--status-success);
    border: 1px solid var(--status-success);
  }}
  
  .caption-text {{
    font-size: 0.83rem;
    color: var(--text-primary);
    margin-bottom: 8px;
    font-style: italic;
  }}
  
  .prompt-box {{
    background-color: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: 6px;
    padding: 8px 12px;
    font-size: 0.78rem;
    color: #cbd5e1;
    font-family: monospace;
    max-height: 75px;
    overflow-y: auto;
    white-space: pre-wrap;
    margin-bottom: 12px;
  }}

  .btn-group {{
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }}
  .btn {{
    background-color: var(--bg-primary);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    padding: 6px 14px;
    border-radius: 6px;
    font-size: 0.8rem;
    cursor: pointer;
    font-weight: 500;
    display: inline-flex;
    align-items: center;
    gap: 5px;
    transition: all 0.15s;
    text-decoration: none;
  }}
  .btn:hover {{
    background-color: var(--bg-secondary);
    border-color: #4b5563;
  }}
  .btn.btn-accent {{
    background-color: var(--accent-teal);
    border-color: var(--accent-teal);
    color: #000;
    font-weight: 700;
  }}
  .btn.btn-accent:hover {{
    background-color: var(--accent-teal-hover);
    border-color: var(--accent-teal-hover);
  }}
  .btn.btn-gemini {{
    background: linear-gradient(135deg, #1a73e8, #8e24aa);
    border: 1px solid #1a73e8;
    color: #fff;
    font-weight: 600;
  }}
  .btn.btn-gemini:hover {{
    background: linear-gradient(135deg, #1557b0, #7b1fa2);
    border-color: #1557b0;
  }}
  .btn.btn-chatgpt {{
    background-color: var(--accent-chatgpt);
    border-color: var(--accent-chatgpt);
    color: #fff;
    font-weight: 600;
  }}
  .btn.btn-chatgpt:hover {{
    background-color: #0d8a6b;
    border-color: #0d8a6b;
  }}

  .empty-state {{
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 40px 20px;
    text-align: center;
    color: var(--text-secondary);
  }}
</style>
</head>
<body>
<div class="container">
  <header>
    <div class="header-title">
      <h1>AI 이미지 통합 제작 헬퍼</h1>
      <div class="header-subtitle">블로그 원고에 수반되는 모든 AI 이미지 제작 및 자동 매칭 현황을 관제합니다.</div>
    </div>
  </header>

  <!-- Date Selection Controls -->
  <div class="date-control-card">
    <div class="date-selector-group">
      <span class="date-selector-label">📅 일자 선택:</span>
      <select id="date-select" class="date-select-dropdown" onchange="switchDate(this.value)"></select>
    </div>
    <div class="date-pills" id="date-pills-container"></div>
  </div>

  <!-- Filter Buttons -->
  <div class="filter-bar">
    <button class="filter-btn active" id="filter-all" onclick="setFilter('all')">
      🌐 전체 이미지 (<span id="filter-all-cnt">0</span>)
    </button>
    <button class="filter-btn" id="filter-pending" onclick="setFilter('pending')">
      ⏳ 대기 중만 보기 (<span id="filter-pending-cnt">0</span>)
    </button>
    <button class="filter-btn" id="filter-completed" onclick="setFilter('completed')">
      ✅ 등록 완료만 보기 (<span id="filter-completed-cnt">0</span>)
    </button>
  </div>

  <!-- Stats Bar -->
  <div class="stats-bar">
    <div class="stat-card total">
      <div class="stat-label">필요한 전체 이미지</div>
      <div class="stat-value" id="stat-total">0</div>
    </div>
    <div class="stat-card completed">
      <div class="stat-label">제작 / 등록 완료</div>
      <div class="stat-value completed" id="stat-completed">0</div>
    </div>
    <div class="stat-card pending">
      <div class="stat-label">대기 중 (미제작)</div>
      <div class="stat-value pending" id="stat-pending">0</div>
    </div>
  </div>

  <!-- Instruction Section -->
  <div class="instruction-section">
    <div class="instruction-title">💡 초고속 이미지 저장 꿀팁 워크플로우</div>
    <ul class="instruction-list">
      <li>1. 아래 카드의 <strong>[📋 프롬프트 복사]</strong> 또는 <strong>[♊ Gemini 열기]</strong>를 통해 브라우저 탭을 엽니다. (Gemini 열기 클릭 시 프롬프트 자동 복사됨)</li>
      <li>2. 이미지 생성 후, 아래 카드의 <strong>[💾 저장 경로 복사]</strong> 버튼을 클릭합니다.</li>
      <li>3. 다운로드 시 Windows '다른 이름으로 저장' 창의 파일 이름 칸에 경로를 <strong>붙여넣기(Ctrl+V) 후 엔터</strong>를 누릅니다.</li>
      <li>4. 이미지가 저장되어 <strong>[등록 완료]</strong>가 되면, 아래 매칭 명령어를 복사하여 터미널에서 실행해 원고에 자동 삽입합니다.</li>
    </ul>
    <div class="code-block">
      <span id="cmd-text">python scripts/move_and_replace_images.py</span>
      <button class="btn" style="padding: 4px 10px; font-size: 0.75rem;" onclick="copyCmd()">명령어 복사</button>
    </div>
  </div>

  <!-- Batch Actions -->
  <div class="batch-actions">
    <span class="batch-label">⚡ 한꺼번에 탭 열기:</span>
    <button class="btn btn-gemini" onclick="openAllTabs('gemini')">♊ 남은 대기 이미지 Gemini 탭 일괄 열기</button>
    <button class="btn btn-chatgpt" onclick="openAllTabs('chatgpt')">🤖 ChatGPT 탭 일괄 열기</button>
  </div>

  <!-- Articles Container -->
  <div id="articles-container"></div>
</div>

<script>
  const ALL_DATES_DATA = {all_dates_json};
  let CURRENT_DATE = "{target_date}";
  let CURRENT_FILTER = "all";
  let completedImages = new Set();

  function initApp() {{
    const dateSelect = document.getElementById('date-select');
    const pillsContainer = document.getElementById('date-pills-container');
    
    dateSelect.innerHTML = '';
    pillsContainer.innerHTML = '';
    
    const dates = Object.keys(ALL_DATES_DATA).sort((a, b) => b.localeCompare(a));
    dates.forEach(d => {{
      const dData = ALL_DATES_DATA[d];
      const opt = document.createElement('option');
      opt.value = d;
      opt.innerText = `📅 20${{d.slice(0,2)}}-${{d.slice(2,4)}}-${{d.slice(4,6)}} (${{d}}) — 전체 ${{dData.total_slots}}개 (완료 ${{dData.completed_slots}} / 대기 ${{dData.pending_slots}})`;
      if (d === CURRENT_DATE) opt.selected = true;
      dateSelect.appendChild(opt);
      
      const pill = document.createElement('button');
      pill.className = `date-pill ${{d === CURRENT_DATE ? 'active' : ''}}`;
      pill.innerText = d;
      pill.onclick = () => switchDate(d);
      pillsContainer.appendChild(pill);
    }});
    
    renderDashboard();
  }}

  function switchDate(newDate) {{
    if (!ALL_DATES_DATA[newDate]) return;
    CURRENT_DATE = newDate;
    document.getElementById('date-select').value = newDate;
    
    const pills = document.querySelectorAll('.date-pill');
    pills.forEach(p => {{
      if (p.innerText === newDate) p.classList.add('active');
      else p.classList.remove('active');
    }});
    
    completedImages.clear();
    renderDashboard();
  }}

  function setFilter(filterType) {{
    CURRENT_FILTER = filterType;
    document.querySelectorAll('.filter-btn').forEach(btn => btn.classList.remove('active'));
    document.getElementById(`filter-${{filterType}}`).classList.add('active');
    renderDashboard();
  }}

  function renderDashboard() {{
    const data = ALL_DATES_DATA[CURRENT_DATE];
    if (!data) return;
    
    document.getElementById('cmd-text').innerText = `python scripts/move_and_replace_images.py ${{CURRENT_DATE}}`;
    
    document.getElementById('stat-total').innerText = data.total_slots;
    document.getElementById('filter-all-cnt').innerText = data.total_slots;
    document.getElementById('filter-pending-cnt').innerText = data.pending_slots;
    document.getElementById('filter-completed-cnt').innerText = data.completed_slots;
    
    const container = document.getElementById('articles-container');
    container.innerHTML = '';
    
    let displayedArticleCount = 0;
    
    data.articles.forEach(art => {{
      let placeholdersToDisplay = art.placeholders.filter(ph => {{
        if (CURRENT_FILTER === 'pending') return !ph.is_completed;
        if (CURRENT_FILTER === 'completed') return ph.is_completed;
        return true;
      }});
      
      if (placeholdersToDisplay.length === 0) return;
      displayedArticleCount++;
      
      const artSection = document.createElement('div');
      artSection.className = 'article-section';
      
      let artHtml = `
        <div class="article-header">
          <div>
            <div class="article-title">${{art.title}}</div>
            <div class="article-meta">원고 파일: ${{art.filename}}</div>
          </div>
          <span style="font-size:0.8rem; color: var(--text-secondary); background: var(--bg-tertiary); padding: 3px 8px; border-radius:4px;">
            ${{placeholdersToDisplay.length}}개 이미지
          </span>
        </div>
      `;
      
      placeholdersToDisplay.forEach(ph => {{
        const phId = `prompt_${{ph.filename.replace('.', '_')}}`;
        const initialStatusClass = ph.is_completed ? 'loaded' : '';
        const initialBadgeText = ph.is_completed ? '등록 완료' : '대기 중';
        const cardExtraClass = ph.is_completed ? 'completed-card' : '';
        
        artHtml += `
          <div class="placeholder-card ${{cardExtraClass}}" data-filename="${{ph.filename}}" data-completed="${{ph.is_completed}}">
            <div class="preview-box ${{initialStatusClass}}" id="preview-${{phId}}">
              <span class="status-icon">📷</span>
              <img src="images/${{CURRENT_DATE}}/${{ph.filename}}" data-original-src="images/${{CURRENT_DATE}}/${{ph.filename}}" alt="Preview" onload="imageLoaded('${{phId}}')" onerror="imageFailed('${{phId}}', ${{ph.is_completed}})">
            </div>
            <div class="info-box">
              <div>
                <div class="ph-meta">
                  <span class="ph-name">${{ph.filename}}</span>
                  <span class="ph-badge ${{initialStatusClass}}" id="badge-${{phId}}">${{initialBadgeText}}</span>
                </div>
                <div class="caption-text">설명: ${{ph.caption || '(설명 없음)'}}</div>
                <div class="prompt-box" id="${{phId}}">${{ph.prompt}}</div>
              </div>
              <div class="btn-group">
                <button class="btn btn-accent" onclick="copyText('${{phId}}', this)">📋 프롬프트 복사</button>
                <button class="btn" onclick="copyPath('${{ph.abs_path.replace(/\\\\/g, '\\\\\\\\')}}', this)">💾 저장 경로 복사</button>
                <button class="btn btn-gemini" onclick="openGemini('${{phId}}')">♊ Gemini 열기</button>
              </div>
            </div>
          </div>
        `;
      }});
      
      artSection.innerHTML = artHtml;
      container.appendChild(artSection);
    }});
    
    if (displayedArticleCount === 0) {{
      container.innerHTML = `
        <div class="empty-state">
          <h3>📌 해당 조건의 이미지가 없습니다.</h3>
          <p style="margin-top:8px; font-size:0.88rem;">선택한 필터 (${{CURRENT_FILTER}}) 조건에 부합하는 원고 항목이 존재하지 않습니다.</p>
        </div>
      `;
    }}
    
    updateLiveStats();
  }}

  function updateLiveStats() {{
    const data = ALL_DATES_DATA[CURRENT_DATE];
    if (!data) return;
    
    let compCount = 0;
    data.articles.forEach(art => {{
      art.placeholders.forEach(ph => {{
        const phId = `prompt_${{ph.filename.replace('.', '_')}}`;
        if (ph.is_completed || completedImages.has(phId)) {{
          compCount++;
        }}
      }});
    }});
    
    const pendCount = Math.max(0, data.total_slots - compCount);
    document.getElementById('stat-completed').innerText = compCount;
    document.getElementById('stat-pending').innerText = pendCount;
  }}

  function imageLoaded(phId) {{
    completedImages.add(phId);
    
    const preview = document.getElementById('preview-' + phId);
    if (preview) preview.classList.add('loaded');
    
    const badge = document.getElementById('badge-' + phId);
    if (badge) {{
      badge.innerText = "등록 완료";
      badge.classList.add('loaded');
    }}
    
    updateLiveStats();
  }}

  function imageFailed(phId, originallyCompleted) {{
    if (!originallyCompleted) {{
      completedImages.delete(phId);
      const preview = document.getElementById('preview-' + phId);
      if (preview) preview.classList.remove('loaded');
      
      const badge = document.getElementById('badge-' + phId);
      if (badge) {{
        badge.innerText = "대기 중";
        badge.classList.remove('loaded');
      }}
      updateLiveStats();
    }}
  }}

  setInterval(() => {{
    const cards = document.querySelectorAll('.placeholder-card');
    cards.forEach(card => {{
      const phId = 'prompt_' + card.getAttribute('data-filename').replace('.', '_');
      if (!completedImages.has(phId)) {{
        const img = card.querySelector('.preview-box img');
        if (img) {{
          const originalSrc = img.getAttribute('data-original-src') || img.src.split('?')[0];
          img.src = originalSrc + '?t=' + Date.now();
        }}
      }}
    }});
  }}, 2500);

  function openAllTabs(service) {{
    const data = ALL_DATES_DATA[CURRENT_DATE];
    if (!data) return;
    
    let pendingPhs = [];
    data.articles.forEach(art => {{
      art.placeholders.forEach(ph => {{
        const phId = `prompt_${{ph.filename.replace('.', '_')}}`;
        if (!ph.is_completed && !completedImages.has(phId)) {{
          pendingPhs.push(ph);
        }}
      }});
    }});
    
    if (pendingPhs.length === 0) {{
      alert("현재 날짜에 대기 중인 이미지가 없습니다!");
      return;
    }}
    
    if (!confirm(`남은 ${{pendingPhs.length}}개의 대기 이미지를 위해 탭을 일괄 여시겠습니까?`)) return;
    
    pendingPhs.forEach((ph, index) => {{
      let url = '';
      if (service === 'chatgpt') {{
        url = 'https://chatgpt.com/?q=' + ph.encoded_prompt;
      }} else {{
        url = 'https://gemini.google.com/app';
      }}
      setTimeout(() => {{
        window.open(url, '_blank');
      }}, index * 250);
    }});
  }}

  function openGemini(phId) {{
    const el = document.getElementById(phId);
    if (!el) return;
    const text = el.innerText;
    navigator.clipboard.writeText(text).then(() => {{
      window.open('https://gemini.google.com/app', '_blank');
    }});
  }}

  function copyText(id, btn) {{
    const el = document.getElementById(id);
    if (!el) return;
    const text = el.innerText;
    navigator.clipboard.writeText(text).then(() => {{
      const originalText = btn.innerText;
      btn.innerText = "✔ 프롬프트 복사 완료!";
      btn.style.background = "#059669";
      btn.style.color = "#fff";
      setTimeout(() => {{
        btn.innerText = originalText;
        btn.style.background = "";
        btn.style.color = "";
      }}, 1500);
    }});
  }}

  function copyPath(pathStr, btn) {{
    navigator.clipboard.writeText(pathStr).then(() => {{
      const originalText = btn.innerText;
      btn.innerText = "✔ 경로 복사 완료!";
      btn.style.background = "#2563eb";
      btn.style.color = "#fff";
      setTimeout(() => {{
        btn.innerText = originalText;
        btn.style.background = "";
        btn.style.color = "";
      }}, 1500);
    }});
  }}

  function copyCmd() {{
    const text = document.getElementById('cmd-text').innerText;
    navigator.clipboard.writeText(text).then(() => {{
      alert("명령어가 복사되었습니다. 터미널에 붙여넣어 실행하세요.");
    }});
  }}

  window.onload = initApp;
</script>
</body>
</html>
"""

    output_html_path = os.path.join(project_root, "prompt_helper.html")
    with open(output_html_path, "w", encoding="utf-8") as f:
        f.write(html_template)
    print(f"Successfully generated multi-date helper dashboard at: {output_html_path}")

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else None
    build_dashboard(target)
