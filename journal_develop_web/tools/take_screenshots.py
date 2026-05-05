"""自动截屏脚本 — 使用 Playwright + 系统 Chrome 截取所有关键界面"""
import asyncio, os, time
from playwright.async_api import async_playwright

BASE_URL = "http://localhost:8000"
SCREENSHOT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "docs", "screenshots")
VIEWPORT = {"width": 420, "height": 850}

async def screenshot(page, name, delay=0.8):
    if delay:
        await page.wait_for_timeout(int(delay * 1000))
    path = os.path.join(SCREENSHOT_DIR, f"{name}.png")
    await page.screenshot(path=path, full_page=False)
    print(f"  [OK] {name}.png")

async def main():
    os.makedirs(SCREENSHOT_DIR, exist_ok=True)

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            channel="chrome",
            args=["--disable-gpu", "--no-sandbox"],
        )
        context = await browser.new_context(viewport=VIEWPORT, device_scale_factor=2)
        page = await context.new_page()

        # 1. 先加载页面让 JS 初始化
        print("[Load page...]")
        await page.goto(BASE_URL, wait_until="networkidle")
        await page.wait_for_timeout(2000)

        # 2. 通过 JS 调用 API 登录，然后将 token 写入 localStorage
        print("[Login via API...]")
        result = await page.evaluate("""
            async () => {
                try {
                    const resp = await fetch('/api/auth/login', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({username: 'charlie', password: 'password123'})
                    });
                    const data = await resp.json();
                    if (data.access_token) {
                        localStorage.setItem('echo_token', data.access_token);
                        return {ok: true, nickname: data.user?.nickname};
                    }
                    return {ok: false, detail: data.detail};
                } catch(e) {
                    return {ok: false, detail: e.message};
                }
            }
        """)
        print(f"  Login result: {result}")

        # 3. 如果 alice 不存在，注册新用户
        if not result.get("ok"):
            result = await page.evaluate("""
                async () => {
                    const ts = Date.now();
                    const resp = await fetch('/api/auth/register', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({username: 'suser' + (ts%10000), password: 'password123'})
                    });
                    const data = await resp.json();
                    if (data.access_token) {
                        localStorage.setItem('echo_token', data.access_token);
                        return {ok: true, nickname: data.user?.nickname || 'NewUser'};
                    }
                    return {ok: false, detail: data.detail};
                }
            """)
            print(f"  Register result: {result}")

        # 4. 重新加载页面使 token 生效
        await page.goto(BASE_URL, wait_until="networkidle")
        await page.wait_for_timeout(3000)

        # 5. 隐藏可能存在的 auth overlay
        await page.evaluate("""
            () => {
                const overlay = document.getElementById('authOverlay');
                if (overlay && overlay.style.display !== 'none') {
                    overlay.style.display = 'none';
                }
            }
        """)

        print("Taking screenshots...")

        # --- Screenshot 1: 日记时间线 ---
        await page.evaluate("if (typeof switchTab === 'function') switchTab('timeline');")
        await page.wait_for_timeout(2500)
        await screenshot(page, "timeline")

        # --- Screenshot 2: 写日记弹窗 ---
        await page.evaluate("document.getElementById('btnOpenModal')?.click();")
        await page.wait_for_timeout(1200)
        await screenshot(page, "write")
        await page.evaluate("document.getElementById('btnCloseModal')?.click();")
        await page.wait_for_timeout(500)

        # --- Screenshot 3: 发现广场 ---
        await page.evaluate("if (typeof switchTab === 'function') switchTab('discover');")
        await page.wait_for_timeout(3000)
        await screenshot(page, "discover")

        # --- Screenshot 4: 日记详情（点击发现列表第一个卡片）---
        await page.evaluate("""
            () => {
                const list = document.getElementById('discoverList');
                if (list) {
                    const card = list.firstElementChild;
                    if (card) card.click();
                }
            }
        """)
        await page.wait_for_timeout(3000)
        await screenshot(page, "detail")
        # 关闭详情
        await page.evaluate("""
            () => {
                if (typeof closeDiscDetail === 'function') closeDiscDetail();
            }
        """)
        await page.wait_for_timeout(800)

        # --- Screenshot 5: 树洞 ---
        await page.evaluate("if (typeof switchTab === 'function') switchTab('treehole');")
        await page.wait_for_timeout(3000)
        await screenshot(page, "treehole")

        # --- Screenshot 6: 消息中心 ---
        await page.evaluate("if (typeof switchTab === 'function') switchTab('messages');")
        await page.wait_for_timeout(2000)
        await screenshot(page, "messages")

        # --- Screenshot 7: 我的主页 ---
        await page.evaluate("if (typeof switchTab === 'function') switchTab('profile');")
        await page.wait_for_timeout(3000)
        await screenshot(page, "profile")

        # --- Screenshot 8: 关注/粉丝列表 ---
        await page.evaluate("if (typeof switchTab === 'function') switchTab('profile');")
        await page.wait_for_timeout(2500)
        # 点击关注数打开列表
        await page.evaluate("""
            () => {
                const btn = document.getElementById('btnMyFollowing');
                if (btn) btn.click();
            }
        """)
        await page.wait_for_timeout(1500)
        await screenshot(page, "follow")
        # 关闭弹窗
        await page.evaluate("""
            () => {
                const overlay = document.getElementById('followListOverlay');
                if (overlay && overlay.style.display !== 'none') overlay.click();
            }
        """)
        await page.wait_for_timeout(800)

        # --- Screenshot 9: 安全中心 ---
        await page.evaluate("""
            () => {
                const btns = document.querySelectorAll('button');
                for (const b of btns) {
                    if (b.textContent.includes('安全中心')) { b.click(); break; }
                }
            }
        """)
        await page.wait_for_timeout(1500)
        await screenshot(page, "safety")

        await browser.close()
        print("\nAll screenshots done!")

if __name__ == "__main__":
    asyncio.run(main())
