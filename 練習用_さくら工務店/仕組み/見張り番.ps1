# 見張り番（Windows）：AIを使わずに会社フォルダを見て、やることがあるときだけ Claude を起こす。
# やることが無いときは何もしない（＝トークンを使わない）。10分ごとに動かす（見張り番を始める.ps1 で登録）。
#   起こす条件：画面から頼みごと・判断の返事が届いた／受付箱に書類が入った／会計ソフトの数字が6時間より古い（7〜19時）／今日の朝の確認がまだ（7時以降）／今日の議事録がまだ（設定の minutes_hour 時以降。初期値18時）
#   新しい版：1日1回、公開の置き場（GitHub）で版を確かめ、新しければ判断待ちに出す。社長が「OK」を押したら、データはそのまま仕組みだけ新しくする（AIは使わない）
#   試すだけ：powershell -ExecutionPolicy Bypass -File 見張り番.ps1 -DryRun
param([switch]$DryRun, [string]$Folder = (Split-Path -Parent $PSScriptRoot),
      [string]$VersionUrl = 'https://raw.githubusercontent.com/jetstream20200901/aihonsha/main/version.txt',
      [string]$ZipUrl = 'https://github.com/jetstream20200901/aihonsha/releases/latest/download/aihonsha.zip')

$ErrorActionPreference = 'Stop'
$here = Join-Path $Folder '仕組み'
$logFile = Join-Path $here '見張り番の記録.txt'
$lock = Join-Path $here '動いています.lock'
function Log($t) { $line = (Get-Date -Format 'yyyy-MM-dd HH:mm') + ' ' + $t; Add-Content -Path $logFile -Value $line -Encoding UTF8; Write-Output $line }
function ReadJson($rel, $def) { $p = Join-Path $Folder $rel; if (-not (Test-Path $p)) { return $def }; try { return (Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $def } }

# 前の Claude がまだ動いていたら待つ（2時間たったロックは古いとみなす）
if (Test-Path $lock) { if ((Get-Item $lock).LastWriteTime -gt (Get-Date).AddHours(-2)) { exit 0 } else { Remove-Item $lock -Force } }

$now = Get-Date; $today = $now.ToString('yyyy-MM-dd'); $reasons = @()
$utf8 = New-Object Text.UTF8Encoding($false)
function WriteJson($rel, $obj) { [IO.File]::WriteAllText((Join-Path $Folder $rel), (ConvertTo-Json -InputObject @($obj) -Depth 10), $utf8) }

# ===== 新しい版（AIは使わない） =====
$st0 = ReadJson '設定.json' $null
# 社長が「OK」を押した更新を行う
$updAns = @(@(ReadJson '箱\判断箱.json' @()) | Where-Object { "$($_.id)" -like 'upd-*' -and "$($_.id)" -notlike 'upd-fail*' -and $_.answer -eq 'OK' }) | Select-Object -First 1
if ($updAns) {
  $ver = "$($updAns.id)".Substring(4)
  if ($DryRun) { Log "【試し】v$ver に更新します（実際にはしません）" }
  else {
    Log "AI本社を v$ver に更新します（社長がOK）"
    $tmp = Join-Path $env:TEMP ('aihonsha_update_' + (Get-Random)); New-Item -ItemType Directory -Path $tmp | Out-Null; $ok = $false
    try {
      Invoke-WebRequest -Uri $ZipUrl -OutFile (Join-Path $tmp 'a.zip') -UseBasicParsing -TimeoutSec 180
      Expand-Archive -LiteralPath (Join-Path $tmp 'a.zip') -DestinationPath (Join-Path $tmp 'x') -Force
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp 'x\update_windows.ps1') -Target $Folder -Source (Join-Path $tmp 'x\会社フォルダ') -Yes *>&1 | Out-File -FilePath (Join-Path $here 'さいごの更新.txt') -Encoding UTF8
      $ok = ($LASTEXITCODE -eq 0)
    } catch { Log "更新できませんでした：$($_.Exception.Message)" }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    # 返事を箱から外し、判断待ちを片付ける（AIが同じ返事をもう一度処理しないように）
    WriteJson '箱\判断箱.json' @(@(ReadJson '箱\判断箱.json' @()) | Where-Object { "$($_.id)" -ne "$($updAns.id)" })
    $pend = @(@(ReadJson '台帳\判断待ち.json' @()) | Where-Object { "$($_.id)" -ne "$($updAns.id)" })
    if (-not $ok) { $pend = @([pscustomobject]@{ id = "upd-fail-$ver-$($now.ToString('yyyyMMddHHmm'))"; kind = '確認'; text = "AI本社を v$ver に新しくできませんでした。データは元のままです（控えから戻しました）。仕組み/さいごの更新.txt を JETSTREAM にお知らせください"; buttons = @('わかった') }) + $pend }
    WriteJson '台帳\判断待ち.json' $pend
    $logCsv = Join-Path $Folder '台帳\部署の記録.csv'
    if (Test-Path $logCsv) { Add-Content -LiteralPath $logCsv -Value ($today + ',事務,' + $(if ($ok) { "AI本社を v$ver に更新（データはそのまま）" } else { "AI本社の v$ver への更新に失敗（元に戻した）" }) + ',') -Encoding UTF8 }
    Log $(if ($ok) { "v$ver に更新しました" } else { "v$ver への更新に失敗し、元に戻しました" })
  }
}
# 1日1回、新しい版があるか確かめる（設定で止められる）
$vmark = Join-Path $here '版を確かめた日.txt'
if (-not ($st0 -and $st0.auto_update_check -eq $false) -and $now.Hour -ge 7 -and (-not (Test-Path $vmark) -or (Get-Content $vmark -Raw).Trim() -ne $today)) {
  if (-not $DryRun) { Set-Content -Path $vmark -Value $today -Encoding UTF8 }
  try {
    $r = Invoke-WebRequest -Uri $VersionUrl -UseBasicParsing -TimeoutSec 15
    $txt = $utf8.GetString($r.RawContentStream.ToArray())
    $lines = @($txt -split "`r?`n" | Where-Object { $_.Trim() }); $rv = $lines[0].Trim(); $note = if ($lines.Count -gt 1) { $lines[1].Trim() } else { '' }
    $lv = '0'; $vf = Join-Path $here 'バージョン.txt'; if (Test-Path $vf) { $lv = (Get-Content $vf -Raw -Encoding UTF8).Trim() }
    if ([version]$rv -gt [version]$lv) {
      $pend = @(ReadJson '台帳\判断待ち.json' @())
      if (-not ($pend | Where-Object { "$($_.id)" -eq "upd-$rv" })) {
        if ($DryRun) { Log "【試し】新しい版 v$rv があります（判断待ちには出していません）" }
        else {
          $item = [pscustomobject]@{ id = "upd-$rv"; kind = '確認'; text = "AI本社の新しい版 v$rv があります（$note）。「OK」で、台帳・書類・設定はそのまま、仕組み（画面・スキル・見張り番）だけを新しくします。先に控えを取り、データが変わったら自動で元に戻します"; link = 'https://github.com/jetstream20200901/aihonsha/releases/latest'; buttons = @('OK', 'あとで') }
          WriteJson '台帳\判断待ち.json' (@($pend) + $item); Log "新しい版 v$rv があるので、判断待ちに出しました"
        }
      }
    }
  } catch { }
}

$req = @(@(ReadJson '箱\依頼箱.json' @()) | Where-Object { $_.status -eq '未着手' })
if ($req.Count -gt 0) { $reasons += "頼みごと $($req.Count)件" }
$ans = @(ReadJson '箱\判断箱.json' @())
if ($ans.Count -gt 0) { $reasons += "判断の返事 $($ans.Count)件" }
$inbox = Join-Path $Folder '00_受付箱'
if (Test-Path $inbox) { $n = @(Get-ChildItem $inbox -Recurse -File | Where-Object { $_.Name -notmatch '^\.' -and $_.Name -ne 'ここに入れる.txt' }).Count; if ($n -gt 0) { $reasons += "受付箱に $n 件" } }

$st = ReadJson '設定.json' $null
if ($st -and $st.accounting -and $st.accounting -ne 'none' -and $now.Hour -ge 7 -and $now.Hour -lt 19) {
  $m = ReadJson '台帳\お金.json' $null; $old = $true
  if ($m -and $m.synced_at) { try { $old = ([datetime]::ParseExact($m.synced_at, 'yyyy-MM-dd HH:mm', $null) -lt $now.AddHours(-6)) } catch { } }
  if ($old) { $reasons += '会計ソフトの数字が古い' }
}
$mark = Join-Path $here '朝の確認をした日.txt'
$morning = $false
if ($now.Hour -ge 7 -and (-not (Test-Path $mark) -or (Get-Content $mark -Raw).Trim() -ne $today)) { $morning = $true; $reasons += '今日の朝の確認' }

$mmark = Join-Path $here '議事録を書いた日.txt'
$mh = 18; if ($st -and $st.minutes_hour) { try { $mh = [int]$st.minutes_hour } catch { } }
$minutes = $false
if ($now.Hour -ge $mh -and (-not (Test-Path $mmark) -or (Get-Content $mmark -Raw).Trim() -ne $today)) {
  $mdir = Join-Path $Folder '20_議事録\AI本社'
  if (-not (Test-Path (Join-Path $mdir ($today + '_AI本社_議事録.md')))) { $minutes = $true; $reasons += '今日の議事録' }
}

if ($reasons.Count -eq 0) { exit 0 }   # やることなし：Claude を起こさない
$why = $reasons -join '・'
if ($DryRun) { Log "【試し】起こす理由：$why（実際には起こしていません）"; exit 0 }

$claude = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claude) { $p = Join-Path $env:USERPROFILE '.local\bin\claude.exe'; if (Test-Path $p) { Set-Alias claude $p } ; $claude = Get-Command claude -ErrorAction SilentlyContinue }
if (-not $claude) { Log "Claude Code（claude コマンド）が見つかりません。理由：$why"; exit 1 }

$only = @($reasons | Where-Object { $_ -ne '今日の議事録' }) -join '・'
$prompt = if ($morning) { "会社のルール（CLAUDE.md と AI本社の基本ルール）の「毎朝の確認」を行って。ただし、やることが無い手順はとばして短く終わらせて。" }
          elseif ($only) { "会社のルール（CLAUDE.md と AI本社の基本ルール）の「毎朝の確認」のうち、次に関係する手順だけを行って：$only。それ以外はしないで、短く終わらせて。" }
          else { "ほかの手順はしないで、短く終わらせて。" }
if ($minutes) { $prompt += " 最後に /daily-minutes で今日の議事録を書いて。" }
New-Item -ItemType File -Path $lock -Force | Out-Null
try {
  Log "Claude を起こします：$why"
  Push-Location $Folder
  & claude -p $prompt --permission-mode acceptEdits --allowedTools "Read,Write,Edit,Glob,Grep,WebSearch,WebFetch" 2>&1 | Out-File -FilePath (Join-Path $here 'さいごの作業.txt') -Encoding UTF8
  Pop-Location
  if ($morning) { Set-Content -Path $mark -Value $today -Encoding UTF8 }
  if ($minutes) { Set-Content -Path $mmark -Value $today -Encoding UTF8 }
  Log '終わりました'
} finally { Remove-Item $lock -Force -ErrorAction SilentlyContinue }
