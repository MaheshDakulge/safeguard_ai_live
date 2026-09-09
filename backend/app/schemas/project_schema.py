from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from uuid import UUID
from datetime import datetime


class ProjectBase(BaseModel):
    name: str
    program: Optional[str] = None
    examination: Optional[str] = None
    semester: Optional[str] = None
    passing_marks: Optional[int] = 40
    credits_json: Optional[Dict[str, Any]] = None
    grade_scale: Optional[Dict[str, Any]] = None


class ProjectCreate(ProjectBase):
    pass


class ProjectUpdate(BaseModel):
    name: Optional[str] = None
    program: Optional[str] = None
    examination: Optional[str] = None
    semester: Optional[str] = None
    passing_marks: Optional[int] = None
    credits_json: Optional[Dict[str, Any]] = None
    grade_scale: Optional[Dict[str, Any]] = None


class ProjectResponse(ProjectBase):
    id: UUID
    teacher_id: UUID
    status: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

