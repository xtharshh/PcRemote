param([string]$Pin="1234", [int]$Port=5000, [string]$AppDir="", [string]$PythonW="")
# Lumen Desk first-run setup: register the always-on daemon (no window).
# Runs as the installing user (per-user logon task) — no admin needed here.
$ErrorActionPreference = "SilentlyContinue"
if ($AppDir -eq "") { $AppDir = Split-Path -Parent $PSScriptRoot }
if ($PythonW -eq "") { $PythonW = (Get-Command pythonw).Source }
# Remove a legacy manual install so two daemons never fight over the port.
Unregister-ScheduledTask -TaskName "PCRemote" -Confirm:$false
netsh advfirewall firewall delete rule name="PCRemote" | Out-Null
$action = New-ScheduledTaskAction -Execute $PythonW `
  -Argument "`"${AppDir}\src\pc_service\daemon.py`" ${Pin} ${Port}" `
  -WorkingDirectory $AppDir
$trig = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries -RestartCount 3 `
  -RestartInterval (New-TimeSpan -Minutes 1) -Hidden
Register-ScheduledTask -TaskName "LumenDesk" -Action $action `
  -Trigger $trig -Settings $set -Force | Out-Null
Start-ScheduledTask -TaskName "LumenDesk"
Write-Output "LumenDesk service running (PIN set, port $Port)"
