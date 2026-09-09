from fastapi import APIRouter, Depends, HTTPException
from app.core.database import get_supabase
from app.core.security import get_current_teacher
from app.services.analytics_service import AnalyticsService
from supabase import Client

router = APIRouter(prefix="/analytics", tags=["analytics"])

analytics_service = AnalyticsService()

EMPTY_ANALYTICS = {
    "total_students": 0,
    "pass_count": 0,
    "fail_count": 0,
    "atkt_count": 0,
    "absent_count": 0,
    "avg_sgpa": 0,
    "top_sgpa": 0,
    "min_sgpa": 0,
    "above_avg_count": 0,
    "below_avg_count": 0,
    "toppers": [],
    "grade_distribution": {},
    "subject_averages": [],
    "sgpa_histogram": [],
}


@router.get("/{project_id}")
async def get_analytics(
    project_id: str,
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    proj = (
        supabase.table("projects")
        .select("*")
        .eq("id", project_id)
        .eq("teacher_id", teacher["id"])
        .execute()
    )
    if not proj.data:
        raise HTTPException(status_code=404, detail="Project not found")

    # Fetch all results (not just confirmed — teacher can view analytics in progress)
    results = (
        supabase.table("student_results")
        .select("*, subject_marks(*), students(name, seat_no, prn)")
        .eq("project_id", project_id)
        .execute()
    )

    if not results.data:
        return EMPTY_ANALYTICS

    return analytics_service.compute(results.data)
