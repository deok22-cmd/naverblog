# Naverblog 일일 자동 발행 PowerShell 래퍼
# Windows 작업 스케줄러가 매일 새벽 4:00 실행
# 1) Claude CLI로 원고 5건 작성 → 2) 작성 결과만 GitHub에 자동 push

$ErrorActionPreference = "Continue"
$ProjectRoot = "D:\lightsail\naverblog"
$ScriptsDir  = Join-Path $ProjectRoot ".scripts"
$LogsDir     = Join-Path $ScriptsDir "logs"
$PromptFile  = Join-Path $ScriptsDir "daily-prompt.md"
$Stamp       = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile     = Join-Path $LogsDir "daily-$Stamp.log"

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

# === Step 1: Claude CLI로 원고 작성 ===
try {
    $prompt = Get-Content -LiteralPath $PromptFile -Raw -Encoding utf8

    $prompt | & claude `
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
    $exit = $LASTEXITCODE
    Write-Log ""
    Write-Log "=== Claude exit code: $exit ==="
} catch {
    [System.IO.File]::AppendAllText($LogFile, "FATAL (Claude step): $_`r`n", $utf8NoBom)
    exit 1
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

# === Step 1.6: 인스타 카드 채널 (Phase C) ===
# 콘텐츠(네이버/티스토리) 성공 시에만 진행. 실패는 비치명적(전체 종료코드 불변).
Write-Log ""
Write-Log "=== Insta Card Channel @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
if ($exit -ne 0) {
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

        # Phase C-2: 슬러그별 배경 생성 + 래스터 (순수 node — Claude 예산 미사용, 멱등)
        $InstaDay = Join-Path $ProjectRoot "output_insta\$YMD"
        $nodeOk   = [bool](Get-Command node -ErrorAction SilentlyContinue)
        if (-not $nodeOk) {
            Write-Log "WARN: node 미발견 — Phase C-2(이미지/래스터) 스킵."
        } elseif (-not $env:GEMINI_API_KEY) {
            Write-Log "WARN: GEMINI_API_KEY 없음 — Phase C-2 스킵(카드 SVG는 생성됨)."
        } elseif (-not (Test-Path -LiteralPath $InstaDay)) {
            Write-Log "WARN: $InstaDay 없음 — insta-card-builder 산출물 없음. Phase C-2 스킵."
        } else {
            Write-Log "--- Phase C-2: insta_render + insta_rasterize (node) ---"
            Get-ChildItem -LiteralPath $InstaDay -Directory | ForEach-Object {
                $slugName = $_.Name
                $slugDir  = $_.FullName
                $cardCnt  = (Get-ChildItem -LiteralPath $slugDir -Filter "card_*.svg" -ErrorAction SilentlyContinue |
                             Where-Object { $_.Name -notlike "*_done.svg" }).Count
                $pngDir   = Join-Path $slugDir "png"
                $pngCnt   = 0
                if (Test-Path -LiteralPath $pngDir) {
                    $pngCnt = (Get-ChildItem -LiteralPath $pngDir -Filter "card_*.png" -ErrorAction SilentlyContinue).Count
                }
                if ($cardCnt -lt 1) {
                    Write-Log "  SKIP $slugName : card SVG 없음"
                } elseif ($pngCnt -ge 10) {
                    Write-Log "  SKIP $slugName : png 이미 $pngCnt 개 (멱등)"
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

# === Step 2: 작성 성공 시 git add / commit / push ===
Write-Log ""
Write-Log "=== Git Auto-Push @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="

if ($exit -ne 0) {
    Write-Log "SKIP: Claude exited with code $exit, no push attempted."
    exit $exit
}

try {
    $YYMMDD               = Get-Date -Format "yyMMdd"
    $TodayRelPath         = "output/$YYMMDD"
    $TodayAbsPath         = Join-Path $ProjectRoot "output\$YYMMDD"
    $TistoryRelPath       = "output_tistory/$YYMMDD"
    $TistoryAbsPath       = Join-Path $ProjectRoot "output_tistory\$YYMMDD"
    $ImagesRelPath        = "images/$YYMMDD"
    $ImagesAbsPath        = Join-Path $ProjectRoot "images\$YYMMDD"
    # 추적 가능한 트래커 파일 (있을 때만 stage)
    $Trackers = @(
        "국내여행지.md",
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

    # 오늘자 output_tistory(티스토리 미러) 폴더 stage
    if (Test-Path $TistoryAbsPath) {
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

    # 통합 대시보드 stage (매일 갱신되므로 항상 포함)
    $DashboardAbsPath = Join-Path $ProjectRoot "dashboard.html"
    if (Test-Path $DashboardAbsPath) {
        $out = & git add -- "dashboard.html" 2>&1
        if ($out) { $out | ForEach-Object { Write-Log "git add dashboard.html: $_" } }
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
        exit $exit
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
        exit $exit
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

exit $exit
