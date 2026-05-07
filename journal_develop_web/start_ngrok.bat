@echo off
chcp 65001 >nul

echo ========================================
echo   Echo 日记 - Ngrok 内网穿透
echo ========================================
echo.
echo   确保后端服务已启动 (端口 8000)
echo   查看下方 Forwarding 的 HTTPS 地址
echo   粘贴到网页「我的」页面的连接设置中
echo   按 Ctrl+C 停止
echo ========================================
echo.

F:\ngrok\ngrok.exe http 8000
