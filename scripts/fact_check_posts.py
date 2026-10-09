import os
import sys
import re
import json
import time
import urllib.request
import urllib.error
import datetime
from bs4 import BeautifulSoup

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
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

def call_gemini_json(prompt, api_key, model="gemini-2.5-flash", max_retries=2):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseMimeType": "application/json",
            "temperature": 0.1
        }
    }
    data = json.dumps(payload).encode("utf-8")

    for attempt in range(1, max_retries + 1):
        try:
            req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=45) as resp:
                res = json.loads(resp.read().decode("utf-8"))
                text = res["candidates"][0]["content"]["parts"][0]["text"]
                return json.loads(text)
        except Exception as e:
            if attempt < max_retries:
                time.sleep(3)
            else:
                raise e
    return None

def extract_candidate_facts(html_content):
    soup = BeautifulSoup(html_content, "html.parser")
    title = soup.find("h1").get_text().strip() if soup.find("h1") else ""
    
    # Extract tables
    tables_text = []
    for table in soup.find_all("table"):
        tables_text.append(table.get_text(separator=" | ").strip())
        
    # Extract intro
    text_blocks = []
    intro = soup.find(class_="intro-box")
    if intro:
        text_blocks.append("도입부:\n" + intro.get_text().strip())
        
    # Extract sections under h2
    for h2 in soup.find_all("h2"):
        h2_title = h2.get_text().strip()
        section_sentences = [h2_title]
        sibling = h2.find_next_sibling()
        while sibling and sibling.name != "h2":
            classes = sibling.get("class", [])
            if any(c in classes for c in ["recommend-area", "tags", "prompt-box"]):
                break
            txt = sibling.get_text().strip()
            if txt and len(txt) > 5:
                # Include full paragraphs that contain key facts, without mid-word slicing
                if any(k in txt for k in ["원", "일", "월", "역", "시", "료", "할인", "만", "위치", "주차", "탑승", "나이", "기준", "km", "%"]):
                    section_sentences.append(txt)
            sibling = sibling.find_next_sibling()
        if len(section_sentences) > 1:
            text_blocks.append("\n".join(section_sentences[:4]))

    combined_text = f"제목: {title}\n\n"
    if tables_text:
        combined_text += "핵심 정보 테이블:\n" + "\n---\n".join(tables_text) + "\n\n"
    combined_text += "본문 핵심 섹션:\n" + "\n\n".join(text_blocks[:6])
    return title, combined_text

FACT_CHECK_PROMPT = """당신은 대한민국 전문 팩트체커(Fact-Checker) 서브에이전트입니다.
제공된 블로그 원고 요약본에서 **일정(날짜/D-day), 장소/위치, 금액(입장료/주차료/요금), 제도 규정(법정 나이/할인율/공식 기준)**의 사실관계를 엄격히 검증하세요.

[원고 내용]
{CONTENT}

[★ 필수 검증 원칙 - 반드시 엄수할 것]
1. [기준 연도 2026년 절대 준수]: 현재 블로그의 기준 연도는 **2026년**입니다. 원고 내의 "2026년", "2026" 또는 2026년 가을/연말 행사·축제 일정을 절대로 과거 연도(2024년, 2025년 등)로 변경/퇴행시키지 마십시오. 아직 미래 시점이라 공식 세부 일정이 미발표된 행사라도 연도를 과거로 낮추지 말고 verdict: "NOTE"로 기록하십시오.
2. [보정(CORRECTED) 적용 기준]: 명백하고 객관적인 오류(예: 존재하지 않는 전철/KTX 역명, 명백한 수치 연산 오류, 실제 법령/공식 기준과 정반대인 규정, 잘못 기재된 공식 입장료/주차요금)에 대해서만 verdict: "CORRECTED"로 지정하십시오.
3. [치환 구문 무결성]:
   - original_text: 원문 본문에 실제로 온전히 존재하는 **완전한 단어 또는 구문**이어야 합니다. 문장 일부를 어색하게 잘라내거나 불완전한 파편을 지정하지 마십시오.
   - replacement_text: 원문 문맥에 대입했을 때 문법과 어순이 자연스럽게 유지되어야 합니다.
   - 단순한 문체 선호, 예측성 행사 일정, 주관적 추천 금액/예산 배분은 절대 CORRECTED로 바꾸지 말고 "VERIFIED" 또는 "NOTE"로 처리하십시오.
4. 오기가 없고 사실과 부합하면 verdict: "VERIFIED"로 지정하십시오.
5. 유의해야 할 추가 팁이나 공식 일정 미확정 주의사항은 verdict: "NOTE"로 지정하십시오.

반드시 다음 JSON 스키마 형식으로만 응답하세요:
{{
  "claims": [
    {{
      "category": "일정/금액/장소/규정 중 하나",
      "claim": "검증 대상 진술 내용",
      "verdict": "VERIFIED" | "CORRECTED" | "NOTE",
      "original_text": "원문 내 오기된 정확한 단어/구문 (수정 필요할 때만, 없으면 null)",
      "replacement_text": "치환할 올바른 단어/구문 (수정 필요할 때만, 없으면 null)",
      "reason": "검증 근거 및 공식 출처 설명"
    }}
  ]
}}
"""

def fact_check_directory(target_date=None):
    start_time = time.time()
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    
    # Determine target date
    if not target_date:
        output_dir = os.path.join(project_root, "output")
        available_dates = sorted([d for d in os.listdir(output_dir) if d.isdigit() and os.path.isdir(os.path.join(output_dir, d))], reverse=True)
        target_date = available_dates[0] if available_dates else datetime.datetime.now().strftime("%y%m%d")

    day_dir = os.path.join(project_root, "output", target_date)
    if not os.path.exists(day_dir):
        print(f"[fact-checker] 대상 디렉터리가 없습니다: {day_dir}")
        return None

    api_key = get_gemini_api_key()
    if not api_key:
        print("[fact-checker] 오류: GEMINI_API_KEY를 찾을 수 없습니다.")
        return None

    print(f"=== 팩트체크 서브에이전트 가동 ({target_date} 일자 원고 검증) ===")
    print(f"대상 폴더: {day_dir}")

    html_files = [f for f in sorted(os.listdir(day_dir)) if f.endswith(".html") and f != "index.html"]
    print(f"검증 대상 원고: {len(html_files)}건\n")

    all_file_results = []
    total_claims = 0
    total_verified = 0
    total_corrected = 0
    total_notes = 0
    corrections_applied = 0
    errors = []
    log_lines = []

    def log(msg):
        print(msg, flush=True)
        log_lines.append(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] {msg}")

    for idx, fname in enumerate(html_files, 1):
        fpath = os.path.join(day_dir, fname)
        with open(fpath, "r", encoding="utf-8") as f:
            html_content = f.read()

        title, candidate_text = extract_candidate_facts(html_content)
        log(f"[{idx}/{len(html_files)}] 검증 중: {fname}")
        log(f"      제목: {title[:45]}...")

        prompt = FACT_CHECK_PROMPT.format(CONTENT=candidate_text)
        try:
            res = call_gemini_json(prompt, api_key)
            claims = res.get("claims", []) if res else []
        except Exception as e:
            errors.append(f"{fname} 팩트체크 API 호출 실패: {e}")
            log(f"      ⚠️ API 호출 오류: {e}")
            claims = []

        file_corrections = 0
        file_checks = []
        for c in claims:
            total_claims += 1
            verdict = c.get("verdict", "VERIFIED")
            claim_desc = c.get("claim", "")
            orig_txt = c.get("original_text")
            repl_txt = c.get("replacement_text")
            reason = c.get("reason", "")

            if verdict == "CORRECTED" and orig_txt and repl_txt:
                orig_clean = orig_txt.strip()
                repl_clean = repl_txt.strip()

                # Guardrail 1: 기준 연도(2026) 과거 퇴행 방지
                if ("2026" in orig_clean) and any(yr in repl_clean for yr in ["2024", "2025", "2023"]):
                    log(f"      🛡️ 보정 거부 (기준 연도 2026년 퇴행 방지): '{orig_clean}' ➡️ '{repl_clean}'")
                    verdict = "NOTE"
                    c["verdict"] = "NOTE"
                    total_notes += 1
                # Guardrail 2: 원문 미존재
                elif orig_clean not in html_content:
                    log(f"      ⚠️ 보정 대상 문구 미발견: '{orig_clean}' ({reason})")
                    verdict = "NOTE"
                    c["verdict"] = "NOTE"
                    total_notes += 1
                # Guardrail 3: 너무 짧은 단편 (3자 미만)
                elif len(orig_clean) < 3:
                    log(f"      ⚠️ 보정 대상 문구가 너무 짧아 거부: '{orig_clean}'")
                    verdict = "NOTE"
                    c["verdict"] = "NOTE"
                    total_notes += 1
                # Guardrail 4: 접미사 중복 위험 (예: 100만 원0만 원)
                elif repl_clean.endswith("원") and (orig_clean + "원" in html_content) and not orig_clean.endswith("원"):
                    log(f"      ⚠️ 접미사 중복 오염 위험으로 보정 거부: '{orig_clean}'")
                    verdict = "NOTE"
                    c["verdict"] = "NOTE"
                    total_notes += 1
                else:
                    total_corrected += 1
                    html_content = html_content.replace(orig_clean, repl_clean, 1)
                    file_corrections += 1
                    corrections_applied += 1
                    log(f"      ✏️ 보정 완료: '{orig_clean}' ➡️ '{repl_clean}' ({reason})")
            elif verdict == "NOTE":
                total_notes += 1
                log(f"      📌 참고 사항: {claim_desc} ({reason})")
            else:
                total_verified += 1

            file_checks.append({
                "category": c.get("category", "기타"),
                "claim": claim_desc,
                "verdict": verdict,
                "original_text": orig_txt,
                "replacement_text": repl_txt,
                "reason": reason
            })

        # Save corrected HTML if modifications occurred
        if file_corrections > 0:
            with open(fpath, "w", encoding="utf-8") as f:
                f.write(html_content)
            log(f"      💾 원고 파일 저장 완료: {file_corrections}건 보정 반영")
        else:
            log(f"      ✔️ 모든 팩트 정상 확인 ({len(claims)}개 항목)")

        all_file_results.append({
            "file": fname,
            "title": title,
            "claims_count": len(claims),
            "corrections_count": file_corrections,
            "checks": file_checks
        })
        time.sleep(1) # rate limiting courtesy

    duration = round(time.time() - start_time, 2)
    confidence_score = round(((total_verified + total_corrected) / max(total_claims, 1)) * 100, 1)

    status = "SUCCESS" if len(errors) == 0 else "ERROR"
    summary = f"원고 {len(html_files)}건 중 {total_claims}개 팩트 검증 완료 (정상: {total_verified}개, 보정: {corrections_applied}개, 참고: {total_notes}개, 신뢰도: {confidence_score}%)"

    log("\n=== 팩트체크 완료 요약 ===")
    log(f"결과 상태     : {status}")
    log(f"소요 시간     : {duration}초")
    log(f"검증 팩트 수  : {total_claims}개")
    log(f"정상 확인     : {total_verified}개")
    log(f"자동 보정 반영: {corrections_applied}개")
    log(f"참고 알림     : {total_notes}개")
    log(f"신뢰도 지수   : {confidence_score}%")

    # Save state to subagents log directory
    subagent_logs_dir = os.path.join(project_root, ".scripts", "logs", "subagents")
    os.makedirs(subagent_logs_dir, exist_ok=True)

    state_path = os.path.join(subagent_logs_dir, "fact-checker.json")
    daily_history_path = os.path.join(subagent_logs_dir, f"fact-checker-{target_date}.json")

    state_data = {
        "id": "fact-checker",
        "name": "원고 팩트체크 서브에이전트 (Fact-Checker)",
        "last_run": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "status": status,
        "duration_sec": duration,
        "metrics": {
            "target_date": target_date,
            "total_posts": len(html_files),
            "total_claims": total_claims,
            "verified_count": total_verified,
            "corrected_count": corrections_applied,
            "note_count": total_notes,
            "confidence_score": confidence_score,
            "error_count": len(errors)
        },
        "summary": summary,
        "files": all_file_results,
        "errors": errors,
        "log_tail": log_lines[-18:]
    }

    with open(state_path, "w", encoding="utf-8") as f:
        json.dump(state_data, f, ensure_ascii=False, indent=2)

    with open(daily_history_path, "w", encoding="utf-8") as f:
        json.dump(state_data, f, ensure_ascii=False, indent=2)

    return state_data

if __name__ == "__main__":
    t_date = sys.argv[1] if len(sys.argv) > 1 else None
    fact_check_directory(t_date)
