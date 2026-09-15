# Status of always-on daemon
Get-ScheduledTask -TaskName "PCRemote" -ErrorAction SilentlyContinue | Format-Table TaskName, State
Get-ScheduledTaskInfo -TaskName "PCRemote" -ErrorAction SilentlyContinue | Format-List LastTaskResult, LastRunTime, NextRunTime
try { (Invoke-RestMethod http://localhost:5000/status).brightness | ForEach-Object { "API OK, brightness=$_" } }
catch { "API not responding (task not running? run scripts/install_autostart.ps1)" }
Get-Content ..\profiles\daemon.log -Tail 5 -ErrorAction SilentlyContinue
