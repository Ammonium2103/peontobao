import os
import json
import sqlite3
import logging
from fastapi import FastAPI, HTTPException, UploadFile, File
from pydantic import BaseModel
from openai import OpenAI
from dotenv import load_dotenv
from datetime import datetime

# --- JARVIS SUPREME CORE v9.0 ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - [%(levelname)s] - %(message)s')
logger = logging.getLogger("JarvisNeuralCore")

load_dotenv()
app = FastAPI()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Neural Memory & Skill Database
def init_db():
    conn = sqlite3.connect("memory.db", check_same_thread=False)
    c = conn.cursor()
    # 1. Ký ức hội thoại
    c.execute("CREATE TABLE IF NOT EXISTS memory (id INTEGER PRIMARY KEY, text TEXT, role TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)")
    # 2. Quản lý tài chính
    c.execute("CREATE TABLE IF NOT EXISTS finances (id INTEGER PRIMARY KEY, item TEXT, amount REAL, category TEXT, date DATE)")
    # 3. Nhắc nhở thông minh
    c.execute("CREATE TABLE IF NOT EXISTS reminders (id INTEGER PRIMARY KEY, task TEXT, time TEXT, status TEXT DEFAULT 'pending')")
    conn.commit()
    return conn

db_conn = init_db()

class ChatRequest(BaseModel):
    text: str

@app.post("/chat")
async def chat_with_jarvis(req: ChatRequest):
    cursor = db_conn.cursor()
    # Lấy lịch sử hội thoại
    rows = cursor.execute("SELECT role, text FROM memory ORDER BY id DESC LIMIT 5").fetchall()
    context = [{"role": r[0], "content": r[1]} for r in reversed(rows)]
    
    # Prompt Engineering: SUPREME AGENT LOGIC
    system_prompt = (
        "You are JARVIS, a supreme AI. You have advanced skills: "
        "1. FINANCIAL: To track spending (Action: ADD_EXPENSE, list: GET_EXPENSES). "
        "2. REMINDERS: To set tasks (Action: ADD_REMINDER). "
        "3. KNOWLEDGE/WEATHER: Use your internal knowledge or search simulation. "
        "Return response as plain text but ALWAYS perform the database actions internally if user mentions money or tasks. "
        "Speak in Vietnamese, be concise and elite."
    )

    try:
        # LLM Reasoning
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "system", "content": system_prompt}] + context + [{"role": "user", "content": req.text}],
            temperature=0.7
        )
        ai_text = response.choices[0].message.content

        # Logic thực thi ngầm (Data Scientist logic)
        text_lower = req.text.lower()
        if "tiêu" in text_lower or "chi" in text_lower or "vnđ" in text_lower:
            # Giả lập bốc tách số tiền (sếp có thể nâng cấp regex sau)
            logger.info("Financial Skill Triggered")
        elif "nhắc" in text_lower or "lúc" in text_lower:
            logger.info("Reminder Skill Triggered")

        # Lưu ký ức
        cursor.execute("INSERT INTO memory (text, role) VALUES (?, ?)", (req.text, "user"))
        cursor.execute("INSERT INTO memory (text, role) VALUES (?, ?)", (ai_text, "assistant"))
        db_conn.commit()

        return {"response": ai_text}
    except Exception as e:
        return {"response": "Hệ thần kinh đang quá tải, sếp ạ."}

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
    except:
        return {"text": ""}
