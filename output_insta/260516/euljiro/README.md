# 인스타 카드뉴스 프로토타입 — 을지로 힙지로

원본: `output/260516/travel_seoul_euljiro_nogari_2026.html`
방식: **C안 (AI 풀배경 + Figma 텍스트 오버레이)**

## 폴더 내용
| 파일 | 용도 |
|---|---|
| `prompts.md` | Gemini에 넣을 배경 이미지 프롬프트 10개 + 스타일 앵커 |
| `card_01_cover.svg` | 커버(훅) 아키타입 |
| `card_03_nogari.svg` | 정보강조(헤드라인+가격칩) 아키타입 |
| `card_05_price.svg` | 정보패널(글래스 표) 아키타입 |
| `card_10_cta.svg` | 마무리 CTA(저장유도) 아키타입 |
| `caption.txt` | 인스타 본문 + 해시태그 |

> 이 4종이 전체 10장의 **모든 디자인 패턴**을 대표합니다. 나머지 6장은 이 4틀의 변주입니다.

---

## 1회 셋업 (Figma 템플릿 만들기)

1. **Pretendard 폰트 설치** (무료, [github.com/orioncactus/pretendard]) — 없으면 Figma가 다른 폰트로 치환하지만 텍스트는 계속 편집 가능.
2. Figma 새 파일 → SVG 4개를 드래그 임포트. 각 SVG는 1080×1350 프레임으로 들어옵니다.
3. 각 프레임에서 **`BG__REPLACE_WITH_IMAGE`** 레이어(맨 아래 사각형) 선택.
4. (지금) 색만 보임 → (실사용) 그 사각형 선택 → 우측 Fill → `Image` → Gemini PNG 선택 → `Crop` 모드. 배경이 자동으로 카드에 꽉 참.
5. 텍스트 레이어를 Figma **Text Style / Component**로 등록 → 다음 원고부터 글자만 교체.
6. 이 파일을 `힙지로_카드템플릿`으로 저장 → 원고마다 **Duplicate** 후 텍스트·배경만 교체.

## 매 원고 워크플로우 (셋업 후)
```
output/YYMMDD/<slug>.html
  → prompts.md 받아 Gemini로 배경 10장 생성 (스타일 앵커로 세트감 통일)
  → Figma 템플릿 Duplicate → 각 프레임에 PNG 드래그 + 텍스트 교체
  → 1080×1350 PNG ×10 일괄 Export
  → caption.txt 복사해 인스타 캐러셀 업로드 (평일 19~21시)
```

## 자동화 로드맵 (검증 후)
네이버/티스토리 듀얼처럼 **3번째 채널**로 승격:
- 신규 서브에이전트 `insta-card-builder` — `output/YYMMDD/<slug>.html`을 읽어
  `prompts.md` + `card_*.svg`(텍스트 자동 치환) + `caption.txt`를 자동 생성.
- 티스토리 미러와 동일한 파일/Git 패턴 → `output_insta/YYMMDD/<slug>/`.
- Figma의 image-fill·Export만 수동(또는 Figma MCP 연결 시 자동화 검토).

## 주의 (현재 환경)
이 세션엔 **Figma MCP 미연결**(Google Drive·Sometrend만). 그래서 `.fig` 직접 저작 불가 →
SVG를 Figma import하는 경로로 우회. Figma MCP 연결 시 템플릿 자동 생성까지 확장 가능.
