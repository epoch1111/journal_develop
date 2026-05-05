@echo off
chcp 65001 >nul
echo ============================================
echo   Echo 日记 - 启动开发服务器
echo ============================================
echo.

set PYTHON=E:\Anaconda\envs\journal_develop\python.exe

if not exist "%PYTHON%" (
    echo [ERROR] Python 未找到: %PYTHON%
    echo 请修改 start.bat 中的 PYTHON 变量为正确的 Python 路径
    pause
    exit /b 1
)

echo [+] 检查依赖...
%PYTHON% -c "import fastapi, uvicorn, passlib, jose" 2>nul
if %ERRORLEVEL% neq 0 (
    echo [!] 缺少依赖，请运行: %PYTHON% -m pip install -r requirements.txt
    pause
    exit /b 1
)

echo [+] 杀掉已有的 Python 进程...
taskkill /F /IM python.exe 2>nul

echo [+] 启动服务器...
echo.
echo   前端页面: http://localhost:8000
echo   API 文档: http://localhost:8000/docs
echo   按 Ctrl+C 停止服务器
echo.

cd /d "%~dp0"
%PYTHON% -m uvicorn main:app --reload --host 0.0.0.0 --port 8000

pause
