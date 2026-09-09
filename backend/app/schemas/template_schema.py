from pydantic import BaseModel
from typing import Optional, List, Any
from uuid import UUID
from datetime import datetime


class ColumnDefinition(BaseModel):
    order: int
    type: str       # sr_no, course_code, course_name, credits, grade, grade_point, earned_gp, remark
    label: str


class TemplateCreate(BaseModel):
    name: str
    columns: List[ColumnDefinition] = []


class TemplateResponse(TemplateCreate):
    id: UUID
    teacher_id: UUID
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
