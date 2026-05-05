#!/usr/bin/env bash
set -e

echo "============================================"
echo "  Echo 日记 - 启动开发服务器"
echo "============================================"
echo ""

# 尝试自动查找 Python
if command -v python3 &>/dev/null; then
    PYTHON=python3
elif command -v python &>/dev/null; then
    PYTHON=python
else
    echo "[ERROR] 未找到 Python，请确保已安装 Python 3.11+"
    exit 1
fi

echo "[+] Python: $($PYTHON --version)"

# 检查依赖
echo "[+] 检查依赖..."
$PYTHON -c "import fastapi, uvicorn, passlib, jose" 2>/dev/null || {
    echo "[!] 缺少依赖，请运行: pip install -r requirements.txt"
    exit 1
}

# 确保 uploads 目录存在
mkdir -p uploads

echo "[+] 启动服务器..."
echo ""
echo "  前端页面: http://localhost:8000"
echo "  API 文档: http://localhost:8000/docs"
echo "  按 Ctrl+C 停止服务器"
echo ""

cd "$(dirname "$0")"
$PYTHON -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
