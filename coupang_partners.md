# 쿠팡 파트너스 블로그 운영 지침 v1.1 (Coupang Partners)

---

## 01 | 목적 및 기본 원칙

이 지침은 **"쿠팡 주제"** 요청 시 발동하며, 네이버 블로그를 통한 성공적인 쿠팡 파트너스 수익 창출(구매 전환율 극대화) 및 블로그 지수 보호를 목적으로 합니다.
기존 `Naverblog.md`의 고품질 HTML 양식과 1만 자 이상의 심도 있는 정보성 퀄리티를 그대로 유지하되, **상품 리뷰와 구매 의지를 자극하는 문제 해결형 카피라이팅**을 핵심으로 합니다.

- **발행량**: 하루 최대 2개의 쿠팡 주제 원고 세트 작성 (단, 한 개의 포스팅에 여러 제품을 비교 분석하는 것을 권장)
- **저장 경로**: `./output_coupang/yymmdd/` 폴더 내 개별 HTML 및 `index.html` (현황판) 생성
- **이미지 정책**: **원고 작성 시 반드시 AI 툴(generate_image)을 사용하여 상업적 연출급(High-end) 제품 촬영 분위기의 이미지를 최소 2~3장 생성합니다.** 생성된 이미지는 `./output_coupang/yymmdd/images/` 디렉토리에 저장하며, 원고 본문의 맥락에 맞게 `<img src="images/...png">` 태그를 활용해 시각적 매력도를 극대화합니다.

---

## 02 | "쿠팡 파트너스" 아이템 발굴 기준

사용자가 파트너스 아이템을 요청할 경우, 수익률과 전환율을 높이기 위해 다음 4가지 기준을 고려하여 발굴합니다.

1. **데이터 기반 수요 파악**: 네이버 쇼핑 트렌드, 쿠팡 인기 상승 카테고리, 틱톡/인스타 등에서 바이럴 되는 제품 선점.
2. **시즌 및 트렌드 반영**: 계절 아이템 (여름 쿨매트, 겨울 발열조끼 등), 사회적 트렌드 (1인가구 가전, 캠핑 등) 및 당면한 문제를 해결할 수 있는 시의성 아이템.
3. **신뢰도와 배송 옵션**: 이탈률 방지를 위해 가급적 **'로켓배송'** 상품을 타겟팅하고, 최근 1~2개월 내의 **'사진 리뷰'**가 많고 긍정적인 평가 키워드가 존재하는 상품을 우선합니다.
4. **틈새시장(Niche Market) 공략**: 과도한 경쟁(예: 무선 이어폰)보다는 '실버 세대용 리모컨', '소형 반려견용 발톱깎이' 등 특정 니즈가 분명한 틈새 타겟 상품의 전환율이 좋습니다.
5. **[필수] 중복 추천 방지**: `used_keywords.json` 파일에 기록된 제품군(로봇청소기, 웨건 등)은 무조건 배제하여 항상 새로운 파이프라인을 구축합니다.

---

## 03 | 콘텐츠 작성 형태 및 세일즈 카피라이팅

단순 스펙 나열은 구매를 유도하지 못합니다. **1만 자 이상의 심층 정보와 공감 스토리를 베이스로 작성**해야 합니다.

1. **비교 및 큐레이션 글 (가장 추천)**: 하루 2개의 아이템을 올리더라도, 이를 하나의 글로 묶어 "A vs B 전격 비교" 형식으로 발행하는 것이 독자 체류시간과 클릭률 획득에 압도적으로 유리합니다. (예: "건조분쇄형 vs 미생물 발효형 음식물 처리기 전격 비교")
2. **문제 해결형 포맷**: 1인칭 관점의 공감 스토리텔링("초파리 지옥에서 탈출하고 싶었습니다")으로 페인 포인트(Pain Point)를 짚고 솔루션으로써 제품을 큐레이션합니다.
3. **✨ 핵심 요약 제공**: 각 제품별로 **'추천 이유 (이 제품을 사야 하는 사람)'를 2~3줄로 직관적으로 요약**해 주어 독자의 최종 구매 결정을 돕는 섹션을 반드시 포함합니다.
4. **명시적 대장주 공개**: 해당 키워드의 업계 1위 혹은 베스트셀러 모델의 실명(예: 스마트카라 400, 린클 프라임 등)을 직접 원고에 노출하여 독자의 검색 이탈을 막습니다.

---

## 04 | 주기적 업로드 시 블로그 지수 보호 원칙 🚨

하루 2개의 쿠팡 링크 글을 무분별하게 발행하면 네이버 저품질(어뷰징) 알고리즘에 즉각 적발됩니다. 안정적인 운영을 위해 다음 규칙을 **반드시** 지킵니다.

1. **포스팅 비율 1:5 유지**: 쿠팡 관련 상업성 글과 일반 정보 및 실시간 이슈 글의 발행 비율을 **1:5** 정도로 관리하여 블로그 지수 방어에 총력을 다합니다.
2. **링크 개수 제한**: 1만 자 본문이라 하더라도 **쿠팡 아웃 링크는 포스팅 당 최소 1개 ~ 최대 2개**로만 엄격하게 제한합니다.
3. **우회 랜딩 페이지 사용 원칙**: 쿠팡 원본 URL을 본문에 직접 도배하지 않습니다. 블로그 품질 보호를 위해, 중간 우회 리디렉션 페이지(서브 블로그, Linktree, 또는 단축 URL)를 경유한다고 가정하고 버튼 코드를 작성합니다. (`<a href="Redirect_Link">`)
4. **공정위 대가성 문구 필수**: 포스팅(문서) 최하단에는 반드시 아래의 공정거래위원회 문구를 삽입합니다.
   > **"이 포스팅은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다."**

---

## 05 | 쿠팡 전용 HTML 표준 템플릿

```html
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>쿠팡 세일즈 훅 제목</title>
<style>
  /* ── 전역 ── */
  body { margin: 0; padding: 16px; background: #fff; font-family: 'Apple SD Gothic Neo', 'Noto Sans KR', sans-serif; font-size: 16px; line-height: 1.9; color: #222; max-width: 780px; margin: 0 auto; }
  p { margin-bottom: 24px; }
  
  /* ── 제목 ── */
  h1 { font-size: 1.6em; font-weight: 800; border-bottom: 3px solid #0073e9; padding-bottom: 10px; margin-bottom: 20px; color: #111; }
  h2 { font-size: 1.25em; font-weight: 700; border-left: 4px solid #0073e9; padding-left: 10px; margin-top: 48px; margin-bottom: 16px; color: #111; }
  h3 { font-size: 1.1em; font-weight: 700; margin-top: 32px; margin-bottom: 12px; color: #333; }

  /* ── 박스 (리뷰, 단점, 스펙) ── */
  .lead { background: #f0f8ff; border-left: 4px solid #0073e9; padding: 16px 20px; margin: 20px 0; font-size: 1.05em; color: #0056b3; border-radius: 0 4px 4px 0; }
  .point-box { border: 1px solid #cce5ff; border-radius: 8px; padding: 18px 22px; margin: 24px 0; background: #f8fbff; position: relative; }
  .point-box::before { content: "SUMMARY POINT"; position: absolute; top: -12px; left: 20px; background: #0073e9; color: #fff; padding: 2px 10px; font-size: 0.75em; border-radius: 4px; font-weight: 700; }

  /* ── 쿠팡 구매 버튼 ── */
  .cta-btn { display: block; text-align: center; background: #0073e9; color: #fff; font-weight: 800; font-size: 1.1em; padding: 16px 24px; margin: 32px auto; width: 80%; border-radius: 8px; text-decoration: none; box-shadow: 0 4px 6px rgba(0, 115, 233, 0.3); }

</style>
</head>
<body>

    <h1>[분석] 장단점 비교 훅 제목</h1>
    
    <div class="lead">
        (여기에 1인칭 공감 스토리, 문제 제기 작성)
    </div>

    <!-- AI 생성 이미지 삽입 -->
    <div class="img-container" style="text-align:center; margin: 20px 0;">
        <img src="images/example_image.png" alt="AI 연출 상품 상세 컷" style="max-width:100%; border-radius:10px; box-shadow:0 4px 10px rgba(0,0,0,0.1);">
    </div>

    <h2>1. 문제 해결 솔루션</h2>
    <p>비교 본문 내용...</p>

    <!-- 제품 핵심 요약 파트 필수 -->
    <div class="point-box">
        <strong>✨ 3줄 핵심 요약: A 모델을 사야 하는 사람</strong>
        <ul>
            <li>요약 1</li>
            <li>요약 2</li>
            <li>요약 3</li>
        </ul>
    </div>

    <!-- 우회 링크 권장, 한 포스팅 내 링크 1~2개 제한 -->
    <a href="https://redirect-subblog.com/productA" class="cta-btn">👉 현재가 확인 및 로켓배송 리뷰 보러가기</a>

    <div class="closing-box" style="margin-top:50px; padding-top:20px; border-top: 1px solid #ddd; font-size:0.85em; color:#888;">
        <strong>"이 포스팅은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다."</strong>
    </div>

</body>
</html>
```
