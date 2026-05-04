"""Echo 日记 - 全局配置"""

APP_TITLE = "Echo - 治愈系智能日记"
DB_PATH = None  # None 表示使用 database.py 中的默认路径

# JWT 密钥（生产环境请更换为随机字符串并妥善保管）
JWT_SECRET_KEY = "echo-dev-secret-key-change-in-production"
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_DAYS = 7

# AI 伙伴人格预设
AI_PERSONAS = {
    "default": {
        "name": "小兔",
        "tone": "温柔、共情、治愈",
        "emoji": "🐰",
    },
    "cheerful": {
        "name": "小兔",
        "tone": "活泼、元气、鼓励",
        "emoji": "🐰",
    },
}

# 心情颜色映射（用于 UI 卡片装饰色）
MOOD_COLORS = {
    "😊": {"accent": "#FEF3C7", "border": "#F59E0B", "label": "开心"},
    "😫": {"accent": "#E0E7FF", "border": "#6366F1", "label": "疲惫"},
    "😢": {"accent": "#DBEAFE", "border": "#3B82F6", "label": "难过"},
    "😡": {"accent": "#FEE2E2", "border": "#EF4444", "label": "生气"},
    "🥰": {"accent": "#FCE7F3", "border": "#EC4899", "label": "幸福"},
}

# 引导式写作提示
WRITING_PROMPTS = [
    "今天最让你印象深刻的一件事是什么？",
    "此刻你的心情像什么颜色？",
    "如果你可以给今天起一个标题，会是什么？",
    "今天有什么小事让你感到温暖？",
    "闭上眼睛，最先浮现在脑海的画面是？",
]
