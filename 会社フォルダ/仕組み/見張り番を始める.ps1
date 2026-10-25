# 見張り番を Windows の「タスク スケジューラ」に登録する（10分ごと・ログオン中だけ動く）。一度だけ実行。
# 使い方：このファイルを右クリック →「PowerShell で実行」
# やめるとき：powershell -ExecutionPolicy Bypass -File 見張り番を始める.ps1 -Stop
param([switch]$Stop)
$name = 'AI本社の見張り番'
if ($Stop) { Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue; Write-Output '見張り番を止めました'; exit 0 }
$script = Join-Path $PSScriptRoot '見張り番.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 10)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings -Description 'AIを使わずに会社フォルダを見て、やることがあるときだけ Claude を起こす' -Force | Out-Null
Write-Output "見張り番を登録しました（10分ごと）。記録は 仕組み\見張り番の記録.txt に残ります。"
