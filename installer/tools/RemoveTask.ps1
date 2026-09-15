param([string]$AppDir="")
# Lumen Desk uninstall cleanup: stop + delete task, kill daemon, drop firewall rule.
$ErrorActionPreference = "SilentlyContinue"
foreach ($t in @("LumenDesk", "PCRemote")) {
  Stop-ScheduledTask -TaskName $t
  Unregister-ScheduledTask -TaskName $t -Confirm:$false
}
Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" |
  Where-Object { $_.CommandLine -like "*daemon.py*" -and
    ($AppDir -eq "" -or $_.CommandLine -like "*${AppDir}*") } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
netsh advfirewall firewall delete rule name="Lumen Desk" | Out-Null
netsh advfirewall firewall delete rule name="PCRemote" | Out-Null
Write-Output "LumenDesk stopped and removed"
