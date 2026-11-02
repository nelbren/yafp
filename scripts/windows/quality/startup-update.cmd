@echo off
pwsh -NoProfile -File "%~dp0..\..\..\tests\startup_update_test.ps1"
exit /b %errorlevel%
