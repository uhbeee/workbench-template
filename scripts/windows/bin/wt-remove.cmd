@echo off
setlocal enabledelayedexpansion
call "%~dp0wt-config.cmd" 2>nul
if "%WORKBENCH_ROOT%"=="" (
  for %%I in ("%~dp0..\..\..") do set "WORKBENCH_ROOT=%%~fI"
)
if "%PYTHON_BIN%"=="" set "PYTHON_BIN=python"

set "REPO_ROOT="
for /f "delims=" %%R in ('git rev-parse --git-common-dir 2^>nul') do set "REPO_ROOT=%%R"
if "%REPO_ROOT%"=="." set "REPO_ROOT=%CD%"

"%PYTHON_BIN%" "%WORKBENCH_ROOT%\scripts\worktrees\wt_remove.py" --workdir "%CD%" %*
set "RC=%ERRORLEVEL%"

if "%RC%"=="0" (
  if not "%REPO_ROOT%"=="" cd /d "%REPO_ROOT%"
)
exit /b %RC%
