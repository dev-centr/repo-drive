# Unregister RepoDrive context menu
$ErrorActionPreference = "Stop"
$key = "HKCU:\Software\Classes\Directory\shell\RepoDriveOpenIssues"
if (Test-Path $key) {
  Remove-Item -Path $key -Recurse -Force
  Write-Host "Removed RepoDriveOpenIssues context menu"
} else {
  Write-Host "Nothing to remove"
}
