# AI Ses Günlüğü (Voice Diary)

Sesli günlük tutma uygulaması — ses kaydınızı yapın, AI otomatik olarak metne çevirsin, duygu analizini yapsın ve size kişiselleştirilmiş geri bildirim versin.

## ✨ Özellikler

- 🎙️ **Ses Kaydı** — Başlat, duraklat, devam et, durdur
- 📝 **Otomatik Transkripsiyon** — Whisper Large V3 Turbo ile ses → metin
- 💭 **Duygu Analizi** — Metin + ses tonu analizi (Qwen 2.5-72B)
- 🧠 **AI Geri Bildirim** — Empatik, kişiselleştirilmiş Türkçe geri bildirim
- 📊 **İstatistikler** — Duygu dağılımı, trend grafikleri, kayıt sıklığı
- 🌙 **Karanlık Mod** — Göz dostu tema desteği
- 🔍 **Arama & Filtreleme** — Transkripsiyon araması, duygu filtresi
- 📱 **Offline-first** — İnternet yokken bile kayıt yapılır, sonra analiz edilir

## 🚀 Kurulum

### Backend

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
# .env dosyasına HF_API_TOKEN=hf_... ekleyin
uvicorn main:app --host 0.0.0.0 --port 8000
```

### Flutter

```bash
flutter pub get
flutter run
```

## 🤖 AI Modelleri

| Görev | Model |
|-------|-------|
| Ses → Metin | OpenAI Whisper Large V3 Turbo |
| Akustik Analiz | ffmpeg + custom PCM analizi |
| Duygu Analizi | Qwen 2.5-72B-Instruct |
| Geri Bildirim | Qwen 2.5-72B-Instruct |

Tüm AI modelleri **Hugging Face Inference API** üzerinden çalışır — yerel GPU gerekmez.
