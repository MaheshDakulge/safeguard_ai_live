from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import projects, upload, review, analytics, export, templates

app = FastAPI(
    title="Marksheet Analytics API",
    description="Backend for scanning, processing and analysing college marksheets.",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],      # tighten in production
    allow_credentials=False,  # Set to False because we use Authorization header, not cookies. This solves Chrome CORS errors.
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include all routers
app.include_router(projects.router)
app.include_router(upload.router)
app.include_router(review.router)
app.include_router(analytics.router)
app.include_router(export.router)
app.include_router(templates.router)


@app.get("/", tags=["health"])
async def health():
    return {"status": "ok", "service": "Marksheet Analytics API v2"}
