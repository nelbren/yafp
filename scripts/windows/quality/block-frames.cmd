@echo off
pwsh -NoProfile -File "%~dp0..\..\..\tests\block_frames_test.ps1"
exit /b %errorlevel%
