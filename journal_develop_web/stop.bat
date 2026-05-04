@echo off
chcp 65001 >nul
echo ============================================
echo   Echo 日记 - 停止服务器
echo ============================================
echo.
echo [+] 杀掉所有 Python 进程...
taskkill /F /IM python.exe 2>nul
if %ERRORLEVEL% equ 0 (
    echo [+] 服务已停止
) else (
    echo [!] 没有正在运行的 Python 进程
)
echo.
pause
