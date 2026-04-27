import os
import json
import sqlite3
import logging
from fastapi import FastAPI, HTTPException, UploadFile, File
from pydantic import BaseModel
from openai import OpenAI
from dotenv import load_dotenv
from datetime import datetime
from elevenlabs.client import ElevenLabs

# --- AI Architect Module v6.0 ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - [%(levelname)s] - %(message)s')
logger = logging.getLogger("JarvisNeuralCore")

load_dotenv()

app = FastAPI()

# 🧠 OpenAI Engine (Whisper & GPT)
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# 🎧 ElevenLabs Engine (High-quality TTS)
eleven = ElevenLabs(api_key=os.getenv("ELEVENLABS_API_KEY"))

# Neural Memory System
def init_db():
    conn = sqlite3.connect("memory.db", check_same_thread=False)
    c = conn.cursor()
    c.execute("CREATE TABLE IF NOT EXISTS memory (id INTEGER PRIMARY KEY, text TEXT, role TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)")
    conn.commit()
    return conn

db_conn = init_db()

class ChatRequest(BaseModel):
    text: str

@app.get("/")
def health():
    return {"status": "Jarvis Voice Core Online", "version": "6.0.0-Whisper-Eleven"}

@app.post("/chat")
async def chat_with_jarvis(req: ChatRequest):
    # 1. Memory Context
    cursor = db_conn.cursor()
    rows = cursor.execute("SELECT role, text FROM memory ORDER BY id DESC LIMIT 5").fetchall()
    context = [{"role": r[0], "content": r[1]} for r in reversed(rows)]
    
    # 2. LLM Reasoning
    try:
        messages = [{"role": "system", "content": "You are JARVIS. Sophisticated, helpful, and speak in Vietnamese. Be concise."}] + context
        messages.append({"role": "user", "content": req.text})

        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            temperature=0.7
        )
        ai_text = response.choices[0].message.content
        
        # 3. Save Memory
        cursor.execute("INSERT INTO memory (text, role) VALUES (?, ?)", (req.text, "user"))
        cursor.execute("INSERT INTO memory (text, role) VALUES (?, ?)", (ai_text, "assistant"))
        db_conn.commit()

        # 4. Generate Voice with ElevenLabs (Return URL or Stream)
        # ML Engineer: We return the text and the client handles TTS or we can return audio bytes.
        return {"response": ai_text}

    except Exception as e:
        logger.error(f"Brain Error: {e}")
        return {"response": "Hệ thần kinh đang gặp lỗi, sếp ạ."}

@app.post("/stt")
async def speech_to_text(file: UploadFile = File(...)):
    """OpenAI Whisper: Chuyển giọng nói từ APP thành văn bản chuẩn xác"""
    try:
        # Save temp file
        temp_filename = "temp_audio.wav"
        with open(temp_filename, "wb") as buffer:
            buffer.write(await file.read())
            
        audio_file = open(temp_filename, "rb")
        transcript = client.audio.transcriptions.create(
            model="whisper-1", 
            file=audio_file,
            language="vi"
        )
        os.remove(temp_filename)
        return {"text": transcript.text}
    except Exception as e:
        logger.error(f"Whisper Error: {e}")
        return {"text": ""}
