param([int]$Level=50,[int]$Timeout=1)
(Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightnessMethods | Select-Object -First 1 | Invoke-CimMethod -MethodName WmiSetBrightness -Arguments @{Timeout=$Timeout; Brightness=$Level}) | Out-Null
Write-Output "set to $Level"
