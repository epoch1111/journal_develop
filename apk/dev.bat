@echo off
set ANDROID_HOME=F:\Android\sdk
set ANDROID_SDK_ROOT=F:\Android\sdk
set JAVA_HOME=F:\Android\android_studio\jbr
set PATH=F:\flutter\bin;F:\Android\sdk\platform-tools;%PATH%

echo ========================================
echo   Echo Journal - Dev Mode
echo ========================================
echo.

cd /d "%~dp0"

echo [1/2] Building APK...
call build.bat
if %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    pause
    exit /b 1
)

echo.
echo [2/2] Installing to device 10AD1D0K690012N...
adb install -r echo_release.apk

echo.
echo ========================================
echo   Done! App installed on device.
echo ========================================
pause
