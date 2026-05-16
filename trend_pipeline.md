# 트렌드 기반 블로그 파이프라인 (수동 실행 플레이북) v1.0

> 작성일: 2026-05-12
> 출력 폴더: `./output_trend/`
> 기존 시스템(`output/`, `output_tistory/`)과 **완전 분리** 운영

---

## 0 | 개요

본 파이프라인은 Sometrend MCP의 실시간 SNS·블로그 버즈 데이터를 분석해 **'지금 검색량이 급상승하는 주제'** 를 발굴하고, 그 주제로 매일 1건씩 트렌드 원고를 작성합니다.

기존의 `국내여행지.md`·`spreadsheet.md`·`receipt.md` 기반 발행과는 별개로, **추가 채널** 로 운영합니다.

```
┌──────────────────────────────────────────────────────────────┐
│  Sometrend MCP                                               │
│   ↓ 버즈데이터 분석                                          │
│  trend-scout (서브에이전트)                                  │
│   ↓ 핫 키워드 + 연관어 JSON 반환                             │
│  trend-curator (서브에이전트)                                │
│   ↓ 7일치 발행 캘린더 생성                                   │
│  output_trend/weekly_topics_<YYMMDD>.md                      │
│   ↓ 매일 1건씩 호출                                          │
│  trend-writer (서브에이전트)                                 │
│   ↓ Naverblog.md v5 준수한 HTML 생성                         │
│  output_trend/<YYMMDD>/<slug>.html  (하루 1개)               │
└──────────────────────────────────────────────────────────────┘
```

---

## 1 | 사전 준비 (1회)

### 1.1 폴더 구조 확인
```
naverblog/
├── .claude/
│   └── agents/
│       ├── trend-scout.md      ← Sometrend 분석
│       ├── trend-curator.md    ← 주제 큐레이션
│       └── trend-writer.md     ← 원고 작성
├── output_trend/
│   ├── used_topics.json        ← 자동 생성 (중복 방지 트래커)
│   ├── weekly_topics_YYMMDD.md ← 주별 1회 생성
│   └── YYMMDD/                 ← 일별 폴더
│       └── trend_<slug>.html
└── trend_pipeline.md           ← 본 문서
```

### 1.2 Sometrend MCP 크레딧 확인
- Claude Code에서 다음 입력:
  ```
  Sometrend 크레딧 잔량 확인해줘
  ```
- 권장 잔량: 주간 분석 1회당 **약 5~10 크레딧** 소모 예상. 월 4회 분석 기준 40 크레딧/월 확보 권장.

---

## 2 | 주간 트렌드 분석 (주 1회 — 보통 일요일/월요일)

### 2.1 1단계: 트렌드 감지

Claude Code에 다음 중 한 가지 방식으로 입력합니다.

**방식 A — 자연어 호출 (권장)**
```
trend-scout 에이전트로 지난 7일간(2026-05-06~05-12) 한국 SNS·블로그 버즈 트렌드 분석해줘.
카테고리는 여행/축제/맛집/생활 위주로, 크레딧 5회 이내 사용.
```

**방식 B — 명시적 호출**
```
@agent-trend-scout 최근 일주일 트렌드 분석. 분석기간 20260506~20260512, 5월 가정의달 후반부 키워드 집중.
```

**산출물 (서브에이전트가 채팅으로 반환)**:
- 급상승 키워드 Top 5~10
- 각 키워드의 연관어
- 블로그 주제 후보
- 사용한 크레딧 + 잔량

### 2.2 2단계: 주간 주제 리스트 생성

위 분석 결과를 받은 직후, 같은 세션에서 이어서 입력:

```
trend-curator 에이전트로 위 분석 결과 받아서 7일치 발행 캘린더 만들어줘.
오늘은 2026-05-12 월요일이고, 5/13~5/19까지 7건 분배. 출력은 output_trend/에 저장.
```

**산출물 (파일 2개)**:
- `output_trend/weekly_topics_260512.md` — 발행 캘린더 표
- `output_trend/used_topics.json` — 누적 트래커 (자동 생성/갱신)

**확인 포인트**:
- 7개 주제 모두 빅+미들+롱테일 3단 구조인가?
- 카테고리 분배 비율 (여행 3 / 생활 2 / 시즌 1 / 라이프 1) 맞는가?
- 기존 `국내여행지.md`·`festival.md`와 중복 없는가?

---

## 3 | 일별 원고 작성 (매일 1회)

### 3.1 오늘의 원고 작성

매일 한 번, 다음과 같이 입력:

```
trend-writer 에이전트로 오늘(2026-05-13)의 트렌드 원고 1건 작성해줘.
weekly_topics_260512.md의 Day 1 주제 사용. 출력은 output_trend/260513/에 저장.
```

또는 더 간단히:
```
오늘의 트렌드 원고 1건 작성. weekly_topics 1번 주제.
```
(이 경우 Claude가 trend-writer description 매칭으로 자동 위임)

### 3.2 작성 후 확인 사항

서브에이전트가 보고하는 내용:
- 생성된 파일 경로 (예: `output_trend/260513/trend_yangyang_solbeach_2026.html`)
- 글자 수 (목표: 1.5만 자 내외)
- `<h2>` 꼭지 개수 (≥ 9)
- 자가 검증 통과 여부

브라우저에서 직접 열어 시각 확인:
```
start "" "D:\0. LAMP\naverblog\output_trend\260513\trend_yangyang_solbeach_2026.html"
```

### 3.3 다음 날 원고

다음 날도 동일하게:
```
오늘의 트렌드 원고 1건 작성. weekly_topics Day 2 주제.
```

7일이 지나면 다시 2장으로 돌아가 새로운 주간 분석.

---

## 4 | 수동 단계별 명령어 치트시트

| 시점 | 입력 명령어 | 호출되는 에이전트 | 크레딧 |
|------|-------------|-------------------|--------|
| **주 1회** (월요일 아침) | "지난 7일 트렌드 분석해줘" | trend-scout | 4~5 |
| **주 1회** (분석 직후) | "위 결과로 7일치 캘린더 짜줘" | trend-curator | 0 |
| **매일 아침** | "오늘의 트렌드 원고 1건 작성" | trend-writer | 0 |
| **확인** | "Sometrend 잔량" | (직접 MCP 호출) | 0 |

---

## 5 | 출력 파일 명명 규칙

### 5.1 슬러그 (slug) 규칙
- 형식: `trend_<지역or주제>_<핵심키워드>_2026`
- 예시:
  - `trend_yangyang_solbeach_filial_2026.html`
  - `trend_seoul_carnation_diy_2026.html`
  - `trend_jeju_indoor_rainy_2026.html`
- **소문자, 언더스코어 구분, 공백 금지** (티스토리 미러 명명 규칙과 일관성 유지)

### 5.2 폴더
- `output_trend/<YYMMDD>/<slug>.html`
- 예: `output_trend/260513/trend_yangyang_solbeach_filial_2026.html`

---

## 6 | 트래커 파일 구조 (참고)

### 6.1 `weekly_topics_YYMMDD.md`
```markdown
# 트렌드 주간 발행 리스트 (2026-05-13 ~ 2026-05-19)

> 출처: trend-scout 분석 (분석기간: 20260506~20260512)
> 생성일: 2026-05-12 22:30

## 이번 주 트렌드 요약
... (scout가 작성한 trend_summary_korean) ...

## 발행 캘린더

| 발행일 | 카테고리 | 제목 | 슬러그 | 메인키워드 | 트렌드 근거 |
|---|---|---|---|---|---|
| 2026-05-13 (수) | 생활·정보 | 어버이날 효도여행 양양 솔비치 ... | trend_yangyang_solbeach_filial_2026 | 어버이날 효도여행 | 5/8 직전 320% 급증 |
| ... | | | | | |

## 작성 상태
- [ ] Day 1 (2026-05-13): trend_yangyang_solbeach_filial_2026
- [ ] Day 2 (2026-05-14): trend_seoul_carnation_diy_2026
...
```

### 6.2 `used_topics.json`
```json
{
  "2026-05-13": {
    "slug": "trend_yangyang_solbeach_filial_2026",
    "title": "...",
    "main_keyword": "어버이날 효도여행",
    "category": "생활·정보",
    "status": "completed",
    "created_at": "2026-05-13T08:42:00"
  }
}
```

---

## 7 | 크레딧 절약 팁

1. **주간 1회만 분석**: 매일 분석하면 크레딧 폭발. 일요일 저녁 또는 월요일 아침에만 1회.
2. **광범위 키워드부터**: `["여행"]`, `["맛집"]` 같은 큰 카테고리 추이 1~2회로 핫 키워드 도출 후, 그것에만 연관어 호출.
3. **분석 기간 7일 고정**: 30일·90일은 크레딧 더 쓰는 경향. 단기 트렌드 감지가 목표이므로 7일이면 충분.
4. **WebSearch 보완**: Sometrend로 신호만 잡고 디테일은 무료인 WebSearch로 보완.

---

## 8 | 트러블슈팅

### Q. trend-scout 에이전트가 자동으로 호출되지 않아요
- `.claude/agents/trend-scout.md`가 존재하는지 확인
- Claude Code 세션 재시작 (파일 기반 에이전트는 세션 시작 시 로드)
- 명시적으로 `@agent-trend-scout` 또는 `trend-scout 에이전트로` 호출

### Q. Sometrend 크레딧 부족 메시지
- 응답에 표시된 message를 그대로 따름
- 절약 모드: `period: "주별"` 사용, `topN1000: 50` 이하

### Q. 원고가 9꼭지 미만으로 짧게 나옴
- trend-writer에게 "꼭지 9개 이상, 1.5만 자 보장하라"고 강조해서 재호출
- 그래도 짧으면 모델을 opus로 변경 (`.claude/agents/trend-writer.md`의 `model: sonnet` → `model: opus`)

---

## 9 | 향후 자동화 (집 PC 도입 시 검토)

본 플레이북은 수동 실행 기준입니다. 자동화 시 검토할 옵션:

1. **/loop 슬래시**: Claude Code에 내장된 `/loop` 으로 매일 같은 시간 trend-writer 호출
2. **schedule 슬래시**: cron 형태의 원격 에이전트로 무인 실행
3. **GitHub Actions**: 매일 아침 push로 트리거되는 워크플로우 (Sometrend MCP를 SDK 모드로 호출)

자동화는 **수동 운영으로 1~2주 안정화 검증 후** 도입을 권장합니다.

---

## 부록 A | 첫 실행 체크리스트

- [ ] `.claude/agents/trend-scout.md` 존재 확인
- [ ] `.claude/agents/trend-curator.md` 존재 확인
- [ ] `.claude/agents/trend-writer.md` 존재 확인
- [ ] `output_trend/` 폴더 생성 (`mkdir output_trend`)
- [ ] Sometrend 크레딧 잔량 확인 (최소 10 이상 권장)
- [ ] Naverblog.md v5 지침 1회 정독 (트렌드 폴더는 인라인 강제 적용 안 함)
