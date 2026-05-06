@echo off
chcp 65001 >nul
set ANDROID_HOME=F:\Android\sdk
set ANDROID_SDK_ROOT=F:\Android\sdk
set JAVA_HOME=F:\Android\android_studio\jbr
set PATH=F:\flutter\bin;%PATH%

echo ========================================
echo   Echo Journal - APK Builder
echo ========================================
echo.

cd /d "%~dp0"

echo [1/3] flutter pub get...
call flutter.bat pub get
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: pub get failed
    pause
    exit /b 1
)

echo.
echo [2/3] flutter build apk --release...
call flutter.bat build apk --release
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: build failed
    pause
    exit /b 1
)

echo.
echo [3/4] Moving APK...
move /y "build\app\outputs\flutter-apk\app-release.apk" "echo_release.apk"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: move failed
    pause
    exit /b 1
)

echo [4/4] Copying APK to backend static dir...
if exist "..\journal_develop_web\static\" (
    copy /y "echo_release.apk" "..\journal_develop_web\static\echo_release.apk"
    echo   Copied to ..\journal_develop_web\static\echo_release.apk
) else (
    echo   WARNING: ..\journal_develop_web\static\ not found, skip
)

echo.
echo ========================================
echo   DONE: echo_release.apk
echo   OTA: {server}/api/app/download
echo ========================================
pause
