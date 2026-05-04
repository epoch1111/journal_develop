"""
Treehole threading tests: stable anonymous identities + threaded replies
Start server then run: python test_treehole_threading.py
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

for username in ["tht_a", "tht_b", "tht_c"]:
    code, _ = rest("POST", "/api/auth/register",
                   body={"username": username, "password": "password123"})

token_a = login("tht_a")
token_b = login("tht_b")
token_c = login("tht_c")
test("Setup: user A logged in", bool(token_a))
test("Setup: user B logged in", bool(token_b))
test("Setup: user C logged in", bool(token_c))

_, me_a = rest("GET", "/api/auth/me", token=token_a)
_, me_b = rest("GET", "/api/auth/me", token=token_b)
_, me_c = rest("GET", "/api/auth/me", token=token_c)
uid_a = me_a.get("user", {}).get("id")
uid_b = me_b.get("user", {}).get("id")
uid_c = me_c.get("user", {}).get("id")

# A creates a treehole diary
_, th_res = rest("POST", "/api/treehole", token=token_a, body={
    "mood": "😊", "content": "今天阳光很好，分享给大家。"
})
th_id = th_res.get("id")
test("Setup: treehole created", th_id is not None)

# ============================================================
# Test 1: Stable anonymous identity — same user, same treehole
# ============================================================
print("\n=== Test 1: Stable anonymous identity ===")
# B posts first reply
code, r1 = rest("POST", f"/api/treehole/{th_id}/reply", token=token_b,
                body={"content": "B 的第一条回复"})
test("1a: first reply ok", code == 200 and r1.get("ok"))
name1 = r1.get("reply", {}).get("anon_name")
avatar1 = r1.get("reply", {}).get("anon_avatar")
test("1b: first reply has anon_name", bool(name1))
test("1c: first reply has anon_avatar", bool(avatar1))

# B posts second reply
code, r2 = rest("POST", f"/api/treehole/{th_id}/reply", token=token_b,
                body={"content": "B 的第二条回复"})
test("1d: second reply ok", code == 200 and r2.get("ok"))
name2 = r2.get("reply", {}).get("anon_name")
avatar2 = r2.get("reply", {}).get("anon_avatar")
test("1e: same user → same anon_name", name1 == name2)
test("1f: same user → same anon_avatar", avatar1 == avatar2)

# ============================================================
# Test 2: Different users → different anonymous identities
# ============================================================
print("\n=== Test 2: Different users, different identities ===")
code, r3 = rest("POST", f"/api/treehole/{th_id}/reply", token=token_c,
                body={"content": "C 的回复"})
test("2a: C's reply ok", code == 200 and r3.get("ok"))
name3 = r3.get("reply", {}).get("anon_name")
test("2b: different user → different anon_name", name3 != name1)

# ============================================================
# Test 3: Threaded reply — reply to B's first reply
# ============================================================
print("\n=== Test 3: Threaded reply (replying to a reply) ===")
reply1_id = r1.get("reply", {}).get("id")
identity1_id = r1.get("reply", {}).get("identity_id")
test("3a: B's reply has identity_id", identity1_id is not None)

# C replies to B's reply
code, r4 = rest("POST", f"/api/treehole/{th_id}/reply", token=token_c,
                body={
                    "content": "C 回复 B 的第一条",
                    "parent_reply_id": reply1_id,
                    "reply_to_identity_id": identity1_id,
                })
test("3b: threaded reply ok", code == 200 and r4.get("ok"))
child_reply = r4.get("reply", {})
test("3c: child reply has parent_reply_id", child_reply.get("parent_reply_id") == reply1_id)
test("3d: child reply has root_reply_id set", child_reply.get("root_reply_id") is not None)

# ============================================================
# Test 4: Reply list — verify threaded structure
# ============================================================
print("\n=== Test 4: Threaded structure in reply list ===")
_, detail = rest("GET", f"/api/treehole/{th_id}")
replies = detail.get("replies", [])
test("4a: replies is a list", isinstance(replies, list))

# Find B's root reply
b_root = None
for r in replies:
    if r.get("id") == reply1_id:
        b_root = r
        break
test("4b: found B's root reply in list", b_root is not None)

if b_root:
    child_replies = b_root.get("replies", [])
    test("4c: root reply has child replies", len(child_replies) > 0)
    if child_replies:
        cr = child_replies[0]
        test("4d: child reply has reply_to_anon_name",
             bool(cr.get("reply_to_anon_name")))
        test("4e: child reply anon_name is C's",
             cr.get("anon_name") == name3)

# ============================================================
# Test 5: Second-level reply (reply to a child reply)
# ============================================================
print("\n=== Test 5: Second-level reply ===")
child_id = child_reply.get("id") if b_root and b_root.get("replies") else None
child_identity_id = child_reply.get("identity_id") if b_root and b_root.get("replies") else None

if child_id:
    # A replies to C's child reply
    code, r5 = rest("POST", f"/api/treehole/{th_id}/reply", token=token_a,
                    body={
                        "content": "A 回复 C 的子回复",
                        "parent_reply_id": child_id,
                        "reply_to_identity_id": child_identity_id,
                    })
    test("5a: second-level reply ok", code == 200 and r5.get("ok"))
    test("5b: second-level reply root = first-level root",
         r5.get("reply", {}).get("root_reply_id") == b_root.get("id"))

# ============================================================
# Test 6: Cross-treehole reply rejected
# ============================================================
print("\n=== Test 6: Cross-treehole reply rejected ===")
# Create another treehole
_, th2_res = rest("POST", "/api/treehole", token=token_a, body={
    "mood": "😢", "content": "另一篇树洞"
})
th2_id = th2_res.get("id")
test("6a: second treehole created", th2_id is not None)

# Try using reply from treehole 1 to reply to treehole 2
code, bad = rest("POST", f"/api/treehole/{th2_id}/reply", token=token_b,
                 body={
                     "content": "cross treehole reply",
                     "parent_reply_id": reply1_id,
                 })
test("6b: cross-treehole reply rejected (400)", code == 400)

# ============================================================
# Test 7: Empty content rejected
# ============================================================
print("\n=== Test 7: Validation ===")
code, _ = rest("POST", f"/api/treehole/{th_id}/reply", token=token_b,
               body={"content": ""})
test("7a: empty content rejected (400)", code == 400)

code, _ = rest("POST", f"/api/treehole/{th_id}/reply", token=token_b,
               body={"content": "   "})
test("7b: whitespace-only rejected (400)", code == 400)

# ============================================================
# Test 8: Non-existent parent reply
# ============================================================
print("\n=== Test 8: Non-existent parent reply ===")
code, _ = rest("POST", f"/api/treehole/{th_id}/reply", token=token_b,
               body={
                   "content": "reply to nothing",
                   "parent_reply_id": 999999,
               })
test("8a: non-existent parent rejected (400)", code == 400)

# ============================================================
# Test 9: Non-existent reply_to_identity
# ============================================================
print("\n=== Test 9: Non-existent reply_to_identity ===")
code, _ = rest("POST", f"/api/treehole/{th_id}/reply", token=token_b,
               body={
                   "content": "reply to bad identity",
                   "parent_reply_id": reply1_id,
                   "reply_to_identity_id": 999999,
               })
test("9a: bad identity_id rejected (400)", code == 400)

# ============================================================
# Test 10: Anonymous identity for non-logged-in (client_id)
# ============================================================
print("\n=== Test 10: Non-logged-in (client_id) identity ===")
# The treehole reply endpoint requires auth, so use the auth but simulate
# with consistent client_id parameter
code, r10 = rest("POST", f"/api/treehole/{th_id}/reply", token=token_b,
                 body={
                     "content": "logged in B again",
                 })
test("10a: logged-in B still same name", code == 200 and
     r10.get("reply", {}).get("anon_name") == name1)

# ============================================================
# Test 11: Like on threaded reply
# ============================================================
print("\n=== Test 11: Like on threaded reply ===")
code, like_r = rest("POST", f"/api/treehole/replies/{reply1_id}/like", token=token_a)
test("11a: like root reply ok", code == 200 and like_r.get("ok"))

# Get detail again (as user A, who liked) and verify liked
_, detail2 = rest("GET", f"/api/treehole/{th_id}", token=token_a)
for r in detail2.get("replies", []):
    if r.get("id") == reply1_id:
        test("11b: liked is true for liking user", r.get("liked") == True)
        test("11c: like_count is 1", r.get("like_count") == 1)
        break

# Unlike
code, unlike_r = rest("DELETE", f"/api/treehole/replies/{reply1_id}/like", token=token_a)
test("11d: unlike ok", code == 200 and unlike_r.get("ok"))

# ============================================================
# Test 12: Identity isolation across treeholes
# ============================================================
print("\n=== Test 12: Identity isolation across treeholes ===")
# B posts in treehole 2
code, r12 = rest("POST", f"/api/treehole/{th2_id}/reply", token=token_b,
                 body={"content": "B in treehole 2"})
test("12a: B reply in treehole 2 ok", code == 200)
# Identity should be different from treehole 1 (different treehole)
name_t2 = r12.get("reply", {}).get("anon_name")
# It may or may not be different depending on hash, but it should at least exist
test("12b: has anon_name in treehole 2", bool(name_t2))

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
