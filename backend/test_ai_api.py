"""
Test AI API Endpoints
Tests audio upload and AI processing
"""

import requests
import time
import os

BASE_URL = "http://localhost:8000"

def test_upload_and_process():
    """Test audio upload with AI processing"""
    
    print("🧪 Testing AI Voice Diary API...\n")
    
    # Test 1: Health Check
    print("1️⃣ Health Check:")
    response = requests.get(f"{BASE_URL}/health")
    print(f"   Status: {response.json()['status']}")
    print()
    
    # Test 2: Create test audio file
    print("2️⃣ Creating test audio file...")
    # Create a simple .m4a file (just for testing structure, not real audio)
    test_audio_path = "/tmp/test_voice.m4a"
    with open(test_audio_path, "wb") as f:
        f.write(b"FAKE_AUDIO_DATA_FOR_TESTING")  # Not real audio
    print(f"   Created: {test_audio_path}")
    print()
    
    # Test 3: Upload audio
    print("3️⃣ Uploading audio file...")
    with open(test_audio_path, "rb") as f:
        files = {"file": ("test_voice.m4a", f, "audio/m4a")}
        response = requests.post(f"{BASE_URL}/upload-audio", files=files)
    
    if response.status_code == 200:
        result = response.json()
        entry_id = result["entry"]["id"]
        print(f"   ✅ Upload successful!")
        print(f"   Entry ID: {entry_id}")
        print(f"   Message: {result['message']}")
        print()
        
        # Test 4: Check entry status (before AI processing)
        print("4️⃣ Checking entry status...")
        response = requests.get(f"{BASE_URL}/entries/{entry_id}")
        entry = response.json()
        print(f"   Transcription: {entry.get('transcription_text', 'None')}")
        print(f"   Sentiment: {entry.get('sentiment_label', 'None')}")
        print(f"   AI Feedback: {entry.get('ai_feedback', 'None')}")
        print()
        
        # Test 5: Wait for AI processing
        print("5️⃣ Waiting for AI processing (this may take a while)...")
        print("   Note: With fake audio, AI will likely fail gracefully")
        time.sleep(10)  # Wait 10 seconds for background task
        
        # Test 6: Check final entry status
        print("\n6️⃣ Final entry status:")
        response = requests.get(f"{BASE_URL}/entries/{entry_id}")
        entry = response.json()
        print(f"   Transcription: {entry.get('transcription_text', 'None')}")
        print(f"   Sentiment: {entry.get('sentiment_label', 'None')}")
        print(f"   Sentiment Score: {entry.get('sentiment_score', 'None')}")
        print(f"   AI Feedback: {entry.get('ai_feedback', 'None')[:100]}..." if entry.get('ai_feedback') else "   AI Feedback: None")
        print()
        
        # Test 7: List all entries
        print("7️⃣ Listing all entries:")
        response = requests.get(f"{BASE_URL}/entries")
        entries_data = response.json()
        print(f"   Total entries: {entries_data['total']}")
        print()
        
        print("✅ All tests completed!")
        
    else:
        print(f"   ❌ Upload failed: {response.text}")
    
    # Cleanup
    if os.path.exists(test_audio_path):
        os.remove(test_audio_path)

if __name__ == "__main__":
    try:
        test_upload_and_process()
    except Exception as e:
        print(f"❌ Test error: {e}")
