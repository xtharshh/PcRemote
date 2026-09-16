# Stop background daemon (scheduled task + any stray pythonw)
Unregister-ScheduledTask -TaskName "LumenDesk" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "PCRemote" -Confirm:$false -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -like "*daemon.py*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
netsh advfirewall firewall delete rule name="Lumen Desk" -ErrorAction SilentlyContinue | Out-Null
netsh advfirewall firewall delete rule name="PCRemote" -ErrorAction SilentlyContinue | Out-Null
Write-Output "LumenDesk removed / stopped"
