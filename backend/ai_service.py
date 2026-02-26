"""
AI Service for Voice Diary Application
Handles: Speech-to-Text, Sentiment Analysis, AI Feedback

Uses Hugging Face Inference API (free tier) — no local GPU or
multi-GB model downloads required.

Required env var:
    HF_API_TOKEN  –  Get yours free at https://huggingface.co/settings/tokens
"""

import os
import time
import math
import struct
import subprocess
import requests
import urllib3
from huggingface_hub import InferenceClient
from typing import Dict, Optional

# Suppress SSL warnings for LibreSSL compatibility on macOS
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ── Hugging Face model config ──────────────────────────────────────
WHISPER_MODEL = "openai/whisper-large-v3-turbo"
CHAT_MODEL = "Qwen/Qwen2.5-72B-Instruct"

# ffmpeg absolute path (nohup/background processes may not have /opt/homebrew/bin in PATH)
FFMPEG_PATH = "/opt/homebrew/bin/ffmpeg"

# HF Inference API base for raw requests (whisper needs custom Content-Type)
HF_API_URL = "https://router.huggingface.co/hf-inference/models"


class AIService:
    """Calls Hugging Face hosted Inference API for all AI tasks."""

    def __init__(self):
        self.api_token = os.getenv("HF_API_TOKEN", "")
        if not self.api_token:
            raise ValueError(
                "HF_API_TOKEN ortam değişkeni tanımlı değil. "
                "https://huggingface.co/settings/tokens adresinden ücretsiz token alın "
                "ve backend/.env dosyasına HF_API_TOKEN=hf_... şeklinde ekleyin."
            )
        self.headers = {"Authorization": f"Bearer {self.api_token}"}
        self.hf_client = InferenceClient(token=self.api_token)
        print("✅ AI Service initialized (Hugging Face Inference API)")

    # ── 1. Speech-to-Text (Whisper) ───────────────────────────────
    def transcribe_audio(self, audio_path: str) -> Dict[str, any]:
        """Transcribe audio file using HF Whisper API via raw requests
        (we must set Content-Type: audio/m4a explicitly)."""
        try:
            print(f"🎤 Transcribing: {audio_path}", flush=True)
            with open(audio_path, "rb") as f:
                audio_bytes = f.read()
            print(f"   Audio size: {len(audio_bytes)} bytes", flush=True)

            url = f"{HF_API_URL}/{WHISPER_MODEL}"
            headers = {**self.headers, "Content-Type": "audio/m4a"}

            for attempt in range(5):
                try:
                    resp = requests.post(url, headers=headers, data=audio_bytes,
                                         timeout=180, verify=False)
                    print(f"   Whisper HTTP {resp.status_code} (deneme {attempt+1})", flush=True)

                    if resp.status_code == 503:
                        wait = 20
                        try:
                            wait = resp.json().get("estimated_time", 20)
                        except Exception:
                            pass
                        print(f"   ⏳ Model yükleniyor ~{wait:.0f}s…", flush=True)
                        time.sleep(min(wait, 60))
                        continue

                    resp.raise_for_status()
                    result = resp.json()
                    text = result.get("text", "").strip()
                    print(f"   ✅ Transcription: {text[:80]}…", flush=True)
                    return {"text": text, "language": "auto"}

                except requests.exceptions.HTTPError:
                    raise
                except Exception as e:
                    print(f"   Whisper retry {attempt+1}: {e}", flush=True)
                    time.sleep(5)

            raise Exception("Whisper 5 denemede yanıt vermedi")
        except Exception as e:
            print(f"❌ Transcription error: {e}", flush=True)
            raise Exception(f"Transcription failed: {e}")

    # ── 1b. Audio Acoustic Analysis ────────────────────────────
    def analyze_audio_features(self, audio_path: str) -> Dict[str, any]:
        """Extract acoustic features from audio using ffmpeg.
        Returns voice energy, variation, and descriptive cues."""
        try:
            # Convert to raw PCM via ffmpeg
            result = subprocess.run(
                [FFMPEG_PATH, '-i', audio_path, '-f', 's16le', '-acodec', 'pcm_s16le',
                 '-ar', '16000', '-ac', '1', '-'],
                capture_output=True, stdin=subprocess.DEVNULL, timeout=15
            )
            raw = result.stdout
            if len(raw) < 200:
                return {"description": "Ses analizi yapılamadı", "energy_level": "unknown"}

            samples = struct.unpack(f'<{len(raw)//2}h', raw)
            n = len(samples)
            sr = 16000

            # RMS energy
            rms = math.sqrt(sum(s*s for s in samples) / n)
            peak = max(abs(s) for s in samples)

            # Energy variation across 0.5s segments
            seg_size = sr // 2
            segments = [samples[i:i+seg_size] for i in range(0, n, seg_size)]
            energies = [math.sqrt(sum(s*s for s in seg) / len(seg))
                        for seg in segments if len(seg) > 100]

            if energies:
                energy_mean = sum(energies) / len(energies)
                energy_std = math.sqrt(sum((e - energy_mean)**2 for e in energies) / len(energies))
                energy_cv = energy_std / energy_mean if energy_mean > 0 else 0
            else:
                energy_cv = 0

            # Zero-crossing rate (correlates with pitch/excitement)
            zero_crossings = sum(1 for i in range(1, n) if
                                 (samples[i] >= 0) != (samples[i-1] >= 0))
            zcr = zero_crossings / n

            # Build descriptive cues
            cues = []
            if rms > 3000:
                cues.append("yüksek sesle konuşuyor (heyecanlı veya sinirli olabilir)")
            elif rms > 1500:
                cues.append("normal ses seviyesinde konuşuyor")
            elif rms > 500:
                cues.append("kısık sesle konuşuyor (sakin veya üzgün olabilir)")
            else:
                cues.append("çok sessiz konuşuyor")

            if energy_cv > 0.6:
                cues.append("ses tonu çok değişken (duygusal, gülen veya ağlayan)")
            elif energy_cv > 0.35:
                cues.append("ses tonunda belirgin değişimler var (canlı konuşma)")
            else:
                cues.append("ses tonu monoton ve düz")

            if zcr > 0.15:
                cues.append("yüksek frekanslı sesler var (gülme, heyecan belirtisi)")
            elif zcr < 0.05:
                cues.append("düşük tonlu, ağır konuşma")

            if peak > 20000:
                cues.append("ani yüksek sesler var (kahkaha, bağırma veya vurgu)")

            description = "; ".join(cues)
            energy_level = "high" if rms > 2000 else ("medium" if rms > 800 else "low")

            print(f"   🔊 Audio: RMS={rms:.0f}, CV={energy_cv:.2f}, ZCR={zcr:.3f} → {energy_level}", flush=True)
            print(f"   🔊 Cues: {description}", flush=True)

            return {
                "description": description,
                "energy_level": energy_level,
                "rms": rms,
                "energy_cv": energy_cv,
                "zcr": zcr,
            }
        except Exception as e:
            print(f"⚠️ Audio analysis fallback: {e}", flush=True)
            return {"description": "Ses tonu analizi yapılamadı", "energy_level": "unknown"}

    # ── 2. Sentiment Analysis (Qwen – metin + ses tonu) ──────────
    def analyze_sentiment(self, text: str, voice_cues: str = "") -> Dict[str, any]:
        """Analyze sentiment using Qwen – combines text content with voice tone cues."""
        try:
            print(f"💭 Sentiment: {text[:50]}…", flush=True)

            if len(text.split()) > 400:
                text = " ".join(text.split()[:400])

            voice_section = ""
            if voice_cues:
                voice_section = (
                    "\n\nÖNEMLİ - Ses tonu bilgisi (akustik analiz sonucu):\n"
                    "Aşağıdaki ses tonu ipuçlarını duygu tespitinde MUTLAKA dikkate al. "
                    "Metin nötr görünse bile ses tonu duygusal olabilir. "
                    "Ses tonu bilgisi metinden daha güvenilirdir çünkü doğrudan ses dalgasından ölçülmüştür.\n"
                )

            messages = [
                {
                    "role": "system",
                    "content": (
                        "Sen bir duygu analizi uzmanısın. Sana verilen METİN ve SES TONU bilgisini birlikte değerlendirerek "
                        "kişinin duygu durumunu analiz et.\n"
                        "SADECE aşağıdaki JSON formatında yanıt ver, başka hiçbir şey yazma:\n"
                        '{"label": "positive|negative|neutral", "score": 0.0-1.0}\n\n'
                        "Kurallar:\n"
                        "- positive: mutluluk, sevinç, heyecan, memnuniyet, şükran, umut, gülme, canlılık\n"
                        "- negative: üzüntü, kızgınlık, öfke, hayal kırıklığı, korku, endişe, stres\n"
                        "- neutral: SADECE hem metin hem ses tonu gerçekten nötrse\n"
                        "- score: duygunun ne kadar güçlü olduğu (0.5 = zayıf, 1.0 = çok güçlü)\n"
                        "- Ses tonu yüksek, değişken veya heyecanlıysa → nötr olma ihtimali çok düşüktür\n"
                        "- Gülme, kahkaha, yüksek enerji → positive\n"
                        "- Kısık, monoton, ağır ses → olası negative veya neutral\n"
                        "- Sadece JSON döndür, açıklama yazma."
                    )
                },
                {
                    "role": "user",
                    "content": (
                        f"METİN: \"{text}\""
                        f"{voice_section}"
                        f"{('Ses tonu ipuçları: ' + voice_cues) if voice_cues else ''}"
                    )
                }
            ]

            result = self.hf_client.chat_completion(
                messages=messages,
                model=CHAT_MODEL,
                max_tokens=50,
                temperature=0.1,  # Deterministic for consistent classification
            )

            raw = result.choices[0].message.content.strip()
            print(f"   Raw sentiment response: {raw}", flush=True)

            # Parse JSON response
            import json
            # Handle cases where model wraps JSON in markdown code blocks
            if "```" in raw:
                raw = raw.split("```")[1]
                if raw.startswith("json"):
                    raw = raw[4:]
                raw = raw.strip()

            parsed = json.loads(raw)
            label = parsed.get("label", "neutral").lower().strip()
            score = float(parsed.get("score", 0.5))

            # Validate label
            if label not in ("positive", "negative", "neutral"):
                label = "neutral"
            # Clamp score
            score = max(0.0, min(1.0, score))

            print(f"   ✅ Sentiment: {label} ({score:.2f})", flush=True)
            return {"label": label, "score": score}

        except Exception as e:
            print(f"❌ Sentiment error: {e}", flush=True)
            return {"label": "neutral", "score": 0.5}

    # ── 3. AI Feedback (Chat Completion) ──────────────────────────
    def generate_feedback(self, transcription: str, sentiment: str) -> str:
        """Generate empathetic Turkish feedback via chat completion."""
        try:
            print(f"🧠 Feedback ({sentiment})…", flush=True)

            sentiment_tr = {
                "positive": "mutlu ve pozitif",
                "negative": "üzgün veya sıkıntılı",
                "neutral": "sakin ve düşünceli"
            }.get(sentiment, "düşünceli")

            messages = [
                {
                    "role": "system",
                    "content": (
                        "Sen empatik bir ses günlüğü asistanısın. "
                        "Kullanıcının ses kaydını dinledin ve analiz ettin. "
                        "Türkçe, sıcak, samimi ve destekleyici bir geri bildirim yaz. "
                        "Maksimum 3 cümle. Kısa ve öz ol."
                    )
                },
                {
                    "role": "user",
                    "content": (
                        f"Kullanıcının söylediği: \"{transcription[:500]}\"\n"
                        f"Duygu durumu: {sentiment_tr}"
                    )
                }
            ]

            result = self.hf_client.chat_completion(
                messages=messages,
                model=CHAT_MODEL,
                max_tokens=200,
                temperature=0.7,
            )

            feedback = result.choices[0].message.content.strip()
            print(f"   ✅ Feedback: {feedback[:80]}…", flush=True)
            return feedback

        except Exception as e:
            print(f"⚠️ Feedback fallback: {e}", flush=True)
            fallback = {
                "positive": "Harika! Mutluluğunuzu paylaştığınız için teşekkürler. Bu olumlu enerjinizi korumaya devam edin!",
                "negative": "Anlıyorum, zor zamanlardan geçiyorsunuz. Bu duyguları paylaşmak önemli. Her şey düzelecek, sabırlı olun.",
                "neutral": "Düşüncelerinizi paylaştığınız için teşekkürler. Kendinizi ifade etmek sağlıklı bir alışkanlık."
            }
            return fallback.get(sentiment, fallback["neutral"])

    # ── Full pipeline ─────────────────────────────────────────────
    def process_audio_full(self, audio_path: str) -> Dict[str, any]:
        """Complete AI pipeline: Transcription → Sentiment → Feedback"""
        try:
            pipeline_start = time.time()

            # Step 1: Transcribe
            t0 = time.time()
            transcription_result = self.transcribe_audio(audio_path)
            transcription_text = transcription_result["text"]
            print(f"   ⏱ Whisper: {time.time()-t0:.1f}s", flush=True)

            if not transcription_text or len(transcription_text.strip()) < 5:
                return {
                    "transcription_text": "Ses kaydı anlaşılamadı.",
                    "sentiment_label": "neutral",
                    "sentiment_score": 0.5,
                    "ai_feedback": "Ses kalitesi düşük olduğu için analiz yapılamadı. Lütfen daha net kayıt yapın.",
                    "language": "unknown"
                }

            # Step 1b: Acoustic analysis (parallel-safe, uses ffmpeg)
            t0b = time.time()
            audio_features = self.analyze_audio_features(audio_path)
            voice_cues = audio_features.get("description", "")
            print(f"   ⏱ Audio analysis: {time.time()-t0b:.1f}s", flush=True)

            # Step 2: Sentiment Analysis (text + voice cues)
            t1 = time.time()
            sentiment_result = self.analyze_sentiment(transcription_text, voice_cues)
            print(f"   ⏱ Sentiment: {time.time()-t1:.1f}s", flush=True)

            # Step 3: Generate Feedback
            t2 = time.time()
            ai_feedback = self.generate_feedback(
                transcription_text,
                sentiment_result["label"]
            )
            print(f"   ⏱ Feedback: {time.time()-t2:.1f}s", flush=True)
            print(f"   ⏱ Total pipeline: {time.time()-pipeline_start:.1f}s", flush=True)

            return {
                "transcription_text": transcription_text,
                "sentiment_label": sentiment_result["label"],
                "sentiment_score": sentiment_result["score"],
                "ai_feedback": ai_feedback,
                "language": transcription_result.get("language", "auto")
            }
        except Exception as e:
            print(f"❌ Full AI processing error: {e}", flush=True)
            raise Exception(f"AI processing failed: {e}")


# ── Singleton ─────────────────────────────────────────────────────
_ai_service: Optional[AIService] = None


def get_ai_service() -> AIService:
    """Get or create AI service singleton."""
    global _ai_service
    if _ai_service is None:
        _ai_service = AIService()
    return _ai_service
