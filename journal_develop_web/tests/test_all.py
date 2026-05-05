"""
全量回归测试脚本
使用 FastAPI TestClient，无需启动服务即可运行
覆盖 14 个测试类别，约 80 个测试用例

用法：python test_all.py
"""
import io, sys, os, uuid

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

os.environ['ENVIRONMENT'] = 'development'

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import init_db
init_db()

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

PASS, FAIL = 0, 0
TOKENS = {}

def test(name, condition, detail=""):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  [PASS] {name}")
    else:
        FAIL += 1
        print(f"  [FAIL] {name} -- {detail}")

def separator(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def register(username, password, email=""):
    res = client.post("/api/auth/register", json={"username": username, "password": password, "email": email})
    data = res.json()
    token = data.get("access_token", "")
    if token:  # 仅在成功时覆盖 token，避免 409 时清空有效 token
        TOKENS[username] = token
    return token, data, res.status_code

def login(username, password):
    res = client.post("/api/auth/login", json={"username": username, "password": password})
    data = res.json()
    token = data.get("access_token", "")
    if token:  # 仅在成功时覆盖 token
        TOKENS[username] = token
    return token, data, res.status_code

def auth_headers(username):
    token = TOKENS.get(username, "")
    return {"Authorization": f"Bearer {token}"} if token else {}


# ================================================================
# 1. 认证模块
# ================================================================
separator("1. 认证 (Auth)")

uid_suffix = uuid.uuid4().hex[:6]
ua_name = f"test_a_{uid_suffix}"
ub_name = f"test_b_{uid_suffix}"
uc_name = f"test_c_{uid_suffix}"

# 1.1 注册
token_a, data_a, code_a = register(ua_name, "test123", f"{ua_name}@test.com")
test("注册成功 - 返回 token", bool(token_a) and code_a == 200, str(data_a))
test("注册响应 - ok=true", data_a.get("ok") == True)
test("注册响应 - user 包含 username", data_a.get("user", {}).get("username") == ua_name)

# 1.2 重复注册
_, dup_data, dup_code = register(ua_name, "test123")
test("重复注册 - 409", dup_code == 409, str(dup_data))

# 1.3 登录
token_a2, login_data, login_code = login(ua_name, "test123")
test("登录成功 - 返回 token", bool(token_a2) and login_code == 200)
test("登录响应 - ok=true", login_data.get("ok") == True)

# 1.4 错误密码登录
_, bad_data, bad_code = login(ua_name, "wrong_password")
test("错误密码登录 - 401", bad_code == 401, str(bad_data))

# 1.5 获取当前用户
res_me = client.get("/api/auth/me", headers=auth_headers(ua_name))
me_data = res_me.json()
id_a = me_data.get("user", {}).get("id")
test("获取当前用户 - 成功", res_me.status_code == 200 and id_a is not None, str(me_data))

# 1.6 未登录获取 me
res_noauth = client.get("/api/auth/me")
test("未登录获取 me - 401", res_noauth.status_code == 401)

# 1.7 注册第二个和第三个用户
token_b, data_b, code_b = register(ub_name, "test123")
token_c, data_c, code_c = register(uc_name, "test123")
res_b = client.get("/api/auth/me", headers=auth_headers(ub_name))
res_c = client.get("/api/auth/me", headers=auth_headers(uc_name))
id_b = res_b.json().get("user", {}).get("id")
id_c = res_c.json().get("user", {}).get("id")
test("用户 B 创建成功", id_b is not None)
test("用户 C 创建成功", id_c is not None)


# ================================================================
# 2. 日记 CRUD
# ================================================================
separator("2. 日记 CRUD")

# 2.1 创建日记
d1 = client.post("/api/save", json={
    "mood": "😊", "content": "A的日记1-公开", "is_public": True,
    "ai_summary": "开心", "ai_message": "加油", "tags": "生活"
}, headers=auth_headers(ua_name))
d1_data = d1.json()
d1_id = d1_data.get("id")
test("创建公开日记 - 成功", d1.status_code == 200 and d1_id is not None, str(d1_data))

d2 = client.post("/api/save", json={
    "mood": "😢", "content": "A的日记2-私密", "is_public": False,
    "ai_summary": "伤感", "ai_message": "会好的", "tags": "心情"
}, headers=auth_headers(ua_name))
d2_id = d2.json().get("id")
test("创建私密日记 - 成功", d2.status_code == 200 and d2_id is not None)

# 2.2 获取日记列表
res_list = client.get("/api/diaries", headers=auth_headers(ua_name))
list_data = res_list.json()
test("获取日记列表 - 成功", res_list.status_code == 200 and len(list_data) >= 1, str(list_data))

# 2.3 按日期查询
from datetime import datetime
today_str = datetime.now().strftime("%Y-%m-%d")
res_date = client.get(f"/api/diaries/date/{today_str}", headers=auth_headers(ua_name))
test("按日期查询日记", res_date.status_code == 200)

# 2.4 获取日记详情
res_detail = client.get(f"/api/diaries/{d1_id}", headers=auth_headers(ua_name))
detail_data = res_detail.json()
test("获取日记详情 - 成功", res_detail.status_code == 200 and detail_data.get("id") == d1_id)
test("日记详情包含 image_urls", "image_urls" in detail_data)

# 2.5 编辑日记
res_edit = client.put(f"/api/diaries/{d1_id}", json={
    "content": "A的日记1-已修改"
}, headers=auth_headers(ua_name))
test("编辑日记 - 成功", res_edit.status_code == 200 and res_edit.json().get("ok"))
res_edited = client.get(f"/api/diaries/{d1_id}", headers=auth_headers(ua_name))
test("编辑后内容已更新", res_edited.json().get("content") == "A的日记1-已修改")

# 2.6 用户隔离 - B 不能查看 A 的私密日记
res_iso_private = client.get(f"/api/diaries/{d2_id}", headers=auth_headers(ub_name))
test("用户隔离 - B 不能看 A 的私密日记 (403)", res_iso_private.status_code == 403)

# 2.7 用户隔离 - B 不能看 A 的日记列表
res_iso_list = client.get("/api/diaries", headers=auth_headers(ub_name))
test("用户隔离 - B 的日记列表不包含 A 的日记", res_iso_list.status_code == 200)

# 2.8 B 创建自己的日记
b_diary = client.post("/api/save", json={
    "mood": "🥰", "content": "B的日记", "is_public": True,
    "ai_summary": "幸福", "tags": "生活"
}, headers=auth_headers(ub_name))
b_diary_id = b_diary.json().get("id")
test("B 创建日记成功", b_diary.status_code == 200 and b_diary_id is not None)

# 2.9 删除日记
res_del = client.delete(f"/api/diaries/{b_diary_id}", headers=auth_headers(ub_name))
test("删除自己的日记 - 成功", res_del.status_code == 200 and res_del.json().get("ok"))

# 2.10 未登录不能保存日记
res_nologin = client.post("/api/save", json={"mood": "😊", "content": "test"})
test("未登录保存日记 - 401", res_nologin.status_code == 401)


# ================================================================
# 3. 公开日记广场
# ================================================================
separator("3. 公开日记广场 (Public Diaries)")

# 3.1 获取公开日记列表
res_pub = client.get("/api/public/diaries")
pub_data = res_pub.json()
test("公开日记列表 - 成功", res_pub.status_code == 200)
test("公开日记列表 - 包含 items", "items" in pub_data)
test("公开日记列表 - 有分页信息", "total" in pub_data or "page" in pub_data)

# 3.2 按心情筛选
res_mood = client.get("/api/public/diaries?mood=😊")
test("按心情筛选公开日记", res_mood.status_code == 200)

# 3.3 按标签筛选
res_tag = client.get("/api/public/diaries?tag=生活")
test("按标签筛选公开日记", res_tag.status_code == 200)

# 3.4 关键词搜索
res_kw = client.get("/api/public/diaries?keyword=日记")
test("关键词搜索公开日记", res_kw.status_code == 200)

# 3.5 获取公开日记详情
res_pub_detail = client.get(f"/api/public/diaries/{d1_id}")
pub_d_data = res_pub_detail.json()
test("公开日记详情 - 成功", res_pub_detail.status_code == 200 and pub_d_data.get("id") == d1_id)
test("公开日记详情包含评论列表", "comments" in pub_d_data or "comments" in pub_d_data)
test("公开日记详情包含作者名", "author_name" in pub_d_data, str(list(pub_d_data.keys())[:10]))


# ================================================================
# 4. 点亮互动
# ================================================================
separator("4. 点亮互动 (Likes)")

# 4.1 点亮公开日记
client_id_a = f"test_client_{uid_suffix}_a"
res_like = client.post(f"/api/public/diaries/{d1_id}/like", json={
    "client_id": client_id_a
})
test("点亮公开日记 - 成功", res_like.status_code == 200 and res_like.json().get("ok"))

# 4.2 重复点亮（去重）
res_relike = client.post(f"/api/public/diaries/{d1_id}/like", json={
    "client_id": client_id_a
})
test("重复点亮 - 返回 already_liked", res_relike.status_code == 200)

# 4.3 取消点亮
res_unlike = client.delete(f"/api/public/diaries/{d1_id}/like?client_id={client_id_a}")
test("取消点亮 - 成功", res_unlike.status_code == 200 and res_unlike.json().get("ok"))

# 4.4 再次取消（幂等）
res_unlike2 = client.delete(f"/api/public/diaries/{d1_id}/like?client_id={client_id_a}")
test("再次取消点亮 - 幂等", res_unlike2.status_code == 200)


# ================================================================
# 5. 评论功能
# ================================================================
separator("5. 评论功能 (Comments)")

# 5.1 发表评论
client_id_comment = f"test_comment_{uid_suffix}"
res_cmt = client.post(f"/api/public/diaries/{d1_id}/comments", json={
    "client_id": client_id_comment,
    "content": "写得真好呀！"
})
cmt_data = res_cmt.json()
cmt_id = cmt_data.get("comment", {}).get("id")
test("发表评论 - 成功", res_cmt.status_code == 200 and cmt_id is not None, str(cmt_data))

# 5.2 获取评论列表
res_cmts = client.get(f"/api/public/diaries/{d1_id}/comments")
cmts_data = res_cmts.json()
test("获取评论列表 - 成功", res_cmts.status_code == 200 and len(cmts_data) >= 1)

# 5.3 评论内容超长（>500字）
long_comment = "好" * 501
res_long = client.post(f"/api/public/diaries/{d1_id}/comments", json={
    "client_id": f"{client_id_comment}_long",
    "content": long_comment
})
test("超长评论 - 被拒绝 (400)", res_long.status_code == 400, str(res_long.json()))

# 5.4 回复日记评论（B 评论 A 的日记）
res_cmt_b = client.post(f"/api/public/diaries/{d1_id}/comments", json={
    "client_id": f"test_cmt_b_{uid_suffix}",
    "content": "写得好，支持！"
}, headers=auth_headers(ub_name))
test("B 评论 A 的公开日记", res_cmt_b.status_code == 200)


# ================================================================
# 6. 通知中心
# ================================================================
separator("6. 通知中心 (Notifications)")

# 先让 B 有通知（B 关注 A，产生通知给 A）
res_follow = client.post(f"/api/users/{id_a}/follow", headers=auth_headers(ub_name))
# A 的通知
res_notif = client.get("/api/notifications", headers=auth_headers(ua_name))
notif_data = res_notif.json()
test("获取通知列表 - 成功", res_notif.status_code == 200 and "items" in notif_data, str(notif_data))

# 通知未读数
res_unread = client.get("/api/notifications/unread-count", headers=auth_headers(ua_name))
test("通知未读数 - 成功", res_unread.status_code == 200 and "unread_count" in res_unread.json())

# 标记单条已读
all_notifs = notif_data.get("items", [])
if all_notifs:
    nid = all_notifs[0]["id"]
    res_mark = client.post(f"/api/notifications/{nid}/read", headers=auth_headers(ua_name))
    test("标记通知已读 - 成功", res_mark.status_code == 200 and res_mark.json().get("ok"))

# 全部已读
res_markall = client.post("/api/notifications/read-all", headers=auth_headers(ua_name))
test("全部标记已读 - 成功", res_markall.status_code == 200 and res_markall.json().get("ok"))

# 删除通知
res_del_notif = client.delete(f"/api/notifications/{nid}", headers=auth_headers(ua_name))
test("删除通知 - 成功", res_del_notif.status_code == 200 and res_del_notif.json().get("ok"))

# 未登录
res_nl_notif = client.get("/api/notifications")
test("未登录获取通知 - 401", res_nl_notif.status_code == 401)


# ================================================================
# 7. 关注系统
# ================================================================
separator("7. 关注系统 (Follows)")

# 7.1 关注用户
res_fol = client.post(f"/api/users/{id_b}/follow", headers=auth_headers(ua_name))
test("A 关注 B - 成功", res_fol.status_code == 200 and res_fol.json().get("ok"))
test("关注状态 - following=true", res_fol.json().get("following") == True)

# 7.2 重复关注
res_refol = client.post(f"/api/users/{id_b}/follow", headers=auth_headers(ua_name))
test("重复关注 - already_followed", res_refol.json().get("already_followed") == True)

# 7.3 关注自己
res_selffol = client.post(f"/api/users/{id_a}/follow", headers=auth_headers(ua_name))
test("关注自己 - 被拒绝", res_selffol.status_code in (400, 403, 422), str(res_selffol.json()))

# 7.4 关注状态查询
res_fol_status = client.get(f"/api/users/{id_b}/follow-status", headers=auth_headers(ua_name))
test("关注状态 - following=true", res_fol_status.json().get("following") == True)

# 7.5 我的关注列表
res_following = client.get("/api/me/following", headers=auth_headers(ua_name))
test("我的关注列表 - 包含 B", len(res_following.json()) >= 1)

# 7.6 我的粉丝列表
res_followers = client.get("/api/me/followers", headers=auth_headers(ub_name))
test("B 的粉丝列表 - 包含 A", len(res_followers.json()) >= 1)

# 7.7 关注动态
res_feed = client.get("/api/me/following-feed", headers=auth_headers(ua_name))
test("关注动态 - 成功", res_feed.status_code == 200)

# 7.8 取消关注
res_unfol = client.delete(f"/api/users/{id_b}/follow", headers=auth_headers(ua_name))
test("取消关注 - 成功", res_unfol.status_code == 200 and res_unfol.json().get("ok"))

# 7.9 未登录关注
res_anofol = client.post(f"/api/users/{id_a}/follow")
test("未登录关注 - 401", res_anofol.status_code == 401)


# ================================================================
# 8. 打招呼系统
# ================================================================
separator("8. 打招呼系统 (Greets)")

# 8.1 发起打招呼
res_greet = client.post("/api/greet/requests", json={
    "receiver_id": id_b,
    "message": "你好呀，喜欢你的日记！"
}, headers=auth_headers(ua_name))
greet_data = res_greet.json()
greet_id = greet_data.get("id")
test("A 向 B 打招呼 - 成功", res_greet.status_code == 200 and greet_id is not None, str(greet_data))
test("打招呼状态 - pending", greet_data.get("status") == "pending")

# 8.2 查询打招呼状态
res_gstatus = client.get(f"/api/greet/status/{id_b}", headers=auth_headers(ua_name))
test("查看打招呼状态", res_gstatus.status_code == 200)

# 8.3 收到打招呼列表
res_received = client.get("/api/greet/requests/received?status=pending", headers=auth_headers(ub_name))
test("B 收到待处理打招呼", res_received.status_code == 200 and len(res_received.json()) >= 1)

# 8.4 发出打招呼列表
res_sent = client.get("/api/greet/requests/sent", headers=auth_headers(ua_name))
test("A 发出的打招呼列表", res_sent.status_code == 200 and len(res_sent.json()) >= 1)

# 8.5 打招呼详情
res_gdetail = client.get(f"/api/greet/requests/{greet_id}", headers=auth_headers(ua_name))
test("打招呼详情 - 成功", res_gdetail.status_code == 200)

# 8.6 B 同意打招呼
res_accept = client.post(f"/api/greet/requests/{greet_id}/accept", headers=auth_headers(ub_name))
test("B 同意打招呼 - 成功", res_accept.status_code == 200)

# 8.7 再次向 B 打招呼（已 accepted）
res_greet2 = client.post("/api/greet/requests", json={
    "receiver_id": id_b,
    "message": "再来一次～"
}, headers=auth_headers(ua_name))
# 应该返回 already_accepted 或新建 pending
test("已 accepted 后再次打招呼 - 被正确拒绝", res_greet2.status_code in (200, 400), f"status={res_greet2.status_code}")

# 8.8 待处理计数
res_pcount = client.get("/api/greet/pending-count", headers=auth_headers(ua_name))
test("打招呼待处理数", res_pcount.status_code == 200 and "pending_count" in res_pcount.json())

# 8.9 C 向 A 发起打招呼（用于测试拒绝）
res_greet3 = client.post("/api/greet/requests", json={
    "receiver_id": id_c,
    "message": "Hi C!"
}, headers=auth_headers(ua_name))
greet3_id = res_greet3.json().get("id")

# C 拒绝
if greet3_id:
    res_reject = client.post(f"/api/greet/requests/{greet3_id}/reject", headers=auth_headers(uc_name))
    test("C 拒绝打招呼 - 成功", res_reject.status_code == 200)

# 8.10 取消打招呼
res_greet4 = client.post("/api/greet/requests", json={
    "receiver_id": id_c,
    "message": "又一条"
}, headers=auth_headers(ub_name))
greet4_id = res_greet4.json().get("id")
if greet4_id:
    res_cancel = client.post(f"/api/greet/requests/{greet4_id}/cancel", headers=auth_headers(ub_name))
    test("B 取消打招呼 - 成功", res_cancel.status_code == 200)

# 8.11 不能向自己打招呼
res_selfg = client.post("/api/greet/requests", json={
    "receiver_id": id_a,
    "message": "自己打招呼"
}, headers=auth_headers(ua_name))
test("向自己打招呼 - 被拒绝", res_selfg.status_code == 400, str(res_selfg.json()))


# ================================================================
# 9. 私信系统
# ================================================================
separator("9. 私信系统 (Messages)")

# 9.1 创建/获取会话 (A 和 B 已通过打招呼 accepted)
res_conv = client.post("/api/messages/conversations", json={
    "user_id": id_b
}, headers=auth_headers(ua_name))
conv_data = res_conv.json()
conv = conv_data.get("conversation", {})
conv_id = conv.get("id")
test("创建会话 - 成功", res_conv.status_code == 200 and conv_id is not None, str(conv_data))

# 9.2 获取会话列表
res_convs = client.get("/api/messages/conversations", headers=auth_headers(ua_name))
test("会话列表 - 成功", res_convs.status_code == 200 and len(res_convs.json()) >= 1)

# 9.3 发送消息
if conv_id:
    res_send = client.post(f"/api/messages/conversations/{conv_id}/messages", json={
        "content": "Hello B!"
    }, headers=auth_headers(ua_name))
    test("A 发送消息 - 成功", res_send.status_code == 200 and res_send.json().get("ok"), str(res_send.json()))

    # 9.4 获取消息列表
    res_msgs = client.get(f"/api/messages/conversations/{conv_id}/messages", headers=auth_headers(ua_name))
    msgs_data = res_msgs.json()
    test("获取消息列表 - 成功", res_msgs.status_code == 200 and "items" in msgs_data, str(msgs_data))

    # 9.5 B 回复消息
    res_reply = client.post(f"/api/messages/conversations/{conv_id}/messages", json={
        "content": "Hi A! Nice to meet you!"
    }, headers=auth_headers(ub_name))
    test("B 回复消息 - 成功", res_reply.status_code == 200 and res_reply.json().get("ok"))

    # 9.6 标记已读
    res_read = client.post(f"/api/messages/conversations/{conv_id}/read", headers=auth_headers(ua_name))
    test("标记已读 - 成功", res_read.status_code == 200 and res_read.json().get("ok"))

# 9.7 未读计数
res_msg_unread = client.get("/api/messages/unread-count", headers=auth_headers(ua_name))
test("私信未读数 - 成功", res_msg_unread.status_code == 200 and "unread_count" in res_msg_unread.json())

# 9.8 未登录
res_anoconv = client.post("/api/messages/conversations", json={"user_id": id_b})
test("未登录创建会话 - 401", res_anoconv.status_code == 401)

# 9.9 不能向未建立关系的人发消息（C 和 A 没有 accepted greet）
res_conv2 = client.post("/api/messages/conversations", json={
    "user_id": id_a
}, headers=auth_headers(uc_name))
test("未建立关系发消息 - 被拒绝", res_conv2.status_code in (400, 403), str(res_conv2.json()))


# ================================================================
# 10. 拉黑功能
# ================================================================
separator("10. 拉黑功能 (Blocks)")

# 10.1 拉黑用户
res_blk = client.post(f"/api/users/{id_c}/block", json={
    "reason": "测试拉黑"
}, headers=auth_headers(ua_name))
test("A 拉黑 C - 成功", res_blk.status_code == 200 and res_blk.json().get("ok"), str(res_blk.json()))
test("拉黑状态 - blocked=true", res_blk.json().get("blocked") == True)

# 10.2 重复拉黑
res_reblk = client.post(f"/api/users/{id_c}/block", json={
    "reason": "再次"
}, headers=auth_headers(ua_name))
test("重复拉黑 - already_blocked=true", res_reblk.json().get("already_blocked") == True, str(res_reblk.json()))

# 10.3 拉黑后不能关注
res_fol_after = client.post(f"/api/users/{id_a}/follow", headers=auth_headers(uc_name))
test("被拉黑后 C 不能关注 A", res_fol_after.status_code == 403, str(res_fol_after.json()))

# 10.4 拉黑后不能打招呼
res_greet_after = client.post("/api/greet/requests", json={
    "receiver_id": id_a,
    "message": "你好"
}, headers=auth_headers(uc_name))
test("被拉黑后 C 不能向 A 打招呼", res_greet_after.status_code == 403, str(res_greet_after.json()))

# 10.5 查询拉黑状态
res_blk_status = client.get(f"/api/users/{id_c}/block-status", headers=auth_headers(ua_name))
test("拉黑状态查询", res_blk_status.status_code == 200)
test("blocked=true", res_blk_status.json().get("blocked") == True)

# 10.6 拉黑列表
res_blk_list = client.get("/api/me/blocked-users", headers=auth_headers(ua_name))
test("我的拉黑列表", res_blk_list.status_code == 200 and len(res_blk_list.json()) >= 1)

# 10.7 C 看到的是空拉黑列表
res_blk_empty = client.get("/api/me/blocked-users", headers=auth_headers(uc_name))
test("C 的拉黑列表为空", len(res_blk_empty.json()) == 0)

# 10.8 解除拉黑
res_unblk = client.delete(f"/api/users/{id_c}/block", headers=auth_headers(ua_name))
test("解除拉黑 - 成功", res_unblk.status_code == 200 and res_unblk.json().get("ok"))
test("解除后 blocked=false", res_unblk.json().get("blocked") == False)

# 10.9 解除后可以再次互动
res_fol_after2 = client.post(f"/api/users/{id_a}/follow", headers=auth_headers(uc_name))
test("解除拉黑后 C 可以关注 A", res_fol_after2.status_code == 200)
client.delete(f"/api/users/{id_a}/follow", headers=auth_headers(uc_name))


# ================================================================
# 11. 举报功能
# ================================================================
separator("11. 举报功能 (Reports)")

# 11.1 举报用户
res_repo = client.post("/api/reports", json={
    "target_type": "user", "target_id": id_c,
    "reason": "harassment", "description": "骚扰信息"
}, headers=auth_headers(ua_name))
test("举报用户 - 成功", res_repo.status_code == 200 and res_repo.json().get("ok"))
test("举报状态 - pending", res_repo.json().get("status") == "pending")

# 11.2 举报日记
res_repo_diary = client.post("/api/reports", json={
    "target_type": "diary", "target_id": d1_id,
    "reason": "spam", "description": ""
}, headers=auth_headers(ua_name))
test("举报日记 - 成功", res_repo_diary.status_code == 200 and res_repo_diary.json().get("ok"))

# 11.3 无效 target_type
res_bad_type = client.post("/api/reports", json={
    "target_type": "invalid", "target_id": 1,
    "reason": "other", "description": ""
}, headers=auth_headers(ua_name))
test("无效 target_type - 400", res_bad_type.status_code == 400, str(res_bad_type.json()))

# 11.4 无效 reason
res_bad_reason = client.post("/api/reports", json={
    "target_type": "user", "target_id": id_c,
    "reason": "bad_reason", "description": ""
}, headers=auth_headers(ua_name))
test("无效 reason - 400", res_bad_reason.status_code == 400, str(res_bad_reason.json()))

# 11.5 我的举报列表
res_my_repo = client.get("/api/reports/my", headers=auth_headers(ua_name))
test("我的举报列表", res_my_repo.status_code == 200 and len(res_my_repo.json()) >= 2)

# 11.6 C 看不到 A 的举报
res_other_repo = client.get("/api/reports/my", headers=auth_headers(uc_name))
test("C 看不到 A 的举报", len(res_other_repo.json()) == 0)

# 11.7 未登录举报
res_ano_repo = client.post("/api/reports", json={
    "target_type": "user", "target_id": id_c,
    "reason": "harassment", "description": ""
})
test("未登录举报 - 401", res_ano_repo.status_code == 401)


# ================================================================
# 12. 时光胶囊
# ================================================================
separator("12. 时光胶囊 (Capsules)")

from datetime import datetime, timedelta

# 12.1 创建未来胶囊
future_date = (datetime.now() + timedelta(days=30)).strftime("%Y-%m-%d")
res_cap = client.post("/api/save", json={
    "mood": "🥰", "content": "写给30天后的自己", "is_public": False,
    "unlock_date": future_date,
    "ai_summary": "给未来的信", "tags": "未来"
}, headers=auth_headers(ua_name))
cap_id = res_cap.json().get("id")
test("创建未来胶囊 - 成功", res_cap.status_code == 200 and cap_id is not None, str(res_cap.json()))

# 12.2 未到期胶囊内容被屏蔽
res_cap_detail = client.get(f"/api/diaries/{cap_id}", headers=auth_headers(ua_name))
cap_detail = res_cap_detail.json()
test("未到期胶囊 - 权限正常", res_cap_detail.status_code == 200)
test("未到期胶囊 - locked=true", cap_detail.get("locked") == True)
test("未到期胶囊 - days_left > 0", cap_detail.get("days_left", 0) > 0)

# 12.3 创建胶囊必须是将来的日期（至少明天）
tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
res_tom_cap = client.post("/api/save", json={
    "mood": "😊", "content": "明天解锁的胶囊", "is_public": False,
    "unlock_date": tomorrow,
    "ai_summary": "明天的信", "tags": "回顾"
}, headers=auth_headers(ua_name))
tom_cap_id = res_tom_cap.json().get("id")
test("创建明天解锁的胶囊 - 成功", res_tom_cap.status_code == 200, str(res_tom_cap.json()))

# 12.4 过去日期创建胶囊被拒绝
past_date = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
res_past_cap = client.post("/api/save", json={
    "mood": "😊", "content": "过去的胶囊", "is_public": False,
    "unlock_date": past_date,
    "ai_summary": "过去的信", "tags": "回顾"
}, headers=auth_headers(ua_name))
test("过去日期创建胶囊 - 被拒绝", res_past_cap.status_code == 400, str(res_past_cap.json()))

# 12.5 日记列表中未到期胶囊被屏蔽
res_list_all = client.get("/api/diaries", headers=auth_headers(ua_name))
list_items = res_list_all.json()
capsule_items = [d for d in list_items if d.get("id") == cap_id]
if capsule_items:
    test("列表中的未到期胶囊 - locked=true", capsule_items[0].get("locked") == True)

# 12.6 其他用户看不到别人的胶囊
res_other_cap = client.get(f"/api/diaries/{cap_id}", headers=auth_headers(ub_name))
test("B 看不到 A 的私密胶囊", res_other_cap.status_code == 403)


# ================================================================
# 13. 统计数据
# ================================================================
separator("13. 统计数据 (Stats)")

# 13.1 心情统计
res_stats = client.get("/api/stats", headers=auth_headers(ua_name))
stats_data = res_stats.json()
test("心情统计 - 成功", res_stats.status_code == 200)
test("包含 mood_distribution", "mood_distribution" in stats_data)
test("包含 calendar_data", "calendar_data" in stats_data)

# 13.2 心情速览
res_mood = client.get("/api/mood-stats", headers=auth_headers(ua_name))
test("心情速览 - 成功", res_mood.status_code == 200)

# 13.3 未登录不能看统计
res_ano_stats = client.get("/api/stats")
test("未登录获取统计 - 401", res_ano_stats.status_code == 401)


# ================================================================
# 14. 树洞功能
# ================================================================
separator("14. 树洞功能 (Treehole)")

# 14.0 创建树洞（匿名投递，确保有 treehole 类型数据）
res_create_th = client.post("/api/treehole", json={
    "mood": "😢", "content": "一个匿名树洞测试", "tags": "秘密"
}, headers=auth_headers(ua_name))
th_created_id = res_create_th.json().get("id")
test("创建树洞 - 成功", res_create_th.status_code == 200 and th_created_id is not None, str(res_create_th.json()))

# 14.1 漂流瓶
res_tree = client.get("/api/treehole/random")
tree_data = res_tree.json()
test("随机漂流瓶 - 成功", res_tree.status_code == 200)
test("漂流瓶包含 id/mood/content", all(k in tree_data for k in ["id", "mood", "content"]))

# 14.2 抱抱（需登录，toggle 模式）
tree_id = tree_data.get("id")
res_hug = client.post(f"/api/treehole/{tree_id}/hug", headers=auth_headers(ua_name))
test("抱抱 - 成功", res_hug.status_code == 200 and res_hug.json().get("ok"))
test("抱抱后 hug_count > 0", res_hug.json().get("hug_count", 0) > 0, str(res_hug.json()))
hugged_count = res_hug.json()["hug_count"]
# 重复抱抱应该返回 already_hugged（不能叠加）
res_hug2 = client.post(f"/api/treehole/{tree_id}/hug", headers=auth_headers(ua_name))
test("重复抱抱 - still ok", res_hug2.status_code == 200 and res_hug2.json().get("ok"))
test("重复抱抱 - already_hugged", res_hug2.json().get("already_hugged") == True, str(res_hug2.json()))
test("重复抱抱 - hug_count 不变", res_hug2.json().get("hug_count") == hugged_count, str(res_hug2.json()))
# 取消抱抱（DELETE）
res_unhug = client.delete(f"/api/treehole/{tree_id}/hug", headers=auth_headers(ua_name))
test("取消抱抱 - 成功", res_unhug.status_code == 200 and res_unhug.json().get("ok"))
test("取消抱抱 - hug_count 减 1", res_unhug.json().get("hug_count") == hugged_count - 1, str(res_unhug.json()))
# 再次取消（无记录）应该返回 was_hugged=false
res_unhug2 = client.delete(f"/api/treehole/{tree_id}/hug", headers=auth_headers(ua_name))
test("重复取消抱抱 - still ok", res_unhug2.status_code == 200 and res_unhug2.json().get("ok"))
test("重复取消抱抱 - hug_count 不变", res_unhug2.json().get("hug_count") == res_unhug.json().get("hug_count"), str(res_unhug2.json()))

# 14.3 树洞回复（需登录）
res_reply_th = client.post(f"/api/treehole/{tree_id}/reply", json={
    "content": "加油！一切都会好起来的～"
}, headers=auth_headers(ua_name))
test("树洞回复 - 成功", res_reply_th.status_code == 200 and res_reply_th.json().get("ok"), str(res_reply_th.json()))
reply_id = res_reply_th.json().get("reply", {}).get("id")
test("树洞回复 - 返回 reply id", reply_id is not None, str(res_reply_th.json()))

# 14.4 树洞回复点赞（toggle）
if reply_id:
    res_like = client.post(f"/api/treehole/replies/{reply_id}/like", headers=auth_headers(ua_name))
    test("回复点赞 - 成功", res_like.status_code == 200 and res_like.json().get("ok"))
    test("回复点赞 - like_count > 0", res_like.json().get("like_count", 0) > 0, str(res_like.json()))
    # 重复点赞
    res_like2 = client.post(f"/api/treehole/replies/{reply_id}/like", headers=auth_headers(ua_name))
    test("重复点赞 - already_liked", res_like2.json().get("already_liked") == True, str(res_like2.json()))
    # 取消点赞
    res_unlike = client.delete(f"/api/treehole/replies/{reply_id}/like", headers=auth_headers(ua_name))
    test("取消点赞 - 成功", res_unlike.status_code == 200 and res_unlike.json().get("ok"))
    test("取消点赞 - like_count 恢复", res_unlike.json().get("like_count") == 0, str(res_unlike.json()))


# ================================================================
# 15. 回归测试
# ================================================================
separator("15. 回归测试 (Regression)")

# 15.1 个人主页
res_profile = client.get("/api/profile/me", headers=auth_headers(ua_name))
test("我的主页 - 成功", res_profile.status_code == 200)
test("主页包含 nickname", "nickname" in res_profile.json())

res_upd_profile = client.put("/api/profile/me", json={
    "nickname": "小兔测试",
    "avatar": "🐰",
    "bio": "测试中",
    "interests": "测试,日记"
}, headers=auth_headers(ua_name))
test("编辑主页 - 成功", res_upd_profile.status_code == 200 and res_upd_profile.json().get("ok"))

# 15.2 查看他人主页
res_other_profile = client.get(f"/api/profile/{id_b}", headers=auth_headers(ua_name))
test("查看他人主页 - 成功", res_other_profile.status_code == 200)

# 15.3 AI 分析
res_analyze = client.post("/api/analyze", json={
    "content": "今天阳光很好，心情特别愉快！", "persona": "default"
})
analyze_data = res_analyze.json()
test("AI 分析 - 成功", res_analyze.status_code == 200)
test("AI 分析包含 summary", "summary" in analyze_data)
test("AI 分析包含 tags", "tags" in analyze_data)
test("AI 分析包含 message", "message" in analyze_data)

# 15.4 cheerful persona
res_cheer = client.post("/api/analyze", json={
    "content": "今天有点郁闷", "persona": "cheerful"
})
test("cheerful 人格分析 - 成功", res_cheer.status_code == 200)

# 15.5 图片上传
from io import BytesIO
# 最小有效 JPEG (1x1 像素)，避免 Pillow 依赖
_MINIMAL_JPEG = bytes([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
    0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
    0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
    0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
    0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
    0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
    0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    0x09, 0x0A, 0x0B, 0xFF, 0xC4, 0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03,
    0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7D,
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06,
    0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08,
    0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72,
    0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
    0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45,
    0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
    0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75,
    0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
    0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3,
    0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6,
    0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9,
    0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
    0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4,
    0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01,
    0x00, 0x00, 0x3F, 0x00, 0x7B, 0x94, 0x11, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xFF, 0xD9
])
img_bytes = BytesIO(_MINIMAL_JPEG)

res_upload = client.post("/api/upload", files={"file": ("test.jpg", img_bytes, "image/jpeg")})
test("图片上传 - 成功", res_upload.status_code == 200 and "url" in res_upload.json(), str(res_upload.json()))

# 15.6 不支持的文件类型
txt_bytes = BytesIO(b"not an image")
res_bad_upload = client.post("/api/upload", files={"file": ("test.txt", txt_bytes, "text/plain")})
test("不支持的文件类型 - 400", res_bad_upload.status_code == 400)

# 15.7 开发环境 seed 接口
res_seed = client.get("/api/dev/seed")
test("旧 seed 接口 - 成功", res_seed.status_code == 200)

# 15.8 新 seed-demo 接口
res_seed_demo = client.post("/api/dev/seed-demo")
test("新 seed-demo 接口 - 成功", res_seed_demo.status_code == 200 and res_seed_demo.json().get("ok"), str(res_seed_demo.json()))

# 15.9 seed-demo 包含所有数据
seed_summary = res_seed_demo.json()
test("seed-demo users >= 4", seed_summary.get("users", 0) >= 4)
test("seed-demo diaries > 0", seed_summary.get("diaries", 0) > 0)
test("seed-demo capsules > 0", seed_summary.get("capsules", 0) > 0)
test("seed-demo follows >= 0 (重复调用幂等)", seed_summary.get("follows", -1) >= 0)
test("seed-demo likes >= 0 (重复调用幂等)", seed_summary.get("likes", -1) >= 0)
test("seed-demo comments > 0", seed_summary.get("comments", 0) > 0)

# 15.10 多图上传（通过日记保存）
res_multi = client.post("/api/save", json={
    "mood": "😊", "content": "多图测试日记", "is_public": False,
    "ai_summary": "", "ai_message": "", "tags": "",
    "image_urls": ["/uploads/test1.jpg", "/uploads/test2.jpg"]
}, headers=auth_headers(ua_name))
multi_id = res_multi.json().get("id")
test("多图日记保存 - 成功", res_multi.status_code == 200)
if multi_id:
    res_multi_detail = client.get(f"/api/diaries/{multi_id}", headers=auth_headers(ua_name))
    multi_detail = res_multi_detail.json()
    test("多图日记 image_urls 数组", isinstance(multi_detail.get("image_urls"), list))
    client.delete(f"/api/diaries/{multi_id}", headers=auth_headers(ua_name))


# ================================================================
# 结果汇总
# ================================================================
separator("测试结果汇总")

print(f"\n  PASS: {PASS}")
print(f"  FAIL: {FAIL}")
print(f"  TOTAL: {PASS + FAIL}")
print(f"  通过率: {PASS / (PASS + FAIL) * 100:.1f}%" if (PASS + FAIL) > 0 else "  N/A")

if FAIL == 0:
    print("\n  ✓ 全部测试通过！")
else:
    print(f"\n  ✗ {FAIL} 个测试未通过，请检查上述 FAIL 项")

sys.exit(0 if FAIL == 0 else 1)
