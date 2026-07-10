import os
import re
import shutil
from bs4 import BeautifulSoup

def process_images_and_manuscripts():
    project_root = r"d:\lightsail\naverblog"
    brain_dir = r"C:\Users\User\.gemini\antigravity\brain\c27937a8-3dc9-4888-be22-54ec5ffe072a"
    dest_img_dir = os.path.join(project_root, "images", "260710")
    
    # 1. Create destination directory if it doesn't exist
    if not os.path.exists(dest_img_dir):
        os.makedirs(dest_img_dir)
        print(f"Created directory: {dest_img_dir}")
        
    # List of expected image base names for 260710
    expected_images = [
        "1_hallasan_1", "1_hallasan_2", "1_hallasan_3",
        "2_morningcalm_1", "2_morningcalm_2", "2_morningcalm_3",
        "3_chungju_1", "3_chungju_2", "3_chungju_3",
        "4_ktx_1", "4_ktx_2", "4_ktx_3",
        "5_hipass_1", "5_hipass_2", "5_hipass_3",
        "6_vacuum_1", "6_vacuum_2", "6_vacuum_3",
        "7_familyreg_1", "7_familyreg_2", "7_familyreg_3"
    ]
    
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
    
    # 3. Process Naver manuscripts (output/260710/*.html)
    print("\n--- Processing Naver Manuscripts (output/260710/) ---")
    naver_dir = os.path.join(project_root, "output", "260710")
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
                    ph_file = file_el.get_text().strip() if file_el else ""
                    if not ph_file:
                        continue
                    
                    img_filename = os.path.basename(ph_file)
                    dest_img_path = os.path.join(dest_img_dir, img_filename)
                    if not os.path.exists(dest_img_path):
                        print(f"  -> Skipping placeholder {img_filename} in {f} (image not generated yet)")
                        continue
                    
                    parent_area = ph.find_parent(class_="img-area")
                    caption_text = ""
                    if parent_area:
                        caption_el = parent_area.find(class_="img-caption")
                        if caption_el:
                            caption_text = caption_el.get_text().strip()
                            
                    new_img_tag = soup.new_tag("img")
                    new_img_tag["alt"] = caption_text
                    new_img_tag["src"] = f"../../{ph_file}"
                    new_img_tag["style"] = "width:100%; border-radius:8px; display:block; margin:0 auto;"
                    
                    ph.replace_with(new_img_tag)
                    if parent_area:
                        caption_el = parent_area.find(class_="img-caption")
                        if caption_el:
                            caption_el.decompose()
                    updated = True
                            
                if updated:
                    with open(filepath, "w", encoding="utf-8") as file:
                        file.write(str(soup))
                    print(f"  -> Updated {f}")
    else:
        print(f"Error: Naver output directory {naver_dir} not found.")
        
    # 4. Process Tistory manuscripts (output_tistory/260710/*.html)
    print("\n--- Processing Tistory Manuscripts (output_tistory/260710/) ---")
    tistory_dir = os.path.join(project_root, "output_tistory", "260710")
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
        print(f"Error: Tistory output directory {tistory_dir} not found.")

if __name__ == "__main__":
    process_images_and_manuscripts()
