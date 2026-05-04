"""演示数据生成（仅开发环境）"""

import os, random
from datetime import datetime, timedelta

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from database import (
    get_connection, get_user_by_username, create_user,
    save_diary_to_db, get_user_by_id,
    follow_user as db_follow, is_following,
    like_public_diary as db_like,
    add_public_diary_comment as db_add_comment,
    create_notification,
    create_greet_request, update_greet_status,
    get_or_create_conversation,
    get_blocked_user_ids,
)

router = APIRouter(prefix="/api/dev", tags=["开发工具"])


def _guard():
    if os.environ.get("ENVIRONMENT") != "development":
        raise HTTPException(status_code=403, detail="仅在开发环境可用")


# ---- bcrypt hash ----
def _hash_password(password: str) -> str:
    from passlib.context import CryptContext
    return CryptContext(schemes=["bcrypt"], deprecated="auto").hash(password)


def _now() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _date_str(days_ago: int = 0) -> str:
    d = datetime.now() - timedelta(days=days_ago)
    return d.strftime("%Y-%m-%d %H:%M:%S")


def _ensure_user(username: str, password: str, nickname: str, avatar: str, bio: str, interests: str) -> dict:
    """创建或更新用户，返回用户 dict"""
    user = get_user_by_username(username)
    if user:
        conn = get_connection()
        now = _now()
        conn.execute(
            "UPDATE users SET password_hash=?, nickname=?, avatar=?, bio=?, interests=?, updated_at=? WHERE id=?",
            (_hash_password(password), nickname, avatar, bio, interests, now, user["id"]),
        )
        conn.commit()
        conn.close()
        return get_user_by_username(username)
    else:
        return create_user(username, _hash_password(password))


def _find_public_diaries_of(user_id: int) -> list:
    """获取用户的公开日记 ID 列表（仅 content_type='diary'）"""
    conn = get_connection()
    rows = conn.execute(
        "SELECT id FROM diaries WHERE user_id=? AND content_type='diary' AND is_public=1 AND (unlock_date IS NULL OR unlock_date='')",
        (user_id,),
    ).fetchall()
    conn.close()
    return [r["id"] for r in rows]


def _find_any_diary_of(user_id: int) -> int | None:
    """获取用户任意一篇日记 ID"""
    conn = get_connection()
    row = conn.execute(
        "SELECT id FROM diaries WHERE user_id=? LIMIT 1",
        (user_id,),
    ).fetchone()
    conn.close()
    return row["id"] if row else None


def _find_comment_on(diary_id: int) -> int | None:
    """获取某日记的一条评论 ID"""
    conn = get_connection()
    row = conn.execute(
        "SELECT id FROM public_diary_comments WHERE diary_id=? LIMIT 1",
        (diary_id,),
    ).fetchone()
    conn.close()
    return row["id"] if row else None


def _find_conv_between(u1: int, u2: int) -> int | None:
    """查找两人之间的会话 ID"""
    conn = get_connection()
    a, b = (u1, u2) if u1 < u2 else (u2, u1)
    row = conn.execute(
        "SELECT id FROM conversations WHERE user1_id=? AND user2_id=?",
        (a, b),
    ).fetchone()
    conn.close()
    return row["id"] if row else None


def _insert_msg(conv_id: int, sender_id: int, receiver_id: int, content: str, created_at: str, is_read: int = 0):
    conn = get_connection()
    conn.execute(
        "INSERT INTO private_messages (conversation_id, sender_id, receiver_id, content, is_read, created_at) VALUES (?,?,?,?,?,?)",
        (conv_id, sender_id, receiver_id, content, is_read, created_at),
    )
    conn.execute("UPDATE conversations SET last_message=?, last_message_at=?, updated_at=? WHERE id=?",
                 (content, created_at, created_at, conv_id))
    conn.commit()
    conn.close()


def _insert_block(blocker_id: int, blocked_id: int, reason: str = ""):
    conn = get_connection()
    now = _now()
    try:
        conn.execute(
            "INSERT INTO user_blocks (blocker_id, blocked_id, reason, created_at) VALUES (?,?,?,?)",
            (blocker_id, blocked_id, reason, now),
        )
        conn.commit()
    except Exception:
        pass
    conn.close()


def _insert_report(reporter_id: int, target_type: str, target_id: int,
                   target_user_id: int | None, reason: str, description: str = ""):
    conn = get_connection()
    now = _now()
    conn.execute(
        "INSERT INTO reports (reporter_id, target_type, target_id, target_user_id, reason, description, status, created_at) VALUES (?,?,?,?,?,?,'pending',?)",
        (reporter_id, target_type, target_id, target_user_id, reason, description, now),
    )
    conn.commit()
    conn.close()


DIARY_TEMPLATES = {
    "echo_1": [
        {"mood": "😊", "content": "今天下班路上买了一束洋桔梗，看着花开心情突然就好了起来。", "ai_summary": "洋桔梗的小确幸", "ai_message": "生活里的小美好总是藏在细节里，能发现它们的人，心底一定很柔软吧。", "tags": "生活,小确幸", "is_public": True},
        {"mood": "😫", "content": "连续加了一个星期的班，感觉身体被掏空，有没有人能给我个拥抱呀...", "ai_summary": "加班疲惫", "ai_message": "辛苦了，你的付出都被看在眼里。但别忘了，身体才是最重要的，今晚早点休息吧。", "tags": "工作,疲惫", "is_public": True},
        {"mood": "😢", "content": "今天和妈妈打了两个小时的电话，突然很想家。离家这么远，有时候真的好孤独。", "ai_summary": "想家的时刻", "ai_message": "想念家人的心情是柔软的。距离让我们更懂得珍惜，下次回家的拥抱一定格外温暖。", "tags": "家人,孤独", "is_public": False},
        {"mood": "😊", "content": "终于把拖延了很久的项目交差了！今晚要奖励自己看一部电影加一包薯片！", "ai_summary": "项目交差的放松时刻", "ai_message": "那种如释重负的感觉真的太棒了！你值得这份奖励，好好享受今晚的放松时光吧～", "tags": "成就,放松", "is_public": True},
        {"mood": "🥰", "content": "昨天做的蛋糕被同事们夸奖了，说我很有天赋！突然想开始认真学烘焙。", "ai_summary": "烘焙初体验", "ai_message": "发现新爱好是一件多么美好的事情！说不定烘焙会成为你新的放松方式呢。", "tags": "烘焙,幸福", "is_public": False},
    ],
    "alice": [
        {"mood": "🥰", "content": "周末去了那家新开的猫咖，一只橘猫在我腿上睡着了，整个下午都不舍得动。", "ai_summary": "猫咖的治愈时光", "ai_message": "小动物总是能读懂人的心情。被一只猫信任的感觉，大概是世界上最温柔的体验了。", "tags": "猫咖,治愈", "is_public": True},
        {"mood": "😊", "content": "今天读完了《追忆似水年华》的第一卷，虽然进度很慢，但每一页都值得。", "ai_summary": "阅读时光", "ai_message": "好书就像陈年好酒，慢慢品才是真正的享受。不必追赶进度，享受阅读本身就好。", "tags": "阅读,文学", "is_public": True},
        {"mood": "😫", "content": "这个月的KPI压力好大，做梦都在做汇报。明天要早起再改一版PPT。", "ai_summary": "KPI焦虑", "ai_message": "压力大的时候记得深呼吸，你已经做得很好了。有时候适当放松反而效率更高。", "tags": "工作,焦虑", "is_public": False},
        {"mood": "😊", "content": "傍晚散步看到了一场绝美的日落，整个天空都是粉橙色的。用手机拍了几张，有一张特别喜欢。", "ai_summary": "日落时分", "ai_message": "大自然的治愈力是无穷的。那些不经意间看到的美景，往往是生活给我们最好的礼物。", "tags": "自然,日落", "is_public": True},
    ],
    "bob": [
        {"mood": "😊", "content": "今天跑了人生第一个 5 公里！虽然很慢，但是坚持到了最后，感觉超级有成就感。", "ai_summary": "首次5公里", "ai_message": "从零到一永远是最难的一步，你已经迈出去了！接下来就是不断超越自己。", "tags": "运动,跑步", "is_public": True},
        {"mood": "😢", "content": "最近在学吉他，手指好疼啊。F和弦总是按不住，有点想放弃了...", "ai_summary": "吉他练习困难", "ai_message": "每个吉他手都经历过这个阶段！手上的茧是努力的勋章，坚持下去你会感谢现在的自己。", "tags": "音乐,学习", "is_public": True},
        {"mood": "😊", "content": "今天终于把简历改好了，投了五家公司。希望有回音，哪怕一个面试都好。", "ai_summary": "求职准备", "ai_message": "机会总是留给有准备的人。你已经准备好了，剩下的就交给时间吧。", "tags": "求职,成长", "is_public": False},
        {"mood": "🥰", "content": "和一个很久没联系的朋友重新联系上了，聊了一个多小时，感觉特别好。友情是需要经营的呀。", "ai_summary": "重连老友", "ai_message": "真正的友谊不会因为时间而褪色。主动联系的那一方，往往就是最珍惜这段关系的人。", "tags": "友情,温暖", "is_public": True},
    ],
    "charlie": [
        {"mood": "😊", "content": "凌晨三点爬起来拍星空，郊区光污染少，第一次看到了银河。那种震撼无法用语言形容。", "ai_summary": "拍摄银河", "ai_message": "在浩瀚的星空面前，所有的烦恼都变得渺小。记得保存好这张照片，它是你和宇宙的对话。", "tags": "摄影,星空", "is_public": True},
        {"mood": "😫", "content": "又是一天的加班，回到家里什么都不想动。这样的生活还要持续多久...", "ai_summary": "加班后的疲惫", "ai_message": "有时候疲惫不是因为做了太多，而是没有得到足够的滋养。给自己放个假吧，哪怕是半天也好。", "tags": "工作,疲惫", "is_public": True},
        {"mood": "😢", "content": "楼下那家常去的面馆要关门了，老板说要回老家。城市总是在变，熟悉的东西越来越少。", "ai_summary": "城市变迁", "ai_message": "城市确实一直在变，但那些温暖的记忆永远留在心里。也许下一个街角会有新的惊喜呢。", "tags": "城市,离别", "is_public": False},
        {"mood": "🥰", "content": "今天在地铁上看到一个老爷爷给老奶奶系鞋带，那画面太美好了。长久的爱大概就是这样吧。", "ai_summary": "地铁上的浪漫", "ai_message": "最动人的浪漫往往藏在平凡的生活里。能注意到这种美好的人，内心一定特别温柔。", "tags": "日常,感动", "is_public": True},
        {"mood": "😊", "content": "买了一台胶片机，第一卷拍出来有一半都糊了，但那种等待冲洗的期待感是数码给不了的。", "ai_summary": "胶片初体验", "ai_message": "慢下来反而让每一张照片都有了故事。胶片的魅力就在于不完美中的完美。", "tags": "摄影,胶片", "is_public": True},
    ],
}

CAPSULE_DATA = {
    "echo_1": [
        {"mood": "😊", "content": "写给六个月后的自己：希望你已经找到了更好的工作，不再那么焦虑了。", "ai_summary": "给未来的信", "tags": "未来,期望", "days_ahead": 180},
    ],
    "alice": [
        {"mood": "🥰", "content": "一年后的 Alice，你现在在哪里旅行呢？是不是已经去了心心念念的冰岛？", "ai_summary": "旅行期望", "tags": "未来,旅行", "days_ahead": 365},
    ],
    "bob": [
        {"mood": "😊", "content": "三个月后，你应该已经能弹一首完整的曲子了吧？坚持住啊！", "ai_summary": "吉他目标", "tags": "音乐,目标", "days_ahead": 90},
    ],
    "charlie": [
        {"mood": "😊", "content": "半年后，希望你的摄影作品能被更多人看到。继续拍下去。", "ai_summary": "摄影目标", "tags": "摄影,期望", "days_ahead": 182},
    ],
}

# 已解锁胶囊（过去日期）
UNLOCKED_CAPSULES = {
    "echo_1": {"mood": "🥰", "content": "上个月的自己：那个项目最后通过了！你的努力没有白费。", "ai_summary": "项目通过回顾", "tags": "回顾,成就", "days_ago": 5},
    "alice": {"mood": "😊", "content": "两周前种的多肉发芽了！小小的绿色生命让人心情好好。", "ai_summary": "多肉发芽", "tags": "植物,惊喜", "days_ago": 14},
    "bob": {"mood": "😊", "content": "三个月前还完全不会跑步，现在居然能跑3公里了。进步这种东西都是悄悄发生的。", "ai_summary": "跑步进步", "tags": "运动,成长", "days_ago": 3},
    "charlie": {"mood": "🥰", "content": "一个月前拍的那组雨夜街景被朋友夸了很久，看来摄影真的有在进步。", "ai_summary": "摄影进步", "tags": "摄影,成长", "days_ago": 7},
}


@router.post("/seed-demo")
async def seed_demo():
    _guard()

    summary = {}

    # ===== 1. 创建演示用户 =====
    users_def = [
        ("echo_1", "password123", "小兔", "🐰", "今天也在认真生活", "日记,生活,小确幸"),
        ("alice", "password123", "Alice", "🌸", "喜欢记录生活里的温柔瞬间", "旅行,阅读,日记,咖啡"),
        ("bob", "password123", "Bob", "🐻", "正在学习如何更好地表达自己", "学习,运动,音乐,成长"),
        ("charlie", "password123", "Charlie", "🦊", "喜欢观察城市和夜晚", "摄影,城市,夜晚,随笔"),
    ]
    user_map = {}
    for uname, pwd, nick, av, bio, interests in users_def:
        user = _ensure_user(uname, pwd, nick, av, bio, interests)
        user_map[uname] = user
    summary["users"] = len(user_map)

    # ===== 2. 创建日记 =====
    total_diaries = 0
    for uname, templates in DIARY_TEMPLATES.items():
        uid = user_map[uname]["id"]
        for i, t in enumerate(templates):
            days_ago = len(templates) - i + random.randint(0, 3)
            created_at = _date_str(days_ago)
            conn = get_connection()
            cursor = conn.execute(
                """INSERT INTO diaries (created_at, mood, content, ai_summary, ai_message, tags, is_public, user_id, content_type)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'diary')""",
                (created_at, t["mood"], t["content"], t["ai_summary"], t["ai_message"], t["tags"], int(t["is_public"]), uid),
            )
            conn.commit()
            conn.close()
            total_diaries += 1
    summary["diaries"] = total_diaries

    # ===== 3. 创建时光胶囊 =====
    total_capsules = 0
    for uname, capsules in CAPSULE_DATA.items():
        uid = user_map[uname]["id"]
        for c in capsules:
            unlock_date = (datetime.now() + timedelta(days=c["days_ahead"])).strftime("%Y-%m-%d")
            conn = get_connection()
            conn.execute(
                """INSERT INTO diaries (created_at, mood, content, ai_summary, ai_message, tags, is_public, unlock_date, user_id, content_type)
                   VALUES (?, ?, ?, ?, '', ?, 0, ?, ?, 'capsule')""",
                (_date_str(random.randint(1, 7)), c["mood"], c["content"], c["ai_summary"], c["tags"], unlock_date, uid),
            )
            conn.commit()
            conn.close()
            total_capsules += 1
    for uname, c in UNLOCKED_CAPSULES.items():
        uid = user_map[uname]["id"]
        unlock_date = (datetime.now() - timedelta(days=c["days_ago"])).strftime("%Y-%m-%d")
        conn = get_connection()
        conn.execute(
            """INSERT INTO diaries (created_at, mood, content, ai_summary, ai_message, tags, is_public, unlock_date, user_id, content_type)
               VALUES (?, ?, ?, ?, '', ?, 0, ?, ?, 'capsule')""",
            (_date_str(c["days_ago"] + random.randint(1, 5)), c["mood"], c["content"], c["ai_summary"], c["tags"], unlock_date, uid),
        )
        conn.commit()
        conn.close()
        total_capsules += 1
    summary["capsules"] = total_capsules

    # ===== 4. 创建关注关系 =====
    id_echo = user_map["echo_1"]["id"]
    id_alice = user_map["alice"]["id"]
    id_bob = user_map["bob"]["id"]
    id_charlie = user_map["charlie"]["id"]

    follows = [
        (id_alice, id_echo),
        (id_bob, id_echo),
        (id_echo, id_alice),
        (id_charlie, id_alice),
    ]
    total_follows = 0
    for fid, tid in follows:
        if db_follow(fid, tid):
            total_follows += 1
            # 关注通知
            create_notification(tid, fid, "follow", "user", fid,
                              "新的关注", f"关注了你")
    summary["follows"] = total_follows

    # ===== 5. 公开日记互动 =====
    echo_public = _find_public_diaries_of(id_echo)
    alice_public = _find_public_diaries_of(id_alice)

    total_likes = 0
    total_comments = 0
    total_notifications = 0

    # Alice 点亮 小兔 的公开日记
    if echo_public:
        for did in echo_public[:2]:
            conn = get_connection()
            try:
                conn.execute(
                    "INSERT INTO public_diary_likes (diary_id, client_id, created_at) VALUES (?,?,?)",
                    (did, f"seed_alice_{did}", _now()),
                )
                conn.commit()
                total_likes += 1
                create_notification(id_echo, id_alice, "public_diary_like", "diary", did,
                                  "新的点亮", "有人点亮了你的公开日记")
                total_notifications += 1
            except Exception:
                pass
            conn.close()

    # Bob 评论 小兔 的公开日记
    if echo_public:
        bob_comments = ["这条日记好温柔", "我也有类似的感觉"]
        for i, did in enumerate(echo_public[:2]):
            if i < len(bob_comments):
                db_add_comment(did, f"seed_bob_{did}", bob_comments[i])
                total_comments += 1
                create_notification(id_echo, id_bob, "public_diary_comment", "diary", did,
                                  "新的评论", bob_comments[i])
                total_notifications += 1

    # 小兔 评论 Alice 的公开日记
    if alice_public:
        db_add_comment(alice_public[0], f"seed_echo_{alice_public[0]}", "看到这里突然被治愈了")
        total_comments += 1
        create_notification(id_alice, id_echo, "public_diary_comment", "diary", alice_public[0],
                          "新的评论", "看到这里突然被治愈了")
        total_notifications += 1

    # Bob 点亮 Alice 的公开日记
    if alice_public:
        for did in alice_public[:1]:
            conn = get_connection()
            try:
                conn.execute(
                    "INSERT INTO public_diary_likes (diary_id, client_id, created_at) VALUES (?,?,?)",
                    (did, f"seed_bob2_{did}", _now()),
                )
                conn.commit()
                total_likes += 1
                create_notification(id_alice, id_bob, "public_diary_like", "diary", did,
                                  "新的点亮", "有人点亮了你的公开日记")
                total_notifications += 1
            except Exception:
                pass
            conn.close()

    summary["likes"] = total_likes
    summary["comments"] = total_comments

    # ===== 6. 打招呼数据 =====
    total_greets = 0
    # Alice 向 小兔 发起 pending 打招呼
    greet_id = create_greet_request(id_alice, id_echo, "你好呀小兔，我特别喜欢你的日记，希望能认识你～")
    if greet_id:
        total_greets += 1
        create_notification(id_echo, id_alice, "greet", "greet", greet_id,
                          "新的打招呼", "你好呀小兔，我特别喜欢你的日记，希望能认识你～")
        total_notifications += 1

    # Bob 和 小兔 accepted
    greet_id2 = create_greet_request(id_bob, id_echo, "你好，我看到了你的日记，感觉很有共鸣。")
    if greet_id2:
        total_greets += 1
        update_greet_status(greet_id2, "accepted")
        create_notification(id_echo, id_bob, "greet", "greet", greet_id2,
                          "新的打招呼", "你好，我看到了你的日记，感觉很有共鸣。")
        total_notifications += 1

    # Charlie 向 Alice rejected
    greet_id3 = create_greet_request(id_charlie, id_alice, "Hi Alice, 你的摄影作品很棒")
    if greet_id3:
        total_greets += 1
        update_greet_status(greet_id3, "rejected")

    summary["greet_requests"] = total_greets

    # ===== 7. 私信数据 =====
    # Bob 和 小兔 之间有 conversation
    conv = get_or_create_conversation(id_bob, id_echo)
    total_msgs = 0
    if conv:
        conv_id = conv["id"]
        msg_data = [
            (id_bob, id_echo, "你好，我看到了你的日记，感觉很有共鸣。", _date_str(3), 1),
            (id_echo, id_bob, "谢谢你愿意读到这里。", _date_str(2), 1),
            (id_bob, id_echo, "以后也想多看看你的记录。", _date_str(1), 0),
        ]
        for sid, rid, content, cat, ir in msg_data:
            _insert_msg(conv_id, sid, rid, content, cat, ir)
            total_msgs += 1
    summary["conversations"] = 1 if conv else 0
    summary["messages"] = total_msgs

    # ===== 8. 拉黑和举报 =====
    _insert_block(id_echo, id_charlie, "测试拉黑")
    summary["blocks"] = 1

    # 小兔 举报 Charlie
    _insert_report(id_echo, "user", id_charlie, id_charlie, "harassment", "这个用户不停发骚扰信息")
    # Alice 举报一篇公开日记
    if echo_public:
        _insert_report(id_alice, "diary", echo_public[0], id_echo, "spam", "怀疑是广告内容")
    summary["reports"] = 2

    summary["notifications"] = total_notifications

    return {"ok": True, **summary}
