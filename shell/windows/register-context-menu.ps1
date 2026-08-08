# Register "Open in Issues Browser" for folders (HKCU).
# Run: powershell -ExecutionPolicy Bypass -File register-context-menu.ps1

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cmd = Join-Path $here "open-in-issues-browser.cmd"
$key = "HKCU:\Software\Classes\Directory\shell\RepoDriveOpenIssues"
$cmdKey = Join-Path $key "command"

New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name "(default)" -Value "Open in Issues Browser"
Set-ItemProperty -Path $key -Name "Icon" -Value "shell32.dll,14"
New-Item -Path $cmdKey -Force | Out-Null
Set-ItemProperty -Path $cmdKey -Name "(default)" -Value "`"$cmd`" `"%1`""

Write-Host "Registered context menu. Unregister with unregister-context-menu.ps1"
