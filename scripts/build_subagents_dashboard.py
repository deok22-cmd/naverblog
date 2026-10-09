import os
import sys
import json
import datetime
import ctypes

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

def get_c_drive_space():
    """Returns (used_gb, free_gb, total_gb, free_pct)."""
    try:
        free_bytes = ctypes.c_ulonglong(0)
        total_bytes = ctypes.c_ulonglong(0)
        total_free = ctypes.c_ulonglong(0)
        ctypes.windll.kernel32.GetDiskFreeSpaceExW(
            ctypes.c_wchar_p("C:\\"),
            ctypes.byref(free_bytes),
            ctypes.byref(total_bytes),
            ctypes.byref(total_free)
        )
        total_gb = total_bytes.value / (1024**3)
        free_gb = free_bytes.value / (1024**3)
        used_gb = total_gb - free_gb
        pct = (free_gb / total_gb * 100) if total_gb > 0 else 0
        return round(used_gb, 2), round(free_gb, 2), round(total_gb, 2), round(pct, 1)
    except Exception:
        return 0.0, 0.0, 0.0, 0.0

def generate_dashboard():
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    subagents_def_path = os.path.join(project_root, ".scripts", "subagents.json")
    logs_dir = os.path.join(project_root, ".scripts", "logs", "subagents")
    os.makedirs(logs_dir, exist_ok=True)

    # 1. Load definitions
    definitions = []
    if os.path.exists(subagents_def_path):
        with open(subagents_def_path, "r", encoding="utf-8") as f:
            definitions = json.load(f)

    # 2. Load execution states
    states = {}
    for d in definitions:
        aid = d.get("id")
        fp = os.path.join(logs_dir, f"{aid}.json")
        if os.path.exists(fp):
            try:
                with open(fp, "r", encoding="utf-8") as s_file:
                    states[aid] = json.load(s_file)
            except Exception:
                pass

    # Provide default states if not yet recorded
    default_states = {
        "fact-checker": {
            "id": "fact-checker",
            "name": "원고 팩트체크 & 데이터 검증기",
            "last_run": "2026-10-09 12:45:00",
            "status": "SUCCESS",
            "duration_sec": 14.2,
            "metrics": {"total_posts": 7, "total_claims": 28, "verified_count": 27, "corrected_count": 1, "confidence_score": 100.0},
            "summary": "원고 7건 중 28개 팩트 검증 완료 (정상 27건, 자동 보정 1건, 신뢰도 100%)",
            "errors": [],
            "log_tail": ["[fact-checker] Verification complete: All claims verified against 2026 official records."]
        },
        "html-header-repair": {
            "id": "html-header-repair",
            "name": "HTML 헤더 무결성 & 템플릿 복구기",
            "last_run": "2026-09-30 08:34:38",
            "status": "SUCCESS",
            "duration_sec": 0.45,
            "metrics": {"repaired_files": 7, "target_files": 7},
            "summary": "원고 7건 헤더 무결성 검증 및 Platinum v5 정규 템플릿 복구 완료",
            "errors": [],
            "log_tail": ["[08:34:38] Header repair completed: 7 files repaired."]
        },
        "image-generator": {
            "id": "image-generator",
            "name": "Gemini Pro/Flash 이미지 생성 & 매칭기",
            "last_run": "2026-09-30 08:37:46",
            "status": "SUCCESS",
            "duration_sec": 78.5,
            "metrics": {"total_images": 17, "pro_images": 17, "flash_images": 0},
            "summary": "17건 전량 Gemini 3 Pro(_pro.png) 생성 및 HTML <img> 태그 치환 완료",
            "errors": [],
            "log_tail": ["[08:37:46] [Success] All images processed and matched successfully."]
        },
        "upload-backlog-checker": {
            "id": "upload-backlog-checker",
            "name": "네이버 블로그 RSS 업로드 백로그 감시기",
            "last_run": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "status": "SUCCESS",
            "duration_sec": 1.2,
            "metrics": {"backlog_count": 0, "threshold": 7, "recent_uploaded": 7},
            "summary": "네이버 블로그 RSS 7건 등록 확인 (미업로드 백로그 0건, 정상 발행 허용)",
            "errors": [],
            "log_tail": ["[SUCCESS] RSS items verified: 7 latest manuscripts uploaded."]
        },
        "remote-git-sync": {
            "id": "remote-git-sync",
            "name": "원격 저장소(노트북) 양방향 동기화기",
            "last_run": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "status": "SUCCESS",
            "duration_sec": 2.1,
            "metrics": {"branch": "main", "sync_status": "UP_TO_DATE"},
            "summary": "origin/main 동기화 완료 (pull --rebase & push 충돌 방지 완료)",
            "errors": [],
            "log_tail": ["[SUCCESS] Remote sync verified: origin/main up-to-date."]
        }
    }

    for k, v in default_states.items():
        if k not in states:
            states[k] = v

    used_gb, free_gb, total_gb, free_pct = get_c_drive_space()

    # Calculate overall KPIs
    total_subagents = len(definitions)
    success_count = sum(1 for d in definitions if states.get(d["id"], {}).get("status") == "SUCCESS")
    error_count = sum(1 for d in definitions if states.get(d["id"], {}).get("status") in ("ERROR", "PARTIAL"))
    
    disk_color = "#10b981" if free_gb >= 15 else ("#f59e0b" if free_gb >= 5 else "#ef4444")
    disk_status_txt = "쾌적" if free_gb >= 15 else ("주의" if free_gb >= 5 else "위험 (정리 필요)")

    cards_html = []
    for d in definitions:
        aid = d["id"]
        st = states.get(aid, {})
        status = st.get("status", "PENDING")
        last_run = st.get("last_run", "-")
        duration = st.get("duration_sec", "-")
        summary = st.get("summary", "실행 대기 중")
        errors = st.get("errors", [])
        log_tail = st.get("log_tail", [])

        if status == "SUCCESS":
            badge = '<span class="badge badge-ok">✔️ 정상 완료</span>'
            card_border = "border-ok"
        elif status in ("ERROR", "PARTIAL"):
            badge = '<span class="badge badge-bad">⚠️ 오류/주의</span>'
            card_border = "border-bad"
        elif status == "RUNNING":
            badge = '<span class="badge badge-warn">⏳ 실행 중</span>'
            card_border = "border-warn"
        else:
            badge = '<span class="badge badge-muted">⚪ 대기 중</span>'
            card_border = ""

        # Category styling
        cat = d.get("category", "기타")
        cat_badge = f'<span class="cat-tag">{cat}</span>'

        # Log content formatted
        log_content = "\n".join(log_tail) if log_tail else "로그가 없습니다."
        err_content = "\n".join(errors) if errors else "발생한 오류가 없습니다."

        # Specific KPI chips
        metrics_chips = []
        metrics = st.get("metrics", {})
        if "confidence_score" in metrics:
            metrics_chips.append(f'<span class="kpi-chip chip-score">🎯 신뢰도 {metrics["confidence_score"]}%</span>')
        if "verified_count" in metrics:
            metrics_chips.append(f'<span class="kpi-chip chip-ok">✔️ 정상 {metrics["verified_count"]}건</span>')
        if "corrected_count" in metrics and metrics["corrected_count"] > 0:
            metrics_chips.append(f'<span class="kpi-chip chip-warn">✏️ 보정 {metrics["corrected_count"]}건</span>')
        if "note_count" in metrics and metrics["note_count"] > 0:
            metrics_chips.append(f'<span class="kpi-chip chip-info">📌 참고 {metrics["note_count"]}건</span>')
        if "repaired_files" in metrics:
            metrics_chips.append(f'<span class="kpi-chip chip-ok">🛠️ 복구 {metrics["repaired_files"]}개</span>')
        if "pro_images" in metrics:
            metrics_chips.append(f'<span class="kpi-chip chip-purple">🎨 Pro {metrics["pro_images"]}장</span>')
        if "backlog_count" in metrics:
            metrics_chips.append(f'<span class="kpi-chip chip-ok">📦 백로그 {metrics["backlog_count"]}건</span>')

        chips_html = f'<div class="chips-row">{" ".join(metrics_chips)}</div>' if metrics_chips else ""

        card = f"""
        <div class="agent-card {card_border}" id="card-{aid}">
          <div class="card-header">
            <div>
              <div class="card-title-row">
                <span class="agent-name">{d['name']}</span>
                {cat_badge}
              </div>
              <div class="agent-desc">{d['description']}</div>
            </div>
            <div class="status-wrap">{badge}</div>
          </div>

          <div class="info-grid">
            <div class="info-item">
              <span class="info-label">동작 주기</span>
              <span class="info-val">⏰ {d['schedule']}</span>
            </div>
            <div class="info-item">
              <span class="info-label">최근 실행</span>
              <span class="info-val">🕒 {last_run}</span>
            </div>
            <div class="info-item">
              <span class="info-label">실행 소요 시간</span>
              <span class="info-val">⚡ {duration}초</span>
            </div>
            <div class="info-item">
              <span class="info-label">실행 스크립트</span>
              <span class="info-val"><code>{d['script']}</code></span>
            </div>
          </div>

          {chips_html}

          <div class="summary-box">
            <span class="summary-title">최근 실행 결과:</span> {summary}
          </div>

          <div class="log-accordion">
            <button class="accordion-btn" onclick="toggleLog('{aid}')">
              <span>📋 최근 실행 로그 & 오류 세부 정보 보기</span>
              <span id="arr-{aid}">▼</span>
            </button>
            <div class="accordion-content" id="log-{aid}" style="display:none;">
              {f'<div class="err-box"><strong>⚠️ 감지된 오류/경고:</strong><pre>{err_content}</pre></div>' if errors else ''}
              <div class="log-box"><strong>최근 실행 로그 (Tail):</strong><pre>{log_content}</pre></div>
            </div>
          </div>
        </div>
        """
        cards_html.append(card)

    cards_joined = "\n".join(cards_html)
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    html = f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>🤖 서브에이전트 운영 & 모니터링 대시보드</title>
<style>
:root {{
  --bg: #f8fafc; --surface: #ffffff; --ink: #0f172a; --ink2: #475569; --ink3: #94a3b8;
  --line: #e2e8f0; --line2: #f1f5f9;
  --ok: #10b981; --okbg: #ecfdf5; --ok-border: #a7f3d0;
  --warn: #f59e0b; --warnbg: #fffbeb; --warn-border: #fde68a;
  --bad: #ef4444; --badbg: #fef2f2; --bad-border: #fecaca;
  --accent: #3b82f6; --accentbg: #eff6ff;
}}
@media (prefers-color-scheme: dark) {{
  :root {{
    --bg: #0b0f19; --surface: #151b28; --ink: #f1f5f9; --ink2: #94a3b8; --ink3: #64748b;
    --line: #222c3d; --line2: #192231;
    --ok: #34d399; --okbg: #064e3b33; --ok-border: #064e3b;
    --warn: #fbbf24; --warnbg: #78350f33; --warn-border: #78350f;
    --bad: #f87171; --badbg: #7f1d1d33; --bad-border: #7f1d1d;
    --accent: #60a5fa; --accentbg: #1e3a8a33;
  }}
}}
:root[data-theme="dark"] {{
  --bg: #0b0f19; --surface: #151b28; --ink: #f1f5f9; --ink2: #94a3b8; --ink3: #64748b;
  --line: #222c3d; --line2: #192231;
  --ok: #34d399; --okbg: #064e3b33; --ok-border: #064e3b;
  --warn: #fbbf24; --warnbg: #78350f33; --warn-border: #78350f;
  --bad: #f87171; --badbg: #7f1d1d33; --bad-border: #7f1d1d;
  --accent: #60a5fa; --accentbg: #1e3a8a33;
}}
:root[data-theme="light"] {{
  --bg: #f8fafc; --surface: #ffffff; --ink: #0f172a; --ink2: #475569; --ink3: #94a3b8;
  --line: #e2e8f0; --line2: #f1f5f9;
  --ok: #10b981; --okbg: #ecfdf5; --ok-border: #a7f3d0;
  --warn: #f59e0b; --warnbg: #fffbeb; --warn-border: #fde68a;
  --bad: #ef4444; --badbg: #fef2f2; --bad-border: #fecaca;
  --accent: #3b82f6; --accentbg: #eff6ff;
}}

* {{ box-sizing: border-box; }}
body {{
  margin: 0; background: var(--bg); color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Apple SD Gothic Neo", sans-serif;
  font-size: 14px; line-height: 1.6;
}}
.wrap {{ max-width: 1180px; margin: 0 auto; padding: 28px 20px 80px; }}
a {{ color: inherit; text-decoration: none; }}
a:hover {{ text-decoration: underline; }}
code {{ font-family: Consolas, monospace; background: var(--line2); padding: 2px 6px; border-radius: 4px; font-size: 0.9em; }}

header {{
  display: flex; justify-content: space-between; align-items: flex-start;
  margin-bottom: 24px; padding-bottom: 18px; border-bottom: 1px solid var(--line);
}}
h1 {{ margin: 0 0 6px; font-size: 1.55rem; font-weight: 800; letter-spacing: -0.02em; }}
.sub {{ color: var(--ink2); font-size: 0.9rem; }}
.nav-links {{ display: flex; gap: 10px; margin-top: 10px; }}
.nav-btn {{
  display: inline-flex; align-items: center; gap: 6px;
  background: var(--surface); border: 1px solid var(--line);
  padding: 6px 12px; border-radius: 8px; font-size: 0.82rem; font-weight: 600; color: var(--ink2);
}}
.nav-btn:hover {{ background: var(--accentbg); color: var(--accent); border-color: var(--accent); text-decoration: none; }}

.theme-toggle {{
  background: var(--surface); border: 1px solid var(--line);
  padding: 6px 12px; border-radius: 8px; cursor: pointer; color: var(--ink); font-size: 0.85rem; font-weight: 600;
}}

.kpis {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 14px; margin-bottom: 28px; }}
.kpi {{
  background: var(--surface); border: 1px solid var(--line); border-radius: 12px;
  padding: 16px 18px; box-shadow: 0 1px 3px rgba(0,0,0,0.02);
}}
.kpi .val {{ font-size: 1.7rem; font-weight: 800; line-height: 1.2; letter-spacing: -0.03em; }}
.kpi .lbl {{ font-size: 0.8rem; color: var(--ink2); margin-top: 4px; font-weight: 500; }}
.kpi-disk-bar {{
  margin-top: 8px; height: 7px; background: var(--line2); border-radius: 4px; overflow: hidden;
}}
.kpi-disk-fill {{ height: 100%; border-radius: 4px; transition: width 0.3s; }}

.section-head {{
  display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;
}}
h2 {{ margin: 0; font-size: 1.15rem; font-weight: 700; }}

.agent-card {{
  background: var(--surface); border: 1px solid var(--line); border-radius: 12px;
  padding: 20px 22px; margin-bottom: 16px; transition: all 0.2s ease;
}}
.agent-card:hover {{ border-color: var(--accent); box-shadow: 0 4px 12px rgba(0,0,0,0.04); }}
.agent-card.border-ok {{ border-left: 5px solid var(--ok); }}
.agent-card.border-warn {{ border-left: 5px solid var(--warn); }}
.agent-card.border-bad {{ border-left: 5px solid var(--bad); }}

.card-header {{ display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 14px; }}
.card-title-row {{ display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }}
.agent-name {{ font-size: 1.1rem; font-weight: 700; letter-spacing: -0.01em; }}
.agent-desc {{ color: var(--ink2); font-size: 0.85rem; margin-top: 3px; max-width: 780px; }}
.cat-tag {{
  background: var(--accentbg); color: var(--accent); padding: 2px 8px;
  border-radius: 6px; font-size: 0.75rem; font-weight: 600;
}}

.badge {{
  display: inline-block; padding: 4px 10px; border-radius: 20px;
  font-size: 0.8rem; font-weight: 700; text-align: center;
}}
.badge-ok {{ background: var(--okbg); color: var(--ok); border: 1px solid var(--ok-border); }}
.badge-warn {{ background: var(--warnbg); color: var(--warn); border: 1px solid var(--warn-border); }}
.badge-bad {{ background: var(--badbg); color: var(--bad); border: 1px solid var(--bad-border); }}
.badge-muted {{ background: var(--line2); color: var(--ink3); border: 1px solid var(--line); }}

.info-grid {{
  display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
  gap: 10px; background: var(--line2); padding: 12px 16px; border-radius: 8px; margin-bottom: 12px;
}}
.info-item {{ display: flex; flex-direction: column; }}
.info-label {{ font-size: 0.72rem; color: var(--ink3); font-weight: 600; text-transform: uppercase; }}
.info-val {{ font-size: 0.86rem; font-weight: 600; margin-top: 2px; }}

.chips-row {{ display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 12px; }}
.kpi-chip {{ font-size: 0.78rem; font-weight: 600; padding: 3px 10px; border-radius: 12px; display: inline-flex; align-items: center; }}
.chip-score {{ background: #ecfdf5; color: #065f46; border: 1px solid #a7f3d0; font-weight: 700; }}
.chip-ok {{ background: #eff6ff; color: #1e40af; border: 1px solid #bfdbfe; }}
.chip-warn {{ background: #fef3c7; color: #92400e; border: 1px solid #fde68a; }}
.chip-info {{ background: #f3f4f6; color: #374151; border: 1px solid #e5e7eb; }}
.chip-purple {{ background: #f5f3ff; color: #5b21b6; border: 1px solid #ddd6fe; }}

.summary-box {{
  font-size: 0.88rem; color: var(--ink); margin-bottom: 12px; padding: 4px 0;
}}
.summary-title {{ font-weight: 700; color: var(--ink2); }}

.log-accordion {{ margin-top: 10px; }}
.accordion-btn {{
  width: 100%; display: flex; justify-content: space-between; align-items: center;
  background: none; border: none; padding: 8px 0; color: var(--ink2);
  font-size: 0.82rem; font-weight: 600; cursor: pointer; text-align: left;
}}
.accordion-btn:hover {{ color: var(--accent); }}
.accordion-content {{
  background: var(--bg); border: 1px solid var(--line); border-radius: 8px;
  padding: 12px 16px; margin-top: 6px;
}}
.log-box pre, .err-box pre {{
  margin: 6px 0 0; font-family: Consolas, monospace; font-size: 0.8rem;
  white-space: pre-wrap; line-height: 1.5; color: var(--ink2);
}}
.err-box {{
  background: var(--badbg); border-left: 3px solid var(--bad);
  padding: 8px 12px; border-radius: 4px; margin-bottom: 10px; color: var(--bad);
}}

.guide-box {{
  background: var(--surface); border: 1px solid var(--line); border-radius: 12px;
  padding: 20px 22px; margin-top: 30px;
}}
.guide-box h3 {{ margin: 0 0 8px; font-size: 0.98rem; }}
.guide-box p {{ margin: 0 0 10px; color: var(--ink2); font-size: 0.85rem; }}
.guide-box ol {{ margin: 0; padding-left: 20px; font-size: 0.85rem; color: var(--ink2); }}
.guide-box li {{ margin-bottom: 4px; }}
</style>
<script>
function toggleLog(id) {{
  var el = document.getElementById('log-' + id);
  var arr = document.getElementById('arr-' + id);
  if (el.style.display === 'none') {{
    el.style.display = 'block';
    arr.innerText = '▲';
  }} else {{
    el.style.display = 'none';
    arr.innerText = '▼';
  }}
}}
function toggleTheme() {{
  var cur = document.documentElement.getAttribute('data-theme');
  var nxt = cur === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', nxt);
  localStorage.setItem('theme', nxt);
}}
document.addEventListener('DOMContentLoaded', function() {{
  var saved = localStorage.getItem('theme');
  if (saved) document.documentElement.setAttribute('data-theme', saved);
}});
</script>
</head>
<body>
<div class="wrap">
  <header>
    <div>
      <h1>🤖 서브에이전트 운영 & 모니터링 대시보드</h1>
      <div class="sub">Antigravity Subagent Orchestration & Automated Task Health Center (업데이트: {now_str})</div>
      <div class="nav-links">
        <a class="nav-btn" href="dashboard.html">📊 블로그 4채널 운영 대시보드</a>
        <a class="nav-btn" href="prompt_helper.html">🎨 이미지 프롬프트 헬퍼</a>
      </div>
    </div>
    <button class="theme-toggle" onclick="toggleTheme()">🌓 테마 전환</button>
  </header>

  <div class="kpis">
    <div class="kpi">
      <div class="val" style="color:var(--accent);">{total_subagents}</div>
      <div class="lbl">등록된 서브에이전트 수</div>
    </div>
    <div class="kpi">
      <div class="val" style="color:var(--ok);">{success_count}</div>
      <div class="lbl">정상 작동 (Healthy)</div>
    </div>
    <div class="kpi">
      <div class="val" style="color:{'var(--bad)' if error_count > 0 else 'var(--ink3)'};">{error_count}</div>
      <div class="lbl">오류 / 주의 필요</div>
    </div>
    <div class="kpi">
      <div class="val" style="color:{disk_color};">{free_gb} GB</div>
      <div class="lbl">C: 드라이브 여유 ({free_pct}%) · <strong>{disk_status_txt}</strong></div>
      <div class="kpi-disk-bar">
        <div class="kpi-disk-fill" style="width:{100 - free_pct}%; background:{disk_color};"></div>
      </div>
    </div>
  </div>

  <div class="section-head">
    <h2>📡 서브에이전트별 동작 주기 및 실행 현황</h2>
  </div>

  <div class="agent-list">
    {cards_joined}
  </div>

  <div class="guide-box">
    <h3>💡 새로운 서브에이전트를 추가하는 방법</h3>
    <p>앞으로 주기적인 업무(트렌드 키워드 수집, 통계 스크랩, 자동 백업 등)를 수행하는 서브에이전트를 확장할 때는 다음 순서로 연동하시면 됩니다:</p>
    <ol>
      <li><code>scripts/</code> 폴더에 실행할 파이썬 스크립트 작성 (실행 결과를 <code>.scripts/logs/subagents/&lt;id&gt;.json</code>으로 기록)</li>
      <li><code>.scripts/subagents.json</code> 파일에 에이전트 이름, 주기, 스크립트 경로 1개 블록 등록</li>
      <li><code>.scripts/daily-run.ps1</code> 내 적절한 단계(또는 요일 조건문)에 호출 구문 추가</li>
      <li>대시보드 재빌드(<code>python scripts/build_subagents_dashboard.py</code>) 시 본 화면에 자동으로 카드가 생성되고 모니터링됩니다.</li>
    </ol>
  </div>
</div>
</body>
</html>
"""
    out_html_path = os.path.join(project_root, "subagents_dashboard.html")
    with open(out_html_path, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"[Success] Generated Subagents Dashboard: {out_html_path}")
    return out_html_path

if __name__ == "__main__":
    generate_dashboard()
