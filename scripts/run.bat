@echo off
setlocal

cd /d "%~dp0\.."

call "%~dp0build.bat"
if errorlevel 1 exit /b 1

set "VBOX=C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
if not exist "%VBOX%" (
    echo [ERROR] VirtualBox not found at "%VBOX%".
    exit /b 1
)

echo Starting VirtualBox VM 'KannaOS'...
"%VBOX%" startvm "KannaOS"
if errorlevel 1 (
    echo [ERROR] Failed to start VM.
    exit /b 1
)

echo KannaOS VM started successfully.
exit /b 0
