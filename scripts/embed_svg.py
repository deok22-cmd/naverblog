import base64
import os

def get_base64_image(image_path):
    with open(image_path, "rb") as image_file:
        encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
        ext = os.path.splitext(image_path)[1][1:]
        if ext == 'jpg': ext = 'jpeg'
        return f"data:image/{ext};base64,{encoded_string}"

base_path = r"D:\lightsail\naverblog"
out_dir = os.path.join(base_path, "output_figma")
img_dir = os.path.join(base_path, "images", "260410")

tent_b64 = get_base64_image(os.path.join(img_dir, "9_tent_1.png"))
resin_b64 = get_base64_image(os.path.join(img_dir, "9_tent_2.png"))
price_b64 = get_base64_image(os.path.join(img_dir, "9_coody_price_1.jpg"))

# Page 1
svg1 = f'''<svg width="1080" height="1080" viewBox="0 0 1080 1080" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="1080" height="1080" fill="#00796B"/>
  <image href="{tent_b64}" x="0" y="0" width="1080" height="1080" opacity="0.4" preserveAspectRatio="xMidYMid slice"/>
  <rect x="50" y="50" width="980" height="980" stroke="white" stroke-width="2" stroke-opacity="0.3"/>
  <text fill="white" xml:space="preserve" style="white-space: pre" font-family="Pretendard, sans-serif" font-size="60" font-weight="500" letter-spacing="0.05em"><tspan x="100" y="200">COODY AIR TENT CARE</tspan></text>
  <text fill="white" xml:space="preserve" style="white-space: pre" font-family="Pretendard, sans-serif" font-size="110" font-weight="800" letter-spacing="-0.02em"><tspan x="100" y="380">쿠디 감성 100점,</tspan><tspan x="100" y="520">세탁은 몇 점인가요?</tspan></text>
  <text fill="#B2DFDB" xml:space="preserve" style="white-space: pre" font-family="Pretendard, sans-serif" font-size="45" font-weight="400" line-height="1.6"><tspan x="100" y="700">대형 에어텐트 유저들을 위한</tspan><tspan x="100" y="770">텐트깔끄미의 프리미엄 세탁 솔루션</tspan></text>
</svg>'''

# Page 2
svg2 = f'''<svg width="1080" height="1080" viewBox="0 0 1080 1080" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="1080" height="1080" fill="white"/>
  <image href="{resin_b64}" x="50" y="450" width="980" height="580" opacity="0.9" preserveAspectRatio="xMidYMid slice"/>
  <rect x="100" y="100" width="880" height="300" fill="#F5F5F5" rx="20"/>
  <text fill="#D32F2F" xml:space="preserve" style="white-space: pre" font-family="Pretendard, sans-serif" font-size="80" font-weight="800"><tspan x="180" y="270">무겁고, 크고, 막막하고...</tspan></text>
  <text fill="#222" xml:space="preserve" style="white-space: pre" font-family="Pretendard, sans-serif" font-size="55" font-weight="700" line-height="1.8"><tspan x="100" y="480">수십 킬로의 쿠디 에어텐트,</tspan><tspan x="100" y="560">비좁은 욕조에서 세탁하실 건가요?</tspan></text>
</svg>'''

# Page 4
svg4 = f'''<svg width="1080" height="1080" viewBox="0 0 1080 1080" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="1080" height="1080" fill="white"/>
  <image href="{price_b64}" x="0" y="600" width="1080" height="480" preserveAspectRatio="xMidYMid slice"/>
  <text fill="#00796B" xml:space="preserve" style="white-space: pre" font-family="Pretendard, sans-serif" font-size="70" font-weight="800"><tspan x="100" y="150">거품 뺀 투명한 가격제</tspan></text>
  <rect x="80" y="220" width="920" height="350" fill="#E0F2F1" rx="20"/>
  <text fill="#222" xml:space="preserve" style="white-space: pre" font-family="Pretendard, sans-serif" font-size="48" font-weight="600"><tspan x="130" y="320">쿠디 8.0 / 13.6</tspan><tspan x="130" y="420">다양한 옵션 구비</tspan></text>
</svg>'''

with open(os.path.join(out_dir, "coody_260410_01.svg"), "w", encoding="utf-8") as f: f.write(svg1)
with open(os.path.join(out_dir, "coody_260410_02.svg"), "w", encoding="utf-8") as f: f.write(svg2)
with open(os.path.join(out_dir, "coody_260410_04.svg"), "w", encoding="utf-8") as f: f.write(svg4)

print("Done")
