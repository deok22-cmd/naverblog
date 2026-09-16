import os
import sys
import datetime
from bs4 import BeautifulSoup

def process_images_and_manuscripts(target_date=None):
    if not target_date:
        if len(sys.argv) > 1:
            target_date = sys.argv[1]
        else:
            target_date = datetime.datetime.now().strftime("%y%m%d")

    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    dest_img_dir = os.path.join(project_root, "images", target_date)
    
    if not os.path.exists(dest_img_dir):
        os.makedirs(dest_img_dir)
        print(f"Created directory: {dest_img_dir}")
        
    print(f"\n--- Processing Manuscripts (output/{target_date}/) ---")
    naver_dir = os.path.join(project_root, "output", target_date)
    if os.path.exists(naver_dir):
        naver_files = [f for f in os.listdir(naver_dir) if f.endswith(".html") and f != "index.html"]
        for f in naver_files:
            filepath = os.path.join(naver_dir, f)
            with open(filepath, "r", encoding="utf-8") as file:
                content = file.read()
                
            soup = BeautifulSoup(content, "html.parser")
            placeholders = soup.find_all(class_="img-placeholder")
            
            if placeholders:
                updated = False
                for ph in placeholders:
                    file_el = ph.find(class_="ph-file")
                    ph_file = ""
                    if file_el:
                        ph_file = file_el.get_text().strip()
                    else:
                        prompt_box = ph.find(class_="prompt-box") or ph.find("pre")
                        if prompt_box:
                            box_text = prompt_box.get_text().strip()
                            for line in box_text.split("\n"):
                                line = line.strip()
                                if ":" in line:
                                    parts = line.split(":", 1)
                                    key = parts[0].strip()
                                    val = parts[1].strip()
                                    if "저장 경로" in key or "저장경로" in key:
                                        ph_file = val
                                        break
                                    elif "파일명" in key and not ph_file:
                                        ph_file = f"images/{target_date}/{val}"
                            
                    if not ph_file:
                        continue

                    # Normalize path (remove leading relative path prefixes)
                    if ph_file.startswith("../../"):
                        ph_file = ph_file[6:]
                    elif ph_file.startswith("../"):
                        ph_file = ph_file[3:]
                    
                    img_filename = os.path.basename(ph_file)
                    dest_img_path = os.path.join(dest_img_dir, img_filename)
                    if not os.path.exists(dest_img_path):
                        print(f"  -> Skipping {img_filename} in {f} (image file not found in images/{target_date}/)")
                        continue
                    
                    parent_area = ph.find_parent(class_="img-area")
                    caption_el = None
                    if parent_area:
                        caption_el = parent_area.find(class_="img-caption")
                    else:
                        next_sib = ph.find_next_sibling()
                        if next_sib and next_sib.name == "div" and "img-caption" in next_sib.get("class", []):
                            caption_el = next_sib
                            
                    caption_text = caption_el.get_text().strip() if caption_el else ""
                            
                    new_img_tag = soup.new_tag("img")
                    new_img_tag["alt"] = caption_text
                    new_img_tag["src"] = f"../../{ph_file}"
                    new_img_tag["style"] = "width:100%; border-radius:8px; display:block; margin:0 auto;"
                    
                    ph.replace_with(new_img_tag)
                    if caption_el:
                        caption_el.decompose()
                    updated = True
                            
                if updated:
                    with open(filepath, "w", encoding="utf-8") as file:
                        file.write(str(soup))
                    print(f"  -> Updated {f}")
    else:
        print(f"Error: Output directory {naver_dir} not found.")

if __name__ == "__main__":
    process_images_and_manuscripts()
