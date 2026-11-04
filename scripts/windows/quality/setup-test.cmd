@echo off
pwsh -NoProfile -File "%~dp0..\..\..\tests\windows_quality_setup_test.ps1"
exit /b %errorlevel%
