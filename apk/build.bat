@echo off
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
echo [3/3] Moving APK...
move /y "build\app\outputs\flutter-apk\app-release.apk" "echo_release.apk"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: move failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo   DONE: echo_release.apk
echo ========================================
pause
