# Naverblog 일일 자동 발행 PowerShell 래퍼
# Windows 작업 스케줄러가 매일 새벽 4:00 실행
# 1) Claude CLI로 원고 5건 작성 → 2) 작성 결과만 GitHub에 자동 push

# === 티스토리 자동 발행 플래그 ===
# 2026-07-09 중단(True): 애드센스 "가치 없는 콘텐츠" 반려 → 네이버 파생 미러 폐기.
# 티스토리는 이제 사용자 실사진·실경험 기반 '별도' 애드센스 채널로, 대화형 제작(4시 자동 X).
# daily-run은 티스토리 생성·게이트(Step 1.65/1.7)·스테이징을 스킵. 제작 표준 = 티스토리_애드센스_제작.md.
# 자동 미러로 되돌리려면 $false (권장 안 함 — 애드센스 반려 사유).
$TistorySuspended = $true

# === 인스타 자동생성 플래그 (2026-07-08 중단) ===
# 2026-07-08 사용자 지시로 인스타 카드 자동생성(Step 1.6 Phase C) 중단.
# 블로그 성장모드(일 7건)로 전환하며 유료 이미지 렌더 예산을 블로그에 집중.
# 블로그 삽입 이미지는 사용자가 별도 제작. 재개하려면 아래를 $false로.
$InstaSuspended = $true

$ErrorActionPreference = "Continue"
$ProjectRoot = (Get-Item $PSScriptRoot).Parent.FullName
$ScriptsDir  = Join-Path $ProjectRoot ".scripts"
$LogsDir     = Join-Path $ScriptsDir "logs"
$PromptFile  = Join-Path $ScriptsDir "daily-prompt.md"
$OutputDir   = Join-Path $ProjectRoot "output"
$Stamp       = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile     = Join-Path $LogsDir "daily-$Stamp.log"

# === 하루 기대 발행 건수 (Step 1.8 검증 게이트 기준값) ===
# daily-prompt.md §2의 믹스 합계와 같아야 한다. 믹스를 바꾸면 여기도 같이 바꾼다.
$ExpectedPosts = 7

# 작업 디렉터리 이동
Set-Location $ProjectRoot

# Korean 파일명/커밋 메시지가 깨지지 않도록 native exe 호출 인코딩을 UTF-8로 고정
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 로그 헤더 (UTF-8 BOM 없이)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-Log([string]$line) {
    Write-Host $line
    [System.IO.File]::AppendAllText($LogFile, "$line`r`n", $utf8NoBom)
}

[System.IO.File]::WriteAllText($LogFile, "=== Naverblog Daily Run @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===`r`n", $utf8NoBom)
Write-Log "ProjectRoot: $ProjectRoot"
Write-Log "PromptFile : $PromptFile"
Write-Log "Model      : claude-sonnet-4-6"
Write-Log ""

$exit = 1

# 실패 신호 파일 — 대시보드가 이걸 읽어 상단에 배너를 띄운다(build-dashboard.ps1).
# 성공하면 Step 2에서 지운다. 남아 있으면 "아직 안 고쳐진 실패"라는 뜻.
$FailFlag = Join-Path $LogsDir "LAST_FAILURE.txt"

function Set-Failure([string]$kind, [string]$detail, [string]$howto) {
    $body = @(
        "WHEN=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "KIND=$kind",
        "DETAIL=$detail",
        "HOWTO=$howto",
        "LOG=$LogFile"
    ) -join "`r`n"
    [System.IO.File]::WriteAllText($FailFlag, $body, $utf8NoBom)
}

# === Step 0.4: 인증 사전 점검 (2026-08-30 신설 — 사용자 지시) ===
# 계기: 8/27~8/30 나흘간 "Failed to authenticate: OAuth session expired"로 발행이 0건이었는데
#   아무도 몰랐다. 로그에만 찍히고 스크립트는 조용히 다음 단계로 넘어갔기 때문.
# 여기서 미리 잡아야 의미가 있다 — 발행을 시도한 뒤 실패를 아는 것보다 낫다.
Write-Log "=== Step 0.4: Auth Precheck @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
$authOk = $false
try {
    $probe = ("ping" | & claude -p --model claude-sonnet-4-6 --max-budget-usd 1 --output-format text 2>&1 | Out-String)
    if ($LASTEXITCODE -eq 0 -and $probe -notmatch 'Failed to authenticate|OAuth session expired|Invalid API key') {
        $authOk = $true
        Write-Log "AUTH OK"
    } else {
        Write-Log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        Write-Log "[AUTH FAIL] Claude CLI 인증 만료 - /login 필요"
        Write-Log "  조치: 터미널에서 claude 실행 후 /login (또는 claude login)"
        Write-Log "  인증 전까지 매일 04시 발행이 계속 0건이 됩니다."
        Write-Log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        Write-Log ("probe: " + ($probe -replace "`r?`n", ' ').Trim())
    }
} catch {
    Write-Log "[AUTH FAIL] 인증 점검 중 예외: $_"
}

if (-not $authOk) {
    Set-Failure "AUTH" "Claude CLI 인증 만료(OAuth session expired) - 발행 시도조차 못 함" "터미널에서 claude 실행 후 /login"
    Write-Log ""
    Write-Log "=== 인증 실패로 Step 0.5/0.6/1 전부 건너뜁니다. 예산·큐를 소모하지 않습니다. ==="
    # 대시보드는 그래도 재빌드해서 배너가 뜨게 한다.
    $dashOnly = Join-Path $ScriptsDir "build-dashboard.ps1"
    if (Test-Path -LiteralPath $dashOnly) { & $dashOnly 2>&1 | Out-Null }
    exit 1
}
Write-Log ""

# === Step 0.5: 주간 큐 리필 (2026-08-01 정례화 — 사용자 지시) ===
# 계기: 8/1 실행에서 여행 외 큐가 전부 고갈(시즌게이트 통과 0건) → 7건 전부 travel_ 발행.
# 매주 월요일 실행분에서만 가동, 임계 미달 큐만 채운다. 임계표 = daily-prompt.md §2 G3.
# 실패해도 $exit를 건드리지 않아 본 발행(Step 1)은 그대로 진행된다.
# ⚠️ 2026-08-10: 예산 $3 → $5. 04:00 실행이 "Exceeded USD budget (3)"로 죽어 리필이 건너뛰어졌고,
#    그 상태로 Step 1이 발행해 travel 큐가 9까지 떨어졌다. 큐가 많이 비면 적재 행이 늘고
#    중복 대조(작성완료 전수 대조, 190KB) 비용도 커져 $3으로는 부족하다. Step 1은 $7.
#    로그에 "Exceeded USD budget"이 보이면 리필은 수행되지 않은 것이다 — 수동으로 다시 돌려야 한다.
# 임시로 다른 날 강제 실행하려면 $ForceRefill = $true.
$ForceRefill  = $false
$RefillDay    = 'Monday'
$RefillPrompt = Join-Path $ScriptsDir "refill-prompt.md"
$today        = (Get-Date).DayOfWeek.ToString()

if ((($today -eq $RefillDay) -or $ForceRefill) -and (Test-Path -LiteralPath $RefillPrompt)) {
    Write-Log "=== Step 0.5: Weekly Queue Refill @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
    try {
        $rp = Get-Content -LiteralPath $RefillPrompt -Raw -Encoding utf8

        $rp | & claude `
            -p `
            --model claude-sonnet-4-6 `
            --permission-mode bypassPermissions `
            --max-budget-usd 5 `
            --output-format text `
            --add-dir $ProjectRoot 2>&1 |
        ForEach-Object {
            $line = "$_"
            Write-Host $line
            [System.IO.File]::AppendAllText($LogFile, "$line`r`n", $utf8NoBom)
        }
        Write-Log "=== Refill exit code: $LASTEXITCODE ==="
    } catch {
        Write-Log "ERROR (Refill step, 무시하고 발행 진행): $_"
    }
} elseif (-not (Test-Path -LiteralPath $RefillPrompt)) {
    Write-Log "WARN: $RefillPrompt 없음 - Step 0.5 스킵."
} else {
    Write-Log "SKIP Step 0.5: 주간 리필일($RefillDay) 아님 - 오늘 $today."
}
Write-Log ""

# === Step 0.6: 주간 아카이브 정리 (2026-08-15 신설 - 사용자 지시) ===
# output/ · images/ 의 오래된 날짜 폴더를 매주 월요일 정리한다. 최근 7일만 보존.
# 순서가 중요: prune-archives.ps1 이 **발행이력.md 를 먼저 갱신하고** 실패 시 삭제를 중단한다.
# images/ 가 하루 ~8MB씩 쌓여 2026-08-15 기준 621MB였던 것이 계기.
# 발행 이력(주제 중복 판정 백데이터)은 발행이력.md 에만 남으므로 그 파일은 삭제 금지.
$PruneScript = Join-Path $ScriptsDir "prune-archives.ps1"
if ((($today -eq $RefillDay) -or $ForceRefill) -and (Test-Path -LiteralPath $PruneScript)) {
    Write-Log "=== Step 0.6: Weekly Archive Prune @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $PruneScript -KeepDays 7 2>&1 |
        ForEach-Object {
            $line = "$_"
            Write-Host $line
            [System.IO.File]::AppendAllText($LogFile, "$line`r`n", $utf8NoBom)
        }
        Write-Log "=== Prune exit code: $LASTEXITCODE ==="
    } catch {
        Write-Log "ERROR (Prune step, 무시하고 발행 진행): $_"
    }
} elseif (-not (Test-Path -LiteralPath $PruneScript)) {
    Write-Log "WARN: $PruneScript 없음 - Step 0.6 스킵."
} else {
    Write-Log "SKIP Step 0.6: 주간 정리일($RefillDay) 아님 - 오늘 $today."
}
Write-Log ""

# === Step 0.7: 오늘의 정책 계산 → 프롬프트에 주입 (2026-09-16 신설) ===
# 계기: 2026-09-15(화)을 「월」로 잘못 적고 월요일 로테이션(pass_+recipe_)으로 발행해
#   원고 7건을 통째로 재작성했다. daily-prompt.md에 "요일은 명령으로 계산하라"는 산문
#   규칙이 추가됐지만, 모델에게 계산을 맡기는 한 같은 실수가 다시 난다.
#   래퍼가 요일을 직접 계산해 **기대 계열을 문장으로 박아** 넘긴다 — 추측할 여지를 없앤다.
# 정책 원본 = .scripts/policy.json (사람용 사양은 daily-prompt.md §2 · 계열 상태는 카테고리_포트폴리오.md)
$PolicyFile = Join-Path $ScriptsDir "policy.json"
$Policy = $null
# .NET DayOfWeek는 Sunday=0이다. 한글 요일로 명시 매핑한다(산술 변환은 일요일에서 틀린다).
$DowKrMap = @{
    "Monday" = "월"; "Tuesday" = "화"; "Wednesday" = "수"; "Thursday" = "목"
    "Friday" = "금"; "Saturday" = "토"; "Sunday" = "일"
}
$todayDow = $DowKrMap[(Get-Date).DayOfWeek.ToString()]
$wantRotation = @()
try {
    if (Test-Path -LiteralPath $PolicyFile) {
        $Policy = Get-Content -LiteralPath $PolicyFile -Raw -Encoding utf8 | ConvertFrom-Json
        if ($Policy.rotationByDow.PSObject.Properties.Name -contains $todayDow) {
            $wantRotation = @($Policy.rotationByDow.$todayDow)
        }
        Write-Log "=== Step 0.7: Policy @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
        Write-Log "오늘 = $(Get-Date -Format 'yyyy-MM-dd') ($todayDow) · 기대 로테이션 = $($wantRotation -join ', ')"
        Write-Log "DROP 계열 = $($Policy.dropped -join ', ')"
    } else {
        Write-Log "WARN: $PolicyFile 없음 — 요일 주입·믹스 검증 스킵(프롬프트 규칙만으로 진행)."
    }
} catch {
    Write-Log "ERROR (Step 0.7 policy 로드): $_ — 주입 없이 진행."
    $Policy = $null
}
Write-Log ""

# === Step 1: Claude CLI로 원고 작성 ===
try {
    $prompt = Get-Content -LiteralPath $PromptFile -Raw -Encoding utf8

    # 오늘의 확정 사실을 프롬프트 맨 앞에 붙인다(모델이 요일을 다시 계산하지 않게).
    if ($null -ne $Policy -and $wantRotation.Count -ge 2) {
        $bt = [char]96   # 백틱 — PowerShell 이스케이프 문자라 문자 코드로 만든다
        $dropTxt = (($Policy.dropped | ForEach-Object { "$bt$($_)_$bt" }) -join " · ")
        $rot1 = "$bt$($wantRotation[0])_$bt"
        $rot2 = "$bt$($wantRotation[1])_$bt"
        $ymdFull = Get-Date -Format 'yyyy-MM-dd'
        $ymdShort = Get-Date -Format 'yyMMdd'
        $inject = @(
            "# 🔒 오늘의 확정 사항 (래퍼가 계산함 — 다시 계산하지 말고 그대로 쓸 것)",
            "",
            "- **오늘 날짜**: $ymdFull  (출력 폴더 $bt$ymdShort$bt)",
            "- **오늘 요일**: **${todayDow}요일**",
            "- **오늘 로테이션 2건은 반드시**: $rot1 1건 + $rot2 1건",
            "- **DROP 계열(절대 선정·보충 금지)**: $dropTxt",
            "- **여행은 최대 $($Policy.travelMax)건.** 비여행 칸을 여행으로 채우지 말 것. 모든 비여행 큐가 시즌게이트 0건일 때만 예외이고, 그때는 완료 출력에 $bt[LEAK travel N]$bt 를 남긴다.",
            "",
            "> 위 값은 $bt.scripts/policy.json$bt 에서 계산됐다. 아래 본문의 요일표와 어긋나 보이면 **이 블록이 맞다.**",
            "> 발행 후 $bt daily-run.ps1 $bt Step 1.8이 같은 표로 검증하며, 어기면 실패로 기록된다.",
            "",
            "---",
            ""
        ) -join "`r`n"
        $prompt = $inject + $prompt
        Write-Log "프롬프트에 오늘의 확정 사항 주입 완료(${todayDow}요일 · $($wantRotation -join '+'))."
    }

    $prompt | & claude `
        -p `
        --model claude-sonnet-4-6 `
        --permission-mode bypassPermissions `
        --max-budget-usd 7 `
        --output-format text `
        --add-dir $ProjectRoot 2>&1 |
    ForEach-Object {
        $line = "$_"
        Write-Host $line
        [System.IO.File]::AppendAllText($LogFile, "$line`r`n", $utf8NoBom)
    }
    $exit = $LASTEXITCODE
    Write-Log ""
    Write-Log "=== Claude exit code: $exit ==="

    if ($exit -ne 0) {
        # 인증은 Step 0.4에서 걸렀으니 여기 오는 건 예산 초과·타임아웃·모델 오류 등이다.
        $YMD = Get-Date -Format "yyMMdd"
        $made = 0
        $dayDir = Join-Path $OutputDir $YMD
        if (Test-Path -LiteralPath $dayDir) {
            $made = @(Get-ChildItem -LiteralPath $dayDir -Filter "*.html" -File -EA SilentlyContinue |
                Where-Object { $_.Name -ne "index.html" }).Count
        }
        Write-Log "[STEP1 FAIL] exit=$exit · 오늘 생성된 원고 ${made}건"
        Set-Failure "STEP1" "원고 작성 실패(exit=$exit) - 오늘 생성 ${made}건" "로그에서 마지막 오류 확인 후 수동 재실행"
    }
} catch {
    [System.IO.File]::AppendAllText($LogFile, "FATAL (Claude step): $_`r`n", $utf8NoBom)
    Set-Failure "FATAL" "Claude 호출 중 예외: $_" "로그 확인 후 수동 재실행"
    exit 1
}

# === Step 1.4: 네이버 이미지 캡션 보정 (deterministic) ===
# 모델이 <img alt="...">에만 캡션을 넣고 화면 <div class="img-caption">를 누락하는
# 사고(2026-06-11~13)를 기계적으로 0으로 만든다. alt 텍스트로 누락된 캡션 div를 삽입(멱등).
Write-Log ""
Write-Log "=== Naver Caption Fix @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
try {
    $CaptionScript = Join-Path $ScriptsDir "fix-naver-captions.ps1"
    $CaptionDay    = Get-Date -Format "yyMMdd"
    if (Test-Path -LiteralPath $CaptionScript) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $CaptionScript -Day $CaptionDay 2>&1 |
        ForEach-Object {
            $line = "$_"
            Write-Host $line
            [System.IO.File]::AppendAllText($LogFile, "$line`r`n", $utf8NoBom)
        }
    } else {
        Write-Log "WARN: $CaptionScript 없음 — 캡션 보정 스킵."
    }
} catch {
    Write-Log "ERROR (Naver Caption Fix): $_"
}

# === Step 1.5: 통합 대시보드 재빌드 ===
Write-Log ""
Write-Log "=== Dashboard Rebuild @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
try {
    $dashboardScript = Join-Path $ScriptsDir "build-dashboard.ps1"
    if (Test-Path $dashboardScript) {
        & $dashboardScript 2>&1 | ForEach-Object {
            $line = "$_"
            Write-Host $line
            [System.IO.File]::AppendAllText($LogFile, "$line`r`n", $utf8NoBom)
        }
        Write-Log "Dashboard rebuild complete."
    } else {
        Write-Log "WARN: build-dashboard.ps1 not found at $dashboardScript"
    }
} catch {
    Write-Log "ERROR (Dashboard rebuild): $_"
}

# === Step 1.55: 수동 이미지 헬퍼 대시보드 재빌드 ===
Write-Log ""
Write-Log "=== Prompt Helper Dashboard Rebuild @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
try {
    $YYMMDD = Get-Date -Format "yyMMdd"
    & python "$ProjectRoot\scripts\build_prompt_dashboard.py" $YYMMDD 2>&1 | ForEach-Object {
        $line = "$_"
        Write-Host $line
        [System.IO.File]::AppendAllText($LogFile, "$line`r`n", $utf8NoBom)
    }
    Write-Log "Prompt helper dashboard rebuild complete."
} catch {
    Write-Log "ERROR (Prompt helper dashboard rebuild): $_"
}

# === Step 1.6: 인스타 카드 채널 (Phase C) ===
# 콘텐츠(네이버/티스토리) 성공 시에만 진행. 실패는 비치명적(전체 종료코드 불변).
Write-Log ""
Write-Log "=== Insta Card Channel @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
if ($InstaSuspended) {
    Write-Log "SKIP Insta: 인스타 자동생성 중단됨(2026-07-08 사용자 지시, `$InstaSuspended). 블로그 이미지는 사용자 별도 제작."
} elseif ($exit -ne 0) {
    Write-Log "SKIP Insta: Claude content step exit $exit (콘텐츠 실패 시 인스타 생략)."
} else {
    try {
        $YMD = Get-Date -Format "yyMMdd"

        # GEMINI 키 로드 (gitignore된 로컬 시크릿)
        $SecretFile = Join-Path $ScriptsDir "secret.env.ps1"
        if (Test-Path -LiteralPath $SecretFile) {
            . $SecretFile
            Write-Log "GEMINI key: loaded from secret.env.ps1"
        } else {
            Write-Log "WARN: $SecretFile 없음 — 이미지 생성/래스터는 스킵됩니다(카드 SVG만 생성)."
        }

        # Phase C-1: insta-card-builder 5건 (독립 Claude 실행 — 콘텐츠 예산과 분리)
        $InstaPrompt = Join-Path $ScriptsDir "insta-prompt.md"
        if (Test-Path -LiteralPath $InstaPrompt) {
            Write-Log "--- Phase C-1: insta-card-builder (cards/prompts/caption) ---"
            $ip = Get-Content -LiteralPath $InstaPrompt -Raw -Encoding utf8
            $ip | & claude `
                -p `
                --model claude-sonnet-4-6 `
                --permission-mode bypassPermissions `
                --max-budget-usd 6 `
                --output-format text `
                --add-dir $ProjectRoot 2>&1 |
            ForEach-Object {
                $line = "$_"
                Write-Host $line
                [System.IO.File]::AppendAllText($LogFile, "$line`r`n", $utf8NoBom)
            }
            Write-Log "Phase C-1 claude exit: $LASTEXITCODE"
        } else {
            Write-Log "WARN: $InstaPrompt 없음 — Phase C-1 스킵."
        }

        # Phase C-2: 배경 생성 + 래스터 (순수 node — Claude 예산 미사용, 멱등)
        #  ★ 비용 절감 정책 (2026-05-22): 인스타 미수익화 동안 유료 이미지 자동생성·
        #     주입(_done.svg)·PNG는 '그날의 첫 번째 원고' 1건만 수행한다. 2~5번 원고는
        #     card_*.svg/prompts.md/caption.txt(=Phase C-1 산출)까지만 두고 운영자가
        #     수동으로 이미지를 넣는다. 별도 지시가 있을 때까지 유지.
        #     '첫 번째 원고' = output/<YMD>/ 의 네이버 HTML 중 CreationTime 가장 이른
        #     것(index.html 제외) = 원고 seq 1. 그 슬러그의 insta 폴더만 render+raster.
        $InstaDay = Join-Path $ProjectRoot "output_insta\$YMD"
        $NaverDay = Join-Path $ProjectRoot "output\$YMD"
        $nodeOk   = [bool](Get-Command node -ErrorAction SilentlyContinue)
        if (-not $nodeOk) {
            Write-Log "WARN: node 미발견 — Phase C-2(이미지/래스터) 스킵."
        } elseif (-not $env:GEMINI_API_KEY) {
            Write-Log "WARN: GEMINI_API_KEY 없음 — Phase C-2 스킵(카드 SVG는 생성됨)."
        } elseif (-not (Test-Path -LiteralPath $InstaDay)) {
            Write-Log "WARN: $InstaDay 없음 — insta-card-builder 산출물 없음. Phase C-2 스킵."
        } else {
            # 그날의 첫 번째 원고 슬러그 판별 (네이버 HTML CreationTime 최솟값 = seq 1)
            $firstSlug = $null
            if (Test-Path -LiteralPath $NaverDay) {
                $firstHtml = Get-ChildItem -LiteralPath $NaverDay -Filter "*.html" -ErrorAction SilentlyContinue |
                             Where-Object { $_.Name -ne "index.html" } |
                             Sort-Object CreationTime, Name | Select-Object -First 1
                if ($firstHtml) { $firstSlug = $firstHtml.BaseName }
            }
            if (-not $firstSlug) {
                # 폴백: 네이버 폴더 판별 실패 시 insta 폴더명 알파벳 첫 번째
                $fb = Get-ChildItem -LiteralPath $InstaDay -Directory -ErrorAction SilentlyContinue |
                      Sort-Object Name | Select-Object -First 1
                if ($fb) { $firstSlug = $fb.Name }
            }
            Write-Log "--- Phase C-2: insta_render + insta_rasterize (첫 번째 원고만: $firstSlug) ---"
            Get-ChildItem -LiteralPath $InstaDay -Directory | ForEach-Object {
                $slugName = $_.Name
                $slugDir  = $_.FullName
                if ($slugName -ne $firstSlug) {
                    Write-Log "  SKIP $slugName : 2~5번 원고는 수동 이미지(비용 절감 정책 2026-05-22)"
                    return
                }
                $cardCnt  = (Get-ChildItem -LiteralPath $slugDir -Filter "card_*.svg" -ErrorAction SilentlyContinue |
                             Where-Object { $_.Name -notlike "*_done.svg" }).Count
                $pngDir   = Join-Path $slugDir "png"
                $pngCnt   = 0
                if (Test-Path -LiteralPath $pngDir) {
                    $pngCnt = (Get-ChildItem -LiteralPath $pngDir -Filter "card_*.png" -ErrorAction SilentlyContinue).Count
                }
                if ($cardCnt -lt 1) {
                    Write-Log "  SKIP $slugName : card SVG 없음"
                } elseif ($pngCnt -ge $cardCnt) {
                    Write-Log "  SKIP $slugName : png 이미 $pngCnt 개 (card $cardCnt, 멱등)"
                } else {
                    Write-Log "  RENDER $slugName"
                    & node "$ProjectRoot\scripts\insta_render.mjs" "$slugDir" 2>&1 |
                        ForEach-Object { [System.IO.File]::AppendAllText($LogFile, "    $_`r`n", $utf8NoBom) }
                    Write-Log "  RASTER $slugName"
                    & node "$ProjectRoot\scripts\insta_rasterize.mjs" "$slugDir" 2>&1 |
                        ForEach-Object { [System.IO.File]::AppendAllText($LogFile, "    $_`r`n", $utf8NoBom) }
                }
            }
            Write-Log "Phase C-2 complete."
        }
    } catch {
        Write-Log "ERROR (Insta Card Channel): $_"
    }
}

# === Step 1.65: 티스토리 구조 결정론적 자동복구 (게이트 직전) ===
# LLM 생성이 간헐 누락하는 래퍼(F1)/추천박스(F5)/태그칩(F8)을 네이버 원본에서 기계 복구(멱등).
# 2026-07-08 추가: 게이트 간헐 FAIL(7/4·6·7 push 차단) 근본 대응 → 게이트 전에 수리해 통과율 고정.
Write-Log ""
Write-Log "=== Tistory Structure Auto-Fix @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
if ($TistorySuspended) {
    Write-Log "SKIP auto-fix: 티스토리 중단됨."
} elseif ($exit -ne 0) {
    Write-Log "SKIP auto-fix: 콘텐츠 단계 exit $exit."
} else {
    try {
        $YMD = Get-Date -Format "yyMMdd"
        & python "$ProjectRoot\scripts\fix_tistory_violations.py" $YMD 2>&1 | ForEach-Object {
            $line = "$_"; Write-Host $line
            [System.IO.File]::AppendAllText($LogFile, "$line`r`n", $utf8NoBom)
        }
        Write-Log "Tistory auto-fix exit: $LASTEXITCODE"
    } catch {
        Write-Log "WARN (Tistory auto-fix): $_ — 게이트가 최종 판정."
    }
}

# === Step 1.7: 티스토리 Phase B 검수 게이트 (구조+중복) ===
# daily-prompt.md §5.5.9-bis/ter. 모델 honor-system이 아닌 wrapper 강제 지점.
# FAIL 시 $gateBlocked=$true → Step 2에서 commit/push 차단.
Write-Log ""
Write-Log "=== Tistory QA Gate @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
$gateBlocked = $false
if ($TistorySuspended) {
    Write-Log "SKIP Gate: Tistory 자동 발행 일시 중단(`$TistorySuspended=$true). 수동 작성은 별도."
} elseif ($exit -ne 0) {
    Write-Log "SKIP Gate: Claude content step exit $exit (콘텐츠 실패 시 push도 어차피 스킵)."
} else {
    $GateScript = Join-Path $ScriptsDir "tistory-gate.ps1"
    $GateDay    = Get-Date -Format "yyMMdd"
    if (Test-Path -LiteralPath $GateScript) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $GateScript -Day $GateDay 2>&1 |
        ForEach-Object {
            $line = "$_"
            Write-Host $line
            [System.IO.File]::AppendAllText($LogFile, "$line`r`n", $utf8NoBom)
        }
        $gateExit = $LASTEXITCODE
        Write-Log "Gate exit code: $gateExit"
        if ($gateExit -ne 0) { $gateBlocked = $true }
    } else {
        Write-Log "WARN: $GateScript 없음 — 게이트 미실행(차단하지 않음)."
    }
}

# === Step 1.8: 발행 검증 게이트 (2026-09-11 신설 — 사용자 지시) ===
# 계기: 7/1~9/10 구간을 네이버 실제 등록분과 대조했더니 **원고 112건이 생성만 되고 등록되지
#   않았다**(stats/미업로드_원고_점검_20260911.md). 그중 56건이 8/17·18·21·23·30·9/3·5·6
#   — 그날 치가 통째로 빠진 패턴인데, 스크립트는 매번 성공으로 끝났다. 볼 수 있는 계기판이
#   없었던 게 사고가 두 달을 간 이유다.
#
# ⚠️ 이 게이트가 검증할 수 있는 것과 없는 것을 분명히 해 둔다.
#   daily-run은 **네이버에 업로드하지 않는다** — 등록은 에디터 복사-붙여넣기(수동)다.
#   따라서 여기서 기계적으로 확인 가능한 건 아래 (1)(2)까지다.
#     (1) 오늘 올릴 원고가 실제로 $ExpectedPosts건 만들어졌는가   ← 8/27~29형(생성 0건) 차단
#     (2) 발행이력.md가 그 결과를 반영했는가                      ← 9/7~9형(이력 결손) 차단
#     (3) 최근 14일 중 원고가 모자란 날이 있는가                  ← 결번 조기 발견
#   **실제 네이버 등록 여부는 여기서 알 수 없다.** 그건 주간 통계 대조(stats/weekly)로만
#   확인되므로, 월요일 실행분에서 "지난주 등록분과 대조하라"는 리마인더를 로그·배너에 남긴다.
#
# 실패해도 commit/push는 막지 않는다 — 만든 원고는 보존해야 하고, 티스토리 게이트와 달리
#   여기서 막으면 원고가 로컬에만 남아 오히려 유실 위험이 커진다. 대신 LAST_FAILURE.txt를
#   남겨 대시보드에 배너를 띄우고 종료코드를 3으로 돌려 스케줄러가 실패로 기록하게 한다.
Write-Log ""
Write-Log "=== Step 1.8: Publish Verification Gate @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
$publishGateFailed = $false
$gateReasons = @()

if ($exit -ne 0) {
    Write-Log "SKIP Gate: Step 1이 exit $exit 로 끝나 이미 실패 처리됨."
} else {
    $YMD = Get-Date -Format "yyMMdd"

    # --- (1) 오늘 생성 건수 ---
    $todayDir = Join-Path $OutputDir $YMD
    $madeToday = 0
    if (Test-Path -LiteralPath $todayDir) {
        $madeToday = @(Get-ChildItem -LiteralPath $todayDir -Filter "*.html" -File -EA SilentlyContinue |
            Where-Object { $_.Name -ne "index.html" }).Count
    }
    Write-Log "(1) 오늘($YMD) 생성 원고: $madeToday / $ExpectedPosts 건"
    if ($madeToday -lt $ExpectedPosts) {
        $publishGateFailed = $true
        $gateReasons += "오늘 원고 ${madeToday}건 (기대 ${ExpectedPosts}건)"
        Write-Log "    [FAIL] 생성 건수 미달."
    }

    # --- (2) 발행이력.md 갱신 후 오늘자 행 수 확인 ---
    # 이력 갱신을 파이프라인 마지막 고정 단계로 만든다. 9/7~9/9이 이력에서 통째로 빠져 있었던
    # 이유가 이 스크립트를 따로 돌려야 했기 때문이다.
    $HistFile = Join-Path $ProjectRoot "발행이력.md"
    try {
        & python "$ProjectRoot\scripts\build_publish_history.py" 2>&1 | ForEach-Object {
            $line = "$_"
            Write-Host $line
            [System.IO.File]::AppendAllText($LogFile, "$line`r`n", $utf8NoBom)
        }
        $histExit = $LASTEXITCODE
        Write-Log "build_publish_history exit: $histExit"
        if ($histExit -ne 0) {
            $publishGateFailed = $true
            $gateReasons += "발행이력 갱신 실패(exit=$histExit)"
        }
    } catch {
        $publishGateFailed = $true
        $gateReasons += "발행이력 갱신 중 예외: $_"
        Write-Log "    [FAIL] build_publish_history.py 예외: $_"
    }

    # 이력 본문을 한 번만 읽어 (2)(3)에서 같이 쓴다.
    # ⚠️ Select-String -SimpleMatch 에 [regex]::Escape 한 패턴을 넘기면 역슬래시를 문자 그대로
    #    찾아 항상 0건이 나온다. 정규식 매칭으로 통일한다.
    $histText = ""
    if (Test-Path -LiteralPath $HistFile) {
        $histText = Get-Content -LiteralPath $HistFile -Raw -Encoding utf8
    }
    # 발행이력 행 형식: | 26.09.11 | 국내여행 | `slug` | 제목 |
    $todayLabel = (Get-Date -Format "yy.MM.dd")
    $histRows = ([regex]::Matches($histText, [regex]::Escape("| $todayLabel |"))).Count
    Write-Log "(2) 발행이력.md 오늘자($todayLabel) 행: $histRows 건"
    if ($histRows -lt $madeToday) {
        $publishGateFailed = $true
        $gateReasons += "발행이력 반영 ${histRows}건 < 생성 ${madeToday}건"
        Write-Log "    [FAIL] 이력에 반영되지 않은 원고가 있음."
    }

    # --- (3) 최근 14일 결번 점검 ---
    # output/은 주간 정리로 비워지므로(2026-08-15~) 이력 기준으로 센다.
    $gaps = @()
    for ($i = 1; $i -le 14; $i++) {
        $lbl = (Get-Date).AddDays(-$i).ToString("yy.MM.dd")
        $n = ([regex]::Matches($histText, [regex]::Escape("| $lbl |"))).Count
        if ($n -lt $ExpectedPosts) { $gaps += "$lbl($n)" }
    }
    if ($gaps.Count -gt 0) {
        Write-Log "(3) 최근 14일 중 원고가 모자란 날: $($gaps -join ', ')"
        if ($gaps.Count -ge 3) {
            $publishGateFailed = $true
            $gateReasons += "최근 14일 결번 $($gaps.Count)일: $($gaps -join ', ')"
            Write-Log "    [FAIL] 결번이 3일 이상 — 파이프라인을 점검할 것."
        }
    } else {
        Write-Log "(3) 최근 14일 결번 없음."
    }

    # --- (4) 정책 준수 검증 — 요일 로테이션 · DROP 계열 · 여행 누수 (2026-09-16 신설) ---
    # 산문 규칙만으로 드리프트가 반복됐다: 09-15에 요일을 잘못 계산해 로테이션이 어긋났고,
    #   09-01~15 발행 105건 중 여행이 43건(41%)으로 보충 규칙이 여행으로 샜다.
    #   Step 0.7이 예방(요일 주입), 여기가 검출이다. 둘 다 .scripts/policy.json 한 표를 본다.
    if ($null -eq $Policy) {
        Write-Log "(4) SKIP: policy.json 없음 — 정책 준수 검증 생략."
    } else {
        $prefixes = @()
        if (Test-Path -LiteralPath $todayDir) {
            $prefixes = @(Get-ChildItem -LiteralPath $todayDir -Filter "*.html" -File -EA SilentlyContinue |
                Where-Object { $_.Name -ne "index.html" } |
                ForEach-Object { ($_.BaseName -split "_")[0] })
        }
        Write-Log "(4) 오늘 계열 구성: $(($prefixes | Group-Object | ForEach-Object { "$($_.Name) $($_.Count)" }) -join ' · ')"

        # 4-a. DROP 계열이 섞였나 (하드 위반)
        $dropHit = @($prefixes | Where-Object { $Policy.dropped -contains $_ } | Select-Object -Unique)
        if ($dropHit.Count -gt 0) {
            $publishGateFailed = $true
            $gateReasons += "DROP 계열 발행: $($dropHit -join ', ')"
            Write-Log "    [FAIL] DROP 계열이 발행됐다 — $($dropHit -join ', ')"
        }

        # 4-b. 오늘 요일의 기대 로테이션 2계열이 각각 있나
        if ($wantRotation.Count -ge 2) {
            $missRot = @($wantRotation | Where-Object { $prefixes -notcontains $_ })
            if ($missRot.Count -gt 0) {
                $publishGateFailed = $true
                $gateReasons += "${todayDow}요일 로테이션 누락: $(($missRot | ForEach-Object { $_ + '_' }) -join ', ')"
                Write-Log "    [FAIL] ${todayDow}요일 기대 로테이션 누락 — $($missRot -join ', ')"
            } else {
                Write-Log "    로테이션 OK (${todayDow}: $($wantRotation -join ' + '))"
            }
        }

        # 4-c. 여행 누수 (비여행 칸을 여행으로 채웠나)
        $travelN = @($prefixes | Where-Object { $_ -eq "travel" }).Count
        if ($travelN -gt $Policy.travelMax) {
            $publishGateFailed = $true
            $gateReasons += "여행 누수 ${travelN}건 (상한 $($Policy.travelMax))"
            Write-Log "    [FAIL] 여행 ${travelN}건 — 상한 $($Policy.travelMax) 초과. 비여행 칸이 여행으로 샜다."
        }

        # 4-d. 슬롯 목표 대조 (참고 — 위 셋과 달리 실패로 만들지 않는다)
        $slotCount = @{}
        foreach ($p in $prefixes) {
            $slot = "보충"
            if ($Policy.slotByPrefix.PSObject.Properties.Name -contains $p) { $slot = $Policy.slotByPrefix.$p }
            if (-not $slotCount.ContainsKey($slot)) { $slotCount[$slot] = 0 }
            $slotCount[$slot]++
        }
        $slotTxt = @()
        foreach ($s in $Policy.slotTarget.PSObject.Properties.Name) {
            $have = 0
            if ($slotCount.ContainsKey($s)) { $have = $slotCount[$s] }
            $mark = ""
            if ($have -ne $Policy.slotTarget.$s) { $mark = " (목표 $($Policy.slotTarget.$s))" }
            $slotTxt += "${s} ${have}${mark}"
        }
        Write-Log "    슬롯: $($slotTxt -join ' · ')"
    }

    # --- (5) 월요일: 네이버 실제 등록분 대조 리마인더 (자동 검증 불가 영역) ---
    if ((Get-Date).DayOfWeek -eq [System.DayOfWeek]::Monday) {
        Write-Log "(5) [REMINDER] 월요일 — 네이버 주간 통계를 캡처해 stats/weekly에 적재하고,"
        Write-Log "    실제 등록분과 발행이력.md를 대조하십시오. 업로드는 수동이라 스크립트가 검증할 수 없습니다."
        Write-Log "    대조 절차: stats/미업로드_원고_점검_20260911.md 참조."
    }

    if ($publishGateFailed) {
        $detail = ($gateReasons -join " / ")
        Write-Log "[PUBLISH GATE FAIL] $detail"
        Set-Failure "PUBLISH" $detail "output/$YMD 확인 후 부족분 수동 생성. 네이버 등록은 별도 — 붙여넣기 누락분이 없는지 stats/weekly와 대조."
    } else {
        Write-Log "[PUBLISH GATE OK] 생성 ${madeToday}건 · 이력 ${histRows}건 · 결번 $($gaps.Count)일"
    }
}

# 종료코드 계산 — Step 1은 성공했지만 검증 게이트가 실패하면 3을 돌려준다.
# (Step 2에서 커밋·푸시는 정상 진행한다. 원고를 원격에 남기는 쪽이 언제나 안전하다.)
function Get-FinalExit {
    if ($publishGateFailed -and $exit -eq 0) { return 3 }
    return $exit
}

# === Step 2: 작성 성공 시 git add / commit / push ===
Write-Log ""
Write-Log "=== Git Auto-Push @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="

# 여기까지 왔고 Step 1과 검증 게이트가 모두 통과했다면 지난 실패는 해소된 것 — 신호 파일을 지운다.
# ⚠️ $publishGateFailed 조건이 빠지면 방금 Step 1.8이 쓴 실패 신호를 여기서 지워버린다.
if ($exit -eq 0 -and -not $publishGateFailed -and (Test-Path -LiteralPath $FailFlag)) {
    Remove-Item -LiteralPath $FailFlag -Force -EA SilentlyContinue
    Write-Log "이전 실패 신호(LAST_FAILURE.txt) 해소 - 삭제함."
}

if ($exit -ne 0) {
    Write-Log "SKIP: Claude exited with code $exit, no push attempted."
    exit $exit
}

if ($gateBlocked) {
    Write-Log "[BLOCK] Tistory QA Gate FAIL — commit/push 중단. FAIL 슬러그를 표준 템플릿으로 재작성 후 다음 실행에서 재검증."
    exit 2
}

try {
    $YYMMDD               = Get-Date -Format "yyMMdd"
    $TodayRelPath         = "output/$YYMMDD"
    $TodayAbsPath         = Join-Path $ProjectRoot "output\$YYMMDD"
    $TistoryRelPath       = "output_tistory/$YYMMDD"
    $TistoryAbsPath       = Join-Path $ProjectRoot "output_tistory\$YYMMDD"
    $ImagesRelPath        = "images/$YYMMDD"
    $ImagesAbsPath        = Join-Path $ProjectRoot "images\$YYMMDD"
    $InstaRelPath         = "output_insta/$YYMMDD"
    $InstaAbsPath         = Join-Path $ProjectRoot "output_insta\$YYMMDD"
    # 추적 가능한 트래커 파일 (있을 때만 stage)
    $Trackers = @(
        "국내여행지.md",
        "생활정보.md",
        "발행이력.md",
        "sub_topic_tracker.md",
        "spreadsheet.md",
        "receipt.md"
    )

    # 오늘자 output(네이버) 폴더 stage
    if (Test-Path $TodayAbsPath) {
        $out = & git add -- $TodayRelPath 2>&1
        if ($out) { $out | ForEach-Object { Write-Log "git add output: $_" } }
    } else {
        Write-Log "WARN: $TodayAbsPath not found. Skipping output stage."
    }

    # 오늘자 output_tistory(티스토리 미러) 폴더 stage — 자동 일시 중단 시 skip
    if ($TistorySuspended) {
        Write-Log "SKIP Tistory stage: 자동 발행 일시 중단(수동 1건은 사용자가 별도 stage/push)."
    } elseif (Test-Path $TistoryAbsPath) {
        $out = & git add -- $TistoryRelPath 2>&1
        if ($out) { $out | ForEach-Object { Write-Log "git add output_tistory: $_" } }
    } else {
        Write-Log "WARN: $TistoryAbsPath not found. Skipping tistory stage."
    }

    # 오늘자 images 폴더 stage (네이버/티스토리 공용 자산)
    if (Test-Path $ImagesAbsPath) {
        $out = & git add -- $ImagesRelPath 2>&1
        if ($out) { $out | ForEach-Object { Write-Log "git add images: $_" } }
    }

    # 오늘자 output_insta(인스타 카드) 폴더 stage
    if (Test-Path $InstaAbsPath) {
        # (1) 원본(prompts.md/caption.txt/card_NN_*.svg) — .gitignore 존중(img/·*_done.svg·png/ 제외)
        $out = & git add -- $InstaRelPath 2>&1
        if ($out) { $out | ForEach-Object { Write-Log "git add output_insta: $_" } }
        # (2) **당일 png만 강제 포함** (인스타 즉시 업로드용 최종본 — 원격 사용 필요, 2026-05-19).
        #     png는 .gitignore 기본 제외(과거 누적분 사고 방지)라 -f로 당일치만 push.
        Get-ChildItem -LiteralPath $InstaAbsPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $pngRel = "$InstaRelPath/$($_.Name)/png"
            if (Test-Path -LiteralPath (Join-Path $_.FullName "png")) {
                $out = & git add -f -- $pngRel 2>&1
                if ($out) { $out | ForEach-Object { Write-Log "git add -f png: $_" } }
            }
        }
    } else {
        Write-Log "WARN: $InstaAbsPath not found. Skipping insta stage."
    }

    # 인스타 png retention (2026-05-19): 약 3일 지난 날짜의 추적 png를 git에서 제거.
    # png는 인스타 즉시 업로드용이라 최근 ~3일만 원격 보유하면 충분 → 누적 비대화 방지.
    # git rm(인덱스+워킹트리)로 다음 커밋부터 최신 트리에서 빠진다(원본 SVG/캡션은 유지).
    try {
        $pngCutoff = [int]((Get-Date).AddDays(-3).ToString("yyMMdd"))
        $trackedInsta = & git ls-files -- output_insta 2>$null
        $oldPng = @($trackedInsta | Where-Object {
            $_ -match '^output_insta/(\d{6})/.+/png/.+\.png$' -and [int]$Matches[1] -lt $pngCutoff
        })
        if ($oldPng.Count -gt 0) {
            $rmOut = & git rm -q --ignore-unmatch -- $oldPng 2>&1
            if ($rmOut) { $rmOut | ForEach-Object { Write-Log "git rm old png: $_" } }
            Write-Log "insta png retention: $($oldPng.Count)개 png 제거 (날짜 < $pngCutoff)"
        } else {
            Write-Log "insta png retention: 제거 대상 없음 (cutoff $pngCutoff)"
        }
    } catch { Write-Log "WARN insta png retention: $_" }

    # 통합 대시보드 stage (매일 갱신되므로 항상 포함)
    $DashboardAbsPath = Join-Path $ProjectRoot "dashboard.html"
    if (Test-Path $DashboardAbsPath) {
        $out = & git add -- "dashboard.html" 2>&1
        if ($out) { $out | ForEach-Object { Write-Log "git add dashboard.html: $_" } }
    }

    # 수동 이미지 헬퍼 대시보드 stage
    $PromptHelperAbsPath = Join-Path $ProjectRoot "prompt_helper.html"
    if (Test-Path $PromptHelperAbsPath) {
        $out = & git add -- "prompt_helper.html" 2>&1
        if ($out) { $out | ForEach-Object { Write-Log "git add prompt_helper.html: $_" } }
    }

    # 트래커 파일 stage (변경된 것만 자동으로 잡힘)
    foreach ($t in $Trackers) {
        $tp = Join-Path $ProjectRoot $t
        if (Test-Path -LiteralPath $tp) {
            $out = & git add -- "$t" 2>&1
            if ($out) { $out | ForEach-Object { Write-Log "git add $t : $_" } }
        }
    }

    # staged 변경 내역 확인
    $staged = & git diff --cached --name-only 2>&1
    if ([string]::IsNullOrWhiteSpace(($staged -join "`n"))) {
        Write-Log "INFO: No staged changes; skipping commit/push."
        exit (Get-FinalExit)
    }

    Write-Log "Staged files:"
    $staged | ForEach-Object { Write-Log "  $_" }

    # commit
    $commitDate = Get-Date -Format "yyyy-MM-dd"
    $msg = "[Auto] $commitDate 일자 원고 자동 발행 (네이버 + 티스토리)"
    $out = & git commit -m "$msg" 2>&1
    if ($out) { $out | ForEach-Object { Write-Log "git commit: $_" } }
    $commitExit = $LASTEXITCODE
    Write-Log "Commit exit: $commitExit"

    if ($commitExit -ne 0) {
        Write-Log "ERROR: commit failed; abort push."
        exit (Get-FinalExit)
    }

    # push (현재 체크아웃된 브랜치 → origin)
    $branch = (& git rev-parse --abbrev-ref HEAD 2>&1).Trim()
    Write-Log "Pushing branch '$branch' to origin..."
    $out = & git push origin "$branch" 2>&1
    if ($out) { $out | ForEach-Object { Write-Log "git push: $_" } }
    $pushExit = $LASTEXITCODE
    Write-Log "Push exit: $pushExit"

    if ($pushExit -eq 0) {
        Write-Log "OK: Auto push completed."
    } else {
        Write-Log "ERROR: push failed (exit $pushExit). Commit is local; will retry next run or manual push."
    }
} catch {
    [System.IO.File]::AppendAllText($LogFile, "ERROR (Git step): $_`r`n", $utf8NoBom)
}

$final = Get-FinalExit
if ($final -eq 3) {
    Write-Log ""
    Write-Log "=== 종료코드 3 — 원고는 커밋·푸시됐지만 발행 검증 게이트가 실패했습니다. ==="
    Write-Log "    대시보드 상단 배너와 $FailFlag 를 확인하십시오."
}
exit $final
