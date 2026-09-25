import os
import sys
import re
import json
import time
import base64
import urllib.request
import urllib.error
import datetime
import subprocess
from bs4 import BeautifulSoup

class QuotaExceededError(Exception):
    """Raised when Gemini API quota (HTTP 429 or ResourceExhausted) is reached."""
    pass

def get_gemini_api_key():
    key = os.environ.get("GEMINI_API_KEY")
    if key:
        return key
    secret_path = os.path.join(os.path.dirname(__file__), "..", ".scripts", "secret.env.ps1")
    if os.path.exists(secret_path):
        with open(secret_path, "r", encoding="utf-8") as f:
            content = f.read()
            m = re.search(r'\$env:GEMINI_API_KEY\s*=\s*["\']([^"\']+)["\']', content)
            if m:
                return m.group(1)
    return None

def generate_image(prompt, api_key, max_retries=2):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key={api_key}"
    payload = {
        "contents": [{
            "parts": [{"text": prompt}]
        }]
    }
    data = json.dumps(payload).encode("utf-8")
    
    for attempt in range(1, max_retries + 1):
        try:
            req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as resp:
                res = json.loads(resp.read().decode("utf-8"))
                candidates = res.get("candidates", [])
                if not candidates:
                    raise ValueError(f"No candidates in Gemini response: {res}")
                parts = candidates[0].get("content", {}).get("parts", [])
                for part in parts:
                    if "inlineData" in part and part["inlineData"].get("data"):
                        return base64.b64decode(part["inlineData"]["data"])
                raise ValueError("No inlineData image found in Gemini response parts.")
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="replace")
            if e.code == 429 or "RESOURCE_EXHAUSTED" in err_body or "quota" in err_body.lower():
                if attempt < max_retries:
                    time.sleep(10)
                else:
                    raise QuotaExceededError(f"HTTP 429: {err_body[:200]}")
            else:
                if attempt < max_retries:
                    time.sleep(5)
                else:
                    raise
        except QuotaExceededError:
            raise
        except Exception as e:
            if attempt < max_retries:
                time.sleep(5)
            else:
                raise
    return None

def update_prompt_helper(project_root, target_date):
    helper_script = os.path.join(project_root, "scripts", "build_prompt_dashboard.py")
    if os.path.exists(helper_script):
        try:
            print(f"[Helper] Updating prompt_helper.html for {target_date}...")
            res = subprocess.run([sys.executable, helper_script, target_date], capture_output=True, text=True, check=True)
            print(f"[Helper] prompt_helper.html successfully updated.")
            return True
        except Exception as e:
            print(f"[Helper Warning] build_prompt_dashboard failed: {e}")
            return False
    return False

def get_ordered_html_files(out_dir):
    """Returns html files ordered as listed in index.html (priority 1~7)."""
    index_path = os.path.join(out_dir, "index.html")
    ordered_files = []
    if os.path.exists(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as f:
                soup = BeautifulSoup(f.read(), "html.parser")
            for a in soup.find_all("a"):
                href = a.get("href", "")
                if href.endswith(".html") and href != "index.html":
                    fname = os.path.basename(href)
                    if fname not in ordered_files and os.path.exists(os.path.join(out_dir, fname)):
                        ordered_files.append(fname)
        except Exception as e:
            print(f"[Warn] Reading index.html order failed: {e}")
            
    # Add any remaining html files not listed in index.html
    for f in sorted(os.listdir(out_dir)):
        if f.endswith(".html") and f != "index.html" and f not in ordered_files:
            ordered_files.append(f)
            
    return ordered_files

def main():
    target_date = sys.argv[1] if len(sys.argv) > 1 else datetime.datetime.now().strftime("%y%m%d")
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    out_dir = os.path.join(project_root, "output", target_date)
    img_dir = os.path.join(project_root, "images", target_date)
    
    if not os.path.exists(out_dir):
        print(f"[Error] Output directory not found: {out_dir}")
        sys.exit(1)
        
    os.makedirs(img_dir, exist_ok=True)
    
    api_key = get_gemini_api_key()
    if not api_key:
        print("[Error] GEMINI_API_KEY not found.")
        sys.exit(1)
        
    print(f"=== Auto Image Generation & Matching for {target_date} ===")
    print(f"Output directory : {out_dir}")
    print(f"Images directory : {img_dir}")
    
    # Process strictly in the order listed in index.html (1 to 7)
    html_files = get_ordered_html_files(out_dir)
    print(f"Found {len(html_files)} manuscripts in index.html order:")
    for i, h in enumerate(html_files, 1):
        print(f"  {i}. {h}")
    print()
    
    # Step 1: Scan placeholders in index.html sequence
    tasks = []
    for hname in html_files:
        hpath = os.path.join(out_dir, hname)
        with open(hpath, "r", encoding="utf-8") as f:
            soup = BeautifulSoup(f.read(), "html.parser")
            
        phs = soup.find_all(class_="img-placeholder")
        for ph in phs:
            file_el = ph.find(class_="ph-file")
            prompt_el = ph.find(class_="prompt-text")
            
            parent_area = ph.find_parent(class_="img-area") or ph.find_parent(class_="img-block")
            caption_text = ""
            if parent_area:
                cap_el = parent_area.find(class_="img-caption")
                if cap_el:
                    caption_text = cap_el.get_text().strip()
            
            ph_file = file_el.get_text().strip() if file_el else ""
            prompt = prompt_el.get_text().strip() if prompt_el else ""
            if ph_file and prompt:
                fname = os.path.basename(ph_file)
                tasks.append({
                    "html": hname,
                    "ph_file": ph_file,
                    "filename": fname,
                    "caption": caption_text,
                    "prompt": prompt
                })

    print(f"Total placeholders found: {len(tasks)}")
    
    # Step 2: Generate missing images in order
    success_count = 0
    skip_count = 0
    quota_exceeded = False
    
    for idx, item in enumerate(tasks, 1):
        target_img_path = os.path.join(img_dir, item["filename"])
        print(f"[{idx}/{len(tasks)}] ({item['html']}) {item['filename']} ... ", end="", flush=True)
        
        if os.path.exists(target_img_path) and os.path.getsize(target_img_path) > 1000:
            print("EXISTS (skip)")
            skip_count += 1
            continue
            
        try:
            img_bytes = generate_image(item["prompt"], api_key)
            if img_bytes:
                with open(target_img_path, "wb") as img_file:
                    img_file.write(img_bytes)
                print(f"CREATED ({len(img_bytes)} bytes)")
                success_count += 1
                time.sleep(3) # Rate limit courtesy
            else:
                print("FAILED (no image bytes returned)")
        except QuotaExceededError as qe:
            print("QUOTA EXCEEDED!")
            print(f"\n[ALERT] Image generation quota full or rate limited at image #{idx} ({item['filename']}).")
            quota_exceeded = True
            break
        except Exception as e:
            print(f"FAILED ({e})")
            
    print(f"\nImage generation batch ended: {success_count} created, {skip_count} existing.")
    
    # Step 3: Match and replace all generated images in manuscripts
    print("\n--- Replacing available images in manuscripts ---")
    replaced_count = 0
    for hname in html_files:
        hpath = os.path.join(out_dir, hname)
        with open(hpath, "r", encoding="utf-8") as f:
            soup = BeautifulSoup(f.read(), "html.parser")
            
        phs = soup.find_all(class_="img-placeholder")
        file_updated = False
        for ph in phs:
            file_el = ph.find(class_="ph-file")
            ph_file = file_el.get_text().strip() if file_el else ""
            if not ph_file:
                continue
                
            fname = os.path.basename(ph_file)
            img_path = os.path.join(img_dir, fname)
            if not os.path.exists(img_path):
                # Image not generated yet; leave placeholder for prompt_helper / manual generation
                continue
                
            parent_area = ph.find_parent(class_="img-area") or ph.find_parent(class_="img-block")
            caption_text = ""
            caption_el = None
            if parent_area:
                caption_el = parent_area.find(class_="img-caption")
                if cap_el:
                    caption_text = cap_el.get_text().strip()
            
            # Create new img tag
            img_tag = soup.new_tag("img")
            img_tag["src"] = f"../../images/{target_date}/{fname}"
            img_tag["alt"] = caption_text
            img_tag["style"] = "width:100%; border-radius:8px; display:block; margin:0 auto;"
            
            ph.replace_with(img_tag)
            
            # Ensure caption div remains present
            if not caption_el and caption_text and parent_area:
                cap_tag = soup.new_tag("div")
                cap_tag["class"] = "img-caption"
                cap_tag.string = caption_text
                img_tag.insert_after(cap_tag)
                
            file_updated = True
            replaced_count += 1
            
        if file_updated:
            with open(hpath, "w", encoding="utf-8") as f:
                f.write(str(soup))
            print(f"  [Updated] {hname}")
            
    print(f"\nTotal placeholders replaced: {replaced_count}")
    
    # Step 4: Always update prompt_helper.html so pending/completed status is 100% accurate
    update_prompt_helper(project_root, target_date)
    
    if quota_exceeded:
        print("\n[Notice] Quota reached. Remaining ungenerated images can be managed via prompt_helper.html.")
    else:
        print("\n[Success] All images processed and matched successfully.")

if __name__ == "__main__":
    main()
