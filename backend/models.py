from sqlalchemy import Column, Integer, String, Float, DateTime, Text
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime

Base = declarative_base()

class DiaryEntry(Base):
    __tablename__ = "diary_entries"

    id = Column(Integer, primary_key=True, index=True)
    audio_file_path = Column(String, nullable=False)
    transcription_text = Column(Text, nullable=True)
    sentiment_label = Column(String, nullable=True)  # positive, negative, neutral
    sentiment_score = Column(Float, nullable=True)
    ai_feedback = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "audio_file_path": self.audio_file_path,
            "transcription_text": self.transcription_text,
            "sentiment_label": self.sentiment_label,
            "sentiment_score": self.sentiment_score,
            "ai_feedback": self.ai_feedback,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
