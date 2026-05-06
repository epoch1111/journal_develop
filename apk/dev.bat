@echo off
set ANDROID_HOME=F:\Android\sdk
set ANDROID_SDK_ROOT=F:\Android\sdk
set JAVA_HOME=F:\Android\android_studio\jbr
set PATH=F:\flutter\bin;%PATH%

echo ========================================
echo   Echo Journal - Dev Mode
echo ========================================
echo.
echo   r  Hot Reload
echo   R  Hot Restart
echo   q  Quit
echo.
echo ========================================

cd /d "%~dp0"
call flutter.bat run -d 10AD1D0K690012N
pause
