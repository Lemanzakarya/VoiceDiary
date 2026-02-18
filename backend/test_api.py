"""
Test script for API endpoints
Run server first: python main.py
Then run: python test_api.py
"""

import requests
import os

BASE_URL = "http://localhost:8000"

def test_health():
    """Test health check"""
    print("🔍 Testing health check...")
    response = requests.get(f"{BASE_URL}/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}\n")

def test_upload_audio():
    """Test audio upload"""
    print("🔍 Testing audio upload...")
    
    # Create a dummy audio file for testing
    test_file = "test_audio.m4a"
    with open(test_file, "wb") as f:
        f.write(b"dummy audio content")
    
    try:
        with open(test_file, "rb") as f:
            files = {"file": (test_file, f, "audio/m4a")}
            response = requests.post(f"{BASE_URL}/upload-audio", files=files)
        
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}\n")
        
        if response.status_code == 200:
            return response.json()["entry"]["id"]
    finally:
        # Clean up test file
        if os.path.exists(test_file):
            os.remove(test_file)
    
    return None

def test_get_entries():
    """Test get all entries"""
    print("🔍 Testing get all entries...")
    response = requests.get(f"{BASE_URL}/entries")
    print(f"Status: {response.status_code}")
    data = response.json()
    print(f"Total entries: {data['total']}\n")
    return data

def test_get_entry(entry_id):
    """Test get single entry"""
    print(f"🔍 Testing get entry {entry_id}...")
    response = requests.get(f"{BASE_URL}/entries/{entry_id}")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}\n")

def test_delete_entry(entry_id):
    """Test delete entry"""
    print(f"🔍 Testing delete entry {entry_id}...")
    response = requests.delete(f"{BASE_URL}/entries/{entry_id}")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}\n")

if __name__ == "__main__":
    print("=" * 50)
    print("AI Voice Diary API Test Script")
    print("=" * 50 + "\n")
    
    # Test health
    test_health()
    
    # Test upload
    entry_id = test_upload_audio()
    
    if entry_id:
        # Test get all entries
        test_get_entries()
        
        # Test get single entry
        test_get_entry(entry_id)
        
        # Test delete
        test_delete_entry(entry_id)
        
        # Verify deletion
        test_get_entries()
    
    print("✅ All tests completed!")
