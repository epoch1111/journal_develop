from __future__ import annotations
import sqlite3
import os
from datetime import datetime

DB_PATH = os.path.join(os.path.dirname(__file__), "echo.db")


def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


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
        except Exception:
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
        except Exception:
            pass
    # 为已有默认用户补充 username（username = echo_ + id）
    try:
        conn.execute("UPDATE users SET username = 'echo_' || id WHERE username IS NULL OR username = ''")
    except Exception:
        pass
    # 创建 username 唯一索引（尝试创建，已存在则忽略）
    try:
        conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username)")
    except Exception:
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
    except Exception:
        pass
    for col, col_def in [
        ("parent_comment_id", "INTEGER DEFAULT NULL"),
        ("reply_to_user_id", "INTEGER DEFAULT NULL"),
        ("root_comment_id", "INTEGER DEFAULT NULL"),
    ]:
        try:
            conn.execute(f"ALTER TABLE public_diary_comments ADD COLUMN {col} {col_def}")
        except Exception:
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
            is_read         INTEGER NOT NULL DEFAULT 0,
            created_at      TEXT    NOT NULL
        )
    """)

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
    except Exception:
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
        except Exception:
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


def save_diary_to_db(mood: str, content: str, ai_summary: str, ai_message: str, tags: str, is_public: bool = False, image_url: str = "", unlock_date: str = "", user_id: int = 1, content_type: str = "diary") -> int:
    conn = get_connection()
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cursor = conn.execute(
        """INSERT INTO diaries (created_at, mood, content, ai_summary, ai_message, tags, is_public, image_url, unlock_date, user_id, content_type)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (created_at, mood, content, ai_summary, ai_message, tags, int(is_public), image_url, unlock_date, user_id, content_type),
    )
    conn.commit()
    row_id = cursor.lastrowid
    conn.close()
    return row_id


def get_all_diaries_from_db(date: str = None, user_id: int = None):
    """获取日记列表（不含树洞），可选按日期过滤、按用户过滤"""
    conn = get_connection()
    base_where = "WHERE content_type != 'treehole' AND is_public = 0"
    if date and user_id is not None:
        rows = conn.execute(
            f"SELECT * FROM diaries {base_where} AND created_at LIKE ? AND user_id = ? ORDER BY created_at DESC",
            (date + "%", user_id)
        ).fetchall()
    elif date:
        rows = conn.execute(
            f"SELECT * FROM diaries {base_where} AND created_at LIKE ? ORDER BY created_at DESC",
            (date + "%",)
        ).fetchall()
    elif user_id is not None:
        rows = conn.execute(
            f"SELECT * FROM diaries {base_where} AND user_id = ? ORDER BY created_at DESC",
            (user_id,)
        ).fetchall()
    else:
        rows = conn.execute(f"SELECT * FROM diaries {base_where} ORDER BY created_at DESC").fetchall()
    conn.close()
    return [dict(row) for row in rows]


def get_diary_stats(user_id: int = None):
    """获取统计数据：心情分布 + 每日心情映射，可选按用户过滤"""
    conn = get_connection()
    if user_id is not None:
        rows = conn.execute(
            "SELECT mood, COUNT(*) as cnt FROM diaries WHERE user_id = ? GROUP BY mood",
            (user_id,)
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT mood, COUNT(*) as cnt FROM diaries GROUP BY mood"
        ).fetchall()
    total = sum(r["cnt"] for r in rows)
    mood_distribution = [
        {"mood": r["mood"], "count": r["cnt"], "percentage": round(r["cnt"] / total * 100)}
        for r in rows
    ]
    if user_id is not None:
        rows = conn.execute(
            "SELECT DATE(created_at) as date, mood FROM diaries WHERE user_id = ? ORDER BY created_at DESC",
            (user_id,)
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT DATE(created_at) as date, mood FROM diaries ORDER BY created_at DESC"
        ).fetchall()
    calendar_data = {}
    for r in rows:
        d = r["date"]
        if d not in calendar_data:
            calendar_data[d] = r["mood"]
    conn.close()
    return {"mood_distribution": mood_distribution, "calendar_data": calendar_data}


def get_random_public_diary():
    """随机获取一条树洞日记（content_type='treehole'）"""
    conn = get_connection()
    row = conn.execute(
        "SELECT id, mood, content, hug_count FROM diaries WHERE content_type = 'treehole' ORDER BY RANDOM() LIMIT 1"
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def increment_hug_count(diary_id: int) -> int:
    """抱抱计数 +1，返回新的 hug_count"""
    conn = get_connection()
    conn.execute("UPDATE diaries SET hug_count = hug_count + 1 WHERE id = ?", (diary_id,))
    conn.commit()
    new_count = conn.execute("SELECT hug_count FROM diaries WHERE id = ?", (diary_id,)).fetchone()
    conn.close()
    return new_count["hug_count"] if new_count else 0


def get_diaries_by_date(target_date: str, user_id: int = None):
    """获取指定日期的所有日记（用于日历下钻），可选按用户过滤，排除树洞"""
    conn = get_connection()
    base_where = "WHERE content_type != 'treehole' AND is_public = 0"
    if user_id is not None:
        rows = conn.execute(
            f"SELECT * FROM diaries {base_where} AND created_at LIKE ? AND user_id = ? ORDER BY created_at DESC",
            (target_date + "%", user_id)
        ).fetchall()
    else:
        rows = conn.execute(
            f"SELECT * FROM diaries {base_where} AND created_at LIKE ? ORDER BY created_at DESC",
            (target_date + "%",)
        ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def get_diary_by_id(diary_id: int):
    """根据 id 查询单篇日记，不存在返回 None"""
    conn = get_connection()
    row = conn.execute("SELECT * FROM diaries WHERE id = ?", (diary_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def update_diary(diary_id: int, updates: dict) -> bool:
    """更新日记字段，只更新传入的非 None 字段。返回是否成功"""
    allowed = {"mood", "content", "ai_summary", "ai_message", "tags", "is_public", "image_url", "unlock_date"}
    fields = {k: v for k, v in updates.items() if k in allowed and v is not None}
    if not fields:
        return False

    set_clause = ", ".join(f"{k} = ?" for k in fields)
    values = list(fields.values()) + [diary_id]
    conn = get_connection()
    conn.execute(f"UPDATE diaries SET {set_clause} WHERE id = ?", values)
    conn.commit()
    affected = conn.total_changes
    conn.close()
    return affected > 0


def delete_diary(diary_id: int) -> bool:
    """删除日记，返回是否成功"""
    conn = get_connection()
    conn.execute("DELETE FROM diaries WHERE id = ?", (diary_id,))
    conn.execute("DELETE FROM diary_images WHERE diary_id = ?", (diary_id,))
    conn.commit()
    affected = conn.total_changes
    conn.close()
    return affected > 0


# ===== 日记多图 =====

def set_diary_images(diary_id: int, image_urls: list[str]):
    """替换日记的全部图片（先删后插）"""
    conn = get_connection()
    conn.execute("DELETE FROM diary_images WHERE diary_id = ?", (diary_id,))
    for i, url in enumerate(image_urls):
        if url and url.strip():
            conn.execute(
                "INSERT INTO diary_images (diary_id, image_url, sort_order) VALUES (?, ?, ?)",
                (diary_id, url.strip(), i),
            )
    conn.commit()
    conn.close()


def get_diary_images(diary_id: int) -> list[dict]:
    """获取日记的全部图片，按 sort_order 排序"""
    conn = get_connection()
    rows = conn.execute(
        "SELECT id, image_url FROM diary_images WHERE diary_id = ? ORDER BY sort_order",
        (diary_id,),
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_multi_diary_images(diary_ids: list[int]) -> dict[int, list[dict]]:
    """批量获取多篇日记的图片，返回 {diary_id: [images]}"""
    if not diary_ids:
        return {}
    conn = get_connection()
    placeholders = ",".join("?" for _ in diary_ids)
    rows = conn.execute(
        f"SELECT diary_id, id, image_url FROM diary_images WHERE diary_id IN ({placeholders}) ORDER BY diary_id, sort_order",
        diary_ids,
    ).fetchall()
    conn.close()
    result: dict[int, list[dict]] = {did: [] for did in diary_ids}
    for r in rows:
        result[r["diary_id"]].append({"id": r["id"], "image_url": r["image_url"]})
    return result


# ===== 公开日记广场 =====

def _build_public_diary_where():
    """公共 WHERE 条件：只查公开普通日记，排除私密、胶囊、树洞"""
    return "WHERE content_type = 'diary' AND is_public = 1 AND (unlock_date IS NULL OR unlock_date = '')"


def count_public_diaries(mood=None, tag=None, keyword=None):
    """统计公开日记总数"""
    conn = get_connection()
    where = _build_public_diary_where()
    params = []
    if mood:
        where += " AND mood = ?"
        params.append(mood)
    if tag:
        where += " AND tags LIKE ?"
        params.append(f"%{tag}%")
    if keyword:
        where += " AND content LIKE ?"
        params.append(f"%{keyword}%")
    row = conn.execute(f"SELECT COUNT(*) as cnt FROM diaries {where}", params).fetchone()
    conn.close()
    return row["cnt"] if row else 0


def list_public_diaries(page=1, page_size=10, mood=None, tag=None, keyword=None):
    """分页查询公开日记列表"""
    conn = get_connection()
    where = _build_public_diary_where()
    params = []
    if mood:
        where += " AND mood = ?"
        params.append(mood)
    if tag:
        where += " AND tags LIKE ?"
        params.append(f"%{tag}%")
    if keyword:
        where += " AND content LIKE ?"
        params.append(f"%{keyword}%")
    offset = (page - 1) * page_size
    rows = conn.execute(
        f"SELECT * FROM diaries {where} ORDER BY created_at DESC LIMIT ? OFFSET ?",
        params + [page_size, offset]
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def get_public_diary_by_id(diary_id):
    """获取单篇公开日记，不是公开或不存在返回 None"""
    conn = get_connection()
    row = conn.execute(
        "SELECT * FROM diaries WHERE id = ? AND content_type = 'diary' AND is_public = 1 AND (unlock_date IS NULL OR unlock_date = '')",
        (diary_id,)
    ).fetchone()
    conn.close()
    return dict(row) if row else None


# ---- 点亮 ----

def has_liked_public_diary(diary_id, client_id):
    """检查 client_id 是否已点亮某篇日记"""
    conn = get_connection()
    row = conn.execute(
        "SELECT id FROM public_diary_likes WHERE diary_id = ? AND client_id = ?",
        (diary_id, client_id)
    ).fetchone()
    conn.close()
    return row is not None


def like_public_diary(diary_id, client_id):
    """点亮公开日记，返回 (success, already_liked)"""
    conn = get_connection()
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        conn.execute(
            "INSERT INTO public_diary_likes (diary_id, client_id, created_at) VALUES (?, ?, ?)",
            (diary_id, client_id, created_at)
        )
        conn.commit()
        success, already = True, False
    except Exception:
        success, already = True, True  # UNIQUE 约束冲突 = 已点亮过
    conn.close()
    return success, already


def unlike_public_diary(diary_id, client_id):
    """取消点亮"""
    conn = get_connection()
    conn.execute(
        "DELETE FROM public_diary_likes WHERE diary_id = ? AND client_id = ?",
        (diary_id, client_id)
    )
    conn.commit()
    conn.close()


def count_public_diary_likes(diary_id):
    """获取点亮数量"""
    conn = get_connection()
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM public_diary_likes WHERE diary_id = ?",
        (diary_id,)
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


# 匿名昵称池（3 字，温暖治愈风格）
_ANON_NAMES = [
    "小蘑菇", "清风侠", "深海鲸", "北极星", "萤火虫", "小太阳", "月亮船",
    "蒲公英", "蓝泡泡", "小狐狸", "银河系", "暖洋洋", "棉花糖", "流星雨",
    "彩虹糖", "小蜗牛", "海豚音", "薰衣草", "小橙子", "云朵朵", "星星眼",
    "薄荷糖", "向日葵", "小笼包", "樱花雨", "气泡水", "小布丁", "柠檬草",
    "甜不辣", "芝士猫", "小海豹", "抹茶兔", "焦糖熊", "小饼干", "草莓酱",
    "橘子汽", "小鹿斑", "糯米团", "红豆冰", "小卷毛", "蜂蜜柚", "芒果冰",
    "小熊猫", "茉莉花", "烤红薯", "小刺猬", "蜜桃猫", "雪梨兔", "芋泥波",
]


def _anon_name(seed: int) -> str:
    """根据 seed 从匿名昵称池取一个稳定的 3 字昵称"""
    return _ANON_NAMES[seed % len(_ANON_NAMES)]


# ---- 评论 ----

def add_public_diary_comment(diary_id, client_id, content, user_id=None,
                              parent_comment_id=None, reply_to_user_id=None, root_comment_id=None):
    """添加评论，返回新评论 id"""
    conn = get_connection()
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cursor = conn.execute(
        """INSERT INTO public_diary_comments
           (diary_id, client_id, content, created_at, user_id, parent_comment_id, reply_to_user_id, root_comment_id)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        (diary_id, client_id, content, created_at, user_id, parent_comment_id, reply_to_user_id, root_comment_id)
    )
    conn.commit()
    comment_id = cursor.lastrowid
    conn.close()
    return comment_id


def list_public_diary_comments(diary_id, limit=50, viewer_id=None):
    """获取评论列表，返回线程结构：一级评论 + replies（含作者信息、reply_to_nickname、点赞信息）"""
    conn = get_connection()
    rows = conn.execute(
        """SELECT id, content, created_at, user_id, parent_comment_id, reply_to_user_id, root_comment_id
           FROM public_diary_comments WHERE diary_id = ?
           ORDER BY created_at ASC LIMIT ?""",
        (diary_id, limit)
    ).fetchall()

    # 收集所有需要查昵称的 user_id
    all_uids = set()
    all_reply_to_uids = set()
    for r in rows:
        uid = r["user_id"]
        if uid:
            all_uids.add(uid)
        reply_to_uid = r["reply_to_user_id"]
        if reply_to_uid:
            all_reply_to_uids.add(reply_to_uid)

    # 批量获取用户信息（小项目用缓存字典避免重复查询）
    user_cache = {}
    for uid in all_uids | all_reply_to_uids:
        user_cache[uid] = get_user_by_id(uid)

    # 先格式化所有评论
    all_comments = {}
    for r in rows:
        d = dict(r)
        cid = d["id"]
        uid = d.get("user_id")
        reply_to_uid = d.get("reply_to_user_id")

        if uid and uid in user_cache and user_cache[uid]:
            d["author_name"] = user_cache[uid]["nickname"]
            d["author_avatar"] = user_cache[uid]["avatar"]
        else:
            d["author_name"] = _anon_name(cid)
            d["author_avatar"] = "🌸"

        if reply_to_uid and reply_to_uid in user_cache and user_cache[reply_to_uid]:
            d["reply_to_nickname"] = user_cache[reply_to_uid]["nickname"]
        else:
            d["reply_to_nickname"] = ""

        # 点赞数 + 是否已赞
        d["like_count"] = conn.execute(
            "SELECT COUNT(*) as cnt FROM public_diary_comment_likes WHERE comment_id = ?",
            (cid,),
        ).fetchone()["cnt"]
        if viewer_id:
            liked = conn.execute(
                "SELECT id FROM public_diary_comment_likes WHERE comment_id = ? AND user_id = ?",
                (cid, viewer_id),
            ).fetchone()
            d["liked"] = liked is not None
        else:
            d["liked"] = False

        d["replies"] = []
        all_comments[cid] = d

    # 构建线程树：二级回复挂在 root_comment_id 或 parent_comment_id 下
    root_comments = []
    for cid, c in all_comments.items():
        parent_id = c.get("parent_comment_id")
        root_id = c.get("root_comment_id")
        # 确定挂载目标：优先 root_comment_id，其次 parent_comment_id
        target_id = root_id if root_id else parent_id
        if target_id and target_id in all_comments:
            all_comments[target_id]["replies"].append(c)
        else:
            root_comments.append(c)

    conn.close()
    return root_comments


def count_public_diary_comments(diary_id):
    """获取评论数量（含所有层级）"""
    conn = get_connection()
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM public_diary_comments WHERE diary_id = ?",
        (diary_id,)
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


def get_comment_by_id(comment_id: int) -> dict | None:
    """根据 id 获取单条评论"""
    conn = get_connection()
    row = conn.execute(
        "SELECT id, diary_id, content, created_at, user_id, parent_comment_id, reply_to_user_id, root_comment_id FROM public_diary_comments WHERE id = ?",
        (comment_id,)
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def save_comment_like(comment_id: int, user_id: int) -> tuple[bool, bool]:
    """点赞评论。返回 (success, already_liked)"""
    conn = get_connection()
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        conn.execute(
            "INSERT INTO public_diary_comment_likes (comment_id, user_id, created_at) VALUES (?, ?, ?)",
            (comment_id, user_id, created_at),
        )
        conn.commit()
        success, already = True, False
    except Exception:
        success, already = True, True
    conn.close()
    return success, already


def remove_comment_like(comment_id: int, user_id: int) -> bool:
    """取消点赞评论"""
    conn = get_connection()
    conn.execute(
        "DELETE FROM public_diary_comment_likes WHERE comment_id = ? AND user_id = ?",
        (comment_id, user_id),
    )
    affected = conn.total_changes
    conn.commit()
    conn.close()
    return affected > 0


def count_comment_likes(comment_id: int) -> int:
    """获取评论点赞数"""
    conn = get_connection()
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM public_diary_comment_likes WHERE comment_id = ?",
        (comment_id,),
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


# ===== 用户主页 =====

def get_or_create_default_user():
    """获取或创建默认用户"""
    conn = get_connection()
    row = conn.execute("SELECT * FROM users WHERE id = 1").fetchone()
    if not row:
        from datetime import datetime
        conn.execute(
            "INSERT INTO users (id, nickname, avatar, bio, interests, created_at) VALUES (?, ?, ?, ?, ?, ?)",
            (1, "小兔", "🐰", "今天也在认真生活", "日记,生活,小确幸", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        )
        conn.commit()
        row = conn.execute("SELECT * FROM users WHERE id = 1").fetchone()
    conn.close()
    return dict(row) if row else None


def get_user_by_id(user_id: int):
    """根据 id 获取用户"""
    conn = get_connection()
    row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def update_user_profile(user_id: int, data: dict):
    """更新用户资料，只更新传入的非 None 字段"""
    allowed = {"nickname", "avatar", "bio", "interests"}
    fields = {k: v for k, v in data.items() if k in allowed and v is not None}
    if not fields:
        return False
    set_clause = ", ".join(f"{k} = ?" for k in fields)
    values = list(fields.values()) + [user_id]
    conn = get_connection()
    conn.execute(f"UPDATE users SET {set_clause} WHERE id = ?", values)
    conn.commit()
    affected = conn.total_changes
    conn.close()
    return affected > 0


def get_user_profile_stats(user_id: int):
    """获取用户日记统计数据"""
    conn = get_connection()
    # 普通日记总数（不含胶囊和树洞）
    diary_count = conn.execute(
        "SELECT COUNT(*) as cnt FROM diaries WHERE user_id = ? AND content_type = 'diary' AND (unlock_date IS NULL OR unlock_date = '')",
        (user_id,)
    ).fetchone()["cnt"]
    # 公开普通日记
    public_diary_count = conn.execute(
        "SELECT COUNT(*) as cnt FROM diaries WHERE user_id = ? AND content_type = 'diary' AND is_public = 1 AND (unlock_date IS NULL OR unlock_date = '')",
        (user_id,)
    ).fetchone()["cnt"]
    # 时光胶囊
    capsule_count = conn.execute(
        "SELECT COUNT(*) as cnt FROM diaries WHERE user_id = ? AND content_type = 'capsule'",
        (user_id,)
    ).fetchone()["cnt"]
    # 树洞数量
    treehole_count = conn.execute(
        "SELECT COUNT(*) as cnt FROM diaries WHERE user_id = ? AND content_type = 'treehole'",
        (user_id,)
    ).fetchone()["cnt"]
    conn.close()
    return {
        "diary_count": diary_count,
        "public_diary_count": public_diary_count,
        "capsule_count": capsule_count,
        "treehole_count": treehole_count,
    }


def get_user_recent_public_diaries(user_id: int, limit: int = 5):
    """获取用户最近公开日记（只返回公开普通日记，排除胶囊、树洞和私密）"""
    conn = get_connection()
    rows = conn.execute(
        """SELECT id, mood, content, tags, created_at
           FROM diaries
           WHERE user_id = ? AND content_type = 'diary' AND is_public = 1 AND (unlock_date IS NULL OR unlock_date = '')
           ORDER BY created_at DESC LIMIT ?""",
        (user_id, limit)
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def get_user_mood_keywords(user_id: int):
    """获取用户情绪关键词（基于 mood 和 tags）"""
    conn = get_connection()
    # 获取 mood 分布
    moods = conn.execute(
        "SELECT mood, COUNT(*) as cnt FROM diaries WHERE user_id = ? GROUP BY mood ORDER BY cnt DESC LIMIT 5",
        (user_id,)
    ).fetchall()
    # 获取高频 tags
    tags_rows = conn.execute(
        "SELECT tags FROM diaries WHERE user_id = ? AND tags != ''",
        (user_id,)
    ).fetchall()
    conn.close()

    keywords = []
    mood_label_map = {"😊": "开心", "😫": "疲惫", "😢": "难过", "😡": "生气", "🥰": "幸福"}
    for m in moods:
        label = mood_label_map.get(m["mood"], "")
        if label and label not in keywords:
            keywords.append(label)

    # 从 tags 中提取高频词汇
    tag_counter = {}
    for r in tags_rows:
        for t in r["tags"].split(","):
            t = t.strip()
            if t:
                tag_counter[t] = tag_counter.get(t, 0) + 1
    top_tags = sorted(tag_counter.items(), key=lambda x: -x[1])[:5]
    for t, _ in top_tags:
        if t not in keywords:
            keywords.append(t)

    return keywords[:5]


def get_user_public_diary_count(user_id: int):
    """获取用户公开日记数"""
    conn = get_connection()
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM diaries WHERE user_id = ? AND content_type = 'diary' AND is_public = 1 AND (unlock_date IS NULL OR unlock_date = '')",
        (user_id,)
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


# ===== 用户认证 =====

def get_user_by_username(username: str):
    """根据 username 获取用户"""
    conn = get_connection()
    row = conn.execute("SELECT * FROM users WHERE username = ?", (username,)).fetchone()
    conn.close()
    return dict(row) if row else None


def create_user(username: str, password_hash: str, email: str = "") -> dict | None:
    """创建新用户，username 冲突返回 None"""
    conn = get_connection()
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        cursor = conn.execute(
            "INSERT INTO users (nickname, avatar, bio, interests, username, password_hash, email, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (username, "🐰", "今天也在认真生活", "日记,生活,小确幸", username, password_hash, email, now, now)
        )
        conn.commit()
        user_id = cursor.lastrowid
    except Exception:
        conn.close()
        return None
    row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def update_user_password(user_id: int, password_hash: str) -> bool:
    """更新用户密码哈希"""
    conn = get_connection()
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    conn.execute(
        "UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?",
        (password_hash, now, user_id)
    )
    conn.commit()
    affected = conn.total_changes
    conn.close()
    return affected > 0


def ensure_default_user():
    """确保默认用户存在且拥有 username"""
    conn = get_connection()
    row = conn.execute("SELECT * FROM users WHERE id = 1").fetchone()
    if not row:
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        conn.execute(
            "INSERT INTO users (id, nickname, avatar, bio, interests, username, password_hash, email, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (1, "小兔", "🐰", "今天也在认真生活", "日记,生活,小确幸", "echo_1", "", "", now, now)
        )
    else:
        r = dict(row)
        if not r.get("username"):
            conn.execute("UPDATE users SET username = 'echo_1' WHERE id = 1")
    conn.commit()
    conn.close()


# ===== 关注系统 =====

def follow_user(follower_id: int, following_id: int) -> bool:
    """关注用户，返回是否成功（重复关注返回 False）"""
    conn = get_connection()
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        conn.execute(
            "INSERT INTO user_follows (follower_id, following_id, created_at) VALUES (?, ?, ?)",
            (follower_id, following_id, created_at)
        )
        conn.commit()
        ok = True
    except Exception:
        ok = False
    conn.close()
    return ok


def unfollow_user(follower_id: int, following_id: int):
    """取消关注"""
    conn = get_connection()
    conn.execute(
        "DELETE FROM user_follows WHERE follower_id = ? AND following_id = ?",
        (follower_id, following_id)
    )
    conn.commit()
    conn.close()


def is_following(follower_id: int, following_id: int) -> bool:
    """检查 follower_id 是否关注了 following_id"""
    if follower_id is None:
        return False
    conn = get_connection()
    row = conn.execute(
        "SELECT id FROM user_follows WHERE follower_id = ? AND following_id = ?",
        (follower_id, following_id)
    ).fetchone()
    conn.close()
    return row is not None


def get_following_count(user_id: int) -> int:
    """我关注的人数"""
    conn = get_connection()
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM user_follows WHERE follower_id = ?",
        (user_id,)
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


def get_follower_count(user_id: int) -> int:
    """关注我的人数"""
    conn = get_connection()
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM user_follows WHERE following_id = ?",
        (user_id,)
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


def list_following_users(user_id: int) -> list[dict]:
    """我关注的用户列表"""
    conn = get_connection()
    rows = conn.execute(
        """SELECT u.id, u.nickname, u.avatar, u.bio, u.interests, u.created_at
           FROM user_follows f
           JOIN users u ON u.id = f.following_id
           WHERE f.follower_id = ?
           ORDER BY f.created_at DESC""",
        (user_id,)
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def list_follower_users(user_id: int) -> list[dict]:
    """关注我的用户列表"""
    conn = get_connection()
    rows = conn.execute(
        """SELECT u.id, u.nickname, u.avatar, u.bio, u.interests, u.created_at
           FROM user_follows f
           JOIN users u ON u.id = f.follower_id
           WHERE f.following_id = ?
           ORDER BY f.created_at DESC""",
        (user_id,)
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def get_following_recent_diaries(user_id: int, limit: int = 20) -> list[dict]:
    """我关注的用户最近公开普通日记（不含私密、胶囊、树洞）"""
    conn = get_connection()
    rows = conn.execute(
        """SELECT d.id, d.user_id, d.mood, d.content, d.ai_summary, d.ai_message,
                  d.tags, d.image_url, d.created_at,
                  u.nickname AS author_name, u.avatar AS author_avatar
           FROM diaries d
           JOIN user_follows f ON f.following_id = d.user_id
           JOIN users u ON u.id = d.user_id
           WHERE f.follower_id = ?
             AND d.content_type = 'diary'
             AND d.is_public = 1
             AND (d.unlock_date IS NULL OR unlock_date = '')
           ORDER BY d.created_at DESC
           LIMIT ?""",
        (user_id, limit)
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


# ===== 通知系统 =====

def create_notification(recipient_id: int, actor_id: int | None, type: str,
                        entity_type: str, entity_id: int | None,
                        title: str, content: str) -> int | None:
    """创建通知，返回通知 id"""
    from datetime import datetime
    conn = get_connection()
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cursor = conn.execute(
        """INSERT INTO notifications (recipient_id, actor_id, type, entity_type, entity_id, title, content, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        (recipient_id, actor_id, type, entity_type, entity_id, title, content, created_at),
    )
    conn.commit()
    nid = cursor.lastrowid
    conn.close()
    return nid


def notification_exists(recipient_id: int, actor_id: int | None, type: str, entity_id: int | None) -> bool:
    """检查是否已有相同通知（防重复）"""
    conn = get_connection()
    row = conn.execute(
        """SELECT id FROM notifications
           WHERE recipient_id = ? AND type = ? AND entity_id = ?
             AND (actor_id = ? OR (actor_id IS NULL AND ? IS NULL))
           LIMIT 1""",
        (recipient_id, type, entity_id, actor_id, actor_id),
    ).fetchone()
    conn.close()
    return row is not None


def list_notifications(user_id: int, page: int = 1, page_size: int = 20, unread_only: bool = False) -> dict:
    """获取用户通知列表（分页），附带 actor 信息"""
    conn = get_connection()
    where = "WHERE recipient_id = ? AND type NOT IN ('private_message', 'message')"
    params: list = [user_id]
    if unread_only:
        where += " AND is_read = 0"

    total = conn.execute(
        f"SELECT COUNT(*) as cnt FROM notifications {where}", params
    ).fetchone()["cnt"]

    offset = (page - 1) * page_size
    rows = conn.execute(
        f"""SELECT n.*, u.nickname AS actor_nickname, u.avatar AS actor_avatar
            FROM notifications n
            LEFT JOIN users u ON u.id = n.actor_id
            {where}
            ORDER BY n.created_at DESC
            LIMIT ? OFFSET ?""",
        params + [page_size, offset],
    ).fetchall()
    conn.close()

    items = []
    for r in rows:
        d = dict(r)
        actor = None
        if d.get("actor_nickname") or d.get("actor_avatar"):
            actor = {
                "id": d.pop("actor_id"),
                "nickname": d.pop("actor_nickname", ""),
                "avatar": d.pop("actor_avatar", "🐰"),
            }
        else:
            d.pop("actor_nickname", None)
            d.pop("actor_avatar", None)
        d["actor"] = actor
        items.append(d)

    return {
        "items": items,
        "page": page,
        "page_size": page_size,
        "total": total,
        "has_more": offset + page_size < total,
    }


def count_unread_notifications(user_id: int) -> int:
    """统计未读通知数"""
    conn = get_connection()
    row = conn.execute(
        """SELECT COUNT(*) as cnt FROM notifications
           WHERE recipient_id = ? AND is_read = 0
           AND type NOT IN ('private_message', 'message')""",
        (user_id,),
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


def mark_notification_read(user_id: int, notification_id: int) -> bool:
    """标记单条通知已读（仅操作自己的通知）"""
    from datetime import datetime
    conn = get_connection()
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    conn.execute(
        "UPDATE notifications SET is_read = 1, read_at = ? WHERE id = ? AND recipient_id = ?",
        (now, notification_id, user_id),
    )
    affected = conn.total_changes
    conn.commit()
    conn.close()
    return affected > 0


def mark_all_notifications_read(user_id: int) -> int:
    """标记所有通知已读，返回影响行数"""
    from datetime import datetime
    conn = get_connection()
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    conn.execute(
        "UPDATE notifications SET is_read = 1, read_at = ? WHERE recipient_id = ? AND is_read = 0",
        (now, user_id),
    )
    affected = conn.total_changes
    conn.commit()
    conn.close()
    return affected


def delete_notification(user_id: int, notification_id: int) -> bool:
    """删除通知（仅操作自己的通知）"""
    conn = get_connection()
    conn.execute(
        "DELETE FROM notifications WHERE id = ? AND recipient_id = ?",
        (notification_id, user_id),
    )
    affected = conn.total_changes
    conn.commit()
    conn.close()
    return affected > 0


# ===== 打招呼系统 =====

def create_greet_request(requester_id: int, receiver_id: int, message: str) -> int | None:
    """创建打招呼申请，已有 pending 申请时返回 None"""
    conn = get_connection()
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    # 检查是否已有 pending 申请
    existing = conn.execute(
        "SELECT id FROM greet_requests WHERE requester_id = ? AND receiver_id = ? AND status = 'pending'",
        (requester_id, receiver_id),
    ).fetchone()
    if existing:
        conn.close()
        return None
    cursor = conn.execute(
        "INSERT INTO greet_requests (requester_id, receiver_id, message, status, created_at) VALUES (?, ?, ?, 'pending', ?)",
        (requester_id, receiver_id, message, created_at),
    )
    conn.commit()
    rid = cursor.lastrowid
    conn.close()
    return rid


def get_greet_request_by_id(request_id: int) -> dict | None:
    """按 id 获取打招呼申请"""
    conn = get_connection()
    row = conn.execute("SELECT * FROM greet_requests WHERE id = ?", (request_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def get_pending_greet_between(requester_id: int, receiver_id: int) -> dict | None:
    """获取两人之间 pending 的申请"""
    conn = get_connection()
    row = conn.execute(
        "SELECT * FROM greet_requests WHERE requester_id = ? AND receiver_id = ? AND status = 'pending'",
        (requester_id, receiver_id),
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def get_latest_greet_between(user_a: int, user_b: int) -> dict | None:
    """获取两人之间最新一条打招呼记录（不限方向）"""
    conn = get_connection()
    row = conn.execute(
        """SELECT * FROM greet_requests
           WHERE (requester_id = ? AND receiver_id = ?)
              OR (requester_id = ? AND receiver_id = ?)
           ORDER BY created_at DESC LIMIT 1""",
        (user_a, user_b, user_b, user_a),
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def has_accepted_greet_between(user_a: int, user_b: int) -> bool:
    """检查两人之间是否存在任意一条 accepted 的打招呼记录"""
    conn = get_connection()
    row = conn.execute(
        """SELECT 1 FROM greet_requests
           WHERE ((requester_id = ? AND receiver_id = ?)
              OR (requester_id = ? AND receiver_id = ?))
           AND status = 'accepted'
           LIMIT 1""",
        (user_a, user_b, user_b, user_a),
    ).fetchone()
    conn.close()
    return row is not None


def list_user_contacts(user_id: int) -> list[dict]:
    """获取用户的所有 contacts（已 accepted 打招呼关系，过滤拉黑，附带会话信息）"""
    conn = get_connection()
    rows = conn.execute(
        """SELECT DISTINCT u.id, u.username, u.nickname, u.avatar, u.bio, u.interests,
                  c.id AS conversation_id,
                  CASE WHEN c.id IS NOT NULL THEN 1 ELSE 0 END AS has_conversation
           FROM users u
           JOIN greet_requests g ON (
               (g.requester_id = ? AND g.receiver_id = u.id)
               OR (g.receiver_id = ? AND g.requester_id = u.id)
           )
           LEFT JOIN conversations c ON (
               (c.user1_id = ? AND c.user2_id = u.id)
               OR (c.user2_id = ? AND c.user1_id = u.id)
           )
           WHERE g.status = 'accepted'
             AND u.id != ?
             AND u.id NOT IN (
                 SELECT blocked_id FROM user_blocks WHERE blocker_id = ?
                 UNION
                 SELECT blocker_id FROM user_blocks WHERE blocked_id = ?
             )
           ORDER BY u.nickname""",
        (user_id, user_id, user_id, user_id, user_id, user_id, user_id),
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def _attach_user_info(conn, row: dict, prefix: str) -> dict:
    """为申请记录附加用户信息"""
    uid = row.get(prefix + "_id")
    if uid:
        u = conn.execute(
            "SELECT id, nickname, avatar, bio, interests FROM users WHERE id = ?", (uid,)
        ).fetchone()
        if u:
            row[prefix] = dict(u)
        else:
            row[prefix] = None
    else:
        row[prefix] = None
    return row


def list_received_greet_requests(user_id: int, status: str | None = None) -> list[dict]:
    """我收到的打招呼申请"""
    conn = get_connection()
    where = "WHERE receiver_id = ?"
    params: list = [user_id]
    if status:
        where += " AND status = ?"
        params.append(status)
    rows = conn.execute(
        f"SELECT * FROM greet_requests {where} ORDER BY created_at DESC",
        params,
    ).fetchall()
    result = []
    for r in rows:
        d = _attach_user_info(conn, dict(r), "requester")
        result.append(d)
    conn.close()
    return result


def list_sent_greet_requests(user_id: int, status: str | None = None) -> list[dict]:
    """我发出的打招呼申请"""
    conn = get_connection()
    where = "WHERE requester_id = ?"
    params: list = [user_id]
    if status:
        where += " AND status = ?"
        params.append(status)
    rows = conn.execute(
        f"SELECT * FROM greet_requests {where} ORDER BY created_at DESC",
        params,
    ).fetchall()
    result = []
    for r in rows:
        d = _attach_user_info(conn, dict(r), "receiver")
        result.append(d)
    conn.close()
    return result


def update_greet_status(request_id: int, status: str) -> bool:
    """更新打招呼状态"""
    conn = get_connection()
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    conn.execute(
        "UPDATE greet_requests SET status = ?, responded_at = ? WHERE id = ?",
        (status, now, request_id),
    )
    affected = conn.total_changes
    conn.commit()
    conn.close()
    return affected > 0


def cancel_greet_request(request_id: int, requester_id: int) -> bool:
    """取消自己发出的 pending 申请"""
    conn = get_connection()
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    conn.execute(
        "UPDATE greet_requests SET status = 'cancelled', responded_at = ? WHERE id = ? AND requester_id = ? AND status = 'pending'",
        (now, request_id, requester_id),
    )
    affected = conn.total_changes
    conn.commit()
    conn.close()
    return affected > 0


def count_pending_greet_requests(user_id: int) -> int:
    """收到的待处理打招呼数量"""
    conn = get_connection()
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM greet_requests WHERE receiver_id = ? AND status = 'pending'",
        (user_id,),
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


# ===== 私信系统 =====

def _ensure_user1_user2(a: int, b: int) -> tuple[int, int]:
    """确保 user1_id < user2_id"""
    return (a, b) if a < b else (b, a)


def get_or_create_conversation(user_a_id: int, user_b_id: int) -> dict | None:
    """获取或创建两人之间的私信会话"""
    u1, u2 = _ensure_user1_user2(user_a_id, user_b_id)
    conn = get_connection()
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    row = conn.execute(
        "SELECT * FROM conversations WHERE user1_id = ? AND user2_id = ?",
        (u1, u2),
    ).fetchone()
    if not row:
        conn.execute(
            "INSERT INTO conversations (user1_id, user2_id, created_at, updated_at) VALUES (?, ?, ?, ?)",
            (u1, u2, now, now),
        )
        conn.commit()
        row = conn.execute(
            "SELECT * FROM conversations WHERE user1_id = ? AND user2_id = ?",
            (u1, u2),
        ).fetchone()
    conn.close()
    return dict(row) if row else None


def get_conversation_by_id(conversation_id: int) -> dict | None:
    """按 id 获取会话"""
    conn = get_connection()
    row = conn.execute("SELECT * FROM conversations WHERE id = ?", (conversation_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def get_conversation_between(user_a_id: int, user_b_id: int) -> dict | None:
    """获取两人之间的会话"""
    u1, u2 = _ensure_user1_user2(user_a_id, user_b_id)
    conn = get_connection()
    row = conn.execute(
        "SELECT * FROM conversations WHERE user1_id = ? AND user2_id = ?",
        (u1, u2),
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def list_user_conversations(user_id: int) -> list[dict]:
    """获取用户的会话列表，附带对方信息"""
    conn = get_connection()
    rows = conn.execute(
        """SELECT c.*,
                  CASE WHEN c.user1_id = ? THEN c.user2_id ELSE c.user1_id END AS other_user_id
           FROM conversations c
           WHERE c.user1_id = ? OR c.user2_id = ?
           ORDER BY c.last_message_at DESC, c.updated_at DESC""",
        (user_id, user_id, user_id),
    ).fetchall()
    result = []
    for r in rows:
        d = dict(r)
        other_id = d.pop("other_user_id")
        u = conn.execute(
            "SELECT id, nickname, avatar, bio FROM users WHERE id = ?", (other_id,)
        ).fetchone()
        d["other_user"] = dict(u) if u else None
        d["unread_count"] = conn.execute(
            "SELECT COUNT(*) as cnt FROM private_messages WHERE conversation_id = ? AND receiver_id = ? AND is_read = 0",
            (d["id"], user_id),
        ).fetchone()["cnt"]
        result.append(d)
    conn.close()
    return result


def create_private_message(conversation_id: int, sender_id: int, receiver_id: int, content: str) -> int | None:
    """创建私信消息，返回消息 id"""
    conn = get_connection()
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cursor = conn.execute(
        "INSERT INTO private_messages (conversation_id, sender_id, receiver_id, content, created_at) VALUES (?, ?, ?, ?, ?)",
        (conversation_id, sender_id, receiver_id, content, created_at),
    )
    conn.commit()
    mid = cursor.lastrowid
    conn.close()
    return mid


def list_private_messages(conversation_id: int, page: int = 1, page_size: int = 30) -> dict:
    """获取会话消息列表（分页），ASC 顺序"""
    conn = get_connection()
    total = conn.execute(
        "SELECT COUNT(*) as cnt FROM private_messages WHERE conversation_id = ?",
        (conversation_id,),
    ).fetchone()["cnt"]
    offset = (page - 1) * page_size
    rows = conn.execute(
        "SELECT * FROM private_messages WHERE conversation_id = ? ORDER BY created_at ASC LIMIT ? OFFSET ?",
        (conversation_id, page_size, offset),
    ).fetchall()
    conn.close()
    return {
        "items": [dict(r) for r in rows],
        "page": page,
        "page_size": page_size,
        "total": total,
        "has_more": offset + page_size < total,
    }


def mark_conversation_read(conversation_id: int, user_id: int) -> int:
    """标记当前用户收到的该会话消息为已读，返回影响行数"""
    conn = get_connection()
    conn.execute(
        "UPDATE private_messages SET is_read = 1 WHERE conversation_id = ? AND receiver_id = ? AND is_read = 0",
        (conversation_id, user_id),
    )
    affected = conn.total_changes
    conn.commit()
    conn.close()
    return affected


def count_unread_messages(user_id: int) -> int:
    """统计用户所有未读私信数"""
    conn = get_connection()
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM private_messages WHERE receiver_id = ? AND is_read = 0",
        (user_id,),
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


def count_conversation_unread(conversation_id: int, user_id: int) -> int:
    """统计某个会话中用户的未读数"""
    conn = get_connection()
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM private_messages WHERE conversation_id = ? AND receiver_id = ? AND is_read = 0",
        (conversation_id, user_id),
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


def update_conversation_last_message(conversation_id: int, content: str, created_at: str):
    """更新会话最后一条消息"""
    conn = get_connection()
    conn.execute(
        "UPDATE conversations SET last_message = ?, last_message_at = ?, updated_at = ? WHERE id = ?",
        (content, created_at, created_at, conversation_id),
    )
    conn.commit()
    conn.close()


# ===== 拉黑系统 =====

def block_user(blocker_id: int, blocked_id: int, reason: str = '') -> bool:
    """拉黑用户，重复拉黑或拉黑自己返回 False"""
    if blocker_id == blocked_id:
        return False
    conn = get_connection()
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        conn.execute(
            "INSERT INTO user_blocks (blocker_id, blocked_id, reason, created_at) VALUES (?, ?, ?, ?)",
            (blocker_id, blocked_id, reason, now),
        )
        conn.commit()
        ok = True
    except Exception:
        ok = False
    conn.close()
    return ok


def unblock_user(blocker_id: int, blocked_id: int):
    """取消拉黑"""
    conn = get_connection()
    conn.execute(
        "DELETE FROM user_blocks WHERE blocker_id = ? AND blocked_id = ?",
        (blocker_id, blocked_id),
    )
    conn.commit()
    conn.close()


def is_blocked_between(user_a_id: int, user_b_id: int) -> bool:
    """检查任意方向是否存在拉黑关系"""
    if not user_a_id or not user_b_id:
        return False
    conn = get_connection()
    row = conn.execute(
        """SELECT id FROM user_blocks
           WHERE (blocker_id = ? AND blocked_id = ?)
              OR (blocker_id = ? AND blocked_id = ?)
           LIMIT 1""",
        (user_a_id, user_b_id, user_b_id, user_a_id),
    ).fetchone()
    conn.close()
    return row is not None


def has_blocked(blocker_id: int, blocked_id: int) -> bool:
    """检查 blocker_id 是否拉黑了 blocked_id"""
    conn = get_connection()
    row = conn.execute(
        "SELECT id FROM user_blocks WHERE blocker_id = ? AND blocked_id = ?",
        (blocker_id, blocked_id),
    ).fetchone()
    conn.close()
    return row is not None


def list_blocked_users(blocker_id: int) -> list[dict]:
    """获取我拉黑的用户列表"""
    conn = get_connection()
    rows = conn.execute(
        """SELECT u.id, u.nickname, u.avatar, u.bio, u.interests, u.created_at AS user_created_at,
                  b.created_at AS blocked_at, b.reason
           FROM user_blocks b
           JOIN users u ON u.id = b.blocked_id
           WHERE b.blocker_id = ?
           ORDER BY b.created_at DESC""",
        (blocker_id,),
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def count_blocked_users(blocker_id: int) -> int:
    """统计拉黑用户数"""
    conn = get_connection()
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM user_blocks WHERE blocker_id = ?",
        (blocker_id,),
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


def get_blocked_user_ids(user_id: int) -> list[int]:
    """获取拉黑我的 + 我拉黑的所有用户 id"""
    conn = get_connection()
    rows = conn.execute(
        """SELECT blocked_id AS uid FROM user_blocks WHERE blocker_id = ?
           UNION
           SELECT blocker_id AS uid FROM user_blocks WHERE blocked_id = ?""",
        (user_id, user_id),
    ).fetchall()
    conn.close()
    return [r["uid"] for r in rows]


# ===== 举报系统 =====

def create_report(reporter_id: int, target_type: str, target_id: int, target_user_id: int | None,
                  reason: str, description: str) -> int:
    """创建举报，返回举报 id"""
    conn = get_connection()
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cursor = conn.execute(
        """INSERT INTO reports (reporter_id, target_type, target_id, target_user_id, reason, description, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        (reporter_id, target_type, target_id, target_user_id, reason, description, now),
    )
    conn.commit()
    rid = cursor.lastrowid
    conn.close()
    return rid


def list_my_reports(reporter_id: int) -> list[dict]:
    """获取我的举报记录"""
    conn = get_connection()
    rows = conn.execute(
        "SELECT * FROM reports WHERE reporter_id = ? ORDER BY created_at DESC",
        (reporter_id,),
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def get_report_by_id(report_id: int) -> dict | None:
    """按 id 获取举报"""
    conn = get_connection()
    row = conn.execute("SELECT * FROM reports WHERE id = ?", (report_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def count_my_reports(reporter_id: int) -> int:
    """统计我的举报数"""
    conn = get_connection()
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM reports WHERE reporter_id = ?",
        (reporter_id,),
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


# ===== 辅助查询 =====

def get_diary_owner_id(diary_id: int) -> int | None:
    """获取日记作者 id"""
    conn = get_connection()
    row = conn.execute("SELECT user_id FROM diaries WHERE id = ?", (diary_id,)).fetchone()
    conn.close()
    return row["user_id"] if row else None


def get_comment_owner_or_diary_owner(comment_id: int) -> int | None:
    """获取评论所属日记的作者 id"""
    conn = get_connection()
    row = conn.execute(
        """SELECT d.user_id FROM public_diary_comments c
           JOIN diaries d ON d.id = c.diary_id
           WHERE c.id = ?""",
        (comment_id,),
    ).fetchone()
    conn.close()
    return row["user_id"] if row else None


def get_message_participants(message_id: int) -> tuple[int | None, int | None]:
    """获取私信消息的发送者和接收者 id"""
    conn = get_connection()
    row = conn.execute(
        "SELECT sender_id, receiver_id FROM private_messages WHERE id = ?",
        (message_id,),
    ).fetchone()
    conn.close()
    return (row["sender_id"], row["receiver_id"]) if row else (None, None)


def get_treehole_by_id(treehole_id: int) -> dict | None:
    """获取树洞日记详情（仅 content_type='treehole'）"""
    conn = get_connection()
    row = conn.execute(
        "SELECT id, mood, content, tags, hug_count, created_at FROM diaries WHERE id = ? AND content_type = 'treehole'",
        (treehole_id,),
    ).fetchone()
    conn.close()
    return dict(row) if row else None


# 树洞匿名昵称/头像池
_TH_ANON_NAMES = [
    "深海鲸", "北极星", "月亮船", "雾里鹿", "橘子海", "晚风信",
    "小云朵", "玻璃猫", "星河兔", "雨后森林", "蓝莓岛", "白昼梦",
]
_TH_ANON_AVATARS = ["🫧", "🌙", "🐳", "⭐", "🦌", "🍊", "☁️", "🐱", "🐰", "🌧️", "🐚", "🌿"]


def _make_identity_key(user_id: int | None, client_id: str | None) -> str:
    """构建匿名身份 key"""
    if user_id:
        return f"user:{user_id}"
    if client_id:
        return f"client:{client_id}"
    return "anon:unknown"


def get_or_create_treehole_identity(treehole_id: int, user_id: int | None, client_id: str | None) -> dict:
    """获取或创建当前用户在指定树洞中的匿名身份，返回 {id, anon_name, anon_avatar}"""
    conn = get_connection()
    identity_key = _make_identity_key(user_id, client_id)
    row = conn.execute(
        "SELECT id, anon_name, anon_avatar FROM treehole_identities WHERE treehole_id = ? AND identity_key = ?",
        (treehole_id, identity_key),
    ).fetchone()
    if row:
        conn.close()
        return dict(row)
    # 分配新的匿名身份（随机但稳定——用 identity_key.hash 取模）
    seed = abs(hash(identity_key)) % len(_TH_ANON_NAMES)
    anon_name = _TH_ANON_NAMES[seed]
    anon_avatar = _TH_ANON_AVATARS[seed]
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cursor = conn.execute(
        "INSERT INTO treehole_identities (treehole_id, identity_key, anon_name, anon_avatar, created_at) VALUES (?, ?, ?, ?, ?)",
        (treehole_id, identity_key, anon_name, anon_avatar, created_at),
    )
    conn.commit()
    identity_id = cursor.lastrowid
    conn.close()
    return {"id": identity_id, "anon_name": anon_name, "anon_avatar": anon_avatar}


def get_treehole_identity_by_id(identity_id: int) -> dict | None:
    """根据 identity_id 获取匿名身份（含 treehole_id）"""
    conn = get_connection()
    row = conn.execute(
        "SELECT id, treehole_id, anon_name, anon_avatar FROM treehole_identities WHERE id = ?",
        (identity_id,),
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def save_treehole_reply(diary_id: int, content: str, user_id: int | None = None,
                         identity_id: int | None = None, parent_reply_id: int | None = None,
                         root_reply_id: int | None = None, reply_to_identity_id: int | None = None) -> int:
    """保存树洞匿名回复（支持线程），返回回复 id"""
    conn = get_connection()
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cursor = conn.execute(
        """INSERT INTO treehole_replies
           (diary_id, user_id, content, created_at, identity_id, parent_reply_id, root_reply_id, reply_to_identity_id)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        (diary_id, user_id, content, created_at, identity_id, parent_reply_id, root_reply_id, reply_to_identity_id),
    )
    conn.commit()
    reply_id = cursor.lastrowid
    conn.close()
    return reply_id


def get_treehole_reply_full(reply_id: int) -> dict | None:
    """获取单条树洞回复（含线程字段）"""
    conn = get_connection()
    row = conn.execute(
        "SELECT id, diary_id, user_id, content, created_at, identity_id, parent_reply_id, root_reply_id, reply_to_identity_id FROM treehole_replies WHERE id = ?",
        (reply_id,),
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def list_treehole_replies(diary_id: int, viewer_id: int | None = None) -> list[dict]:
    """获取树洞回复列表——返回线程结构（一级回复 + replies 子数组）"""
    conn = get_connection()
    rows = conn.execute(
        "SELECT id, content, created_at, identity_id, parent_reply_id, root_reply_id, reply_to_identity_id FROM treehole_replies WHERE diary_id = ? ORDER BY created_at ASC",
        (diary_id,),
    ).fetchall()

    # 收集所有 identity_id
    all_id_ids = set()
    for r in rows:
        if r["identity_id"]:
            all_id_ids.add(r["identity_id"])
        if r["reply_to_identity_id"]:
            all_id_ids.add(r["reply_to_identity_id"])

    # 批量查询匿名身份
    id_cache = {}
    for iid in all_id_ids:
        id_cache[iid] = get_treehole_identity_by_id(iid)

    # 格式化所有回复
    all_replies = {}
    for r in rows:
        d = dict(r)
        rid = d["id"]
        iid = d.pop("identity_id", None)
        reply_to_iid = d.pop("reply_to_identity_id", None)

        if iid and iid in id_cache and id_cache[iid]:
            d["anon_name"] = id_cache[iid]["anon_name"]
            d["anon_avatar"] = id_cache[iid]["anon_avatar"]
        else:
            d["anon_name"] = _anon_name(rid)
            d["anon_avatar"] = "👻"
        d["identity_id"] = iid

        if reply_to_iid and reply_to_iid in id_cache and id_cache[reply_to_iid]:
            d["reply_to_anon_name"] = id_cache[reply_to_iid]["anon_name"]
        else:
            d["reply_to_anon_name"] = ""
        d["reply_to_identity_id"] = reply_to_iid

        # 点赞数 + 是否已赞
        d["like_count"] = conn.execute(
            "SELECT COUNT(*) as cnt FROM treehole_reply_likes WHERE reply_id = ?",
            (rid,),
        ).fetchone()["cnt"]
        if viewer_id:
            liked = conn.execute(
                "SELECT id FROM treehole_reply_likes WHERE reply_id = ? AND user_id = ?",
                (rid, viewer_id),
            ).fetchone()
            d["liked"] = liked is not None
        else:
            d["liked"] = False

        d["replies"] = []
        all_replies[rid] = d

    # 构建线程树
    root_replies = []
    for rid, r in all_replies.items():
        parent_id = r.get("parent_reply_id")
        root_id = r.get("root_reply_id")
        target_id = root_id if root_id else parent_id
        if target_id and target_id in all_replies:
            all_replies[target_id]["replies"].append(r)
        else:
            root_replies.append(r)

    conn.close()
    return root_replies


def get_treehole_reply_by_id(reply_id: int) -> dict | None:
    """获取单条树洞回复（含 user_id，内部用）"""
    conn = get_connection()
    row = conn.execute(
        "SELECT id, diary_id, user_id, content, created_at FROM treehole_replies WHERE id = ?",
        (reply_id,),
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def save_treehole_reply_like(reply_id: int, user_id: int) -> tuple[bool, bool]:
    """点赞树洞回复。返回 (success, already_liked)"""
    conn = get_connection()
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        conn.execute(
            "INSERT INTO treehole_reply_likes (reply_id, user_id, created_at) VALUES (?, ?, ?)",
            (reply_id, user_id, created_at),
        )
        conn.commit()
        success, already = True, False
    except Exception:
        success, already = True, True
    conn.close()
    return success, already


def remove_treehole_reply_like(reply_id: int, user_id: int) -> bool:
    """取消点赞树洞回复"""
    conn = get_connection()
    conn.execute(
        "DELETE FROM treehole_reply_likes WHERE reply_id = ? AND user_id = ?",
        (reply_id, user_id),
    )
    affected = conn.total_changes
    conn.commit()
    conn.close()
    return affected > 0


def count_treehole_reply_likes(reply_id: int) -> int:
    """获取树洞回复点赞数"""
    conn = get_connection()
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM treehole_reply_likes WHERE reply_id = ?",
        (reply_id,),
    ).fetchone()
    conn.close()
    return row["cnt"] if row else 0


def has_liked_treehole_reply(reply_id: int, user_id: int) -> bool:
    """检查用户是否已点赞某条树洞回复"""
    if not user_id:
        return False
    conn = get_connection()
    row = conn.execute(
        "SELECT id FROM treehole_reply_likes WHERE reply_id = ? AND user_id = ?",
        (reply_id, user_id),
    ).fetchone()
    conn.close()
    return row is not None


def save_treehole_hug(diary_id: int, user_id: int) -> tuple[bool, bool]:
    """记录树洞抱抱。返回 (success, already_hugged)"""
    conn = get_connection()
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        conn.execute(
            "INSERT INTO treehole_hugs (diary_id, user_id, created_at) VALUES (?, ?, ?)",
            (diary_id, user_id, created_at),
        )
        conn.commit()
        success, already = True, False
    except Exception:
        success, already = True, True
    conn.close()
    return success, already


def remove_treehole_hug(diary_id: int, user_id: int) -> bool:
    """取消树洞抱抱，返回是否确实删除了记录"""
    conn = get_connection()
    conn.execute(
        "DELETE FROM treehole_hugs WHERE diary_id = ? AND user_id = ?",
        (diary_id, user_id),
    )
    affected = conn.total_changes
    conn.commit()
    conn.close()
    return affected > 0


def decrement_hug_count(diary_id: int) -> int:
    """抱抱计数 -1（不低于 0），返回新的 hug_count"""
    conn = get_connection()
    conn.execute(
        "UPDATE diaries SET hug_count = MAX(0, hug_count - 1) WHERE id = ?",
        (diary_id,),
    )
    conn.commit()
    new_count = conn.execute("SELECT hug_count FROM diaries WHERE id = ?", (diary_id,)).fetchone()
    conn.close()
    return new_count["hug_count"] if new_count else 0


def get_treehole_owner_id(treehole_id: int) -> int | None:
    """获取树洞日记作者 id"""
    return get_diary_owner_id(treehole_id)
