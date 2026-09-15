param([int]$Port=5000)
# Run phone remote + auto-brightness loop together
Start-Job -Name pc_remote -ScriptBlock { Set-Location $using:PWD; python src/pc_service/server.py } | Out-Null
python src/autobrightness/service.py --interval 5
