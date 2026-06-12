@echo off
call "%~dp0wt-config.cmd" 2>nul
if "%WORKBENCH_ROOT%"=="" (
  for %%I in ("%~dp0..\..\..") do set "WORKBENCH_ROOT=%%~fI"
)
if "%PYTHON_BIN%"=="" set "PYTHON_BIN=python"
"%PYTHON_BIN%" "%WORKBENCH_ROOT%\scripts\worktrees\wt_sync_permissions.py" --workdir "%CD%" %*
