import os
import re
import sys
from datetime import datetime
from bs4 import BeautifulSoup

def fix_tistory_violations(day_str=None):
    project_root = r"d:\lightsail\naverblog"
    if not day_str:
        day_str = datetime.now().strftime("%y%m%d")
    tistory_dir = os.path.join(project_root, "output_tistory", day_str)
    naver_dir = os.path.join(project_root, "output", day_str)
    
    if not os.path.exists(tistory_dir):
        print(f"Error: Directory {tistory_dir} does not exist.")
        return
        
    html_files = [f for f in os.listdir(tistory_dir) if f.endswith(".html") and f != "index.html"]
    
    for f in html_files:
        filepath = os.path.join(tistory_dir, f)
        with open(filepath, "r", encoding="utf-8") as file:
            content = file.read()
            
        soup = BeautifulSoup(content, "html.parser")
        modified = False
        
        # 1. Fix H1 styling
        h1 = soup.find("h1")
        if h1:
            style_str = h1.get("style", "")
            if not re.search(r'font-weight:\s*800;\s*border-bottom:\s*5px\s+solid', style_str):
                border_match = re.search(r"border-bottom:\s*[0-9a-zA-Z\s#]+", style_str)
                color_match = re.search(r"color:\s*#[0-9a-fA-F]{6}", style_str)
                font_size_match = re.search(r"font-size:\s*[0-9.]+(?:em|px)", style_str)
                
                theme_color = "#1565c0"
                if border_match:
                    color_hex = re.search(r"#[0-9a-fA-F]{3,6}", border_match.group(0))
                    if color_hex:
                        theme_color = color_hex.group(0)
                elif color_match:
                    theme_color = color_match.group(0).split(":")[-1].strip()
                
                border_val = f"border-bottom: 5px solid {theme_color}"
                color_val = color_match.group(0) if color_match else f"color: {theme_color}"
                font_size_val = font_size_match.group(0) if font_size_match else "font-size: 1.6em"
                
                new_style = f"{font_size_val}; font-weight: 800; {border_val}; padding-bottom: 12px; {color_val}; text-align: center;"
                h1["style"] = new_style
                modified = True
                print(f"[{f}] Standardized/Repaired H1 style")
                    
        # 2. Fix F1 Wrapper
        content_str = str(soup)
        if not re.search(r'max-width:\s*780px;\s*margin:\s*0\s+auto;\s*padding:\s*16px;', content_str):
            body = soup.body
            if body:
                body.attrs.pop("style", None)
                wrapper = soup.new_tag("div", style="font-family:'Apple SD Gothic Neo',sans-serif;font-size:16px;line-height:1.9;color:#222;max-width:780px;margin:0 auto;padding:16px;")
                for child in list(body.children):
                    wrapper.append(child)
                body.append(wrapper)
                modified = True
                print(f"[{f}] Wrapped body content in a standard wrapper div")
                content_str = str(soup)

        # 3. Extract and convert recommendation box and tags from Naver file
        naver_filepath = os.path.join(naver_dir, f)
        if os.path.exists(naver_filepath):
            with open(naver_filepath, "r", encoding="utf-8") as nf:
                naver_soup = BeautifulSoup(nf.read(), "html.parser")
            
            # Find theme color from Tistory H1 style or fallback
            h1 = soup.find("h1")
            theme_color = "#00796b"
            if h1 and h1.get("style"):
                border_match = re.search(r"border-bottom:\s*5px\s+solid\s*(#[0-9a-fA-F]{3,6})", h1["style"])
                if border_match:
                    theme_color = border_match.group(1)
            
            # Check if Tistory already has recommendation box
            rec_box_pattern = r"(같이|함께)[^<]{0,15}(볼만|보면|읽으면|읽어)[^<]{0,10}글"
            has_rec = re.search(rec_box_pattern, content_str) is not None
            
            if not has_rec:
                naver_rec = naver_soup.find("div", class_="recommend-area")
                if naver_rec:
                    rec_div = soup.new_tag("div", style="background:#f8f9fa;border:1px solid #eee;padding:20px;margin:40px 0;border-radius:10px;")
                    strong_tag = soup.new_tag("strong", style="font-weight: 700;")
                    strong_tag.string = "🔗 함께 읽으면 좋은 글"
                    rec_div.append(strong_tag)
                    rec_div.append(soup.new_tag("br"))
                    rec_div.append(soup.new_tag("br"))
                    
                    a_tags = naver_rec.find_all("a")
                    for idx, a in enumerate(a_tags):
                        rec_div.append("▶ ")
                        new_a = soup.new_tag("a", href=a.get("href"), style=f"color:{theme_color};text-decoration:none;")
                        new_a.string = a.get_text().strip()
                        rec_div.append(new_a)
                        if idx < len(a_tags) - 1:
                            rec_div.append(soup.new_tag("br"))
                    
                    wrapper = soup.find("div", style=re.compile(r"max-width:\s*780px;"))
                    if wrapper:
                        memo_div = wrapper.find("div", style=re.compile("background:#e8f5e9|background:#fffde7|background:#e0f2f1"))
                        if memo_div:
                            memo_div.insert_before(rec_div)
                        else:
                            wrapper.append(rec_div)
                    else:
                        soup.body.append(rec_div)
                        
                    modified = True
                    content_str = str(soup)
                    print(f"[{f}] Imported recommendation box from Naver")
            
            # Check tag chips
            has_tags = (soup.find("span", style=re.compile("background:#f0f0f0")) is not None or
                        soup.find("span", class_="tag") is not None)
            
            if not has_tags:
                naver_tags = naver_soup.find("div", class_="tags")
                if naver_tags:
                    tags_div = soup.new_tag("div", style="margin-top:30px;")
                    for span in naver_tags.find_all("span"):
                        tag_span = soup.new_tag("span", style="display:inline-block; background:#f0f0f0; padding:3px 10px; border-radius:5px; margin:3px; font-size:0.85em; color:#666; border:1px solid #ddd;")
                        tag_span.string = span.get_text().strip()
                        tags_div.append(tag_span)
                        tags_div.append("\n")
                    
                    wrapper = soup.find("div", style=re.compile(r"max-width:\s*780px;"))
                    if wrapper:
                        wrapper.append(tags_div)
                    else:
                        soup.body.append(tags_div)
                        
                    modified = True
                    content_str = str(soup)
                    print(f"[{f}] Imported tag chips from Naver")
                
        # 4. Standardize any existing tag chips (if any)
        spans = soup.find_all("span", style=re.compile("background:"))
        tag_spans_updated = 0
        for span in spans:
            if span.get_text().startswith("#"):
                span["style"] = "display:inline-block; background:#f0f0f0; padding:3px 10px; border-radius:5px; margin:3px; font-size:0.85em; color:#666; border:1px solid #ddd;"
                tag_spans_updated += 1
                
        if tag_spans_updated > 0:
            modified = True
            print(f"[{f}] Standardized {tag_spans_updated} tag chips to #f0f0f0")
            
        if modified:
            with open(filepath, "w", encoding="utf-8") as file:
                file.write(str(soup))
            print(f"[{f}] Saved changes.")

if __name__ == "__main__":
    day = sys.argv[1] if len(sys.argv) > 1 else None
    fix_tistory_violations(day)
