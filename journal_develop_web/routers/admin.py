"""后台管理 - 活跃用户"""

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse

from services.admin_service import get_active_users, get_active_count
from services.auth_service import require_user

router = APIRouter(prefix="/api/admin", tags=["admin"])


def _is_localhost(request: Request) -> bool:
    """检查请求是否来自本机（无鉴权接口的安全保护）"""
    client_host = request.client.host if request.client else ""
    return client_host in ("127.0.0.1", "localhost", "::1", "::ffff:127.0.0.1")


@router.get("/online")
async def online_users(request: Request):
    """无鉴权接口，仅本机可访问——查看当前在线用户"""
    if not _is_localhost(request):
        return {"error": "Only localhost can access", "online": [], "total": 0}
    users = get_active_users(minutes=30)
    return {
        "online": users,
        "total": len(users),
    }


@router.get("/page")
async def admin_page(request: Request):
    """仅本机可访问的管理页面"""
    if not _is_localhost(request):
        return HTMLResponse("<h1>Only localhost can access</h1>")

    users = get_active_users(minutes=30)
    user_html = ""
    for u in users:
        avatar = u.get("avatar", "🐰")
        nickname = u.get("nickname") or "小兔"
        username = u.get("username", "")
        uid = u.get("user_id", "?")
        ago = u.get("active_ago", "?")
        avatar_html = f'<img src="{avatar}" style="width:100%;height:100%;border-radius:50%;object-fit:cover">' if avatar.startswith("/") else avatar
        user_html += f"""
        <div class="card">
          <div class="card-header">
            <div class="avatar">{avatar_html}</div>
            <div>
              <div class="name">{nickname}</div>
              <div class="meta">@{username} · UID:{uid}</div>
            </div>
            <div class="status" style="margin-left:auto">{ago}</div>
          </div>
        </div>"""

    html = f"""<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Echo Admin</title>
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: -apple-system, sans-serif; background: #f9fafb; padding: 24px; }}
  .container {{ max-width: 600px; margin: 0 auto; }}
  h1 {{ font-size: 20px; color: #1f2937; margin-bottom: 16px; }}
  .card {{ background: white; border-radius: 16px; padding: 16px; margin-bottom: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }}
  .card-header {{ display: flex; align-items: center; gap: 12px; }}
  .avatar {{ width: 40px; height: 40px; border-radius: 50%; background: #ecfdf5; display: flex; align-items: center; justify-content: center; font-size: 20px; overflow: hidden; }}
  .name {{ font-weight: 600; color: #1f2937; }}
  .meta {{ font-size: 12px; color: #9ca3af; }}
  .status {{ display: inline-flex; align-items: center; gap: 4px; font-size: 12px; color: #10b981; }}
  .status::before {{ content: ''; width: 8px; height: 8px; border-radius: 50%; background: #10b981; }}
  .empty {{ text-align: center; padding: 40px; color: #9ca3af; }}
  .refresh {{ display: inline-flex; align-items: center; gap: 6px; padding: 8px 16px; background: #10b981; color: white; border: none; border-radius: 10px; cursor: pointer; font-size: 14px; }}
  .refresh:hover {{ background: #059669; }}
  .header {{ display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }}
  .total {{ font-size: 13px; color: #6b7280; }}
  .note {{ font-size: 12px; color: #9ca3af; margin-top: 12px; }}
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>Echo Admin</h1>
    <span class="total">{len(users)} online</span>
  </div>
  <button class="refresh" onclick="location.reload()">reload</button>
  <div style="margin-top:16px">{user_html if user_html else '<div class="empty">No online users</div>'}</div>
  <p class="note">Refresh every 15s · Only accessible from localhost</p>
</div>
<script>setTimeout(() => location.reload(), 15000);</script>
</body>
</html>"""
    return HTMLResponse(html)
