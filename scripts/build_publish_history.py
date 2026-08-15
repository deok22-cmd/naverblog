# -*- coding: utf-8 -*-
"""
발행이력.md 생성·병합기 — output/ 폴더를 지워도 "무엇을 이미 썼는지"가 남게 한다.

  python scripts/build_publish_history.py

동작
  1. output/<YYMMDD>/*.html 을 스캔해 (발행일, 계열, slug, 제목)을 추출
  2. 기존 발행이력.md 를 읽어 **병합**한다 — 기존 행은 절대 지우지 않는다(멱등)
     → output/ 이 이미 정리된 과거 날짜도 이력에는 계속 남는다
  3. 계열별 집계 + 날짜 내림차순 표로 다시 쓴다

이 파일이 주제 중복 판정의 백데이터다. 큐 리필·주제 선정 시 여기서 먼저 검색한다.
"""
import os, re, io, sys
from collections import Counter, OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT  = os.path.join(ROOT, "output")
HIST = os.path.join(ROOT, "발행이력.md")

CAT = {
    "travel": "국내여행", "local": "인접·여행실무", "rite": "경조사", "car": "자동차",
    "recipe": "레시피", "house": "전원주택", "tech": "기기·IT실무",
    "gov": "지원금", "appli": "계절가전", "cert": "증명서(폐지)",
    "admin": "행정발급", "money": "재테크(폐지)", "home": "집·인테리어",
}

ROW = re.compile(r"^\|\s*(\d{2}\.\d{2}\.\d{2})\s*\|\s*([^|]*?)\s*\|\s*`([^`]+)`\s*\|\s*(.*?)\s*\|\s*$")


def h1(path):
    try:
        with io.open(path, encoding="utf-8", errors="ignore") as f:
            m = re.search(r"<h1[^>]*>(.*?)</h1>", f.read(), re.S)
        if m:
            t = re.sub(r"<[^>]+>", "", m.group(1))
            t = (t.replace("&ndash;", "-").replace("&mdash;", "-")
                  .replace("&amp;", "&").replace("&lsquo;", "'").replace("&rsquo;", "'")
                  .replace("&ldquo;", '"').replace("&rdquo;", '"').replace("&nbsp;", " "))
            return re.sub(r"\s+", " ", t).strip()
    except Exception:
        pass
    return ""


def load_existing():
    """기존 이력 → {(날짜6, slug): (계열, 제목)}"""
    rows = {}
    if not os.path.exists(HIST):
        return rows
    with io.open(HIST, encoding="utf-8") as f:
        for line in f:
            m = ROW.match(line.rstrip("\n"))
            if not m:
                continue
            d, cat, slug, title = m.groups()
            if slug in ("slug",):
                continue
            rows[(d.replace(".", ""), slug)] = (cat, title)
    return rows


def scan_output():
    rows = {}
    if not os.path.isdir(OUT):
        return rows
    for d in sorted(os.listdir(OUT)):
        if not re.fullmatch(r"\d{6}", d):
            continue
        p = os.path.join(OUT, d)
        for fn in sorted(os.listdir(p)):
            if not fn.endswith(".html") or fn == "index.html":
                continue
            slug = fn[:-5]
            pre = slug.split("_")[0]
            rows[(d, slug)] = (CAT.get(pre, pre), h1(os.path.join(p, fn)))
    return rows


def main():
    old = load_existing()
    new = scan_output()
    added = [k for k in new if k not in old]
    merged = dict(old)
    for k, v in new.items():
        # 제목이 새로 확인되면 갱신, 기존 행은 유지
        if k not in merged or (v[1] and not merged[k][1]):
            merged[k] = v

    keys = sorted(merged.keys(), key=lambda k: (k[0], k[1]), reverse=True)

    by_cat = Counter(merged[k][0] for k in keys)
    by_year_month = Counter(k[0][:4] for k in keys)

    L = []
    L.append("# 발행 이력 (주제 선정·중복 방지 백데이터)\n")
    L.append("> `output/<YYMMDD>/` 원고 HTML을 정리해도 **무엇을 이미 썼는지**가 남도록 추출해 둔 색인이다.")
    L.append("> 주제를 새로 고르거나 큐를 리필할 때 **여기서 먼저 검색해 중복을 확인**한다.")
    L.append("> 생성·갱신: `python scripts/build_publish_history.py` (멱등 — 기존 행은 지우지 않고 병합)")
    L.append("> ⚠️ 이 파일은 **삭제 금지.** output/ 이 정리된 과거 날짜는 이 파일에만 기록이 남는다.\n")
    L.append(f"**총 {len(keys)}건** · 최근 발행 {keys[0][0] if keys else '-'} · 최초 {keys[-1][0] if keys else '-'}\n")

    L.append("## 계열별 누적\n")
    L.append("| 계열 | 건수 |")
    L.append("|:--|--:|")
    for c, n in by_cat.most_common():
        L.append(f"| {c} | {n} |")
    L.append("")

    L.append("## 월별 발행량\n")
    L.append("| 연월 | 건수 |")
    L.append("|:--|--:|")
    for ym in sorted(by_year_month, reverse=True):
        L.append(f"| 20{ym[:2]}-{ym[2:]} | {by_year_month[ym]} |")
    L.append("")

    L.append("## 전체 이력 (발행일 내림차순)\n")
    L.append("| 발행일 | 계열 | slug | 제목 |")
    L.append("|:--|:--|:--|:--|")
    for k in keys:
        d, slug = k
        cat, title = merged[k]
        L.append(f"| {d[:2]}.{d[2:4]}.{d[4:]} | {cat} | `{slug}` | {title} |")
    L.append("")

    with io.open(HIST, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))

    print(f"발행이력.md 갱신: 총 {len(keys)}건 (기존 {len(old)} + 신규 {len(added)})")
    if added:
        for k in sorted(added, reverse=True)[:5]:
            print(f"  + {k[0]} {k[1]}")
        if len(added) > 5:
            print(f"  ... 외 {len(added)-5}건")


if __name__ == "__main__":
    main()
