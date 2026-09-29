import os
import sys
import re

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

CATEGORY_COLORS = {
    "travel_": {
        "ACCENT": "#00796b",
        "DARK": "#004d40",
        "TINT": "#e0f2f1",
        "BORDER": "#b2dfdb",
        "SOFT": "#f9fdf9",
        "EVEN": "#f1faf9"
    },
    "recipe_": {
        "ACCENT": "#e64a19",
        "DARK": "#bf360c",
        "TINT": "#fbe9e7",
        "BORDER": "#ffccbc",
        "SOFT": "#fffaf8",
        "EVEN": "#fff5f2"
    },
    "default": {
        "ACCENT": "#388e3c",
        "DARK": "#1b5e20",
        "TINT": "#e8f5e9",
        "BORDER": "#c8e6c9",
        "SOFT": "#f9fdf9",
        "EVEN": "#f1faf1"
    }
}

STYLE_TEMPLATE = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>{TITLE}</title>
<style>
  body {{ margin: 0; padding: 16px; background: #fff; font-family: 'Apple SD Gothic Neo', sans-serif; font-size: 16px; line-height: 1.9; color: #222; max-width: 780px; margin: 0 auto; }}
  h1 {{ font-size: 1.6em; font-weight: 800; border-bottom: 5px solid {ACCENT}; padding-bottom: 12px; color: {DARK}; text-align: center; }}
  h2 {{ font-size: 1.2em; font-weight: 700; background: {TINT}; padding: 12px 15px; border-left: 6px solid {ACCENT}; margin-top: 50px; color: {DARK}; }}
  h3 {{ font-size: 1.05em; font-weight: 700; color: {DARK}; margin: 24px 0 8px; }}
  .intro-box {{ background: {SOFT}; border: 2px solid {BORDER}; padding: 25px; border-radius: 10px; margin: 30px 0; }}
  .info-table {{ width: 100%; margin: 20px 0; border-collapse: collapse; }}
  .info-table th {{ background: {ACCENT}; color: #fff; padding: 9px 12px; text-align: left; font-size: 0.9em; }}
  .info-table td {{ padding: 9px 12px; border-bottom: 1px solid #eee; font-size: 0.9em; }}
  .info-table tr:nth-child(even) td {{ background: {EVEN}; }}
  .img-area {{ margin: 30px 0; text-align: center; }}
  .img-placeholder {{ border: 2px dashed {BORDER}; border-radius: 8px; padding: 20px; background: {SOFT}; }}
  .ph-head {{ display: flex; justify-content: space-between; margin-bottom: 10px; font-weight: 700; color: {ACCENT}; font-size: 0.9em; }}
  .ph-file {{ font-size: 0.82em; color: #888; font-family: monospace; }}
  .prompt-text {{ font-size: 0.82em; color: #555; line-height: 1.6; text-align: left; white-space: pre-wrap; background: #fff; border: 1px solid #ddd; border-radius: 4px; padding: 10px; margin: 10px 0; }}
  .copy-btn {{ background: {ACCENT}; color: #fff; border: none; border-radius: 4px; padding: 6px 14px; font-size: 0.85em; cursor: pointer; }}
  .img-caption {{ font-size: 0.88em; color: #666; margin-top: 8px; font-style: italic; }}
  .info-box {{ background: {SOFT}; border: 1px solid {BORDER}; border-left: 4px solid {ACCENT}; padding: 15px 18px; margin: 20px 0; border-radius: 0 6px 6px 0; }}
  .step-box {{ background: #fff; border: 1px solid #eee; border-left: 4px solid {ACCENT}; padding: 15px 20px; margin: 15px 0; }}
  .tip-box {{ background: #fff8e1; border-left: 4px solid #ffc107; padding: 15px 18px; margin: 20px 0; border-radius: 0 6px 6px 0; }}
  .warn-box {{ background: #fff3e0; border-left: 4px solid #ff6b00; padding: 15px 18px; margin: 20px 0; border-radius: 0 6px 6px 0; }}
  .recommend-area {{ background: #f8f9fa; border: 1px solid #eee; padding: 20px; margin: 40px 0; border-radius: 10px; }}
  .tag {{ display: inline-block; background: #f0f0f0; padding: 3px 10px; border-radius: 5px; margin: 3px; font-size: 0.85em; color: #666; border: 1px solid #ddd; }}
</style>
<script>
function copyPrompt(id) {{
  const text = document.getElementById(id).innerText;
  navigator.clipboard.writeText(text).then(() => {{
    const btn = document.querySelector(`button[onclick="copyPrompt('${{id}}')"]`);
    const orig = btn.innerText;
    btn.innerText = '복사 완료!'; btn.style.background = '#27ae60';
    setTimeout(() => {{ btn.innerText = orig; btn.style.background = '{ACCENT}'; }}, 2000);
  }});
}}
</script>
</head>
<body>
"""

def repair_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    first_h1_match = re.search(r'<h1[^>]*>(.*?)</h1>', content, re.DOTALL | re.IGNORECASE)
    if not first_h1_match:
        return False
        
    title = re.sub(r'<[^>]+>', '', first_h1_match.group(1)).strip()
    prefix = content[:first_h1_match.start()]
    
    needs_repair = False
    if prefix.strip().startswith("<!--") and "-->" not in prefix:
        needs_repair = True
    elif "<!DOCTYPE" not in prefix.upper() or "<style>" not in prefix.lower():
        needs_repair = True
        
    if not needs_repair:
        return False

    hot_comment = ""
    hot_m = re.search(r'<!--\s*hot-dday:[^>]+-->', content)
    if hot_m and hot_m.start() < first_h1_match.start():
        hot_comment = hot_m.group(0) + "\n"

    body_content = content[first_h1_match.start():]
    body_content = re.sub(r'(?:</body>\s*)?(?:</html>\s*)?$', '', body_content.strip(), flags=re.IGNORECASE).strip()

    fname = os.path.basename(filepath)
    prefix_key = "default"
    for k in CATEGORY_COLORS:
        if fname.startswith(k):
            prefix_key = k
            break
    colors = CATEGORY_COLORS[prefix_key]

    header = STYLE_TEMPLATE.format(
        TITLE=title,
        ACCENT=colors["ACCENT"],
        DARK=colors["DARK"],
        TINT=colors["TINT"],
        BORDER=colors["BORDER"],
        SOFT=colors["SOFT"],
        EVEN=colors["EVEN"]
    )

    repaired_content = header + hot_comment + body_content + "\n</body>\n</html>\n"

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(repaired_content)

    print(f"[Repaired] {fname} (Title: {title[:30]}...)")
    return True

def main():
    import datetime
    target_date = sys.argv[1] if len(sys.argv) > 1 else datetime.datetime.now().strftime("%y%m%d")
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    out_dir = os.path.join(project_root, "output", target_date)
    
    if not os.path.exists(out_dir):
        print(f"[repair] Directory not found: {out_dir}")
        return

    print(f"=== Repairing HTML Headers for {target_date} ===")
    repaired_count = 0
    for f in sorted(os.listdir(out_dir)):
        if f.endswith(".html") and f != "index.html":
            fpath = os.path.join(out_dir, f)
            if repair_file(fpath):
                repaired_count += 1

    print(f"Header repair completed: {repaired_count} files repaired.\n")

if __name__ == "__main__":
    main()
