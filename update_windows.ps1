# AI本社 アップデート（Windows）。「アップデート（Windows）.bat」をダブルクリックすると動きます。
# 決まり：台帳・箱・書類・設定の値・社長が書いたルールは変えない。差し替えるのは「仕組み」だけ（画面・スキル・見張り番・基本ルール）。
# 流れ：①会社フォルダを選ぶ ②控え（バックアップ）を取る ③仕組みだけ差し替え ④データが1つも変わっていないか確かめる → 変わっていたら控えから元に戻す
param([string]$Target = '', [string]$Source = '', [string]$BackupRoot = '', [switch]$Yes, [switch]$TestBreak)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$utf8 = New-Object Text.UTF8Encoding($false)
function Say($t) { Write-Host $t }
function Step($t) { Write-Host ''; Write-Host "■ $t" -ForegroundColor Cyan }
function Ask($q, $def) { if ($Yes) { return $def }; $a = Read-Host "$q $(if ($def) { '[Y/n]' } else { '[y/N]' })"; if ([string]::IsNullOrWhiteSpace($a)) { return $def }; return ($a.Trim() -match '^(y|yes|はい|ｙ)$') }
function Done() { if (-not $Yes) { Read-Host 'Enter キーで閉じます' | Out-Null } }
function Rel($base, $full) { return $full.Substring($base.TrimEnd('\').Length + 1) }

Say '======================================'
Say '  AI本社 アップデート（JETSTREAM合同会社）'
Say '======================================'
if (-not $Source) { $Source = Join-Path $PSScriptRoot '会社フォルダ' }
if (-not (Test-Path (Join-Path $Source '仕組み\バージョン.txt'))) { Say '新しい版の「会社フォルダ」が見つかりません。ZIP をすべて展開してから、中の「アップデート（Windows）.bat」をダブルクリックしてください。'; Done; exit 1 }
$newVer = (Get-Content (Join-Path $Source '仕組み\バージョン.txt') -Raw -Encoding UTF8).Trim()

# ① 会社フォルダを選ぶ
Step '① アップデートする会社フォルダを選びます'
function IsCompany($p) { return (Test-Path (Join-Path $p 'CLAUDE.md')) -and (Test-Path (Join-Path $p '画面\dashboard.html')) -and (Test-Path (Join-Path $p '台帳')) }
if (-not $Target) {
  $roots = @([Environment]::GetFolderPath('MyDocuments'), [Environment]::GetFolderPath('Desktop'), (Join-Path $env:USERPROFILE 'OneDrive\ドキュメント'), (Join-Path $env:USERPROFILE 'OneDrive\Documents')) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
  $cands = @(foreach ($r in $roots) { Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue | Where-Object { IsCompany $_.FullName } | ForEach-Object { $_.FullName } })
  if ($cands.Count -eq 1 -and (Ask "「$($cands[0])」をアップデートしますか？" $true)) { $Target = $cands[0] }
  elseif ($cands.Count -gt 1) { for ($i = 0; $i -lt $cands.Count; $i++) { Say "  $($i + 1). $($cands[$i])" }; $n = Read-Host '番号を入れてください'; if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $cands.Count) { $Target = $cands[[int]$n - 1] } }
  if (-not $Target) { $Target = (Read-Host '会社フォルダをこの窓にドラッグして Enter（または場所を入力）').Trim().Trim('"') }
}
if (-not $Target -or -not (IsCompany $Target)) { Say "会社フォルダではないようです：$Target（CLAUDE.md・画面・台帳 があるフォルダを選んでください）"; Done; exit 1 }
$Target = (Resolve-Path -LiteralPath $Target).Path
$verFile = Join-Path $Target '仕組み\バージョン.txt'
$oldVer = if (Test-Path $verFile) { (Get-Content $verFile -Raw -Encoding UTF8).Trim() } else { '1.3 以前' }
Say "会社フォルダ：$Target"
Say "今の版：$oldVer → 新しい版：$newVer"
try { if ([version]$oldVer -ge [version]$newVer) { if (-not (Ask 'もう同じか新しい版です。それでも入れ直しますか？' $false)) { Done; exit 0 } } } catch { }

# AI が動いている間はしない。アップデートのあいだは見張り番も動かない（同じ目印を使う）
$lock = Join-Path $Target '仕組み\動いています.lock'
if ((Test-Path $lock) -and (Get-Item $lock).LastWriteTime -gt (Get-Date).AddHours(-2)) { Say 'いま AI が作業中です。終わってから（数分〜数十分あと）もう一度アップデートしてください。'; Done; exit 1 }
New-Item -ItemType File -Path $lock -Force | Out-Null

# 差し替える「仕組み」のファイル。これ以外は、無ければ足すだけ・あれば触らない
$sysFiles = @('画面\dashboard.html', '画面\settings.html', '画面\contacts.html', '画面\theme.css', '画面\theme.js','仕組み\見張り番.ps1', '仕組み\見張り番.sh', '仕組み\見張り番を始める.ps1', '仕組み\AI本社の基本ルール.md', '仕組み\バージョン.txt')
$imgRoot = Join-Path $Source '画面\img'
if (Test-Path $imgRoot) { $sysFiles += @(Get-ChildItem -LiteralPath $imgRoot -File | ForEach-Object { '画面\img\' + $_.Name }) }
$skillRoot = Join-Path $Source '.claude\skills'
$sysFiles += @(Get-ChildItem -LiteralPath $skillRoot -Recurse -File -Force | ForEach-Object { '.claude\skills\' + (Rel $skillRoot $_.FullName) })
$sysSet = @{}; foreach ($f in $sysFiles + @('設定.json', 'CLAUDE.md', '仕組み\アップデートの記録.txt')) { $sysSet[$f.ToLower()] = $true }

function Snapshot() {
  $h = @{}
  Get-ChildItem -LiteralPath $Target -Recurse -File -Force | ForEach-Object {
    $r = Rel $Target $_.FullName
    if ($sysSet.ContainsKey($r.ToLower()) -or $r -eq '仕組み\動いています.lock') { return }
    $h[$r] = '' + $_.Length + '|' + $_.LastWriteTimeUtc.Ticks
  }
  return $h
}

# ② 控え
Step '② 控え（バックアップ）を取ります'
if (-not $BackupRoot) { $BackupRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'AI本社_アップデート前の控え' }
$bk = Join-Path $BackupRoot ((Split-Path $Target -Leaf) + '_' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '_v' + ($oldVer -replace '[^\d\.]', ''))
New-Item -ItemType Directory -Path $bk -Force | Out-Null
foreach ($item in @('設定.json', 'CLAUDE.md', '画面', '仕組み', '.claude', '台帳', '箱')) {
  $p = Join-Path $Target $item; if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination (Join-Path $bk $item) -Recurse -Force }
}
Remove-Item -LiteralPath (Join-Path $bk '仕組み\動いています.lock') -Force -ErrorAction SilentlyContinue
$before = Snapshot
Say "控えを取りました：$bk"
Say "（書類のフォルダは触らないので控えは取りません。$($before.Count) 個のファイルが変わらないことを最後に確かめます）"

$script:created = @()
function Restore($why) {
  Write-Host ''; Write-Host "問題が見つかったため、元に戻します：$why" -ForegroundColor Yellow
  foreach ($c in $script:created) { $p = Join-Path $Target $c; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force } }
  foreach ($item in Get-ChildItem -LiteralPath $bk -Force) { Copy-Item -LiteralPath $item.FullName -Destination $Target -Recurse -Force }
  Say "元に戻しました（控えは $bk に残っています）。お手数ですが、この画面を写真に撮って JETSTREAM までお知らせください。"
}

try {
  # ③ 仕組みを差し替え
  Step '③ 仕組みを新しくします（画面・スキル・見張り番・基本ルール）'
  $blockIds = @{ '画面\dashboard.html' = 'company-data'; '画面\settings.html' = 'settings-data'; '画面\contacts.html' = 'contacts-data' }
  foreach ($f in $sysFiles) {
    $src = Join-Path $Source $f; $dst = Join-Path $Target $f
    New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
    if ($blockIds.ContainsKey($f) -and (Test-Path -LiteralPath $dst)) {
      # 画面の中のデータ（フォルダとつながっていないときの表示）は、今のものを新しい画面に移す
      $pat = '(<script id="' + $blockIds[$f] + '" type="application/json">)([\s\S]*?)(</script>)'
      $old = [IO.File]::ReadAllText($dst, $utf8); $new = [IO.File]::ReadAllText($src, $utf8)
      $m = [regex]::Match($old, $pat)
      if ($m.Success) { $keep = $m.Groups[2].Value; $new = [regex]::Replace($new, $pat, { param($x) $x.Groups[1].Value + $keep + $x.Groups[3].Value }) }
      [IO.File]::WriteAllText($dst, $new, $utf8)
    } else {
      if (-not (Test-Path -LiteralPath $dst)) { $script:created += $f }
      Copy-Item -LiteralPath $src -Destination $dst -Force
    }
  }
  # 新しい版で増えたデータの入れ物は、無いときだけ足す（あるものは触らない）
  foreach ($file in Get-ChildItem -LiteralPath $Source -Recurse -File -Force) {
    $r = Rel $Source $file.FullName
    if ($sysSet.ContainsKey($r.ToLower())) { continue }
    $dst = Join-Path $Target $r
    if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null; Copy-Item -LiteralPath $file.FullName -Destination $dst; $script:created += $r; Say "  足しました：$r" }
  }
  # 設定.json：今の値はそのまま。新しい項目だけ、最後に足す
  $sp = Join-Path $Target '設定.json'; $stText = [IO.File]::ReadAllText($sp, $utf8).TrimEnd()
  $cur = $stText | ConvertFrom-Json; $def = [IO.File]::ReadAllText((Join-Path $Source '設定.json'), $utf8) | ConvertFrom-Json
  $add = @(); foreach ($p in $def.PSObject.Properties) { if (-not ($cur.PSObject.Properties.Name -contains $p.Name)) { $add += (' "' + $p.Name + '": ' + (ConvertTo-Json $p.Value -Compress)) } }
  if ($add.Count -gt 0) {
    if (-not $stText.EndsWith('}')) { throw '設定.json の形が読めません' }
    $stText = $stText.Substring(0, $stText.Length - 1).TrimEnd() + ",`n" + ($add -join ",`n") + "`n}`n"
    $null = $stText | ConvertFrom-Json
    [IO.File]::WriteAllText($sp, $stText, $utf8); Say "  設定に新しい項目を $($add.Count) 個足しました（今の値はそのまま）"
  }
  # CLAUDE.md：社長が書いた所はそのまま。基本ルールを読む1行が無ければ、最後に足す
  $cp = Join-Path $Target 'CLAUDE.md'; $cl = [IO.File]::ReadAllText($cp, $utf8)
  if ($cl -notmatch 'AI本社の基本ルール\.md') {
    $cl = $cl.TrimEnd() + "`n`n## AI本社の基本ルール（アップデートで新しくなる）`n（この上が会社だけの決まり。食い違うときは上の決まりを優先）`n@./仕組み/AI本社の基本ルール.md`n"
    [IO.File]::WriteAllText($cp, $cl, $utf8); Say '  会社のルール（CLAUDE.md）の最後に、基本ルールを読む1行を足しました（今の決まりはそのまま）'
  }
  if ($TestBreak) { $t = Get-ChildItem -LiteralPath (Join-Path $Target '台帳') -File | Select-Object -First 1; Add-Content -LiteralPath $t.FullName -Value 'こわれたテスト' }

  # ④ 確かめる
  Step '④ データが変わっていないか確かめます'
  $after = Snapshot; $bad = @()
  foreach ($k in $before.Keys) { if (-not $after.ContainsKey($k)) { $bad += "なくなった：$k" } elseif ($after[$k] -ne $before[$k]) { $bad += "変わった：$k" } }
  $chk = [IO.File]::ReadAllText($sp, $utf8) | ConvertFrom-Json
  foreach ($p in $cur.PSObject.Properties) { if ((ConvertTo-Json $chk.($p.Name) -Compress) -ne (ConvertTo-Json $p.Value -Compress)) { $bad += "設定の値が変わった：$($p.Name)" } }
  if (-not ([IO.File]::ReadAllText($cp, $utf8).StartsWith(([IO.File]::ReadAllText((Join-Path $bk 'CLAUDE.md'), $utf8)).TrimEnd()))) { $bad += '会社のルールが変わった' }
  if ($bad.Count -gt 0) { throw (($bad | Select-Object -First 5) -join '／') }
  Say "台帳・箱・書類 $($before.Count) 個と、設定の値・会社のルールは、すべてそのままです。"
} catch {
  Restore $_.Exception.Message; Remove-Item $lock -Force -ErrorAction SilentlyContinue; Done; exit 2
}

Add-Content -LiteralPath (Join-Path $Target '仕組み\アップデートの記録.txt') -Value ("$(Get-Date -Format 'yyyy-MM-dd HH:mm') $oldVer → $newVer（控え：$bk）") -Encoding UTF8
Remove-Item $lock -Force -ErrorAction SilentlyContinue
Step "終わりました（$oldVer → $newVer）"
Say '会社の画面を開き直すと、新しい画面になります。'
Say "調子が悪いときは、控え（$bk）の中身を会社フォルダに戻せば、前の版に戻ります。"
Done
