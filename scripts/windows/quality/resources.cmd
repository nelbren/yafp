@echo off
pwsh -NoProfile -File "%~dp0..\..\..\tests\resources_test.ps1"
exit /b %errorlevel%
