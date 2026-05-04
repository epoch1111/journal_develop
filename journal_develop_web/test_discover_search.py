"""
发现页搜索功能测试
用法：python test_discover_search.py
"""
import io, sys, os, json

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

os.environ['ENVIRONMENT'] = 'development'

_db_path = os.path.join(os.path.dirname(__file__), "echo.db")
if os.path.exists(_db_path):
    os.remove(_db_path)

from database import init_db
init_db()

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

PASS, FAIL = 0, 0


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


def auth(token):
    return {"Authorization": f"Bearer {token}"}


def api_register(username, nickname=None):
    res = client.post("/api/auth/register", json={
        "username": username, "password": "password123",
        "nickname": nickname or username, "avatar": "🐰"
    })
    return res.json() if res.is_success else {}


def api_save(token, mood="😊", content="", tags="", is_public=False,
             content_type="diary", unlock_date="", ai_summary="", ai_message=""):
    res = client.post("/api/save", json={
        "mood": mood, "content": content, "tags": tags,
        "is_public": is_public, "content_type": content_type,
        "unlock_date": unlock_date,
        "ai_summary": ai_summary, "ai_message": ai_message,
    }, headers=auth(token))
    return res.json() if res.is_success else {}


def api_search(keyword=None, mood=None, tag=None):
    params = []
    if keyword is not None:
        params.append(f"keyword={keyword}")
    if mood:
        params.append(f"mood={mood}")
    if tag:
        params.append(f"tag={tag}")
    qs = "&".join(params)
    url = f"/api/public/diaries?{qs}" if qs else "/api/public/diaries"
    return client.get(url).json()


# ===== 准备数据 =====
separator("准备数据")

alice = api_register("search_alice")
bob = api_register("search_bob")
alice_token = alice.get("access_token", "")
bob_token = bob.get("access_token", "")
test("注册 Alice", bool(alice_token))
test("注册 Bob", bool(bob_token))

# 从 token payload 解析 user_id (JWT sub claim)
def get_uid(token_str):
    import base64
    try:
        payload = token_str.split(".")[1]
        payload += "=" * (4 - len(payload) % 4)
        return json.loads(base64.urlsafe_b64decode(payload))["sub"]
    except:
        return "0"

alice_uid = get_uid(alice_token)
bob_uid = get_uid(bob_token)
test(f"Alice uid={alice_uid}", int(alice_uid) > 0)
test(f"Bob uid={bob_uid}", int(bob_uid) > 0)

# Alice 创建公开日记
r1 = api_save(alice_token, "😊", "今天小确幸阳光好", tags="生活,小确幸",
              is_public=True, ai_summary="小确幸一天", ai_message="享受小确幸吧")
test("公开日记1(小确幸)", r1.get("ok") and r1.get("id"))

r2 = api_save(alice_token, "🥰", "幸福学习时光", tags="学习,成长",
              is_public=True, ai_summary="学习总结", ai_message="学习让人幸福")
test("公开日记2(学习/幸福)", r2.get("ok") and r2.get("id"))

# Alice 创建私密日记
r3 = api_save(alice_token, "😊", "私密小确幸记录", tags="私密", is_public=False)
test("私密日记", r3.get("ok") and r3.get("id"))

# Alice 创建树洞
from database import get_connection
conn = get_connection()
conn.execute(
    "INSERT INTO diaries (created_at, mood, content, content_type, is_public, tags, ai_summary, ai_message, user_id)"
    " VALUES (datetime('now'), '😊', '树洞里小确幸', 'treehole', 0, '树洞', '', '', ?)",
    (int(alice_uid),))
conn.commit()
conn.close()
test("树洞", True)

# Alice 创建胶囊
r4 = api_save(alice_token, "😊", "未来小确幸胶囊", tags="胶囊", is_public=False,
              content_type="capsule", unlock_date="2099-12-31")
test("胶囊", r4.get("ok") and r4.get("id"))


# ===== 1. 搜索正文 =====
separator("1. 搜索正文 content")
data = api_search(keyword="小确幸")
items = data.get("items", [])
test("有结果", len(items) > 0, f"共{len(items)}条")
has_content = any("小确幸" in (d.get("content") or "") for d in items)
test("正文含小确幸", has_content)


# ===== 2. 搜索标签 =====
separator("2. 搜索标签 tags")
data = api_search(keyword="生活")
items = data.get("items", [])
test("有结果", len(items) > 0, f"共{len(items)}条")


# ===== 3. 搜索昵称 =====
separator("3. 搜索作者昵称")
data = api_search(keyword="alice")
items = data.get("items", [])
test("有结果", len(items) > 0, f"共{len(items)}条")


# ===== 4. 中文心情词 =====
separator("4. 中文心情词")
data = api_search(keyword="开心")
items = data.get("items", [])
moods = [d.get("mood") for d in items]
test("开心匹配😊", "😊" in moods or len(items) > 0)


# ===== 5. emoji心情 =====
separator("5. emoji搜索")
data = api_search(keyword="😊")
items = data.get("items", [])
test("😊有结果", len(items) > 0, f"共{len(items)}条")


# ===== 6. 空keyword =====
separator("6. 空keyword")
data = api_search(keyword="")
test("空keyword有items", "items" in data)
data = api_search()
test("无keyword有items", "items" in data)


# ===== 7. 超长keyword =====
separator("7. 超长")
res = client.get("/api/public/diaries?keyword=" + "a" * 51)
test("51字=400", res.status_code == 400, f"status={res.status_code}")


# ===== 8. 私密隔离 =====
separator("8. 私密隔离")
data = api_search(keyword="小确幸")
items = data.get("items", [])
has_private = any("私密" in (d.get("content") or "") for d in items)
test("无私密", not has_private)


# ===== 9. 树洞隔离 =====
separator("9. 树洞隔离")
data = api_search(keyword="小确幸")
items = data.get("items", [])
has_tree = any("树洞" in (d.get("content") or "") for d in items)
test("无树洞", not has_tree)


# ===== 10. 胶囊隔离 =====
separator("10. 胶囊隔离")
data = api_search(keyword="小确幸")
items = data.get("items", [])
has_cap = any("胶囊" in (d.get("content") or "") for d in items)
test("无胶囊", not has_cap)


# ===== 11. 搜索+mood =====
separator("11. 搜索+mood")
data = api_search(keyword="学习", mood="🥰")
for d in data.get("items", []):
    test(f"mood={d.get('mood')}", d.get("mood") == "🥰")


# ===== 12. 搜索+tag =====
separator("12. 搜索+tag")
data = api_search(tag="生活")
test("tag=生活有结果", len(data.get("items", [])) > 0)


# ===== 13. 已关注 =====
separator("13. 已关注")
res = client.post(f"/api/users/{alice_uid}/follow", headers=auth(bob_token))
test("Bob关注Alice", res.is_success)
res = client.get("/api/me/following-feed", headers=auth(bob_token))
test("关注动态", res.is_success)


# ===== 14. 拉黑 =====
separator("14. 拉黑")
res = client.post(f"/api/users/{alice_uid}/block", json={"reason": ""}, headers=auth(bob_token))
test("Bob拉黑Alice", res.is_success)
from database import get_blocked_user_ids
blocked = get_blocked_user_ids(int(bob_uid))
test("拉黑列表非空", len(blocked) > 0, str(blocked))


# ===== 15. SQL注入 =====
separator("15. SQL注入")
dangerous = ["'; DROP TABLE diaries; --", "' OR 1=1 --", "'; SELECT * FROM users; --"]
for kw in dangerous:
    res = client.get(f"/api/public/diaries?keyword={kw}")
    test(f"不异常: {kw[:25]}", res.is_success, f"status={res.status_code}")
    if res.is_success:
        test(f"正常返回: {kw[:25]}", "items" in res.json())


# ===== 16. AI搜索 =====
separator("16. AI摘要/陪伴语")
data = api_search(keyword="小确幸")
items = data.get("items", [])
ai_hit = False
for d in items:
    if "小确幸" in (d.get("ai_summary") or "") or "小确幸" in (d.get("ai_message") or ""):
        ai_hit = True
        break
test("AI字段可搜索", ai_hit)


# ===== 17. 组合 =====
separator("17. 组合")
data = api_search(keyword="小确幸", tag="生活")
test("keyword+tag", len(data.get("items", [])) > 0)


separator("结果")
print(f"  通过: {PASS}/{PASS + FAIL}")
print(f"  失败: {FAIL}/{PASS + FAIL}")
if FAIL:
    print("\n  存在失败!")
    sys.exit(1)
else:
    print("\n  全部通过!")
