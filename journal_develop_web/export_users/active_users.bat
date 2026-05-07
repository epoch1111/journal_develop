@echo off
chcp 65001 >nul
echo ============================================
echo   Echo Journal - Online Users
echo ============================================
echo.
echo Opening browser...
start http://localhost:8000/api/admin/page
