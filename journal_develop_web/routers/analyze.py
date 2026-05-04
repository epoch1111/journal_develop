"""AI 分析路由"""

from fastapi import APIRouter
from models.schemas import AnalyzeRequest, AnalyzeResponse
from services.ai_service import analyze_diary

router = APIRouter(prefix="/api", tags=["AI分析"])


@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze(req: AnalyzeRequest):
    result = analyze_diary(content=req.content, persona=req.persona)
    return AnalyzeResponse(**result)
