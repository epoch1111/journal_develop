"""开发/测试专用路由（生产环境自动禁用）"""

import os

from fastapi import APIRouter, HTTPException
from database import save_diary_to_db

router = APIRouter(prefix="/api/dev", tags=["开发工具"])


def _guard():
    """非开发环境直接拒绝访问"""
    if os.environ.get("ENVIRONMENT") != "development":
        raise HTTPException(status_code=403, detail="仅在开发环境可用")


@router.get("/seed")
async def dev_seed():
    """插入 3 条公开日记用于树洞 UI 测试"""
    _guard()

    seed_data = [
        {"mood": "😊", "content": "今天下班路上买了一束洋桔梗，看着花开心情突然就好了起来。", "ai_summary": "洋桔梗的小确幸", "ai_message": "生活里的小美好总是藏在细节里，能发现它们的人，心底一定很柔软吧。", "tags": "生活,小确幸", "is_public": True},
        {"mood": "😫", "content": "连续加了一个星期的班，感觉身体被掏空，有没有人能给我个拥抱呀...", "ai_summary": "加班疲惫", "ai_message": "辛苦了，你的付出都被看在眼里。但别忘了，身体才是最重要的，今晚早点休息吧。", "tags": "工作,疲惫", "is_public": True},
        {"mood": "😌", "content": "终于把拖延了很久的项目交差了！今晚要奖励自己看一部电影加一包薯片！", "ai_summary": "项目交差的放松时刻", "ai_message": "那种如释重负的感觉真的太棒了！你值得这份奖励，好好享受今晚的放松时光吧～", "tags": "成就,放松", "is_public": True},
    ]
    ids = []
    for d in seed_data:
        row_id = save_diary_to_db(
            mood=d["mood"],
            content=d["content"],
            ai_summary=d["ai_summary"],
            ai_message=d["ai_message"],
            tags=d["tags"],
            is_public=d["is_public"],
        )
        ids.append(row_id)
    return {"status": "ok", "inserted_count": len(ids), "ids": ids}
