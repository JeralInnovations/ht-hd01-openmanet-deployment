@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0open-camera2-video.ps1"
if errorlevel 1 (
  echo.
  echo Camera stream launch failed. Review the message above.
  pause
)
endlocal
