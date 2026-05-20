# 티스토리 Phase B 자동 검수 게이트 (구조 적합성 + 중복 차단)
#
# 배경: daily-prompt.md §5.5.9-bis 검증은 "모델이 세션 내에서 스스로 실행"하는
#       honor-system이었고, 실제 commit/push를 하는 daily-run.ps1 에는 연결돼
#       있지 않아 무조건 push 되었다. 또 그 검증은 네이버↔티스토리 중복(dedup)만
#       보고 템플릿 구조 이탈(2026-05-19 #4/#5: 래퍼 누락·비팔레트색·번호없는 h2·
#       태그칩 없음·이미지프롬프트박스 누출·작성일 줄)은 보지 못했다.
#       본 스크립트는 두 검사를 모두 수행하고, daily-run.ps1 Step 2(git) 직전에
#       강제 호출되어 FAIL 시 commit/push 를 차단한다.
#
# 사용:
#   powershell -File .scripts\tistory-gate.ps1                 # 오늘(YYMMDD)
#   powershell -File .scripts\tistory-gate.ps1 -Day 260519     # 특정 일자
# 종료코드: 0 = 전부 PASS([OK]) / 1 = 1건 이상 FAIL([BLOCK]) 또는 입력오류

param(
  [string]$Day = (Get-Date -Format "yyMMdd"),
  [string]$ProjectRoot = "D:\lightsail\naverblog"
)

$enc = [System.Text.Encoding]::UTF8
$tdir = Join-Path $ProjectRoot "output_tistory\$Day"
$ndir = Join-Path $ProjectRoot "output\$Day"

if (-not (Test-Path -LiteralPath $tdir)) {
  Write-Host "[BLOCK] tistory 폴더 없음: $tdir"
  exit 1
}

$files = Get-ChildItem -LiteralPath $tdir -Filter "*.html" | Where-Object Name -ne 'index.html'
if (-not $files) {
  Write-Host "[BLOCK] $tdir 에 검사할 티스토리 원고가 없음"
  exit 1
}

$fail = $false

foreach ($f in $files) {
  $slug = $f.Name
  $h = [System.IO.File]::ReadAllText($f.FullName, $enc)
  $codes = @()

  # ===== 1) 구조 적합성 (Platinum 인라인 표준 / daily-prompt.md §5.5.4-bis) =====
  # F1 외곽 래퍼 div (§5.5.4-bis 규칙 5) — 모든 정상본·기준템플릿(260511) 공통
  if ($h -notmatch [regex]::Escape('max-width: 780px; margin: 0 auto; padding: 16px;')) { $codes += 'F1:wrapper없음' }
  # F2 h1 Platinum 시그니처 (굵기 800 + 5px 밑줄). 색은 카테고리 무관(여행/레시피 공통 형태)
  if ($h -notmatch [regex]::Escape('font-weight: 800; border-bottom: 5px solid')) { $codes += 'F2:h1비표준' }
  # F3 이미지 프롬프트 placeholder 누출 (네이버 전용 산출물이 티스토리로 새면 안 됨)
  if ($h -match '이미지 프롬프트 \(placeholder\)|AI 이미지 생성 영역|프롬프트 복사하기|prompt-text|img-placeholder|id="prompt-') { $codes += 'F3:프롬프트박스누출' }
  # F4 <style> 블록 / class 속성 (§5.5.4-bis 금지 — CSS-only 복사 사고 클래스도 차단)
  if ($h -match '<style' -or $h -match ' class="') { $codes += 'F4:style/class' }
  # F5 추천(내부순환) 박스 — 정상본/기준템플릿은 둘 중 한 문구를 반드시 가짐
  if (-not ($h -match '같이 볼만한 글' -or $h -match '같이 보면 좋은 글')) { $codes += 'F5:추천박스없음' }
  # F6 비표준 '작성일 20YY' 부제 줄 (표준 템플릿엔 없음 — 범용템플릿 드리프트 마커)
  if ($h -match '>작성일 20') { $codes += 'F6:작성일줄' }
  # F7 팔레트 이탈 색 (2026-05-19 #4/#5 드리프트 실측색 denylist)
  if ($h -match '#4a8c4a|#2e7da6|#1a4f6e|#2d5a2d|#3d7a3d|#246090|#e6c840') { $codes += 'F7:비팔레트색' }
  # F8 태그칩 누락 (2026-05-20 추가) — 표준 10개 chip(span background:#f0f0f0); 8 미만이면 FAIL.
  $chipCount = ([regex]::Matches($h, 'background:#f0f0f0')).Count
  if ($chipCount -lt 8) { $codes += "F8:태그칩부족($chipCount)" }

  $structFail = $codes.Count -gt 0

  # ===== 2) 중복 차단 (daily-prompt.md §5.5.9-bis 이식 — 산문만 비교) =====
  $dedup = 'n/a'
  $np = Join-Path $ndir $slug
  if (Test-Path -LiteralPath $np) {
    $nc = [System.IO.File]::ReadAllText($np, $enc)
    $nT = [regex]::Match($nc, '<title>(.*?)</title>').Groups[1].Value.Trim()
    $tT = [regex]::Match($h,  '<title>(.*?)</title>').Groups[1].Value.Trim()
    $titleFail = ($nT -ne '' -and $nT -eq $tT)
    $cut = {
      param($x)
      $x = $x -replace '(?s)<script.*?</script>', '' -replace '(?s)<style.*?</style>', ''
      $i = $x.IndexOf('같이 볼만한'); if ($i -lt 0) { $i = $x.IndexOf('같이 보면 좋은') }
      if ($i -ge 0) { $x = $x.Substring(0, $i) }
      ($x -replace '<[^>]+>', ' ' -replace '\s+', ' ')
    }
    $nL = (& $cut $nc) -split '(?<=[.!?])\s+' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -ge 20 }
    $tL = (& $cut $h)  -split '(?<=[.!?])\s+' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -ge 20 }
    $nH = [System.Collections.Generic.HashSet[string]]::new()
    $nL | ForEach-Object { [void]$nH.Add($_) }
    $dups = $tL | Where-Object { $nH.Contains($_) } | Select-Object -Unique
    $tcount = ($tL | Select-Object -Unique).Count
    $ratio = [math]::Round(100 * $dups.Count / [math]::Max($tcount, 1), 1)
    $dupFail = ($titleFail -or $ratio -ge 25 -or $dups.Count -ge 20)
    $dedup = if ($dupFail) { "FAIL(title=$(if($titleFail){'SAME'}else{'ok'}) dup=$($dups.Count)/$tcount ${ratio}%)" } else { "ok(${ratio}%)" }
    if ($dupFail) { $structFail = $true }
  }

  if ($structFail) { $fail = $true }
  $verdict = if ($structFail) { 'FAIL' } else { 'PASS' }
  $cstr = if ($codes.Count) { $codes -join ',' } else { 'ok' }
  "{0,-46} struct={1} dedup={2} => {3}" -f $slug, $cstr, $dedup, $verdict
}

if ($fail) {
  Write-Host "`n[BLOCK] 티스토리 검수 실패 — FAIL 슬러그를 표준 템플릿(daily-prompt.md §5.5.4-bis / 정상본 #1)으로 재작성 후 재검증. commit/push 금지."
  exit 1
} else {
  Write-Host "`n[OK] 티스토리 검수 통과 — 구조·중복 모두 정상. push 진행 가능."
  exit 0
}
