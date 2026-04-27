import os
import json
import sqlite3
import logging
from fastapi import FastAPI, HTTPException, UploadFile, File
from pydantic import BaseModel
from openai import OpenAI
from dotenv import load_dotenv
from datetime import datetime

# --- JARVIS SKILL ENGINE v8.0 ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - [%(levelname)s] - %(message)s')
logger = logging.getLogger("JarvisNeuralCore")

load_dotenv()
app = FastAPI()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Neural Memory System
def init_db():
    conn = sqlite3.connect("memory.db", check_same_thread=False)
    c = conn.cursor()
    c.execute("CREATE TABLE IF NOT EXISTS memory (id INTEGER PRIMARY KEY, text TEXT, role TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)")
    c.execute("CREATE TABLE IF NOT EXISTS skills (name TEXT PRIMARY KEY, description TEXT, action_code TEXT)")
    conn.commit()
    return conn

db_conn = init_db()

class ChatRequest(BaseModel):
    text: str

@app.post("/chat")
async def chat_with_jarvis(req: ChatRequest):
    cursor = db_conn.cursor()
    rows = cursor.execute("SELECT role, text FROM memory ORDER BY id DESC LIMIT 5").fetchall()
    context = [{"role": r[0], "content": r[1]} for r in reversed(rows)]
    
    # Prompt Engineering: SKILL-AWARE PERSONA
    system_prompt = (
        "You are JARVIS. You have a SKILL SYSTEM. "
        "When the user asks for something, check if it fits a specific skill. "
        "Skills available: OPEN_APP, SEARCH, WEATHER, SYSTEM_CONTROL, IOT_CONTROL. "
        "Speak in Vietnamese, be sophisticated and efficient."
    )

    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "system", "content": system_prompt}] + context + [{"role": "user", "content": req.text}],
            temperature=0.7
        )
        ai_text = response.choices[0].message.content
        cursor.execute("INSERT INTO memory (text, role) VALUES (?, ?)", (req.text, "user"))
        cursor.execute("INSERT INTO memory (text, role) VALUES (?, ?)", (ai_text, "assistant"))
        db_conn.commit()
        return {"response": ai_text}
    except Exception as e:
        return {"response": "Neural Core offline."}

@app.post("/stt")
async def speech_to_text(file: UploadFile = File(...)):
    try:
        temp_filename = "temp_audio.wav"
        with open(temp_filename, "wb") as buffer:
            buffer.write(await file.read())
        audio_file = open(temp_filename, "rb")
        transcript = client.audio.transcriptions.create(model="whisper-1", file=audio_file, language="vi")
        os.remove(temp_filename)
        return {"text": transcript.text}
    except Exception as e:
        return {"text": ""}
