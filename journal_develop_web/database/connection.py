"""数据库连接层和 schema 初始化。所有公开 SQL 函数见 queries.py。"""

from __future__ import annotations
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "..", "echo.db")

# 心情关键词 → emoji 映射（用于发现页搜索）
MOOD_KEYWORD_MAP = {
    "开心": "😊", "高兴": "😊", "快乐": "😊",
    "疲惫": "😫", "累": "😫",
    "难过": "😢", "伤心": "😢",
    "生气": "😡", "愤怒": "😡",
    "幸福": "🥰", "幸运": "🥰",
    "平静": "😐", "平淡": "😐", "一般": "😐",
}


def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


class _DbContext:
    """数据库连接上下文管理器，自动 commit/rollback/close"""
    def __init__(self):
        self.conn = get_connection()

    def __enter__(self):
        return self.conn

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is None:
            self.conn.commit()
        else:
            self.conn.rollback()
        self.conn.close()
        return False


def get_db():
    """上下文管理器，用法: with get_db() as conn: ..."""
    return _DbContext()


def init_db():
    conn = get_connection()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS diaries (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT    NOT NULL,
            mood       TEXT    NOT NULL,
            content    TEXT    NOT NULL,
            ai_summary TEXT    NOT NULL DEFAULT '',
            ai_message TEXT    NOT NULL DEFAULT '',
            tags       TEXT    NOT NULL DEFAULT ''
        )
    """)
    # 增量添加列（向后兼容已有数据库）
    for col, col_def in [
        ("is_public", "INTEGER NOT NULL DEFAULT 0"),
        ("hug_count", "INTEGER NOT NULL DEFAULT 0"),
        ("image_url", "TEXT DEFAULT ''"),
        ("unlock_date", "TEXT DEFAULT ''"),
        ("user_id", "INTEGER NOT NULL DEFAULT 1"),
        ("content_type", "TEXT NOT NULL DEFAULT 'diary'"),
    ]:
        try:
            conn.execute(f"ALTER TABLE diaries ADD COLUMN {col} {col_def}")
        except sqlite3.OperationalError:
            pass

    # 用户表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            nickname   TEXT    NOT NULL DEFAULT '小兔',
            avatar     TEXT    NOT NULL DEFAULT '🐰',
            bio        TEXT    NOT NULL DEFAULT '今天也在认真生活',
            interests  TEXT    NOT NULL DEFAULT '日记,生活,小确幸',
            created_at TEXT    NOT NULL
        )
    """)
    # 增量添加用户认证字段（向后兼容）
    for col, col_def in [
        ("username", "TEXT"),
        ("password_hash", "TEXT DEFAULT ''"),
        ("email", "TEXT DEFAULT ''"),
        ("updated_at", "TEXT DEFAULT ''"),
    ]:
        try:
            conn.execute(f"ALTER TABLE users ADD COLUMN {col} {col_def}")
        except sqlite3.OperationalError:
            pass
    # 为已有默认用户补充 username（username = echo_ + id）
    try:
        conn.execute("UPDATE users SET username = 'echo_' || id WHERE username IS NULL OR username = ''")
    except sqlite3.OperationalError:
        pass
    # 创建 username 唯一索引（尝试创建，已存在则忽略）
    try:
        conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username)")
    except sqlite3.OperationalError:
        pass
    # 确保默认用户存在
    row = conn.execute("SELECT COUNT(*) as cnt FROM users").fetchone()
    if row["cnt"] == 0:
        from datetime import datetime
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        conn.execute(
            "INSERT INTO users (nickname, avatar, bio, interests, username, password_hash, email, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            ("小兔", "🐰", "今天也在认真生活", "日记,生活,小确幸", "echo_1", "", "", now, now)
        )

    # 公开广场 - 点亮表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS public_diary_likes (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            diary_id   INTEGER NOT NULL,
            client_id  TEXT    NOT NULL,
            created_at TEXT    NOT NULL,
            UNIQUE(diary_id, client_id)
        )
    """)
    # 公开广场 - 评论表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS public_diary_comments (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            diary_id   INTEGER NOT NULL,
            client_id  TEXT    NOT NULL,
            content    TEXT    NOT NULL,
            created_at TEXT    NOT NULL
        )
    """)
    try:
        conn.execute("ALTER TABLE public_diary_comments ADD COLUMN user_id INTEGER")
    except sqlite3.OperationalError:
        pass
    try:
        conn.execute("ALTER TABLE public_diary_comments ADD COLUMN image_url TEXT DEFAULT ''")
    except sqlite3.OperationalError:
        pass
    for col, col_def in [
        ("parent_comment_id", "INTEGER DEFAULT NULL"),
        ("reply_to_user_id", "INTEGER DEFAULT NULL"),
        ("root_comment_id", "INTEGER DEFAULT NULL"),
    ]:
        try:
            conn.execute(f"ALTER TABLE public_diary_comments ADD COLUMN {col} {col_def}")
        except sqlite3.OperationalError:
            pass

    # 关注表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS user_follows (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            follower_id  INTEGER NOT NULL,
            following_id INTEGER NOT NULL,
            created_at   TEXT    NOT NULL,
            UNIQUE(follower_id, following_id)
        )
    """)

    # 日记多图表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS diary_images (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            diary_id   INTEGER NOT NULL,
            image_url  TEXT    NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (diary_id) REFERENCES diaries(id) ON DELETE CASCADE
        )
    """)

    # 通知表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS notifications (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            recipient_id INTEGER NOT NULL,
            actor_id     INTEGER,
            type         TEXT    NOT NULL,
            entity_type  TEXT    NOT NULL DEFAULT '',
            entity_id    INTEGER,
            title        TEXT    NOT NULL DEFAULT '',
            content      TEXT    NOT NULL DEFAULT '',
            is_read      INTEGER NOT NULL DEFAULT 0,
            created_at   TEXT    NOT NULL,
            read_at      TEXT    NOT NULL DEFAULT ''
        )
    """)

    # 打招呼申请表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS greet_requests (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            requester_id INTEGER NOT NULL,
            receiver_id  INTEGER NOT NULL,
            message      TEXT    NOT NULL DEFAULT '',
            status       TEXT    NOT NULL DEFAULT 'pending',
            created_at   TEXT    NOT NULL,
            responded_at TEXT    NOT NULL DEFAULT ''
        )
    """)

    # 私信会话表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS conversations (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            user1_id        INTEGER NOT NULL,
            user2_id        INTEGER NOT NULL,
            created_at      TEXT    NOT NULL,
            updated_at      TEXT    NOT NULL,
            last_message    TEXT    NOT NULL DEFAULT '',
            last_message_at TEXT    NOT NULL DEFAULT '',
            UNIQUE(user1_id, user2_id)
        )
    """)

    # 私信消息表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS private_messages (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id INTEGER NOT NULL,
            sender_id       INTEGER NOT NULL,
            receiver_id     INTEGER NOT NULL,
            content         TEXT    NOT NULL,
            image_url       TEXT    DEFAULT '',
            is_read         INTEGER NOT NULL DEFAULT 0,
            created_at      TEXT    NOT NULL
        )
    """)
    # 迁移：给已存在的表加 image_url 字段
    try:
        conn.execute("ALTER TABLE private_messages ADD COLUMN image_url TEXT DEFAULT ''")
    except Exception:
        pass

    # 拉黑表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS user_blocks (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            blocker_id  INTEGER NOT NULL,
            blocked_id  INTEGER NOT NULL,
            reason      TEXT    NOT NULL DEFAULT '',
            created_at  TEXT    NOT NULL,
            UNIQUE(blocker_id, blocked_id)
        )
    """)

    # 树洞回复表（匿名，user_id 仅内部用于通知，不对外暴露）
    conn.execute("""
        CREATE TABLE IF NOT EXISTS treehole_replies (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            diary_id   INTEGER NOT NULL,
            user_id    INTEGER,
            content    TEXT    NOT NULL,
            created_at TEXT    NOT NULL,
            FOREIGN KEY (diary_id) REFERENCES diaries(id) ON DELETE CASCADE
        )
    """)
    # 增量添加 user_id 列（向后兼容）
    try:
        conn.execute("ALTER TABLE treehole_replies ADD COLUMN user_id INTEGER")
    except sqlite3.OperationalError:
        pass
    try:
        conn.execute("ALTER TABLE treehole_replies ADD COLUMN image_url TEXT DEFAULT ''")
    except sqlite3.OperationalError:
        pass

    # 树洞回复点赞表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS treehole_reply_likes (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            reply_id   INTEGER NOT NULL,
            user_id    INTEGER NOT NULL,
            created_at TEXT    NOT NULL,
            UNIQUE(reply_id, user_id)
        )
    """)

    # 公开日记评论点赞表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS public_diary_comment_likes (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            comment_id INTEGER NOT NULL,
            user_id    INTEGER NOT NULL,
            created_at TEXT    NOT NULL,
            UNIQUE(comment_id, user_id)
        )
    """)

    # 树洞抱抱记录表（防重复）
    conn.execute("""
        CREATE TABLE IF NOT EXISTS treehole_hugs (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            diary_id   INTEGER NOT NULL,
            user_id    INTEGER NOT NULL,
            created_at TEXT    NOT NULL,
            UNIQUE(diary_id, user_id)
        )
    """)

    # 树洞匿名身份映射表（同一用户在同一树洞中保持同一匿名身份）
    conn.execute("""
        CREATE TABLE IF NOT EXISTS treehole_identities (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            treehole_id  INTEGER NOT NULL,
            identity_key TEXT    NOT NULL,
            anon_name    TEXT    NOT NULL,
            anon_avatar  TEXT    NOT NULL,
            created_at   TEXT    NOT NULL,
            UNIQUE(treehole_id, identity_key)
        )
    """)

    # 树洞回复——增量添加线程字段
    for col, col_def in [
        ("parent_reply_id", "INTEGER DEFAULT NULL"),
        ("root_reply_id", "INTEGER DEFAULT NULL"),
        ("reply_to_identity_id", "INTEGER DEFAULT NULL"),
        ("identity_id", "INTEGER DEFAULT NULL"),
    ]:
        try:
            conn.execute(f"ALTER TABLE treehole_replies ADD COLUMN {col} {col_def}")
        except sqlite3.OperationalError:
            pass

    # 举报表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS reports (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            reporter_id     INTEGER NOT NULL,
            target_type     TEXT    NOT NULL,
            target_id       INTEGER NOT NULL,
            target_user_id  INTEGER,
            reason          TEXT    NOT NULL,
            description     TEXT    NOT NULL DEFAULT '',
            status          TEXT    NOT NULL DEFAULT 'pending',
            created_at      TEXT    NOT NULL,
            handled_at      TEXT    NOT NULL DEFAULT ''
        )
    """)

    conn.commit()
    conn.close()
