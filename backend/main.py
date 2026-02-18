from fastapi import FastAPI, File, UploadFile, HTTPException, Depends
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List, Optional
import os
import uuid
from datetime import datetime
from dotenv import load_dotenv

from database import get_session, init_db
from models import DiaryEntry

load_dotenv()

app = FastAPI(
    title="AI Voice Diary API",
    description="Backend API for AI Voice Diary mobile application",
    version="1.0.0"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
UPLOAD_DIR = os.getenv("UPLOAD_DIR", "./uploads")
MAX_FILE_SIZE = int(os.getenv("MAX_FILE_SIZE", 52428800))  # 50MB
ALLOWED_EXTENSIONS = {".m4a", ".mp3", ".wav", ".aac"}

# Create upload directory
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.on_event("startup")
def startup():
    init_db()
    print("✅ Database initialized")

@app.get("/")
def root():
    return {
        "message": "AI Voice Diary API",
        "version": "1.0.0",
        "status": "running"
    }

@app.post("/upload-audio")
def upload_audio(
    file: UploadFile = File(...),
    session: Session = Depends(get_session)
):
    """
    Upload audio file and create diary entry.
    Later, this will trigger AI analysis pipeline.
    """
    # Validate file extension
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(ALLOWED_EXTENSIONS)}"
        )
    
    # Generate unique filename
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(UPLOAD_DIR, unique_filename)
    
    # Save file
    try:
        contents = file.file.read()
        
        # Check file size
        if len(contents) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=400,
                detail=f"File too large. Max size: {MAX_FILE_SIZE / 1024 / 1024}MB"
            )
        
        with open(file_path, "wb") as f:
            f.write(contents)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error saving file: {str(e)}")
    
    # Create database entry
    try:
        new_entry = DiaryEntry(
            audio_file_path=file_path,
            created_at=datetime.utcnow()
        )
        session.add(new_entry)
        session.commit()
        session.refresh(new_entry)
        
        return {
            "message": "Audio uploaded successfully",
            "entry": new_entry.to_dict()
        }
    except Exception as e:
        # Clean up file if database insert fails
        if os.path.exists(file_path):
            os.remove(file_path)
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.get("/entries")
def get_entries(
    skip: int = 0,
    limit: int = 100,
    session: Session = Depends(get_session)
):
    """Get all diary entries with pagination"""
    try:
        entries = session.query(DiaryEntry).order_by(DiaryEntry.created_at.desc()).offset(skip).limit(limit).all()
        
        return {
            "entries": [entry.to_dict() for entry in entries],
            "total": len(entries)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/entries/{entry_id}")
def get_entry(
    entry_id: int,
    session: Session = Depends(get_session)
):
    """Get single diary entry by ID"""
    try:
        entry = session.query(DiaryEntry).filter(DiaryEntry.id == entry_id).first()
        
        if not entry:
            raise HTTPException(status_code=404, detail="Entry not found")
        
        return entry.to_dict()
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/entries/{entry_id}")
def delete_entry(
    entry_id: int,
    session: Session = Depends(get_session)
):
    """Delete diary entry and associated audio file"""
    try:
        # Get entry first
        entry = session.query(DiaryEntry).filter(DiaryEntry.id == entry_id).first()
        
        if not entry:
            raise HTTPException(status_code=404, detail="Entry not found")
        
        # Delete audio file
        if os.path.exists(entry.audio_file_path):
            os.remove(entry.audio_file_path)
        
        # Delete from database
        session.delete(entry)
        session.commit()
        
        return {"message": "Entry deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/audio/{entry_id}")
def get_audio(
    entry_id: int,
    session: Session = Depends(get_session)
):
    """Stream audio file for playback"""
    try:
        entry = session.query(DiaryEntry).filter(DiaryEntry.id == entry_id).first()
        
        if not entry:
            raise HTTPException(status_code=404, detail="Entry not found")
        
        if not os.path.exists(entry.audio_file_path):
            raise HTTPException(status_code=404, detail="Audio file not found")
        
        return FileResponse(entry.audio_file_path)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
