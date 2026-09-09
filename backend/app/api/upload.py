from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, BackgroundTasks
from typing import Optional
from app.core.database import get_supabase
from app.core.security import get_current_teacher
from app.schemas.upload_schema import UploadJobResponse
from app.services.ocr_service import OCRService
from supabase import Client
import uuid

router = APIRouter(prefix="/upload", tags=["upload"])

ocr_service = OCRService()


async def _process_upload(
    job_id: str,
    project_id: str,
    file_bytes: bytes,
    filename: str,
    supabase: Client,
):
    """Background task: runs OCR, inserts results into DB."""
    try:
        # FIX: mark job as processing at the START (was set after done in original)
        supabase.table("upload_jobs").update({"status": "processing"}).eq("id", job_id).execute()
        # FIX: also update project status to processing at the start
        supabase.table("projects").update({"status": "processing"}).eq("id", project_id).execute()

        extracted_students = await ocr_service.process_pdf(file_bytes, filename)

        inserted = 0
        for student_data in extracted_students:
            prn = student_data.get("prn")
            if not prn:
                continue

            # Upsert student master record
            supabase.table("students").upsert({
                "prn": prn,
                "seat_no": student_data.get("seat_no"),
                "name": student_data.get("name", "Unknown"),
                "program": student_data.get("program"),
            }, on_conflict="prn").execute()

            # FIX: delete existing subject_marks for this student+project before re-inserting
            # to prevent duplicate rows on re-upload of the same PDF
            existing_result = (
                supabase.table("student_results")
                .select("id")
                .eq("project_id", project_id)
                .eq("student_prn", prn)
                .execute()
            )
            if existing_result.data:
                old_id = existing_result.data[0]["id"]
                supabase.table("subject_marks").delete().eq("result_id", old_id).execute()

            # Upsert student_result row
            result_row = {
                "project_id": project_id,
                "job_id": job_id,
                "student_prn": prn,
                "examination": student_data.get("examination"),
                "semester": student_data.get("semester"),
                "total_credits": student_data.get("total_credits"),
                "total_egp": student_data.get("total_egp"),
                "sgpa": student_data.get("sgpa"),
                "cgpa": student_data.get("cgpa"),
                "status": student_data.get("status", "pending"),
                "is_flagged": student_data.get("is_flagged", False),
                "errors": student_data.get("errors", []),
            }
            result_resp = supabase.table("student_results").upsert(
                result_row, on_conflict="project_id,student_prn"
            ).execute()
            result_id = result_resp.data[0]["id"]

            # Insert subject_marks (clean insert — old ones deleted above)
            for mark in student_data.get("subject_marks", []):
                mark_data = {k: v for k, v in mark.items()}  # shallow copy
                mark_data["result_id"] = result_id
                supabase.table("subject_marks").insert(mark_data).execute()

            inserted += 1

        supabase.table("upload_jobs").update({
            "status": "done",
            "processed": inserted,
        }).eq("id", job_id).execute()

    except Exception as exc:
        supabase.table("upload_jobs").update({
            "status": "failed",
            "error_message": str(exc),
        }).eq("id", job_id).execute()


@router.post("/{project_id}", response_model=UploadJobResponse, status_code=202)
async def upload_marksheet(
    project_id: str,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    template_id: Optional[str] = Form(None),
    supabase: Client = Depends(get_supabase),
    teacher: dict = Depends(get_current_teacher),
):
    # Verify project ownership
    proj = (
        supabase.table("projects")
        .select("id")
        .eq("id", project_id)
        .eq("teacher_id", teacher["id"])
        .execute()
    )
    if not proj.data:
        raise HTTPException(status_code=404, detail="Project not found")

    file_bytes = await file.read()
    job_id = str(uuid.uuid4())

    job_data = {
        "id": job_id,
        "project_id": project_id,
        "template_id": template_id,
        "status": "queued",
        "file_count": 1,
        "processed": 0,
    }
    result = supabase.table("upload_jobs").insert(job_data).execute()

    background_tasks.add_task(
        _process_upload,
        job_id,
        project_id,
        file_bytes,
        file.filename or "upload.pdf",
        supabase,
    )

    return result.data[0]


@router.get("/{project_id}/status/{job_id}", response_model=UploadJobResponse)
async def get_job_status(
    project_id: str,
    job_id: str,
    supabase: Client = Depends(get_supabase),
    teacher: dict = Depends(get_current_teacher),
):
    proj = (
        supabase.table("projects")
        .select("id")
        .eq("id", project_id)
        .eq("teacher_id", teacher["id"])
        .execute()
    )
    if not proj.data:
        raise HTTPException(status_code=404, detail="Project not found")

    result = (
        supabase.table("upload_jobs")
        .select("*")
        .eq("id", job_id)
        .eq("project_id", project_id)
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Job not found")
    return result.data[0]
