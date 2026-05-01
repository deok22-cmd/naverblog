# Naverblog 일일 자동 발행 PowerShell 래퍼
# Windows 작업 스케줄러가 매일 새벽 4:00 실행

$ErrorActionPreference = "Continue"
$ProjectRoot = "D:\lightsail\naverblog"
$ScriptsDir  = Join-Path $ProjectRoot ".scripts"
$LogsDir     = Join-Path $ScriptsDir "logs"
$PromptFile  = Join-Path $ScriptsDir "daily-prompt.md"
$Stamp       = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile     = Join-Path $LogsDir "daily-$Stamp.log"

# 작업 디렉터리 이동
Set-Location $ProjectRoot

# 로그 헤더 (UTF-8 BOM 없이)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($LogFile, "=== Naverblog Daily Run @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===`r`n", $utf8NoBom)
[System.IO.File]::AppendAllText($LogFile, "ProjectRoot: $ProjectRoot`r`n", $utf8NoBom)
[System.IO.File]::AppendAllText($LogFile, "PromptFile : $PromptFile`r`n", $utf8NoBom)
[System.IO.File]::AppendAllText($LogFile, "Model      : claude-sonnet-4-6`r`n`r`n", $utf8NoBom)

# 프롬프트 로드 후 Claude Code CLI에 stdin으로 전달
try {
    $prompt = Get-Content -LiteralPath $PromptFile -Raw -Encoding utf8

    # Claude 출력은 UTF-8로 일관되게 로그에 기록 (한 줄씩 추가하며 화면에도 표시)
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
    [System.IO.File]::AppendAllText($LogFile, "`r`n=== Exit code: $exit ===`r`n", $utf8NoBom)
    exit $exit
} catch {
    [System.IO.File]::AppendAllText($LogFile, "FATAL: $_`r`n", $utf8NoBom)
    exit 1
}
