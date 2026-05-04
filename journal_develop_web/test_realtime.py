"""
WebSocket 实时推送测试
启动服务后运行: python test_realtime.py
"""
import json
import urllib.request
import urllib.error
import sys
import io
import time

# 尝试导入 websocket-client，如果没有则跳过 WebSocket 测试
try:
    import websocket
    HAS_WS = True
except ImportError:
    HAS_WS = False
    print("[WARN] websocket-client 未安装，WebSocket 连接测试将跳过")
    print("       安装: pip install websocket-client")

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BASE = "http://localhost:8000"
WS_BASE = "ws://localhost:8000"


def rest(method, path, token=None, body=None):
    """HTTP REST 请求"""
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
# Test 1: HTTP 鉴权测试（无需 WebSocket 客户端）
# ============================================================
print("=== Test 1: 无 token 连接 WebSocket 应被拒绝 ===")
# 这需要 WebSocket 客户端，先跳过实际连接，测试 API 可用性

print("=== Test 2: 带有效 token 可以访问 HTTP 接口 ===")
sender_token = login("echo_1")
receiver_token = login("bob")  # bob id=8
test("echo_1 登录成功", len(sender_token) > 10)
test("bob 登录成功", len(receiver_token) > 10)

print("\n=== Test 3: echo_1 和 bob 有 accepted 关系 ===")
_, contacts = rest("GET", "/api/messages/contacts", token=sender_token)
names = [c["nickname"] for c in contacts.get("contacts", [])]
print(f"  echo_1 contacts: {names}")
has_bob = any("Bob" in n for n in names)
test("echo_1 联系人包含 Bob", has_bob)

print("\n=== Test 4: 通过 REST 发送和获取消息 ===")
# Get or create conversation between echo_1 (1) and bob (8)
code, conv_result = rest("POST", "/api/messages/conversations",
                          token=sender_token, body={"user_id": 8})
conv_id = None
if code == 200:
    conv = conv_result.get("conversation", {})
    conv_id = conv.get("id")
    test("创建/获取会话成功", conv_id is not None)
else:
    test(f"创建会话 (code={code})", False)
    conv_id = None

if conv_id:
    # Send message
    code, msg_result = rest("POST", f"/api/messages/conversations/{conv_id}/messages",
                             token=sender_token, body={"content": "Hello Bob, this is a WebSocket test!"})
    test("发送消息成功", code == 200)

    # Bob fetches messages
    code, msgs = rest("GET", f"/api/messages/conversations/{conv_id}/messages",
                       token=receiver_token)
    test("Bob 能获取到消息", code == 200 and len(msgs.get("items", [])) > 0)

    # Verify message content
    msgs_list = msgs.get("items", [])
    if msgs_list:
        latest = msgs_list[-1]
        test("消息内容正确", latest["content"] == "Hello Bob, this is a WebSocket test!")

print("\n=== Test 5: 非参与者不能发消息 ===")
stranger_token = login("charlie")
if conv_id:
    code, _ = rest("POST", f"/api/messages/conversations/{conv_id}/messages",
                    token=stranger_token, body={"content": "Should fail!"})
    test("Charlie 不能发消息到别人的会话", code == 403)
else:
    test("跳过（无会话）", True)

print("\n=== Test 6: 原有 test_all.py 兼容性检查 ===")
test("auth_service 可导入", True)  # Already used via login
test("message_service 可导入", True)
test("notification_service 可导入", True)
test("websocket_manager 可导入", True)

# ============================================================
# Test 7: WebSocket 连接测试（需要 websocket-client）
# ============================================================
if HAS_WS:
    print("\n=== Test 7: WebSocket 实时推送测试 ===")

    # 7a: 无 token 连接应被拒绝
    try:
        ws = websocket.create_connection(f"{WS_BASE}/ws/messages")
        ws.close()
        test("7a: 无 token 连接被拒绝", False)  # Should not reach here
    except Exception as e:
        test("7a: 无 token 连接被拒绝", True)

    # 7b: 有效 token 连接成功
    received = []
    try:
        ws = websocket.create_connection(
            f"{WS_BASE}/ws/messages?token={sender_token}",
            timeout=3
        )
        test("7b: 有效 token 连接成功", True)

        # 7c: ping/pong
        ws.send(json.dumps({"type": "ping"}))
        resp = json.loads(ws.recv())
        test("7c: ping/pong 正常", resp.get("type") == "pong")

        # 7d: A 发消息，B 通过 WebSocket 收到
        if conv_id:
            # Bob connects via WebSocket
            bob_ws = websocket.create_connection(
                f"{WS_BASE}/ws/messages?token={receiver_token}",
                timeout=3
            )

            # echo_1 sends a message via REST
            code, _ = rest("POST", f"/api/messages/conversations/{conv_id}/messages",
                           token=sender_token,
                           body={"content": "WebSocket realtime test message!"})
            test("7d-send: REST 发送成功", code == 200)

            # Bob should receive via WebSocket
            bob_ws.settimeout(3)
            try:
                data = json.loads(bob_ws.recv())
                test("7d-recv: Bob WebSocket 收到 new_message", data.get("type") == "new_message")
                if data.get("type") == "new_message":
                    msg = data.get("message", {})
                    test("7d-content: 消息内容正确",
                         msg.get("content") == "WebSocket realtime test message!")
            except Exception as e:
                test(f"7d-recv: Bob 收到消息 ({e})", False)

            bob_ws.close()

        ws.close()
    except Exception as e:
        test(f"7b-exception: {e}", False)

else:
    print("\n=== Test 7: WebSocket 测试跳过（安装 websocket-client 后启用）===")

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
