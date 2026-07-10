import os
import re
from bs4 import BeautifulSoup

def convert_naver_to_tistory():
    project_root = r"d:\lightsail\naverblog"
    naver_path = os.path.join(project_root, "output", "260704", "travel_bonghwa_valley_summer.html")
    tistory_path = os.path.join(project_root, "output_tistory", "260704", "travel_bonghwa_valley_summer.html")
    
    with open(naver_path, "r", encoding="utf-8") as f:
        content = f.read()
        
    soup = BeautifulSoup(content, "html.parser")
    
    # We will build the tistory content inside a wrapper div
    tistory_soup = BeautifulSoup('<div style="font-family: \'Apple SD Gothic Neo\', sans-serif; font-size: 16px; line-height: 1.9; color: #222; max-width: 780px; margin: 0 auto; padding: 16px;"></div>', 'html.parser')
    wrapper = tistory_soup.div
    
    # Get Naver body children
    body = soup.body
    
    for child in list(body.children):
        # BeautifulSoup child might be NavigableString or Tag
        if child.name is None:
            # Text/whitespace
            wrapper.append(child)
            continue
            
        # Process tags
        if child.name == "h1":
            new_h1 = tistory_soup.new_tag("h1", style="font-size: 1.6em; font-weight: 800; border-bottom: 5px solid #00796b; padding-bottom: 12px; color: #004d40; text-align: center;")
            new_h1.extend(child.contents)
            wrapper.append(new_h1)
            
        elif child.name == "div" and "intro-box" in child.get("class", []):
            new_div = tistory_soup.new_tag("div", style="background: #f1faf9; border: 2px solid #b2dfdb; padding: 25px; border-radius: 10px; margin: 30px 0;")
            
            # Format strong tags inside
            for strong in child.find_all("strong"):
                strong["style"] = "font-weight: 700;"
            new_div.extend(child.contents)
            wrapper.append(new_div)
            
        elif child.name == "table" and "info-table" in child.get("class", []):
            new_table = tistory_soup.new_tag("table", style="width: 100%; margin: 30px 0; border-collapse: collapse;")
            for row in child.find_all("tr"):
                new_tr = tistory_soup.new_tag("tr")
                for cell in row.children:
                    if cell.name == "th":
                        new_cell = tistory_soup.new_tag("th", style="background: #00796b; color: #fff; padding: 10px 12px; text-align: left;")
                        new_cell.extend(cell.contents)
                        new_tr.append(new_cell)
                    elif cell.name == "td":
                        new_cell = tistory_soup.new_tag("td", style="border: 1px solid #cde9e6; padding: 10px 12px;")
                        new_cell.extend(cell.contents)
                        new_tr.append(new_cell)
                new_table.append(new_tr)
            wrapper.append(new_table)
            
        elif child.name == "h2":
            new_h2 = tistory_soup.new_tag("h2", style="font-size: 1.2em; font-weight: 700; background: #e0f2f1; padding: 12px 15px; border-left: 6px solid #00796b; margin-top: 50px; color: #004d40;")
            new_h2.extend(child.contents)
            wrapper.append(new_h2)
            
        elif child.name == "div" and "img-area" in child.get("class", []):
            img = child.find("img")
            if img:
                alt_text = img.get("alt", "").strip()
                src_path = img.get("src", "").strip()
                
                new_div = tistory_soup.new_tag("div", style="margin:30px 0;text-align:center;")
                new_img = tistory_soup.new_tag("img", alt=alt_text, src=src_path, style="max-width:100%;height:auto;border-radius:8px;")
                new_div.append(new_img)
                
                new_cap = tistory_soup.new_tag("div", style="font-size:0.9em;color:#666;margin-top:10px;font-style:italic;")
                new_cap.string = f"{alt_text} / AI 제작 이미지"
                new_div.append(new_cap)
                
                wrapper.append(new_div)
                
        elif child.name == "div" and "recommend-area" in child.get("class", []):
            # Format recommendation box to standard Tistory style
            new_div = tistory_soup.new_tag("div", style="background: #f8f9fa; border: 1px solid #eee; padding: 20px; margin: 40px 0; border-radius: 10px;")
            strong = tistory_soup.new_tag("strong", style="font-weight: 700;")
            strong.string = "📌 함께 읽으면 좋은 글"
            new_div.append(strong)
            new_div.append(tistory_soup.new_tag("br"))
            new_div.append(tistory_soup.new_tag("br"))
            
            # Format list of links
            # Naver original links are simple paragraph or list of a tags
            # Let's rebuild the links
            a_tags = child.find_all("a")
            for a in a_tags:
                new_div.append("▶ ")
                new_a = tistory_soup.new_tag("a", href=a.get("href"), style="color: #1565c0; text-decoration: none;")
                new_a.string = a.get_text().strip()
                new_div.append(new_a)
                new_div.append(tistory_soup.new_tag("br"))
                
            wrapper.append(new_div)
            
        elif child.name == "div" and child.get("style") == "margin: 40px 0;":
            # Tag list container
            new_div = tistory_soup.new_tag("div", style="margin-top: 40px;")
            spans = child.find_all("span", class_="tag")
            for span in spans:
                new_span = tistory_soup.new_tag("span", style="display:inline-block; background:#f0f0f0; padding:3px 10px; border-radius:5px; margin:3px; font-size:0.85em; color:#666; border:1px solid #ddd;")
                new_span.string = span.get_text().strip()
                new_div.append(new_span)
                new_div.append("\n  ")
            wrapper.append(new_div)
            
        else:
            # For other paragraphs, lists, etc., just format any inner strong tags
            for strong in child.find_all("strong"):
                strong["style"] = "font-weight: 700;"
            wrapper.append(child)
            
    with open(tistory_path, "w", encoding="utf-8") as f:
        f.write(str(tistory_soup))
    print("Successfully converted Naver HTML to Tistory HTML and saved it.")

if __name__ == "__main__":
    convert_naver_to_tistory()
