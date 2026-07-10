import os
import sys
import re
from bs4 import BeautifulSoup

# Configure stdout to use utf-8
if sys.platform.startswith('win'):
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

def scan_placeholders():
    project_root = r"d:\lightsail\naverblog"
    day_dir = os.path.join(project_root, "output", "260710")
    
    if not os.path.exists(day_dir):
        print(f"Error: Directory {day_dir} does not exist.")
        return
        
    html_files = [f for f in os.listdir(day_dir) if f.endswith(".html") and f != "index.html"]
    
    print(f"Found {len(html_files)} HTML files to process:")
    for f in html_files:
        print(f" - {f}")
        
    placeholders = []
    
    for f in html_files:
        filepath = os.path.join(day_dir, f)
        with open(filepath, "r", encoding="utf-8") as file:
            content = file.read()
            
        soup = BeautifulSoup(content, "html.parser")
        
        ph_divs = soup.find_all(class_="img-placeholder")
        print(f"\nFile: {f} (Found {len(ph_divs)} placeholders)")
        
        for ph in ph_divs:
            file_el = ph.find(class_="ph-file")
            prompt_el = ph.find(class_="prompt-text")
            
            parent_area = ph.find_parent(class_="img-area")
            caption_text = ""
            if parent_area:
                caption_el = parent_area.find(class_="img-caption")
                if caption_el:
                    caption_text = caption_el.get_text().strip()
            
            ph_file = file_el.get_text().strip() if file_el else "Unknown"
            prompt = prompt_el.get_text().strip() if prompt_el else "Unknown"
            
            placeholders.append({
                "file": f,
                "ph_file": ph_file,
                "prompt": prompt,
                "caption": caption_text
            })
            
            print(f"  * Path: {ph_file}")
            print(f"    Prompt: {prompt}")
            print(f"    Caption: {caption_text}")
            
    print(f"\nTotal placeholders found: {len(placeholders)}")

if __name__ == "__main__":
    scan_placeholders()
