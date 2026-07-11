import os
import re
import shutil
from bs4 import BeautifulSoup

def process_images_and_manuscripts():
    project_root = r"d:\lightsail\naverblog"
    brain_dir = r"C:\Users\User\.gemini\antigravity\brain\c27937a8-3dc9-4888-be22-54ec5ffe072a"
    dest_img_dir = os.path.join(project_root, "images", "260711")
    
    # 1. Create destination directory if it doesn't exist
    if not os.path.exists(dest_img_dir):
        os.makedirs(dest_img_dir)
        print(f"Created directory: {dest_img_dir}")
        
    # List of expected image base names for 260711
    expected_images = [
        "1_bivaldipark_1", "1_bivaldipark_2", "1_bivaldipark_3",
        "2_muuido_1", "2_muuido_2", "2_muuido_3",
        "3_hantangang_1", "3_hantangang_2", "3_hantangang_3",
        "4_typhoon_1", "4_typhoon_2", "4_typhoon_3",
        "5_fine_1", "5_fine_2", "5_fine_3",
        "6_aircon_1", "6_aircon_2", "6_aircon_3",
        "7_mortgage_1", "7_mortgage_2", "7_mortgage_3"
    ]
    
    slug_map = {
        "travel_bivaldipark_oceanworld": "1_bivaldipark",
        "travel_muuido_hanagae": "2_muuido",
        "travel_pocheon_hantangang": "3_hantangang",
        "local_typhoon_cancel": "4_typhoon",
        "car_fine_difference": "5_fine",
        "appli_aircon_electricity": "6_aircon",
        "cert_registry_mortgage": "7_mortgage"
    }
    
    # 2. Move and rename images from brain directory to destination if they exist
    print("\n--- Moving and Renaming Images ---")
    brain_files = os.listdir(brain_dir) if os.path.exists(brain_dir) else []
    moved_count = 0
    
    for base_name in expected_images:
        matched_files = [f for f in brain_files if f.startswith(base_name + "_") and f.endswith(".png")]
        if not matched_files:
            matched_files = [f for f in brain_files if f == base_name + ".png"]
            
        if matched_files:
            matched_files.sort()
            src_file = matched_files[-1]
            src_path = os.path.join(brain_dir, src_file)
            dest_file = base_name + ".png"
            dest_path = os.path.join(dest_img_dir, dest_file)
            
            shutil.copy2(src_path, dest_path)
            print(f"Copied: {src_file} -> {dest_file}")
            moved_count += 1
        else:
            print(f"Notice: No generated file found in brain_dir for {base_name} (yet)")
            
    print(f"Successfully processed {moved_count}/{len(expected_images)} images.")
    
    # 3. Process Naver manuscripts (output/260711/*.html)
    print("\n--- Processing Naver Manuscripts (output/260711/) ---")
    naver_dir = os.path.join(project_root, "output", "260711")
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
                for index, ph in enumerate(placeholders, 1):
                    file_el = ph.find(class_="ph-file")
                    if file_el:
                        ph_file = file_el.get_text().strip()
                    else:
                        slug = f.replace(".html", "")
                        prefix = slug_map.get(slug)
                        if prefix:
                            ph_file = f"images/260711/{prefix}_{index}.png"
                        else:
                            ph_file = ""
                            
                    if not ph_file:
                        continue
                    
                    img_filename = os.path.basename(ph_file)
                    dest_img_path = os.path.join(dest_img_dir, img_filename)
                    if not os.path.exists(dest_img_path):
                        print(f"  -> Skipping placeholder {img_filename} in {f} (image not generated yet)")
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
        print(f"Error: Naver output directory {naver_dir} not found.")
        
    # 4. Process Tistory manuscripts (output_tistory/260711/*.html)
    print("\n--- Processing Tistory Manuscripts (output_tistory/260711/) ---")
    tistory_dir = os.path.join(project_root, "output_tistory", "260711")
    if os.path.exists(tistory_dir):
        tistory_files = [f for f in os.listdir(tistory_dir) if f.endswith(".html") and f != "index.html"]
        for f in tistory_files:
            filepath = os.path.join(tistory_dir, f)
            with open(filepath, "r", encoding="utf-8") as file:
                content = file.read()
                
            soup = BeautifulSoup(content, "html.parser")
            imgs = soup.find_all("img")
            updated = False
            
            for img in imgs:
                src = img.get("src", "")
                img_filename = os.path.basename(src)
                dest_img_path = os.path.join(dest_img_dir, img_filename)
                if os.path.exists(dest_img_path):
                    sibling = img.find_next_sibling()
                    if sibling and sibling.name == "div" and "(이미지 제작 예정)" in sibling.get_text():
                        old_caption = sibling.get_text().strip()
                        new_caption = old_caption.replace("(이미지 제작 예정)", "/ AI 제작 이미지").strip()
                        
                        sibling.string = new_caption
                        img["alt"] = new_caption
                        updated = True
                        print(f"  -> Updated caption for {src}: '{old_caption}' -> '{new_caption}'")
                else:
                    print(f"  -> Skipping caption update for {src} in {f} (image not generated yet)")
                        
            if updated:
                with open(filepath, "w", encoding="utf-8") as file:
                    file.write(str(soup))
                print(f"File: {f} updated successfully.")
            else:
                print(f"File: {f} (No captions needed update or already processed)")
    else:
        print(f"Error: Tistory output directory {tistory_dir} not found (or Tistory is suspended).")

if __name__ == "__main__":
    process_images_and_manuscripts()
