"""
OCR Service — processes PDF marksheets.
Currently returns MOCK data that simulates what Document AI would extract.
Replace _extract_with_document_ai() with actual Google Document AI calls
once you configure the project.
"""
from typing import List, Dict, Any
import random


class OCRService:

    async def process_pdf(self, file_bytes: bytes, filename: str) -> List[Dict[str, Any]]:
        """
        Entry point: Takes raw PDF bytes, returns a list of student data dicts.
        Each dict must have keys matching the student_results + subject_marks schema.
        """
        # TODO: Replace this mock with real Document AI processing.
        return self._mock_extract(filename)

    def _mock_extract(self, filename: str) -> List[Dict[str, Any]]:
        """Returns realistic mock data representing 5 students."""
        courses = [
            {"sr_no": 1, "course_code": "MTM101", "course_name": "Research Methodology & IPR", "credits": 4.0},
            {"sr_no": 2, "course_code": "MTC102", "course_name": "Advanced Algorithms", "credits": 4.0},
            {"sr_no": 3, "course_code": "MTC103", "course_name": "Machine Learning", "credits": 4.0},
            {"sr_no": 4, "course_code": "MTC104", "course_name": "Cloud Computing", "credits": 3.0},
            {"sr_no": 5, "course_code": "MTP101", "course_name": "Lab I", "credits": 2.0},
            {"sr_no": 6, "course_code": "MTP102", "course_name": "Mini Project", "credits": 2.0},
        ]
        grades = ["O", "A+", "A", "B+", "B", "C", "F"]
        grade_points = {"O": 10.0, "A+": 9.0, "A": 8.0, "B+": 7.0, "B": 6.0, "C": 5.0, "F": 0.0}

        students = []
        for i in range(1, 6):
            prn = f"2021030{i:04d}"
            subject_marks = []
            total_egp = 0.0
            total_credits = 0.0
            for c in courses:
                grade = random.choice(grades[:6])  # mostly passing
                gp = grade_points[grade]
                egp = round(gp * c["credits"], 2)
                total_egp += egp
                total_credits += c["credits"]
                subject_marks.append({
                    "sr_no": c["sr_no"],
                    "course_code": c["course_code"],
                    "course_name": c["course_name"],
                    "credits": c["credits"],
                    "grade_obtained": grade,
                    "grade_point": gp,
                    "earned_gp": egp,
                    "remark": "",
                })
            sgpa = round(total_egp / total_credits, 2) if total_credits else 0.0
            students.append({
                "prn": prn,
                "seat_no": f"2115{i:04d}",
                "name": f"Student {i}",
                "program": "M.TECH - COMPUTER SCIENCE & TECHNOLOGY",
                "examination": "End Semester Regular Examinations",
                "semester": "I SEMESTER",
                "total_credits": total_credits,
                "total_egp": total_egp,
                "sgpa": sgpa,
                "cgpa": sgpa,
                "status": "pass" if sgpa >= 5.0 else "fail",
                "is_flagged": False,
                "errors": [],
                "subject_marks": subject_marks,
            })
        return students
