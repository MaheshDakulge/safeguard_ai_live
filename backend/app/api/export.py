from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from app.core.database import get_supabase
from app.core.security import get_current_teacher
from app.services.analytics_service import AnalyticsService
from supabase import Client
import pandas as pd
import io

router = APIRouter(prefix="/export", tags=["export"])

analytics_service = AnalyticsService()


# FIX: was POST — export/download must be GET so browsers can trigger it directly
@router.get("/{project_id}")
async def export_project(
    project_id: str,
    # FIX: format as query param, default excel per PRD
    format: str = Query(default="excel", enum=["csv", "excel"]),
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    # Verify ownership
    proj = (
        supabase.table("projects")
        .select("*")
        .eq("id", project_id)
        .eq("teacher_id", teacher["id"])
        .execute()
    )
    if not proj.data:
        raise HTTPException(status_code=404, detail="Project not found")

    project = proj.data[0]

    # Fetch all results + student info + subject marks
    results = (
        supabase.table("student_results")
        .select("*, subject_marks(*), students(name, seat_no)")
        .eq("project_id", project_id)
        .order("rank")
        .execute()
    )

    if not results.data:
        raise HTTPException(status_code=404, detail="No results found for this project")

    # ── Sheet 1: Student Data ──────────────────────────────────────────────────
    rows = []
    for r in results.data:
        student = r.get("students") or {}
        base_row = {
            "Rank": r.get("rank", ""),
            "PRN": r["student_prn"],
            "Seat No": student.get("seat_no", ""),
            "Name": student.get("name", ""),
            "Semester": r.get("semester", ""),
            "Total Credits": r.get("total_credits", ""),
            "Total Earned GP": r.get("total_egp", ""),
            "SGPA": r.get("sgpa", ""),
            "CGPA": r.get("cgpa", ""),
            "Status": (r.get("status") or "").upper(),
        }
        for mark in sorted(r.get("subject_marks", []), key=lambda m: m.get("sr_no") or 0):
            key = mark.get("course_code") or f"Subject {mark.get('sr_no', '')}"
            base_row[f"{key} Grade"] = mark.get("grade_obtained", "")
            base_row[f"{key} GP"] = mark.get("grade_point", "")
            base_row[f"{key} EGP"] = mark.get("earned_gp", "")
        rows.append(base_row)

    df_students = pd.DataFrame(rows)

    if format == "csv":
        buf = io.StringIO()
        df_students.to_csv(buf, index=False)
        buf.seek(0)
        return StreamingResponse(
            iter([buf.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": f'attachment; filename="project_{project_id}.csv"'},
        )

    # ── Excel: 3 sheets per PRD ────────────────────────────────────────────────
    analytics = analytics_service.compute(results.data)

    # Sheet 2: Analytics Summary
    summary_rows = [
        {"Metric": "Project Name", "Value": project.get("name", "")},
        {"Metric": "Program", "Value": project.get("program", "")},
        {"Metric": "Examination", "Value": project.get("examination", "")},
        {"Metric": "Semester", "Value": project.get("semester", "")},
        {"Metric": "Total Students", "Value": analytics["total_students"]},
        {"Metric": "Pass Count", "Value": analytics["pass_count"]},
        {"Metric": "ATKT Count", "Value": analytics["atkt_count"]},
        {"Metric": "Fail Count", "Value": analytics["fail_count"]},
        {"Metric": "Absent Count", "Value": analytics["absent_count"]},
        {"Metric": "Class Avg SGPA", "Value": analytics["avg_sgpa"]},
        {"Metric": "Highest SGPA", "Value": analytics["top_sgpa"]},
        {"Metric": "Lowest SGPA", "Value": analytics["min_sgpa"]},
        {"Metric": "Above Average", "Value": analytics["above_avg_count"]},
        {"Metric": "Below Average", "Value": analytics["below_avg_count"]},
    ]
    df_summary = pd.DataFrame(summary_rows)

    # Sheet 3: Rank List
    rank_rows = [
        {
            "Rank": t.get("rank", ""),
            "PRN": t.get("prn", ""),
            "Name": t.get("name", ""),
            "SGPA": t.get("sgpa", ""),
            "Status": (t.get("status") or "").upper(),
        }
        for t in analytics.get("toppers", [])
    ]
    df_ranks = pd.DataFrame(rank_rows)

    buf = io.BytesIO()
    with pd.ExcelWriter(buf, engine="openpyxl") as writer:
        df_students.to_excel(writer, index=False, sheet_name="Student Data")
        df_summary.to_excel(writer, index=False, sheet_name="Analytics Summary")
        df_ranks.to_excel(writer, index=False, sheet_name="Rank List")
    buf.seek(0)

    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="project_{project_id}.xlsx"'},
    )
