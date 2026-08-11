# build-dashboard.ps1
# 4채널 통합 운영 대시보드 빌더 (2026-08-09 전면 개편)
#
#   채널 1  네이버 블로그   output/<YYMMDD>/*.html            자동 7건/일
#   채널 2  티스토리(애드센스) output_adsense/<YYMMDD>_<slug>/post.html   수동 1건/일
#   채널 3  인스타 카드뉴스  output_adsense/<...>/insta/png/*.png
#   채널 4  쓰레드          output_adsense/<...>/threads_post.txt
#
# 핵심 화면 = 「네이버 일자별 x 슬롯 매트릭스」. 발행 믹스(여행3/인접1/생활2/신규1)
# 준수 여부와 계열 편중(2026-08-01 큐 고갈 사고 유형)을 한눈에 보게 한다.
#
# daily-run.ps1이 매일 호출하며, 수동 단독 실행도 가능:  .\.scripts\build-dashboard.ps1

$ErrorActionPreference = "Continue"
$ProjectRoot   = "D:\lightsail\naverblog"
$OutputDir     = Join-Path $ProjectRoot "output"
$AdsenseDir    = Join-Path $ProjectRoot "output_adsense"
$TistoryDir    = Join-Path $ProjectRoot "output_tistory"
$InstaDir      = Join-Path $ProjectRoot "output_insta"
$ImagesDir     = Join-Path $ProjectRoot "images"
$DashboardPath = Join-Path $ProjectRoot "dashboard.html"

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# 새 믹스 시행일 (이 날짜부터 신규 로테이션 슬롯 준수를 판정)
$NewMixFrom = "260810"

# ============================================================
# 0. 계열(prefix) 사전 — 슬롯 그룹 / 라벨 / 색
#    색은 dataviz validate_palette.js 통과 조합 (light, --pairs all ALL PASS)
# ============================================================
$SlotOrder = @("여행", "인접", "생활", "신규", "보충")
$SlotColor = @{
    "여행" = "#0891B2"   # cyan-600
    "인접" = "#4F46E5"   # indigo-600
    "생활" = "#EA580C"   # orange-600
    "신규" = "#DB2777"   # pink-600
    "보충" = "#64748B"   # 중립 회색 — 의도적으로 categorical 팔레트 밖
}
$SlotTarget = @{ "여행" = 3; "인접" = 1; "생활" = 2; "신규" = 1; "보충" = 0 }
$SlotDesc = @{
    "여행" = "국내여행 (주력)"
    "인접" = "인접 롱테일 — 해외·교통 여행실무 우선"
    "생활" = "생활 버티컬 — 경조사 + 자동차"
    "신규" = "신규 로테이션 — 레시피·전원주택·기기실무"
    "보충" = "보충·레거시 계열 (큐 부족 시에만)"
}

# prefix -> @(슬롯, 한글라벨)
$Cat = @{
    "travel" = @("여행", "국내여행")
    "local"  = @("인접", "인접·여행실무")
    "rite"   = @("생활", "경조사")
    "car"    = @("생활", "자동차")
    "recipe" = @("신규", "레시피")
    "house"  = @("신규", "전원주택")
    "tech"   = @("신규", "기기·IT실무")
    "gov"    = @("보충", "지원금")
    "appli"  = @("보충", "계절가전")
    "cert"   = @("보충", "증명서(폐지)")
    "admin"  = @("보충", "행정발급")
    "money"  = @("보충", "재테크(폐지)")
    "home"   = @("보충", "집·인테리어")
}

# 요일별 신규 로테이션 기대 계열 (daily-prompt.md 2조)
$RotationByDow = @{
    "월" = "recipe"; "목" = "recipe"; "일" = "recipe"
    "화" = "house";  "금" = "house"
    "수" = "tech";   "토" = "tech"
}
$DowKr = @{
    "Monday" = "월"; "Tuesday" = "화"; "Wednesday" = "수"; "Thursday" = "목"
    "Friday" = "금"; "Saturday" = "토"; "Sunday" = "일"
}

function Enc([string]$s) {
    if ($null -eq $s) { return "" }
    return $s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;")
}

function Get-H1([string]$path) {
    try {
        $m = Select-String -Path $path -Pattern '<h1[^>]*>([^<]+)' -List -ErrorAction SilentlyContinue
        if ($m) { return $m.Matches[0].Groups[1].Value.Trim() }
    } catch { }
    return ""
}

function Format-DateLabel([string]$d) {
    if ($d.Length -ne 6) { return $d }
    return "20" + $d.Substring(0, 2) + "-" + $d.Substring(2, 2) + "-" + $d.Substring(4, 2)
}

function Get-Dow([string]$d) {
    try {
        $dt = [datetime]::ParseExact("20$d", "yyyyMMdd", $null)
        return $DowKr[$dt.DayOfWeek.ToString()]
    } catch { return "" }
}

function Days-Since([string]$d) {
    try {
        $dt = [datetime]::ParseExact("20$d", "yyyyMMdd", $null)
        return [int]((Get-Date).Date - $dt.Date).TotalDays
    } catch { return -1 }
}

# ============================================================
# 1. 채널 1 — 네이버 블로그 스캔
# ============================================================
$naverDays = @()
if (Test-Path $OutputDir) {
    $dateDirs = Get-ChildItem -Path $OutputDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{6}$' } |
        Sort-Object Name -Descending

    foreach ($dd in $dateDirs) {
        $files = @(Get-ChildItem -Path $dd.FullName -Filter "*.html" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne "index.html" } | Sort-Object Name)
        if ($files.Count -eq 0) { continue }

        $posts = @()
        foreach ($f in $files) {
            $prefix = ($f.BaseName -split '_')[0]
            if ($Cat.ContainsKey($prefix)) { $slot = $Cat[$prefix][0]; $label = $Cat[$prefix][1] }
            else { $slot = "보충"; $label = $prefix }
            $posts += [PSCustomObject]@{
                File = $f.Name; Prefix = $prefix; Slot = $slot; Label = $label
                Title = (Get-H1 $f.FullName)
            }
        }

        $imgPath = Join-Path $ImagesDir $dd.Name
        $imgCount = 0
        if (Test-Path $imgPath) {
            $imgCount = @(Get-ChildItem -Path $imgPath -File -ErrorAction SilentlyContinue).Count
        }

        $naverDays += [PSCustomObject]@{
            Date     = $dd.Name
            Posts    = $posts
            Count    = $posts.Count
            HasIndex = (Test-Path (Join-Path $dd.FullName "index.html"))
            Images   = $imgCount
        }
    }
}

# ============================================================
# 2. 채널 2/3/4 — 애드센스 원소스 세트 스캔
# ============================================================
$adsenseSets = @()
if (Test-Path $AdsenseDir) {
    $setDirs = Get-ChildItem -Path $AdsenseDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(\d{6})_(.+)$' } |
        Sort-Object Name -Descending

    foreach ($sd in $setDirs) {
        $null = $sd.Name -match '^(\d{6})_(.+)$'
        $sDate = $Matches[1]; $sSlug = $Matches[2]

        $postPath = Join-Path $sd.FullName "post.html"
        $hasPost = Test-Path $postPath
        $title = ""
        if ($hasPost) { $title = Get-H1 $postPath }

        $pngDir = Join-Path $sd.FullName "insta\png"
        $pngCount = 0
        if (Test-Path $pngDir) {
            $pngCount = @(Get-ChildItem -Path $pngDir -Filter "*.png" -File -ErrorAction SilentlyContinue).Count
        }
        $hasCards   = Test-Path (Join-Path $sd.FullName "insta\cards.json")
        $hasCaption = Test-Path (Join-Path $sd.FullName "insta_caption.txt")
        $hasThreads = Test-Path (Join-Path $sd.FullName "threads_post.txt")
        $hasPhotos  = Test-Path (Join-Path $sd.FullName "photos.md")

        $srcDir = Join-Path $ProjectRoot "adsense_src\$sDate"
        $srcCount = 0
        if (Test-Path $srcDir) {
            $srcCount = @(Get-ChildItem -Path $srcDir -File -Include *.jpg, *.jpeg, *.png -Recurse -ErrorAction SilentlyContinue).Count
        }

        $done = 0
        if ($hasPost) { $done++ }
        if ($pngCount -ge 7 -and $hasCaption) { $done++ }
        if ($hasThreads) { $done++ }

        $adsenseSets += [PSCustomObject]@{
            Date = $sDate; Slug = $sSlug; Dir = $sd.Name; Title = $title
            HasPost = $hasPost; Png = $pngCount; HasCards = $hasCards
            HasCaption = $hasCaption; HasThreads = $hasThreads; HasPhotos = $hasPhotos
            SrcPhotos = $srcCount; Done = $done
        }
    }
}

# ============================================================
# 3. 레거시 채널
# ============================================================
function Count-DateDirs([string]$root) {
    if (-not (Test-Path $root)) { return @(0, 0, "-") }
    $dirs = @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{6}$' } | Sort-Object Name -Descending)
    if ($dirs.Count -eq 0) { return @(0, 0, "-") }
    $files = 0
    foreach ($d in $dirs) {
        $files += @(Get-ChildItem -Path $d.FullName -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne "index.html" }).Count
    }
    return @($dirs.Count, $files, $dirs[0].Name)
}
$legTistory = Count-DateDirs $TistoryDir
$legInsta   = Count-DateDirs $InstaDir

# ============================================================
# 4. 집계
# ============================================================
$totalNaver  = ($naverDays | Measure-Object -Property Count -Sum).Sum
if ($null -eq $totalNaver) { $totalNaver = 0 }
$activeDays  = $naverDays.Count
$latestDate  = "(없음)"
if ($activeDays -gt 0) { $latestDate = $naverDays[0].Date }

# 계열별 누적 / 최근 발행일
$serieStat = @{}
foreach ($day in $naverDays) {
    foreach ($p in $day.Posts) {
        if (-not $serieStat.ContainsKey($p.Prefix)) {
            $serieStat[$p.Prefix] = [PSCustomObject]@{
                Prefix = $p.Prefix; Slot = $p.Slot; Label = $p.Label; Count = 0; Last = $day.Date
            }
        }
        $serieStat[$p.Prefix].Count++
        if ($day.Date -gt $serieStat[$p.Prefix].Last) { $serieStat[$p.Prefix].Last = $day.Date }
    }
}
# 현행 믹스에 편성된 계열은 아직 0건이어도 행을 만들어 둔다(신규 로테이션 추적용)
foreach ($k in @("travel", "local", "rite", "car", "recipe", "house", "tech")) {
    if (-not $serieStat.ContainsKey($k)) {
        $serieStat[$k] = [PSCustomObject]@{
            Prefix = $k; Slot = $Cat[$k][0]; Label = $Cat[$k][1]; Count = 0; Last = ""
        }
    }
}
$serieRows = @($serieStat.Values | Sort-Object @{Expression = { $SlotOrder.IndexOf($_.Slot) } }, @{Expression = "Count"; Descending = $true })
$maxSerie = 1
if ($serieRows.Count -gt 0) { $maxSerie = ($serieRows | Measure-Object -Property Count -Maximum).Maximum }

$setsFull = @($adsenseSets | Where-Object { $_.Done -eq 3 }).Count
$totalPng = ($adsenseSets | Measure-Object -Property Png -Sum).Sum
if ($null -eq $totalPng) { $totalPng = 0 }
$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm"

# ============================================================
# 5. 네이버 매트릭스 행 렌더
# ============================================================
$sbMatrix = New-Object System.Text.StringBuilder
$rowIdx = 0
foreach ($day in $naverDays) {
    $rowIdx++
    $label = Format-DateLabel $day.Date
    $dow = Get-Dow $day.Date
    $hidden = ""
    if ($rowIdx -gt 21) { $hidden = " class=`"folded`"" }

    # 슬롯별 집계
    $bySlot = @{}
    foreach ($s in $SlotOrder) { $bySlot[$s] = @{} }
    foreach ($p in $day.Posts) {
        if (-not $bySlot[$p.Slot].ContainsKey($p.Label)) { $bySlot[$p.Slot][$p.Label] = 0 }
        $bySlot[$p.Slot][$p.Label]++
    }

    $cells = ""
    foreach ($s in $SlotOrder) {
        $n = 0
        foreach ($v in $bySlot[$s].Values) { $n += $v }
        if ($n -eq 0) {
            $cells += "<td class=`"cell empty`">·</td>"
            continue
        }
        $chips = ""
        foreach ($k in ($bySlot[$s].Keys | Sort-Object)) {
            $cnt = $bySlot[$s][$k]
            $mult = ""
            if ($cnt -gt 1) { $mult = " <b>&times;$cnt</b>" }
            $chips += "<span class=`"chip`" style=`"--c:$($SlotColor[$s])`">$(Enc $k)$mult</span>"
        }
        $off = ""
        if ($day.Date -ge $NewMixFrom -and $n -ne $SlotTarget[$s]) { $off = " off" }
        $cells += "<td class=`"cell$off`">$chips</td>"
    }

    # 점검 배지
    $flags = ""
    if ($day.Count -eq 7) {
        $flags += "<span class=`"badge ok`">7건</span>"
    } else {
        $flags += "<span class=`"badge warn`">$($day.Count)건</span>"
    }
    # 계열 편중 (2026-08-01 큐 고갈 사고 패턴)
    $skew = ""
    foreach ($p in ($day.Posts | Group-Object Prefix)) {
        $lim = 3
        if ($p.Name -eq "travel") { $lim = 4 }
        if ($p.Count -gt $lim) { $skew = "$($p.Name) $($p.Count)건" }
    }
    if ($skew -ne "") { $flags += "<span class=`"badge bad`" title=`"큐 고갈 시 한 계열이 하루를 잠식하는 패턴`">편중 $skew</span>" }
    # 신규 로테이션 요일 준수
    if ($day.Date -ge $NewMixFrom -and $RotationByDow.ContainsKey($dow)) {
        $want = $RotationByDow[$dow]
        $got = @($day.Posts | Where-Object { $_.Prefix -eq $want }).Count
        if ($got -eq 0) { $flags += "<span class=`"badge warn`">$want 누락</span>" }
    }
    if (-not $day.HasIndex) { $flags += "<span class=`"badge warn`">index 없음</span>" }

    $imgTxt = "-"
    if ($day.Images -gt 0) { $imgTxt = "$($day.Images)" }

    $null = $sbMatrix.Append("<tr$hidden><th class=`"dcell`"><a href=`"output/$($day.Date)/index.html`">$label</a><span class=`"dow`">$dow</span></th>$cells<td class=`"num`">$imgTxt</td><td class=`"flags`">$flags</td></tr>")

    # 제목 상세 행
    $lis = ""
    foreach ($p in ($day.Posts | Sort-Object @{Expression = { $SlotOrder.IndexOf($_.Slot) } }, Label)) {
        $t = $p.Title
        if ($t -eq "") { $t = $p.File }
        $lis += "<li><span class=`"dot`" style=`"--c:$($SlotColor[$p.Slot])`"></span><span class=`"lb`">$(Enc $p.Label)</span> <a href=`"output/$($day.Date)/$($p.File)`">$(Enc $t)</a></li>"
    }
    $null = $sbMatrix.Append("<tr$hidden class=`"det`"><td colspan=`"8`"><details><summary>원고 $($day.Count)건 제목 보기</summary><ul class=`"tlist`">$lis</ul></details></td></tr>")
}

# ============================================================
# 6. 계열 커버리지 행
# ============================================================
$sbSerie = New-Object System.Text.StringBuilder
foreach ($r in $serieRows) {
    $pct = [math]::Round(100.0 * $r.Count / $maxSerie)
    $gapCls = ""
    if ($r.Count -eq 0) {
        $lastTxt = "&mdash;"
        $gapTxt = "발행 없음"
        $gapCls = " stale"
    } else {
        $gap = Days-Since $r.Last
        $lastTxt = Format-DateLabel $r.Last
        $gapTxt = "$($gap)일 전"
        if ($gap -le 1) { $gapTxt = "최신" }
        elseif ($gap -ge 30) { $gapCls = " stale" }
    }
    $null = $sbSerie.Append("<tr><td class=`"scode`"><span class=`"dot`" style=`"--c:$($SlotColor[$r.Slot])`"></span>$(Enc $r.Label)<code>$($r.Prefix)_</code></td><td class=`"sslot`">$($r.Slot)</td><td class=`"num`">$($r.Count)</td><td class=`"barc`"><span class=`"bar`" style=`"width:$pct%;--c:$($SlotColor[$r.Slot])`"></span></td><td class=`"num$gapCls`">$lastTxt<span class=`"sub`">$gapTxt</span></td></tr>")
}

# ============================================================
# 7. 애드센스 세트 카드
# ============================================================
$sbSets = New-Object System.Text.StringBuilder
foreach ($s in $adsenseSets) {
    $t = $s.Title
    if ($t -eq "") { $t = $s.Slug }

    function Ch([bool]$on, [string]$txt, [string]$link) {
        if ($on) {
            if ($link -ne "") { return "<a class=`"ch on`" href=`"$link`">$txt</a>" }
            return "<span class=`"ch on`">$txt</span>"
        }
        return "<span class=`"ch off`">$txt</span>"
    }

    $c2 = Ch $s.HasPost "티스토리 원고" "output_adsense/$($s.Dir)/post.html"
    $instaOk = ($s.Png -ge 7 -and $s.HasCaption)
    $instaTxt = "인스타 카드 $($s.Png)장"
    if ($s.Png -eq 0) { $instaTxt = "인스타 카드" }
    $c3 = Ch $instaOk $instaTxt ""
    $c4 = Ch $s.HasThreads "쓰레드 원고" ""
    $c1 = Ch $s.HasPhotos "사진·팩트표" "output_adsense/$($s.Dir)/photos.md"

    $dcls = "part"
    if ($s.Done -eq 3) { $dcls = "full" }
    # 원본 사진은 adsense_src/<날짜> 폴더 단위 — 같은 날 2세트면 그 폴더를 공유하므로 수치를 쓰지 않는다
    $srcTxt = "원본 없음"
    $sameDay = @($adsenseSets | Where-Object { $_.Date -eq $s.Date }).Count
    if ($s.SrcPhotos -gt 0) {
        if ($sameDay -gt 1) { $srcTxt = "원본 폴더 공유($sameDay세트)" }
        else { $srcTxt = "원본 $($s.SrcPhotos)장" }
    }

    $null = $sbSets.Append("<div class=`"setcard $dcls`"><div class=`"sethead`"><span class=`"setdate`">$(Format-DateLabel $s.Date)<span class=`"dow`">$(Get-Dow $s.Date)</span></span><span class=`"setdone`">$($s.Done)/3 채널</span></div><div class=`"settitle`">$(Enc $t)</div><div class=`"setmeta`"><code>$(Enc $s.Slug)</code> · $srcTxt</div><div class=`"chrow`">$c1$c2$c3$c4</div></div>")
}

# ============================================================
# 8. HTML 출력
# ============================================================
$html = @"
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>4채널 통합 운영 대시보드</title>
<style>
:root{
  --bg:#f6f7f9; --surface:#fff; --ink:#111827; --ink2:#4b5563; --ink3:#9ca3af;
  --line:#e5e7eb; --line2:#f3f4f6;
  --ok:#047857; --okbg:#ecfdf5; --warn:#b45309; --warnbg:#fffbeb; --bad:#b91c1c; --badbg:#fef2f2;
}
@media (prefers-color-scheme:dark){
  :root{ --bg:#0f1115; --surface:#171a21; --ink:#e9eaee; --ink2:#a8adb8; --ink3:#6b7280;
    --line:#2a2f3a; --line2:#212530;
    --ok:#34d399; --okbg:#052e23; --warn:#fbbf24; --warnbg:#3a2a06; --bad:#f87171; --badbg:#3d1414; }
}
:root[data-theme="dark"]{ --bg:#0f1115; --surface:#171a21; --ink:#e9eaee; --ink2:#a8adb8; --ink3:#6b7280;
  --line:#2a2f3a; --line2:#212530;
  --ok:#34d399; --okbg:#052e23; --warn:#fbbf24; --warnbg:#3a2a06; --bad:#f87171; --badbg:#3d1414; }
:root[data-theme="light"]{ --bg:#f6f7f9; --surface:#fff; --ink:#111827; --ink2:#4b5563; --ink3:#9ca3af;
  --line:#e5e7eb; --line2:#f3f4f6;
  --ok:#047857; --okbg:#ecfdf5; --warn:#b45309; --warnbg:#fffbeb; --bad:#b91c1c; --badbg:#fef2f2; }

*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font-family:"Malgun Gothic","Segoe UI",system-ui,sans-serif;
  font-size:14px;line-height:1.6;-webkit-font-smoothing:antialiased}
.wrap{max-width:1240px;margin:0 auto;padding:28px 20px 60px}
a{color:inherit;text-decoration:none}
a:hover{text-decoration:underline}
code{font-family:Consolas,monospace;font-size:.86em;color:var(--ink3)}

header{margin-bottom:22px}
h1{margin:0 0 4px;font-size:1.45rem;letter-spacing:-.02em}
.sub{color:var(--ink2);font-size:.88rem}

.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(148px,1fr));gap:10px;margin:20px 0 30px}
.kpi{background:var(--surface);border:1px solid var(--line);border-radius:10px;padding:14px 16px}
.kpi .v{font-size:1.6rem;font-weight:700;letter-spacing:-.03em;line-height:1.1}
.kpi .k{font-size:.76rem;color:var(--ink2);margin-top:3px}

section{background:var(--surface);border:1px solid var(--line);border-radius:12px;
  padding:20px 22px;margin-bottom:20px}
h2{margin:0 0 3px;font-size:1.04rem;letter-spacing:-.01em}
h2 .n{color:var(--ink3);font-weight:600;margin-right:7px}
.note{color:var(--ink2);font-size:.83rem;margin:0 0 16px}

.legend{display:flex;flex-wrap:wrap;gap:6px 14px;margin:0 0 14px;font-size:.8rem;color:var(--ink2)}
.legend span.li{display:inline-flex;align-items:center;gap:6px}
.dot{width:9px;height:9px;border-radius:50%;background:var(--c);flex:0 0 auto;display:inline-block}

.scroll{overflow-x:auto}
table{width:100%;border-collapse:collapse;font-size:.85rem}
th,td{padding:7px 9px;text-align:left;vertical-align:middle}
thead th{font-size:.74rem;font-weight:600;color:var(--ink2);text-transform:none;
  border-bottom:1px solid var(--line);white-space:nowrap;padding-bottom:8px}
thead th .tg{font-weight:400;color:var(--ink3);font-size:.94em}
tbody tr{border-bottom:1px solid var(--line2)}
.dcell{white-space:nowrap;font-weight:600;font-variant-numeric:tabular-nums}
.dow{display:inline-block;margin-left:6px;font-weight:400;color:var(--ink3);font-size:.86em}
.cell{min-width:104px}
.cell.empty{color:var(--line);text-align:center}
.cell.off{background:var(--warnbg)}
.num{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap;color:var(--ink2)}
.num.stale{color:var(--bad)}
.num .sub{display:block;font-size:.78em;color:var(--ink3)}

.chip{display:inline-block;margin:1px 3px 1px 0;padding:2px 7px;border-radius:5px;
  font-size:.78rem;white-space:nowrap;
  background:color-mix(in srgb,var(--c) 13%,transparent);
  color:var(--c);border:1px solid color-mix(in srgb,var(--c) 30%,transparent)}
.chip b{font-weight:700}

.badge{display:inline-block;margin:1px 3px 1px 0;padding:2px 7px;border-radius:5px;
  font-size:.74rem;font-weight:600;white-space:nowrap}
.badge.ok{background:var(--okbg);color:var(--ok)}
.badge.warn{background:var(--warnbg);color:var(--warn)}
.badge.bad{background:var(--badbg);color:var(--bad)}
.flags{min-width:130px}

tr.det{border-bottom:1px solid var(--line2)}
tr.det td{padding:0 9px 8px}
tr.det summary{cursor:pointer;font-size:.78rem;color:var(--ink3);padding:2px 0;list-style:none}
tr.det summary::-webkit-details-marker{display:none}
tr.det summary::before{content:"\25B8 ";}
tr.det details[open] summary::before{content:"\25BE ";}
.tlist{margin:6px 0 4px;padding:0;list-style:none;
  columns:2;column-gap:26px;font-size:.82rem}
.tlist li{margin:0 0 4px;break-inside:avoid;display:flex;gap:7px;align-items:baseline}
.tlist .lb{color:var(--ink3);font-size:.9em;flex:0 0 auto;min-width:66px}
@media(max-width:820px){.tlist{columns:1}}

tr.folded{display:none}
body.showall tr.folded{display:table-row}
.morebtn{margin-top:12px;background:none;border:1px solid var(--line);color:var(--ink2);
  border-radius:7px;padding:6px 14px;font-size:.8rem;cursor:pointer;font-family:inherit}
.morebtn:hover{border-color:var(--ink3)}

.barc{width:34%;min-width:110px}
.bar{display:block;height:8px;border-radius:0 4px 4px 0;background:var(--c)}
.scode{white-space:nowrap}
.scode .dot{margin-right:7px}
.scode code{margin-left:6px}
.sslot{color:var(--ink2);font-size:.82em}

.sets{display:grid;grid-template-columns:repeat(auto-fill,minmax(288px,1fr));gap:12px}
.setcard{border:1px solid var(--line);border-radius:10px;padding:13px 14px;background:var(--surface)}
.setcard.full{border-left:3px solid var(--ok)}
.setcard.part{border-left:3px solid var(--warn)}
.sethead{display:flex;justify-content:space-between;align-items:baseline;font-size:.78rem}
.setdate{font-weight:700;font-variant-numeric:tabular-nums}
.setdone{color:var(--ink2)}
.settitle{margin:7px 0 3px;font-size:.9rem;font-weight:600;line-height:1.45}
.setmeta{font-size:.76rem;color:var(--ink3);margin-bottom:9px}
.chrow{display:flex;flex-wrap:wrap;gap:5px}
.ch{display:inline-block;padding:3px 8px;border-radius:5px;font-size:.74rem;font-weight:600}
.ch.on{background:var(--okbg);color:var(--ok)}
.ch.off{background:var(--line2);color:var(--ink3);text-decoration:line-through}
a.ch.on:hover{text-decoration:underline}

.memo{margin:0;padding-left:20px;font-size:.85rem;color:var(--ink2)}
.memo li{margin-bottom:6px}
.memo b{color:var(--ink)}
.stopped{display:flex;flex-wrap:wrap;gap:10px}
.stopcard{flex:1 1 240px;border:1px dashed var(--line);border-radius:9px;padding:12px 14px}
.stopcard .t{font-weight:600;font-size:.88rem;margin-bottom:3px}
.stopcard .d{font-size:.78rem;color:var(--ink3)}
.footer{text-align:center;color:var(--ink3);font-size:.76rem;margin-top:26px}
</style>
</head>
<body data-palette="#0891B2,#4F46E5,#EA580C,#DB2777">
<div class="wrap">

<header>
  <h1>4채널 통합 운영 대시보드</h1>
  <div class="sub">네이버 블로그(자동 7건/일) → 티스토리 애드센스 → 인스타 카드뉴스 → 쓰레드 · 갱신 $generatedAt</div>
</header>

<div class="kpis">
  <div class="kpi"><div class="v">$totalNaver</div><div class="k">네이버 누적 원고</div></div>
  <div class="kpi"><div class="v">$activeDays</div><div class="k">발행 운영일</div></div>
  <div class="kpi"><div class="v">$(Format-DateLabel $latestDate)</div><div class="k">최근 발행일</div></div>
  <div class="kpi"><div class="v">$($adsenseSets.Count)</div><div class="k">애드센스 소재 세트</div></div>
  <div class="kpi"><div class="v">$setsFull<span style="font-size:.55em;color:var(--ink3)">/$($adsenseSets.Count)</span></div><div class="k">3채널 완성 세트</div></div>
  <div class="kpi"><div class="v">$totalPng</div><div class="k">인스타 카드 장수</div></div>
</div>

<section>
  <h2><span class="n">01</span>네이버 블로그 — 일자별 슬롯 구성</h2>
  <p class="note">발행 믹스 목표 = <b>여행 3 · 인접 1 · 생활 2 · 신규 1 = 7건</b>(2026-08-10 시행).
  목표와 어긋난 칸은 <span class="badge warn">노란 배경</span>, 한 계열이 하루를 잠식하면 <span class="badge bad">편중</span>으로 표시된다.
  시행일 이전 날짜는 구 믹스이므로 구성만 보여주고 판정하지 않는다.</p>
  <div class="legend">
    <span class="li"><span class="dot" style="--c:$($SlotColor['여행'])"></span>여행 &mdash; $($SlotDesc['여행'])</span>
    <span class="li"><span class="dot" style="--c:$($SlotColor['인접'])"></span>인접 &mdash; $($SlotDesc['인접'])</span>
    <span class="li"><span class="dot" style="--c:$($SlotColor['생활'])"></span>생활 &mdash; $($SlotDesc['생활'])</span>
    <span class="li"><span class="dot" style="--c:$($SlotColor['신규'])"></span>신규 &mdash; $($SlotDesc['신규'])</span>
    <span class="li"><span class="dot" style="--c:$($SlotColor['보충'])"></span>보충 &mdash; $($SlotDesc['보충'])</span>
  </div>
  <div class="scroll">
  <table>
    <thead><tr>
      <th>발행일</th>
      <th>여행 <span class="tg">목표 3</span></th>
      <th>인접 <span class="tg">1</span></th>
      <th>생활 <span class="tg">2</span></th>
      <th>신규 <span class="tg">1</span></th>
      <th>보충 <span class="tg">0</span></th>
      <th style="text-align:right">이미지</th>
      <th>점검</th>
    </tr></thead>
    <tbody>
$($sbMatrix.ToString())
    </tbody>
  </table>
  </div>
  <button class="morebtn" onclick="document.body.classList.toggle('showall');this.textContent=document.body.classList.contains('showall')?'최근 21일만 보기':'전체 $activeDays일 보기'">전체 $activeDays일 보기</button>
</section>

<section>
  <h2><span class="n">02</span>계열 커버리지 &mdash; 무엇이 쌓이고 무엇이 멈췄나</h2>
  <p class="note">누적 건수와 <b>마지막 발행일</b>. 30일 이상 멈춘 계열은 빨간색이다.
  에버그린 계열이 멈춰 있으면 그 자산은 더 이상 늘지 않는다(카테고리 분석 2026-08-09의 근거).</p>
  <div class="scroll">
  <table>
    <thead><tr><th>계열</th><th>슬롯</th><th style="text-align:right">누적</th><th></th><th style="text-align:right">마지막 발행</th></tr></thead>
    <tbody>
$($sbSerie.ToString())
    </tbody>
  </table>
  </div>
</section>

<section>
  <h2><span class="n">03</span>애드센스 원소스 &mdash; 티스토리 · 인스타 · 쓰레드</h2>
  <p class="note">소재 1건(내 사진·실경험)에서 <b>티스토리 원고 → 인스타 카드뉴스 → 쓰레드</b> 3채널이 파생된다.
  <span class="ch on" style="padding:1px 6px">완료</span> <span class="ch off" style="padding:1px 6px">미완</span> ·
  인스타는 카드 7장 이상 + 캡션이 있어야 완료로 센다.</p>
  <div class="sets">
$($sbSets.ToString())
  </div>
</section>

<section>
  <h2><span class="n">04</span>중단된 채널 (참고용 보존)</h2>
  <div class="stopped">
    <div class="stopcard">
      <div class="t">자동 티스토리 미러</div>
      <div class="d">2026-07-09 중단 &mdash; 애드센스 &quot;가치 없는 콘텐츠&quot; 반려로 미러 양산 폐기.<br>
      보존: $($legTistory[0])일 / 파일 $($legTistory[1])개 · 마지막 $(Format-DateLabel $legTistory[2])</div>
    </div>
    <div class="stopcard">
      <div class="t">자동 여행 인스타</div>
      <div class="d">2026-07-08 중단 &mdash; 이미지 생성 과금 절감.<br>
      현재 인스타는 <b>애드센스 소재 수동 제작만</b>(위 03) 가동.<br>
      보존: $($legInsta[0])일 / 파일 $($legInsta[1])개 · 마지막 $(Format-DateLabel $legInsta[2])</div>
    </div>
  </div>
</section>

<section>
  <h2><span class="n">05</span>운영 메모</h2>
  <ul class="memo">
    <li><b>이 대시보드는 자동 생성물이다.</b> 매일 새벽 4시 발행 직후 <code>.scripts\build-dashboard.ps1</code>이 재생성한다.
    직접 <code>dashboard.html</code>을 고치면 다음 실행에 덮어써지므로, 화면을 바꾸려면 빌더를 고쳐야 한다.</li>
    <li><b>신규 로테이션</b>: 월·목·일 <code>recipe_</code> / 화·금 <code>house_</code> / 수·토 <code>tech_</code>.
    해당 요일에 그 계열이 없으면 점검 칸에 누락 배지가 뜬다.</li>
    <li><b>편중 경보</b>는 2026-08-01 큐 전면 고갈로 7건이 전부 <code>travel_</code>로 나간 사고의 재발 감지용이다.
    떴다면 큐 리필(<code>.scripts\refill-prompt.md</code>, 매주 월요일 자동)이 밀린 것이다.</li>
    <li>수동 갱신: PowerShell에서 <code>.\.scripts\build-dashboard.ps1</code></li>
  </ul>
</section>

<div class="footer">naverblog @ D:\lightsail\naverblog · auto-generated</div>
</div>
</body>
</html>
"@

[System.IO.File]::WriteAllText($DashboardPath, $html, $utf8NoBom)

Write-Host "Dashboard generated: $DashboardPath"
Write-Host "  Naver days / posts : $activeDays / $totalNaver"
Write-Host "  Series tracked     : $($serieRows.Count)"
Write-Host "  Adsense sets       : $($adsenseSets.Count) (3ch complete: $setsFull)"
