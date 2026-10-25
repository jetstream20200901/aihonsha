# AI本社 セットアップ（Windows）。「セットアップ.bat」をダブルクリックすると動きます。
# すること：①会社フォルダを作る ②Claude Code（AI本体）を入れる ③Obsidian を入れる（選べる）
#           ④見張り番を登録 ⑤デスクトップに「会社の画面」 ⑥画面を開く ⑦Claude へのログイン画面を開く
# しないこと：ログイン・お支払い・パスワードの入力（ご本人が行います）。ファイルを消すこともしません。
param([string]$Name = '', [string]$Dest = '', [string]$Source = '', [switch]$Yes, [switch]$NoInstall, [switch]$NoOpen)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$utf8 = New-Object Text.UTF8Encoding($false)
function Say($t) { Write-Host $t }
function Step($t) { Write-Host ''; Write-Host "■ $t" -ForegroundColor Cyan }
function Ask($q, $def) {
  if ($Yes) { return $def }
  $hint = if ($def) { '[Y/n]' } else { '[y/N]' }
  $a = Read-Host "$q $hint"
  if ([string]::IsNullOrWhiteSpace($a)) { return $def }
  return ($a.Trim() -match '^(y|yes|はい|ｙ)$')
}
function Done() { if (-not $Yes) { Read-Host '終わりました。Enter キーで閉じます' | Out-Null } }

Say '======================================'
Say '  AI本社 セットアップ（JETSTREAM合同会社）'
Say '======================================'
Say 'このあと、いくつか質問します。Enter だけ押すと［ ］の大文字の答えになります。'

if (-not $Source) { $Source = Join-Path $PSScriptRoot '会社フォルダ' }
if (-not (Test-Path (Join-Path $Source 'CLAUDE.md'))) {
  Say '「会社フォルダ」が見つかりません。ZIP を右クリック →「すべて展開」してから、展開したフォルダの中の「セットアップ.bat」をダブルクリックしてください。'
  Done; exit 1
}

# ① 会社フォルダ
Step '① 会社フォルダを作ります'
if (-not $Name) { $Name = (Read-Host '会社名を入れてください（例：さくら工務店）').Trim() }
if (-not $Name) { $Name = '私の会社' }
$safe = ($Name -replace '[\/:*?"<>|]', '-')
if (-not $Dest) { $Dest = [Environment]::GetFolderPath('MyDocuments') }
$target = Join-Path $Dest ($safe + '_AI'); $i = 2
while (Test-Path $target) { $target = Join-Path $Dest ($safe + '_AI（' + $i + '）'); $i++ }
Copy-Item -LiteralPath $Source -Destination $target -Recurse -Force
foreach ($rel in @('設定.json', 'CLAUDE.md', '画面\dashboard.html', '画面\settings.html')) {
  $p = Join-Path $target $rel
  if (Test-Path $p) { $t = [IO.File]::ReadAllText($p, $utf8); [IO.File]::WriteAllText($p, $t.Replace('○○株式会社', $Name), $utf8) }
}
Say "作りました：$target"

# ② Claude Code
Step '② Claude Code（AI本体）'
function FindClaude {
  $c = Get-Command claude -ErrorAction SilentlyContinue; if ($c) { return $c.Source }
  $p = Join-Path $env:USERPROFILE '.local\bin\claude.exe'; if (Test-Path $p) { return $p }
  return $null
}
$claude = FindClaude
if ($claude) { Say 'もう入っています。' }
elseif ($NoInstall) { Say '（試しモードのため入れません）' }
elseif (Ask 'Claude Code を入れますか？（公式のインストーラーを使います）' $true) {
  Say '入れています（数分かかることがあります。途中の表示がなくても待ってください）…'
  try { Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression } catch { Say "うまく入りませんでした：$($_.Exception.Message)" }
  $bin = Join-Path $env:USERPROFILE '.local\bin'
  if ((Test-Path $bin) -and (([Environment]::GetEnvironmentVariable('Path', 'User')) -notlike "*$bin*")) {
    [Environment]::SetEnvironmentVariable('Path', ([Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $bin), 'User')
  }
  $env:Path += ';' + $bin
  $claude = FindClaude
  if ($claude) { Say '入りました。' } else { Say '見つかりません。あとで「はじめの30分」の手順で入れてください。' }
} else { Say 'とばしました（見張り番を使うときは必要です）。' }

# ③ Obsidian
Step '③ Obsidian（オブシディアン）'
Say 'Obsidian は、会社フォルダの議事録やマニュアルを「ノート帳」のように読める無料のアプリです（入れなくても使えます）。'
$obs = $false
if ($NoInstall) { Say '（試しモードのため入れません）' }
elseif (Ask 'Obsidian を入れますか？' $false) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Say '入れています…（同意を求められたら、内容を読んで Y を押してください）'
    & winget install -e --id Obsidian.Obsidian; $obs = $true
  } else { Say 'このパソコンでは自動で入れられないため、ダウンロードのページを開きます。'; Start-Process 'https://obsidian.md/download' }
}

# ④ 見張り番
Step '④ 見張り番（やることがあるときだけ AI を起こす仕組み）'
if ($NoInstall) { Say '（試しモードのため登録しません）' }
elseif (Ask '見張り番を登録しますか？（10分ごとに会社フォルダを見ます。AIの利用量は、やることがあるときだけ）' $true) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $target '仕組み\見張り番を始める.ps1')
}

# ⑤ デスクトップに「会社の画面」
Step '⑤ デスクトップに「会社の画面」を置きます'
$dash = Join-Path $target '画面\dashboard.html'
$browser = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
             "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
try {
  $desk = [Environment]::GetFolderPath('Desktop')
  if ($NoOpen) { $desk = $target }
  $sc = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desk ("会社の画面（" + $safe + "）.lnk")))
  if ($browser) { $sc.TargetPath = $browser; $sc.Arguments = '"' + $dash + '"' } else { $sc.TargetPath = $dash }
  $sc.WorkingDirectory = $target; $sc.Save(); Say '置きました。'
} catch { Say "置けませんでした：$($_.Exception.Message)" }

# ⑥⑦ 開く
if (-not $NoOpen) {
  Step '⑥ 会社の画面と設定を開きます'
  $set = Join-Path $target '画面\settings.html'
  if ($browser) { Start-Process $browser -ArgumentList ('"' + $dash + '"'), ('"' + $set + '"') } else { Start-Process $dash; Start-Process $set }
  if ($claude -and (Ask '⑦ Claude にログインしますか？（別の窓が開き、ブラウザでログインします）' $true)) {
    $cmd = "Set-Location -LiteralPath '" + $target.Replace("'", "''") + "'; Write-Host 'ブラウザでログインしてください。終わったら /exit と入れて閉じてかまいません。'; & '" + $claude + "'"
    Start-Process powershell -ArgumentList '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', $cmd
  }
}

$log = @("セットアップ $(Get-Date -Format 'yyyy-MM-dd HH:mm')", "会社名：$Name", "場所：$target", "Claude Code：$(if ($claude) { $claude } else { 'なし' })", "Obsidian：$(if ($obs) { '入れた' } else { 'なし' })")
[IO.File]::WriteAllLines((Join-Path $target 'セットアップの記録.txt'), $log, $utf8)

Step '終わりました。残りは、ご本人がする3つだけです'
Say '  1. Claude にログイン（有料プランが必要です）'
Say '  2. 会社の画面の右上「📁 会社フォルダとつなぐ」を押し、次のフォルダを選んで「編集を許可」'
Say "       $target"
Say '  3. 設定画面で、目標・口座残高・会計ソフトなどを入れて「保存する」'
Say 'このあとは、デスクトップの「会社の画面」を開くだけです。くわしくは「はじめの30分.md」をご覧ください。'
Done
