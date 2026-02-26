"""
AI Service for Voice Diary Application
Handles: Speech-to-Text, Sentiment Analysis, AI Feedback
Uses: Hugging Face Transformers + OpenAI Whisper
"""

import os
import torch
from transformers import pipeline
from typing import Dict, Optional
import whisper

class AIService:
    def __init__(self):
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"🤖 AI Service initializing on device: {self.device}")
        
        # Initialize Whisper for Speech-to-Text
        print("📝 Loading Whisper model...")
        self.whisper_model = whisper.load_model("base", device=self.device)
        
        # Initialize Sentiment Analysis
        print("💭 Loading Sentiment Analysis model...")
        self.sentiment_analyzer = pipeline(
            "sentiment-analysis",
            model="distilbert-base-uncased-finetuned-sst-2-english",
            device=0 if self.device == "cuda" else -1
        )
        
        # Initialize Text Generation for AI Feedback
        print("🧠 Loading Text Generation model...")
        self.text_generator = pipeline(
            "text-generation",
            model="gpt2",
            device=0 if self.device == "cuda" else -1,
            max_length=200
        )
        
        print("✅ AI Service initialized successfully!")
    
    def transcribe_audio(self, audio_path: str) -> Dict[str, any]:
        """
        Transcribe audio file to text using Whisper
        
        Args:
            audio_path: Path to audio file
            
        Returns:
            Dict with transcription text and language
        """
        try:
            print(f"🎤 Transcribing audio: {audio_path}")
            result = self.whisper_model.transcribe(audio_path)
            
            return {
                "text": result["text"].strip(),
                "language": result.get("language", "unknown")
            }
        except Exception as e:
            print(f"❌ Transcription error: {str(e)}")
            raise Exception(f"Transcription failed: {str(e)}")
    
    def analyze_sentiment(self, text: str) -> Dict[str, any]:
        """
        Analyze sentiment of text
        
        Args:
            text: Text to analyze
            
        Returns:
            Dict with sentiment label and score
        """
        try:
            print(f"💭 Analyzing sentiment for text: {text[:50]}...")
            
            # Truncate text if too long (max 512 tokens for BERT)
            max_length = 512
            if len(text.split()) > max_length:
                text = " ".join(text.split()[:max_length])
            
            result = self.sentiment_analyzer(text)[0]
            
            # Map to our labels
            label_map = {
                "POSITIVE": "positive",
                "NEGATIVE": "negative",
            }
            
            sentiment_label = label_map.get(result["label"], "neutral")
            sentiment_score = result["score"]
            
            return {
                "label": sentiment_label,
                "score": sentiment_score
            }
        except Exception as e:
            print(f"❌ Sentiment analysis error: {str(e)}")
            return {
                "label": "neutral",
                "score": 0.5
            }
    
    def generate_feedback(self, transcription: str, sentiment: str) -> str:
        """
        Generate AI feedback based on transcription and sentiment
        
        Args:
            transcription: Transcribed text
            sentiment: Sentiment label (positive/negative/neutral)
            
        Returns:
            AI-generated feedback text
        """
        try:
            print(f"🧠 Generating feedback for {sentiment} sentiment...")
            
            # Create prompt based on sentiment
            if sentiment == "positive":
                prompt = f"The person said: '{transcription[:100]}'. They seem happy. Provide encouraging feedback: "
            elif sentiment == "negative":
                prompt = f"The person said: '{transcription[:100]}'. They seem troubled. Provide supportive feedback: "
            else:
                prompt = f"The person said: '{transcription[:100]}'. Provide thoughtful feedback: "
            
            result = self.text_generator(
                prompt,
                max_length=150,
                num_return_sequences=1,
                temperature=0.7,
                do_sample=True
            )
            
            feedback = result[0]["generated_text"].replace(prompt, "").strip()
            
            # Clean up and limit length
            sentences = feedback.split(".")
            feedback = ". ".join(sentences[:3]) + "."
            
            return feedback
        except Exception as e:
            print(f"❌ Feedback generation error: {str(e)}")
            
            # Fallback responses
            fallback_responses = {
                "positive": "Harika! Mutluluğunuzu paylaştığınız için teşekkürler. Bu olumlu enerjinizi korumaya devam edin!",
                "negative": "Anlıyorum, zor zamanlardan geçiyorsunuz. Bu duyguları paylaşmak önemli. Her şey düzelecek, sabırlı olun.",
                "neutral": "Düşüncelerinizi paylaştığınız için teşekkürler. Kendinizi ifade etmek sağlıklı bir alışkanlık."
            }
            
            return fallback_responses.get(sentiment, fallback_responses["neutral"])
    
    def process_audio_full(self, audio_path: str) -> Dict[str, any]:
        """
        Complete AI pipeline: Transcription -> Sentiment -> Feedback
        
        Args:
            audio_path: Path to audio file
            
        Returns:
            Dict with all AI analysis results
        """
        try:
            # Step 1: Transcribe
            transcription_result = self.transcribe_audio(audio_path)
            transcription_text = transcription_result["text"]
            
            if not transcription_text or len(transcription_text.strip()) < 5:
                return {
                    "transcription_text": "Ses kaydı anlaşılamadı.",
                    "sentiment_label": "neutral",
                    "sentiment_score": 0.5,
                    "ai_feedback": "Ses kalitesi düşük olduğu için analiz yapılamadı. Lütfen daha net kayıt yapın.",
                    "language": "unknown"
                }
            
            # Step 2: Sentiment Analysis
            sentiment_result = self.analyze_sentiment(transcription_text)
            
            # Step 3: Generate Feedback
            ai_feedback = self.generate_feedback(
                transcription_text,
                sentiment_result["label"]
            )
            
            return {
                "transcription_text": transcription_text,
                "sentiment_label": sentiment_result["label"],
                "sentiment_score": sentiment_result["score"],
                "ai_feedback": ai_feedback,
                "language": transcription_result["language"]
            }
        except Exception as e:
            print(f"❌ Full AI processing error: {str(e)}")
            raise Exception(f"AI processing failed: {str(e)}")

# Global instance
ai_service: Optional[AIService] = None

def get_ai_service() -> AIService:
    """Get or create AI service singleton"""
    global ai_service
    if ai_service is None:
        ai_service = AIService()
    return ai_service
