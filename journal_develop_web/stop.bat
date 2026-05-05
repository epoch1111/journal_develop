@echo off
chcp 65001 >nul
echo ============================================
echo   Echo 日记 - 停止服务器
echo ============================================
echo.

echo [+] 查找占用端口 8000 的进程...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000.*LISTENING') do set PID=%%a

if defined PID (
    echo [+] 停止进程 PID=%PID%...
    taskkill /F /PID %PID% 2>nul
    if %ERRORLEVEL% equ 0 (
        echo [+] 服务已停止
    ) else (
        echo [!] 停止失败，请手动结束 PID=%PID%
    )
) else (
    echo [!] 没有找到运行中的服务器（端口 8000）
)
echo.
pause
