# prune-archives.ps1
# output/ · images/ 의 오래된 날짜 폴더를 정리한다 (2026-08-15 신설 — 사용자 지시)
#
# 왜 스크립트인가: 날짜 컷오프로 폴더를 지우는 일은 판단이 0이고 읽을 것도 없다.
#   서브에이전트로 띄우면 비용만 늘고, 파일 삭제를 모델 재량에 맡기는 위험이 생긴다.
#   대신 **되돌릴 수 없는 작업이므로 순서를 코드로 못 박았다** — 이력 먼저, 삭제 나중.
#
# 사용:
#   .\.scripts\prune-archives.ps1                 # 최근 7일 남기고 정리
#   .\.scripts\prune-archives.ps1 -KeepDays 14
#   .\.scripts\prune-archives.ps1 -DryRun         # 지우지 않고 대상만 출력
#
# daily-run.ps1 Step 0.6 이 매주 월요일 호출한다.

param(
    [int]$KeepDays = 7,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProjectRoot = "D:\lightsail\naverblog"
$HistoryFile = Join-Path $ProjectRoot "발행이력.md"
$Builder     = Join-Path $ProjectRoot "scripts\build_publish_history.py"

function Log($m) { Write-Host "[prune] $m" }

# ============================================================
# 1. 이력을 먼저 기록한다 (실패하면 아무것도 지우지 않는다)
# ============================================================
Log "발행이력 갱신 중..."
$before = 0
if (Test-Path -LiteralPath $HistoryFile) {
    $before = @(Select-String -LiteralPath $HistoryFile -Pattern '^\| \d{2}\.\d{2}\.\d{2} \|').Count
}

if (-not (Test-Path -LiteralPath $Builder)) {
    Log "FATAL: $Builder 없음 — 이력을 남길 수 없으므로 정리를 중단한다."
    exit 1
}

& python $Builder
if ($LASTEXITCODE -ne 0) {
    Log "FATAL: 이력 갱신 실패(exit $LASTEXITCODE) — 정리를 중단한다. 원고가 이력 없이 사라지면 복구가 안 된다."
    exit 1
}

$after = @(Select-String -LiteralPath $HistoryFile -Pattern '^\| \d{2}\.\d{2}\.\d{2} \|').Count
Log "이력 $before → $after 건"
if ($after -lt 1) {
    Log "FATAL: 이력이 비어 있다 — 정리를 중단한다."
    exit 1
}

# ============================================================
# 2. 컷오프 계산
# ============================================================
$cutoff = (Get-Date).AddDays(-$KeepDays).ToString("yyMMdd")
Log "컷오프 = $cutoff (이 날짜보다 이전 폴더 삭제 · 최근 $($KeepDays)일 보존)"

# ============================================================
# 3. 삭제
# ============================================================
$totalDirs = 0
$totalFiles = 0
$totalBytes = 0

foreach ($base in @("output", "images")) {
    $baseDir = Join-Path $ProjectRoot $base
    if (-not (Test-Path -LiteralPath $baseDir)) { continue }

    # 6자리 날짜 폴더만 대상. output\sample 같은 비날짜 폴더는 건드리지 않는다.
    $targets = @(Get-ChildItem -LiteralPath $baseDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{6}$' -and $_.Name -lt $cutoff } |
        Sort-Object Name)

    if ($targets.Count -eq 0) { Log "$base : 대상 없음"; continue }

    $files = 0
    $bytes = 0
    foreach ($t in $targets) {
        $ff = @(Get-ChildItem -LiteralPath $t.FullName -File -Recurse -ErrorAction SilentlyContinue)
        $files += $ff.Count
        foreach ($f in $ff) { $bytes += $f.Length }
    }

    Log ("$base : 폴더 {0}개 / 파일 {1}개 / {2:N1} MB  [{3} ~ {4}]" -f `
        $targets.Count, $files, ($bytes / 1MB), $targets[0].Name, $targets[-1].Name)

    if (-not $DryRun) {
        foreach ($t in $targets) {
            Remove-Item -LiteralPath $t.FullName -Recurse -Force -Confirm:$false
        }
        Log "$base : 삭제 완료"
    }

    $totalDirs += $targets.Count
    $totalFiles += $files
    $totalBytes += $bytes
}

if ($DryRun) {
    Log ("DRY RUN — 삭제하지 않았다. 대상 합계: 폴더 {0} / 파일 {1} / {2:N1} MB" -f $totalDirs, $totalFiles, ($totalBytes / 1MB))
} else {
    Log ("[PRUNE] 폴더 {0} / 파일 {1} / {2:N1} MB 정리 · 이력 {3}건 보존" -f $totalDirs, $totalFiles, ($totalBytes / 1MB), $after)
}
