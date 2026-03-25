@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\activate.bat" (
  echo Run install-windows.bat first to create the virtual environment.
  exit /b 1
)
call .venv\Scripts\activate.bat
python -m musubi_tuner.gui_dashboard %*
exit /b %ERRORLEVEL%
