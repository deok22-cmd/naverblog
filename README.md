# 📌 naverblog 프로젝트 지도 (2026-07-09)

> **이 파일이 진입점입니다.** 뭐가 뭔지 헷갈리면 여기부터 보세요.
> 콘텐츠 3채널 운영 프로젝트 — 네이버(자동) + 티스토리·인스타(수동).

---

## 🎯 3채널 한눈에

| 채널 | 방식 | 트리거 | 목적 | 산출물 |
|:---|:---|:---|:---|:---|
| **네이버 블로그** | 🤖 매일 새벽 4시 **자동** 7건 | 무인(작업 스케줄러) | 검색 트래픽 성장(1차 목표 일 1만) | `output/<YYMMDD>/` |
| **티스토리** | ✋ **수동** 애드센스 원고 1건 | `adsense_src/`에 사진+메모 올리고 요청 | 애드센스 승인(진짜 사진·경험) | `output_adsense/<YYMMDD>_<slug>/` |
| **인스타** | ✋ **수동** 카드뉴스 1세트 | 위와 동일 소스 | 브랜딩·유입(티스토리 연계) | `output_insta/<YYMMDD>/<slug>/` |

- **네이버**는 알아서 돕니다(건드릴 필요 X).
- **티스토리·인스타**는 `adsense_src/<날짜>/`에 사진+경험 메모 올리고 "만들어줘" 하면 제작.
- 인스타 계정: **김포 맛집 노트** `@gimpo.matjip.note`(여행 계정 "국내여행 365"의 자매 채널). 상세 `티스토리_애드센스_제작.md`.

---

## ⛔ 건드리면 안 되는 것 (load-bearing — 옮기거나 이름 바꾸면 파이프라인 깨짐)

파이프라인이 전부 **상대경로**로 물려 있어, 아래는 그대로 둡니다:

- `.scripts/daily-run.ps1` · `daily-prompt.md` · `tistory-gate.ps1` — 자동 발행 + 게이트
- `국내여행지.md` · `생활정보.md` — 발행 큐 DB(파이프라인이 매일 읽음)
- `scripts/fix_tistory_violations.py` · `insta_render.mjs` · `insta_rasterize.mjs` · `build_matjip_insta_v2.mjs`(맛집 인스타 표준·photo-first) · `build_profile.mjs`
- `.claude/agents/*` — 서브에이전트 정의
- `Naverblog.md` — 원고 템플릿/규칙 원본

---

## 📁 폴더 용도

| 폴더 | 용도 | 성격 |
|:---|:---|:---|
| `.scripts/` | 자동 파이프라인(ps1·프롬프트·게이트) | 🔧 핵심 |
| `scripts/` | 유틸(인스타 렌더·티스토리 복구·이미지) | 🔧 핵심 |
| `output/` | 네이버 원고(자동) | 산출물 |
| `output_tistory/` | 티스토리 자동 미러(⛔2026-07-09 자동 중단, 레거시) | 레거시 |
| `output_adsense/` | 티스토리 애드센스 원고(수동·진짜 후기) | 산출물(신규) |
| `output_insta/` | 인스타 카드(SVG+PNG+캡션). `_layouts/`=템플릿 표준 | 산출물 |
| `adsense_src/<YYMMDD>/` | 수동 콘텐츠 **소스**(사용자 실사진+메모) | 입력 |
| `images/` | 네이버 원고 이미지 | 산출물 |
| `stats/` | 조회수·수익 분석(스냅샷·주간분석·운영원칙·로드맵) | 분석 |
| `output_coupang/` | 쿠팡 파트너스(휴면). `coupang_partners.md`가 참조 → 보존 | 휴면 |
| `logs/` · `.scripts/logs/` | 실행 로그 | 로그 |
| `node_modules/` | 의존성(puppeteer-core) | 시스템 |
| `_archive/` | 미사용 잔재 보관(삭제 아님) | 🗄️ 아카이브 |

> 🗄️ **아카이브 완료(2026-07-09)** — 자동 파이프라인 미참조·3~4월 잔재를 `_archive/`로 이동: `output_sub1` · `output_텐트깔끄미` · `images_sub1` · `images_텐트깔끄미` · `output_figma` · `_preview` + `Naverblog_backup_20260402.md` · `Naverblog_new.md`. ※ `output_coupang`은 `coupang_partners.md`가 참조 중이라 **제외(보존)**. ⚠️ 유틸 `scripts/embed_svg.py`는 텐트깔끄미/figma 경로를 참조하니 재실행 시 경로 수정 필요(비활성 유틸이라 무방).

---

## 📄 루트 문서 용도

| 문서 | 용도 |
|:---|:---|
| `README.md` | **이 지도** |
| `Naverblog.md` | 원고 템플릿·규칙 원본(핵심) |
| `국내여행지.md` / `생활정보.md` | 여행/생활 발행 큐 DB(핵심) |
| `티스토리_애드센스_제작.md` | 수동 티스토리+인스타 제작 워크플로(§6~7 채널맵) |
| `티스토리수동작성.md` | 수동 vlog 톤 가이드(별도) |
| `insta_card_pipeline.md` | 인스타 카드 파이프라인 상세 |
| `조회수분석.md` · `festival.md` · `1만명_달성_액션플랜.md` | 참고 자료 |
| `원고이미지자동생성요청.md` · `coupang_partners.md` | 참고/보조 |
| `sub_topic_tracker.md` · `spreadsheet.md` · `receipt.md` · `trackabc.md` | 🔒 **동결(수정 금지)** — 옛 트래커, 그냥 둠 |
| ~~`Naverblog_backup_20260402.md` · `Naverblog_new.md`~~ | 🗄️ `_archive/`로 이동됨(2026-07-09) |

> 📊 `stats/` 안: `운영원칙_조회수기반_*.md`(원칙) · `성장로드맵_*.md`(1만 로드맵) · `분석_*.md`/`*.html`(주간 분석) · `weekly/`·`daily/`(캡처 JSON).

---

## 🧭 앞으로 깔끔하게 유지하는 습관

1. **임시·실험 파일은 루트에 두지 않기** — 스크래치패드나 `_experiments/`에.
2. **폴더 구조를 바꾸기 전 확인** — 상대경로로 물린 게 많아, 옮기면 파이프라인이 깨질 수 있음. "이거 옮겨도 되나?" 먼저.
3. **새 채널·규칙이 생기면 이 README를 갱신** — 지도를 항상 최신으로.

---
*메모리 인덱스: `.claude/projects/.../memory/MEMORY.md`. 주요 전략: [[project_growth_100k]]·[[project_stats_analysis_pipeline]]·[[feedback_tistory_eeat_adsense]].*
