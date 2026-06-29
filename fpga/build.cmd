@echo off
REM build.cmd -- thin wrapper around build.ps1 (bypasses execution policy).
REM   build all          build w19 100t          build clean          build distclean
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
