from pydantic import BaseModel
from typing import Optional, List
from uuid import UUID
from datetime import datetime


class ProjectBase(BaseModel):
    name: str
    program: Optional[str] = None
    examination: Optional[str] = None
    semester: Optional[str] = None


class ProjectCreate(ProjectBase):
    pass


class ProjectResponse(ProjectBase):
    id: UUID
    teacher_id: UUID
    status: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
