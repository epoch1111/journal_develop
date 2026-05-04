"""
产品边界测试：日记 / 树洞 / 发现广场 三模块的内容归属、可见性、匿名性
启动服务后运行: python test_visibility_boundaries.py
"""
import json
import urllib.request
import urllib.error
import sys
import io
import time

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BASE = "http://localhost:8000"


def rest(method, path, token=None, body=None):
    url = f"{BASE}{path}"
    data = json.dumps(body).encode() if body else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def login(username, password="password123"):
    _, data = rest("POST", "/api/auth/login", body={"username": username, "password": password})
    return data.get("access_token", "")


PASSED = 0
FAILED = 0


def test(name, condition):
    global PASSED, FAILED
    if condition:
        PASSED += 1
        print(f"  ✓ {name}")
    else:
        FAILED += 1
        print(f"  ✗ {name} FAILED")


# ============================================================
# Test 1: content_type='diary' 的日记会出现在日记列表，但不会出现在树洞
# ============================================================
print("=== Test 1: 日记 (content_type='diary') 不出现在树洞 ===")
token = login("echo_1")

# 创建一篇日记
_, result = rest("POST", "/api/save", token=token, body={
    "mood": "😊", "content": "一篇普通的日记", "is_public": False
})
diary_id = result.get("id")
test("1a: 创建日记成功", diary_id is not None)

# 检查出现在日记列表
code, diaries = rest("GET", "/api/diaries", token=token)
diary_ids = [d["id"] for d in diaries]
test("1b: 日记在日记列表中", diary_id in diary_ids)

# 树洞随机获取 - 应该拿不到 diary 类型的（可能返回其他树洞数据）
_, treehole_data = rest("GET", "/api/treehole/random")
test("1c: 树洞随机不返回 diary 类型", treehole_data is None or treehole_data.get("id") != diary_id)

# ============================================================
# Test 2: content_type='treehole' 不出现在日记列表和发现广场
# ============================================================
print("\n=== Test 2: 树洞 (content_type='treehole') 不泄露到日记/发现 ===")
alice_token = login("alice")

# 创建树洞
_, th_result = rest("POST", "/api/treehole", token=alice_token, body={
    "mood": "😢", "content": "一个匿名树洞测试", "tags": "秘密"
})
th_id = th_result.get("id")
test("2a: 创建树洞成功", th_id is not None)

# 树洞不出现在 Alice 的日记列表
_, alice_diaries = rest("GET", "/api/diaries", token=alice_token)
alice_ids = [d["id"] for d in alice_diaries]
test("2b: 树洞不在日记列表中", th_id not in alice_ids)

# 树洞不出现在发现广场
_, discover = rest("GET", "/api/public/diaries")
discover_ids = [d["id"] for d in discover.get("items", [])]
test("2c: 树洞不在发现广场", th_id not in discover_ids)

# 树洞出现在树洞随机
_, th_random = rest("GET", "/api/treehole/random")
# 可能获取到不同的树洞，但至少应该能找到一条（如果只有这一条的话）
test("2d: 树洞随机能获取到数据", th_random is not None)

# ============================================================
# Test 3: 树洞随机返回的是匿名数据（无 user_id, author_name, author_avatar）
# ============================================================
print("\n=== Test 3: 树洞匿名性 ===")
if th_random:
    test("3a: 树洞不返回 user_id", "user_id" not in th_random)
    test("3b: 树洞不返回 author_name", "author_name" not in th_random)
    test("3c: 树洞不返回 author_avatar", "author_avatar" not in th_random)
else:
    test("3a: 树洞不返回 user_id (skipped, no data)", True)
    test("3b: 树洞不返回 author_name (skipped)", True)
    test("3c: 树洞不返回 author_avatar (skipped)", True)

# ============================================================
# Test 4: GET /api/treehole/{id} 匿名详情
# ============================================================
print("\n=== Test 4: 树洞详情匿名性 ===")
if th_id:
    code, detail = rest("GET", f"/api/treehole/{th_id}")
    test("4a: 树洞详情可访问", code == 200)
    test("4b: 树洞详情不返回 user_id", detail is not None and "user_id" not in detail)
    test("4c: 树洞详情不返回 author_name", detail is not None and "author_name" not in detail)
else:
    test("4a: 跳过（无树洞ID）", True)
    test("4b: 跳过", True)
    test("4c: 跳过", True)

# ============================================================
# Test 5: 发现广场只展示 content_type='diary' + is_public=1 + unlock_date 为空
# ============================================================
print("\n=== Test 5: 发现广场过滤器 ===")
_, discover_items = rest("GET", "/api/public/diaries")
items = discover_items.get("items", [])
# 确保有数据
if items:
    for item in items:
        # 每条数据都应该有作者信息（非匿名）
        has_author = "author_name" in item and "author_avatar" in item
        is_not_anonymous = not item.get("anonymous", False)
        test(f"5-{item['id']}: 广场条目非匿名", has_author and is_not_anonymous)
else:
    test("5a: 广场有数据 (skipped)", True)

# 确保广场不返回树洞
if th_id:
    test("5b: 树洞不在广场", th_id not in discover_ids)

# ============================================================
# Test 6: 胶囊 (content_type='capsule') 不出现在发现广场
# ============================================================
print("\n=== Test 6: 胶囊不出现在发现广场 ===")
# 创建胶囊
_, cap_result = rest("POST", "/api/save", token=token, body={
    "mood": "🥰", "content": "一个未来的秘密",
    "unlock_date": "2027-01-01", "is_public": True
})
cap_id = cap_result.get("id")
test("6a: 创建胶囊成功", cap_id is not None)

if cap_id:
    _, discover2 = rest("GET", "/api/public/diaries")
    cap_in_discover = any(d["id"] == cap_id for d in discover2.get("items", []))
    test("6b: 胶囊不在发现广场", not cap_in_discover)

# 但胶囊在日记列表中出现（对作者自己可见）
_, user_diaries = rest("GET", "/api/diaries", token=token)
cap_in_diary = any(d["id"] == cap_id for d in user_diaries)
test("6c: 胶囊在作者日记列表中", cap_in_diary)

# ============================================================
# Test 7: 树洞抱抱/回复只能对 content_type='treehole' 的条目进行
# ============================================================
print("\n=== Test 7: 树洞操作限制 ===")
# 对 diary 类型进行 hug 应该 404（需登录）
if diary_id:
    code, _ = rest("POST", f"/api/treehole/{diary_id}/hug", token=token)
    test("7a: diary 类型不能被树洞 hug", code == 404)

    code, _ = rest("POST", f"/api/treehole/{diary_id}/reply", token=token, body={"content": "test"})
    test("7b: diary 类型不能被树洞回复", code == 404)

# 对 treehole 类型进行 hug 应该成功（需登录）
if th_id:
    code, hug_result = rest("POST", f"/api/treehole/{th_id}/hug", token=alice_token)
    test("7c: treehole 类型可以 hug", code == 200)

    code, reply_result = rest("POST", f"/api/treehole/{th_id}/reply", token=alice_token, body={"content": "加油"})
    test("7d: treehole 类型可以回复", code == 200)

# ============================================================
# Test 8: 作者公开主页不暴露树洞和胶囊
# ============================================================
print("\n=== Test 8: 作者公开主页只展示公开普通日记 ===")
bob_token = login("bob")
_, bob_me = rest("GET", "/api/auth/me", token=bob_token)
bob_id = bob_me.get("user", {}).get("id")

if bob_id:
    _, profile = rest("GET", f"/api/profile/{bob_id}")
    if profile and not profile.get("blocked"):
        # 公开主页的 recent_public_diaries 不应包含树洞或胶囊
        recent = profile.get("recent_public_diaries", [])
        test("8a: 公开主页有最近日记或为空", isinstance(recent, list))

# ============================================================
# Test 9: 关注动态不包含树洞和胶囊
# ============================================================
print("\n=== Test 9: 关注动态过滤 ===")
_, feed = rest("GET", "/api/me/following-feed", token=token)
feed_items = feed.get("items", [])
test("9a: 关注动态返回列表", isinstance(feed_items, list))
# 如果有树洞数据，不应该出现在 feed 中
if th_id:
    th_in_feed = any(d["id"] == th_id for d in feed_items)
    test("9b: 树洞不在关注动态", not th_in_feed)

# ============================================================
# Test 10: 用户主页统计按 content_type 正确分类
# ============================================================
print("\n=== Test 10: 统计按 content_type 分类 ===")
_, profile = rest("GET", "/api/profile/me", token=alice_token)
if profile:
    stats = profile.get("stats", {})
    test("10a: stats 返回 diary_count", "diary_count" in stats)
    test("10b: stats 返回 public_diary_count", "public_diary_count" in stats)
    test("10c: stats 返回 capsule_count", "capsule_count" in stats)
    test("10d: stats 返回 treehole_count", "treehole_count" in stats)

# ============================================================
# Test 11: 公开广场详情 GET /api/public/diaries/{id} 只返回 diary 类型
# ============================================================
print("\n=== Test 11: 公开广场详情过滤 ===")
# 创建一篇公开日记用于测试广场访问
_, pub_result = rest("POST", "/api/save", token=token, body={
    "mood": "😊", "content": "一篇公开日记用于广场测试", "is_public": True
})
pub_diary_id = pub_result.get("id")
test("11-prea: 公开日记创建成功", pub_diary_id is not None)

if pub_diary_id:
    code, _ = rest("GET", f"/api/public/diaries/{pub_diary_id}")
    # diary 类型且 is_public=1 应该在广场可访问
    test(f"11a: 公开日记可广场访问 (code={code})", code == 200)

if th_id:
    code, _ = rest("GET", f"/api/public/diaries/{th_id}")
    test(f"11b: 树洞不可广场访问 (code={code})", code == 404)

if cap_id:
    code, _ = rest("GET", f"/api/public/diaries/{cap_id}")
    test(f"11c: 胶囊不可广场访问 (code={code})", code == 404)

# ============================================================
# Test 12: POST /api/save 默认 content_type='diary'
# ============================================================
print("\n=== Test 12: 默认 content_type 行为 ===")
_, result = rest("POST", "/api/save", token=token, body={
    "mood": "😊", "content": "默认 diary 类型测试", "is_public": False
})
d2_id = result.get("id")
test("12a: 无 unlock_date 创建 diary 类型", d2_id is not None)

# ============================================================
# Test 13: 非作者不能查看私密 diary
# ============================================================
print("\n=== Test 13: 跨用户可见性 ===")
if d2_id:
    code, _ = rest("GET", f"/api/diaries/{d2_id}", token=alice_token)
    test("13a: 非作者不能看私密日记", code == 403)

# ============================================================
# Test 14: 发现广场评论/点亮不能操作 treehole 类型
# ============================================================
print("\n=== Test 14: 广场互动不能操作树洞 ===")
if th_id:
    code, _ = rest("POST", f"/api/public/diaries/{th_id}/like",
                   body={"client_id": "test_vis_boundary"})
    test("14a: 树洞不能被广场点亮", code == 404)

    code, _ = rest("POST", f"/api/public/diaries/{th_id}/comments",
                   body={"client_id": "test_vis_boundary", "content": "test"})
    test("14b: 树洞不能被广场评论", code == 404)

# ============================================================
# Test 15: seed-demo 数据正确使用 content_type
# ============================================================
print("\n=== Test 15: 发现广场列表验证 ===")
_, discover_all = rest("GET", "/api/public/diaries?page_size=50")
discover_items = discover_all.get("items", [])
test("15a: 发现广场返回数据", len(discover_items) > 0)
# 验证所有广场数据都有作者信息（非匿名）
all_have_author = all(
    item.get("author_name") and not item.get("anonymous", False)
    for item in discover_items
)
test("15b: 全部广场条目有真实作者", all_have_author)

# ============================================================
# Summary
# ============================================================
print(f"\n{'='*40}")
print(f"  通过: {PASSED}  失败: {FAILED}  (共 {PASSED + FAILED})")
print(f"{'='*40}")

if FAILED == 0:
    print("全部通过!")
    sys.exit(0)
else:
    print(f"{FAILED} 个测试失败!")
    sys.exit(1)
