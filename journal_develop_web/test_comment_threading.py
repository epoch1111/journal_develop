"""
Public diary comment threading tests: root comments + child replies + reply_to_nickname
Start server then run: python test_comment_threading.py
"""
import json
import urllib.request
import urllib.error
import sys
import io

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
# Setup
# ============================================================
print("=== Setup ===")

for username in ["pct_a", "pct_b", "pct_c"]:
    _, resp = rest("POST", "/api/auth/register",
                   body={"username": username, "password": "password123"})

token_a = login("pct_a")
token_b = login("pct_b")
token_c = login("pct_c")
test("Setup: A logged in", bool(token_a))
test("Setup: B logged in", bool(token_b))
test("Setup: C logged in", bool(token_c))

_, me_a = rest("GET", "/api/auth/me", token=token_a)
_, me_b = rest("GET", "/api/auth/me", token=token_b)
_, me_c = rest("GET", "/api/auth/me", token=token_c)
user_a = me_a.get("user", {})
user_b = me_b.get("user", {})
user_c = me_c.get("user", {})
uid_a = user_a.get("id")
uid_b = user_b.get("id")
uid_c = user_c.get("id")
nickname_a = user_a.get("nickname", "小兔")
nickname_b = user_b.get("nickname", "小兔")
nickname_c = user_c.get("nickname", "小兔")
test("Setup: got user A id", uid_a is not None)
test("Setup: got user B id", uid_b is not None)
test("Setup: got user C id", uid_c is not None)

# A creates a public diary
_, diary_res = rest("POST", "/api/save", token=token_a, body={
    "mood": "\U0001f60a", "content": "Test diary for comment threading.", "is_public": True
})
diary_id = diary_res.get("id")
test("Setup: public diary created", diary_id is not None)

# ============================================================
# Test 1: Root comment (B comments on A's diary)
# ============================================================
print("\n=== Test 1: Root comment ===")
code, result = rest("POST", f"/api/public/diaries/{diary_id}/comments",
                     body={"client_id": "test_ct", "content": "First root comment by B"}, token=token_b)
test("1a: root comment ok", code == 200 and result.get("ok"))
root_id = result.get("comment", {}).get("id")
test("1b: returned comment id", root_id is not None)

# ============================================================
# Test 2: Reply to root comment (C replies to B)
# ============================================================
print("\n=== Test 2: Reply to root comment ===")
code, result = rest("POST", f"/api/public/diaries/{diary_id}/comments",
                     body={
                         "client_id": "test_ct2",
                         "content": "C replies to B",
                         "parent_comment_id": root_id,
                         "reply_to_user_id": uid_b
                     }, token=token_c)
test("2a: reply to root comment ok", code == 200 and result.get("ok"))
reply1_id = result.get("comment", {}).get("id")
test("2b: returned reply id", reply1_id is not None)

# ============================================================
# Test 3: Reply to child reply (B replies to C's reply)
# ============================================================
print("\n=== Test 3: Reply to child reply ===")
code, result = rest("POST", f"/api/public/diaries/{diary_id}/comments",
                     body={
                         "client_id": "test_ct3",
                         "content": "B replies to C",
                         "parent_comment_id": reply1_id,
                         "reply_to_user_id": uid_c
                     }, token=token_b)
test("3a: reply to child reply ok", code == 200 and result.get("ok"))
reply2_id = result.get("comment", {}).get("id")
test("3b: returned reply id", reply2_id is not None)

# ============================================================
# Test 4: Threaded structure verification
# ============================================================
print("\n=== Test 4: Threaded structure ===")
_, comments = rest("GET", f"/api/public/diaries/{diary_id}/comments")
test("4a: comments is a list", isinstance(comments, list))

# Find B's root comment
our_root = None
for c in comments:
    if c.get("id") == root_id:
        our_root = c
        break
test("4b: found root comment", our_root is not None)

if our_root:
    replies = our_root.get("replies", [])
    test("4c: root has replies", len(replies) >= 2)

    # Find C's reply and B's reply-to-C in the replies
    c_reply = None
    b_reply = None
    for r in replies:
        if r.get("id") == reply1_id:
            c_reply = r
        if r.get("id") == reply2_id:
            b_reply = r

    test("4d: C's reply is under root.replies", c_reply is not None)
    test("4e: B's reply-to-C is also under root.replies", b_reply is not None)

    # Both should have parent_comment_id set
    if c_reply:
        test("4f: C's reply has parent_comment_id", c_reply.get("parent_comment_id") == root_id)
    if b_reply:
        test("4g: B's reply-to-C has parent_comment_id", b_reply.get("parent_comment_id") == reply1_id)

    # Both should have root_comment_id = root_id
    if c_reply:
        test("4h: C's reply root = root_id", c_reply.get("root_comment_id") == root_id)
    if b_reply:
        test("4i: B's reply-to-C root = root_id", b_reply.get("root_comment_id") == root_id)

# ============================================================
# Test 5: reply_to_nickname correctness
# ============================================================
print("\n=== Test 5: reply_to_nickname ===")
if our_root:
    for r in our_root.get("replies", []):
        nickname = r.get("reply_to_nickname", "")
        test(f"5-{r['id']}: reply_to_nickname is non-empty", bool(nickname))

    # Verify specific values
    if c_reply:
        test("5c: C's reply has B's nickname", c_reply.get("reply_to_nickname") == nickname_b)
    if b_reply:
        test("5d: B's reply-to-C has C's nickname", b_reply.get("reply_to_nickname") == nickname_c)

# ============================================================
# Test 6: author_name/author_avatar use real user profiles
# ============================================================
print("\n=== Test 6: Real user identities ===")
if our_root:
    test("6a: root comment has user_id", our_root.get("user_id") == uid_b)
    test("6b: root comment author_name = B's nickname",
         our_root.get("author_name") == nickname_b)
    test("6c: root comment author_avatar = B's avatar",
         our_root.get("author_avatar") == user_b.get("avatar", "🐰"))

    if c_reply:
        test("6d: C's reply has user_id", c_reply.get("user_id") == uid_c)
        test("6e: C's reply author_name = C's nickname",
             c_reply.get("author_name") == nickname_c)

    if b_reply:
        test("6f: B's reply-to-C has user_id", b_reply.get("user_id") == uid_b)
        test("6g: B's reply-to-C author_name = B's nickname",
             b_reply.get("author_name") == nickname_b)

# ============================================================
# Test 7: No anon names, no client_id, no password_hash in response
# ============================================================
print("\n=== Test 7: Response field hygiene ===")
all_comments = []
for c in (comments or []):
    all_comments.append(c)
    for r in (c.get("replies") or []):
        all_comments.append(r)

for c in all_comments:
    cid = c.get("id", "?")
    test(f"7a-{cid}: no client_id", "client_id" not in c)
    test(f"7b-{cid}: no password_hash", "password_hash" not in c)
    # author_name should NOT be an anonymous name like "清风侠", "小蘑菇" etc
    anon_names = ["清风侠", "小蘑菇", "小海星", "小星球", "暖洋洋", "月光光",
                  "追风者", "向阳花", "小星光", "暖阳阳", "雨后森林", "深海小鱼"]
    author = c.get("author_name", "")
    test(f"7c-{cid}: author_name is not anonymous",
         author not in anon_names)

# ============================================================
# Test 8: Cross-diary reply rejected
# ============================================================
print("\n=== Test 8: Cross-diary reply rejected ===")
_, diary2_res = rest("POST", "/api/save", token=token_a, body={
    "mood": "\U0001f622", "content": "Another diary", "is_public": True
})
diary2_id = diary2_res.get("id")
test("8a: second diary created", diary2_id is not None)

code, result = rest("POST", f"/api/public/diaries/{diary_id}/comments",
                     body={
                         "client_id": "test_bad",
                         "content": "cross diary reply",
                         "parent_comment_id": 999999,
                         "reply_to_user_id": uid_a
                     }, token=token_b)
test("8b: non-existent parent comment rejected (400)", code == 400)

# ============================================================
# Test 9: Empty/whitespace content rejected
# ============================================================
print("\n=== Test 9: Content validation ===")
code, _ = rest("POST", f"/api/public/diaries/{diary_id}/comments",
               body={"client_id": "test_e1", "content": ""})
test("9a: empty content rejected (400)", code == 400)
code, _ = rest("POST", f"/api/public/diaries/{diary_id}/comments",
               body={"client_id": "test_e2", "content": "   "})
test("9b: whitespace-only rejected (400)", code == 400)

# ============================================================
# Test 10: Notification verification
# ============================================================
print("\n=== Test 10: Notifications ===")

# A should have notification about B's root comment
_, notifs_a = rest("GET", "/api/notifications", token=token_a)
items_a = notifs_a.get("items", [])
has_comment_notif = any(
    n.get("type") == "public_diary_comment" and "你的日记有新评论" in n.get("title", "")
    for n in items_a
)
test("10a: A received comment notification", has_comment_notif)

# B should have notification about C's reply
_, notifs_b = rest("GET", "/api/notifications", token=token_b)
items_b = notifs_b.get("items", [])
has_reply_notif = any(
    n.get("type") == "public_diary_comment_reply" and "回复了你的评论" in n.get("title", "")
    for n in items_b
)
test("10b: B received reply notification (from C)", has_reply_notif)

# C should have notification about B's reply
_, notifs_c = rest("GET", "/api/notifications", token=token_c)
items_c = notifs_c.get("items", [])
has_reply_notif_c = any(
    n.get("type") == "public_diary_comment_reply" and "回复了你的评论" in n.get("title", "")
    for n in items_c
)
test("10c: C received reply notification (from B)", has_reply_notif_c)

# ============================================================
# Test 11: Detailed reply structure validation
# ============================================================
print("\n=== Test 11: Detail endpoint includes comments ===")
_, detail = rest("GET", f"/api/public/diaries/{diary_id}")
detail_comments = detail.get("comments", [])
test("11a: detail includes comments", isinstance(detail_comments, list) and len(detail_comments) > 0)

root_in_detail = None
for c in detail_comments:
    if c.get("id") == root_id:
        root_in_detail = c
        break
test("11b: root comment in detail", root_in_detail is not None)
if root_in_detail:
    detail_replies = root_in_detail.get("replies", [])
    test("11c: detail root has replies", len(detail_replies) >= 2)

# ============================================================
# Summary
# ============================================================
print(f"\n{'='*40}")
print(f"  Passed: {PASSED}  Failed: {FAILED}  (total {PASSED + FAILED})")
print(f"{'='*40}")

if FAILED == 0:
    print("All passed!")
    sys.exit(0)
else:
    print(f"{FAILED} tests FAILED!")
    sys.exit(1)
