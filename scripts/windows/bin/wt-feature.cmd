@echo off
setlocal enabledelayedexpansion
call "%~dp0wt-config.cmd" 2>nul
if "%WORKBENCH_ROOT%"=="" (
  for %%I in ("%~dp0..\..\..") do set "WORKBENCH_ROOT=%%~fI"
)
if "%PYTHON_BIN%"=="" set "PYTHON_BIN=python"

set "OUT_FILE=%TEMP%\wt-feature-%RANDOM%-%RANDOM%.out"
"%PYTHON_BIN%" "%WORKBENCH_ROOT%\scripts\worktrees\wt_feature.py" --workdir "%CD%" %* > "%OUT_FILE%" 2>&1
set "RC=%ERRORLEVEL%"
set "WT_PATH="

for /f "usebackq delims=" %%L in ("%OUT_FILE%") do (
  echo %%L
  set "LINE=%%L"
  if "!LINE:~0,14!"=="WORKTREE_PATH=" set "WT_PATH=!LINE:~14!"
)
del "%OUT_FILE%" 2>nul

if not "%RC%"=="0" exit /b %RC%
if not "%WT_PATH%"=="" cd /d "%WT_PATH%"
exit /b 0
