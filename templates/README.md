# 네이버 원고 표준 템플릿 — Platinum v5 (SSOT)

⛔ 이 디렉터리의 `naver_v5.html` 내 `<style>` 블록·`<script>` 블록·마크업 구조는 그대로 복사해서 쓴다.
CSS 속성값을 임의로 바꾸거나, 새 클래스를 만들거나, 레이아웃을 새로 디자인하지 않는다.
(2026-08-16 지시: 매일 디자인이 바뀌어 가독성이 떨어지는 문제를 막기 위함)

## 치환 토큰 — 카테고리 컬러 세트

| slug prefix                                              | ACCENT  | DARK    | TINT    | BORDER  | SOFT    | EVEN    |
|----------------------------------------------------------|---------|---------|---------|---------|---------|---------|
| travel_ (국내여행)                                        | #00796b | #004d40 | #e0f2f1 | #b2dfdb | #f9fdf9 | #f1faf9 |
| recipe_ (음식·레시피)                                     | #e64a19 | #bf360c | #fbe9e7 | #ffccbc | #fffaf8 | #fff5f2 |
| 그 외 생활정보 (local_ car_ rite_ tech_ gov_ money_       | #388e3c | #1b5e20 | #e8f5e9 | #c8e6c9 | #f9fdf9 | #f1faf1 |
|  home_ house_ admin_ appli_ cert_ …)                     |         |         |         |         |         |         |

## 구조 규칙
- `naver_v5.html` 파일은 **반드시 1번째 줄 `<!DOCTYPE html>`**로 시작한다 (앞단에 HTML 주석 `<!-- ... -->` 삽입 금지).
- `<body>` 직속으로 `<h1>`, `.intro-box`, `.img-area`, `<h2>`/`<h3>`, `.info-table`, `.step-box`, `.tip-box`, `.warn-box`, `.recommend-area`, `.tags` 만 배치
- `.wrap` 같은 바깥 감싸는 div를 두지 않는다.
- 마크다운 `**` 대신 `<strong>` 태그를 쓴다.
- 문단 구분은 `<br><br>` 로 한다.
- 마지막은 반드시 `</body></html>`로 닫는다.
