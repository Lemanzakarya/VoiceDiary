# AI Voice Diary Backend API

FastAPI backend server for AI Voice Diary mobile application.

## Setup

### 1. Create Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate  # On macOS/Linux
# or
venv\Scripts\activate  # On Windows
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Environment Configuration

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

### 4. Run Server

```bash
python main.py
```

Or with uvicorn directly:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Server will start at: `http://localhost:8000`

API Documentation: `http://localhost:8000/docs`

## API Endpoints

### Upload Audio
```
POST /upload-audio
Content-Type: multipart/form-data

Body:
- file: audio file (.m4a, .mp3, .wav, .aac)

Response:
{
  "message": "Audio uploaded successfully",
  "entry": {
    "id": 1,
    "audio_file_path": "uploads/xxx.m4a",
    "transcription_text": null,
    "sentiment_label": null,
    "sentiment_score": null,
    "ai_feedback": null,
    "created_at": "2026-02-18T10:00:00"
  }
}
```

### Get All Entries
```
GET /entries?skip=0&limit=100

Response:
{
  "entries": [...],
  "total": 10
}
```

### Get Single Entry
```
GET /entries/{entry_id}

Response:
{
  "id": 1,
  "audio_file_path": "uploads/xxx.m4a",
  ...
}
```

### Delete Entry
```
DELETE /entries/{entry_id}

Response:
{
  "message": "Entry deleted successfully"
}
```

### Get Audio File
```
GET /audio/{entry_id}

Returns: Audio file stream
```

### Health Check
```
GET /health

Response:
{
  "status": "healthy",
  "timestamp": "2026-02-18T10:00:00"
}
```

## Database

SQLite database (`voice_diary.db`) is automatically created on first run.

## File Storage

Audio files are stored in `./uploads/` directory.

## Next Steps (Faz 3)

- Integrate Hugging Face API for Speech-to-Text
- Add Sentiment Analysis
- Add AI Feedback Generation
