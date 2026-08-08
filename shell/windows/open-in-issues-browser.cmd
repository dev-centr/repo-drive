@echo off
REM Windows Explorer helper: Open selected folder's repo in issues-browser.
REM Register via shell\windows\register-context-menu.ps1
REM Usage: open-in-issues-browser.cmd <path-under-mount>

setlocal
set "TARGET=%~1"
if "%TARGET%"=="" (
  echo Usage: %~nx0 ^<path^>
  exit /b 1
)
where repodrive >nul 2>&1
if errorlevel 1 (
  echo repodrive not on PATH
  exit /b 1
)
repodrive open-issues "%TARGET%"
endlocal
