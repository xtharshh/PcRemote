param([string]$Pin="1234", [int]$Port=5000, [string]$AppDir="", [string]$PythonW="")
# Lumen Desk first-run setup: register the always-on daemon (no window).
# Runs elevated (RunLevel Highest) so icacls/user-creation work.
$ErrorActionPreference = "SilentlyContinue"
if ($AppDir -eq "") { $AppDir = Split-Path -Parent $PSScriptRoot }
if ($PythonW -eq "") { $PythonW = (Get-Command pythonw).Source }
# Remove a legacy manual install so two daemons never fight over the port.
Unregister-ScheduledTask -TaskName "LumenDesk" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "PCRemote" -Confirm:$false -ErrorAction SilentlyContinue
netsh advfirewall firewall delete rule name="Lumen Desk" -ErrorAction SilentlyContinue | Out-Null
netsh advfirewall firewall delete rule name="PCRemote" -ErrorAction SilentlyContinue | Out-Null
$action = New-ScheduledTaskAction -Execute $PythonW `
  -Argument "`"${AppDir}\src\pc_service\daemon.py`" ${Pin} ${Port}" `
  -WorkingDirectory $AppDir
$trig = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries -RestartCount 3 `
  -RestartInterval (New-TimeSpan -Minutes 1) -Hidden
# -RunLevel Highest on Register-ScheduledTask works on Win10/Server2016+
Register-ScheduledTask -TaskName "LumenDesk" -Action $action `
  -Trigger $trig -Settings $set -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName "LumenDesk"
Write-Output "LumenDesk service running elevated (PIN set, port $Port)"
