# 네이버 원고 이미지 캡션 보정기 (deterministic post-processor)
# 배경: 모델(daily-prompt §4 지침)에 캡션 div를 강제해도 sonnet이 종종 <img alt="...">에만
#       캡션을 넣고 화면에 보이는 <div class="img-caption">를 누락한다(2026-06-11~13 발생).
#       honor-system이 아닌 기계적 보정으로 누락을 0으로 만든다.
# 동작: output/<Day>/*.html(네이버) 각 파일에서 .img-area 안의 <img>가 바로 뒤에
#       <div class="img-caption">를 갖지 않으면, img의 alt 텍스트로 캡션 div를 삽입한다.
#       이미 캡션이 있으면 건드리지 않는다(멱등). output_tistory는 대상 아님.
# 사용: powershell -File fix-naver-captions.ps1 -Day 260613
#       -Day 생략 시 오늘(yyMMdd).

param(
    [string]$Day = (Get-Date -Format "yyMMdd")
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$DayDir = Join-Path $ProjectRoot "output\$Day"

if (-not (Test-Path -LiteralPath $DayDir)) {
    Write-Host "[caption-fix] SKIP: $DayDir 없음"
    exit 0
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$totalFixed = 0
$filesTouched = 0

$files = Get-ChildItem -LiteralPath $DayDir -Filter "*.html" -ErrorAction SilentlyContinue |
         Where-Object { $_.Name -ne "index.html" }

foreach ($file in $files) {
    $lines = [System.IO.File]::ReadAllLines($file.FullName)
    $out = New-Object System.Collections.Generic.List[string]
    $fixedInFile = 0

    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        $out.Add($line)

        # <img ... alt="..." ...> 형태의 라인 감지 (alt 필수)
        $m = [regex]::Match($line, '<img\b[^>]*\balt="([^"]*)"[^>]*>')
        if ($m.Success) {
            $alt = $m.Groups[1].Value

            # 바로 다음 non-empty 라인이 이미 img-caption이면 보정 불필요(멱등)
            $j = $i + 1
            while ($j -lt $lines.Length -and $lines[$j].Trim() -eq "") { $j++ }
            $nextHasCaption = ($j -lt $lines.Length -and $lines[$j] -match 'class="img-caption"')

            if (-not $nextHasCaption -and $alt -ne "") {
                # img 라인의 들여쓰기를 그대로 따른다
                $indent = ([regex]::Match($line, '^[ \t]*')).Value
                $out.Add("$indent<div class=`"img-caption`">$alt</div>")
                $fixedInFile++
            }
        }
    }

    if ($fixedInFile -gt 0) {
        [System.IO.File]::WriteAllLines($file.FullName, $out, $utf8NoBom)
        Write-Host "[caption-fix] $($file.Name): 캡션 $fixedInFile개 삽입"
        $totalFixed += $fixedInFile
        $filesTouched++
    }
}

Write-Host "[caption-fix] 완료: 파일 $filesTouched개, 캡션 $totalFixed개 삽입 (Day=$Day)"
exit 0
