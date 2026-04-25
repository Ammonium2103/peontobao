import os
import json
import sqlite3
import re
import logging
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from openai import OpenAI
from dotenv import load_dotenv

# Logger setup
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

load_dotenv()

app = FastAPI()

# NVIDIA API
NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY", "")
client = OpenAI(
    base_url="https://integrate.api.nvidia.com/v1",
    api_key=NVIDIA_API_KEY
)

# DB Initialization
def init_db():
    conn = sqlite3.connect("memory.db", check_same_thread=False)
    c = conn.cursor()
    c.execute("CREATE TABLE IF NOT EXISTS memory (id INTEGER PRIMARY KEY, text TEXT, role TEXT)")
    c.execute("CREATE TABLE IF NOT EXISTS commands (id INTEGER PRIMARY KEY, action TEXT, target TEXT, value TEXT, status TEXT DEFAULT 'pending')")
    conn.commit()
    return conn

db_conn = init_db()

class Request(BaseModel):
    text: str
    source: str = "pc"

@app.get("/")
def home():
    return {"status": "Jarvis Online", "model": "Meta Llama 3.1 70B"}

def get_memory():
    try:
        cursor = db_conn.cursor()
        rows = cursor.execute("SELECT role, text FROM memory ORDER BY id DESC LIMIT 5").fetchall()
        return [f"{r[0]}: {r[1]}" for r in reversed(rows)]
    except Exception:
        return []

@app.post("/agent")
async def run_agent(req: Request):
    if not NVIDIA_API_KEY:
        raise HTTPException(status_code=500, detail="Missing API Key")

    memory = get_memory()
    
    system_prompt = (
        "You are Jarvis, a PC assistant. Respond ONLY with JSON. "
        "Actions: open_website, search_google, system_control, open_app, none. "
        "Example: {\"action\": \"open_website\", \"target\": \"youtube.com\", \"response\": \"Opening YouTube now.\"}"
    )

    try:
        # Sử dụng model Meta Llama 3.1 70B và ép định dạng JSON
        response = client.chat.completions.create(
            model="meta/llama-3.1-70b-instruct",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"History: {memory}\nUser: {req.text}"}
            ],
            response_format={"type": "json_object"},
            temperature=0.1
        )

        data = json.loads(response.choices[0].message.content)
        
        # Lưu DB
        cursor = db_conn.cursor()
        cursor.execute("INSERT INTO memory (text, role) VALUES (?, ?)", (req.text, "user"))
        cursor.execute("INSERT INTO memory (text, role) VALUES (?, ?)", (data.get("response", ""), "assistant"))
        
        if req.source == "mobile" and data.get("action") != "none":
            cursor.execute("INSERT INTO commands (action, target, value) VALUES (?, ?, ?)",
                          (data["action"], data.get("target", ""), data.get("value", "")))
        
        db_conn.commit()
        return data

    except Exception as e:
        logger.error(f"Error: {e}")
        return {"action": "none", "response": f"Lỗi: {str(e)}"}

@app.get("/poll")
def poll():
    cursor = db_conn.cursor()
    row = cursor.execute("SELECT id, action, target, value FROM commands WHERE status = 'pending' LIMIT 1").fetchone()
    if row:
        cursor.execute("UPDATE commands SET status = 'done' WHERE id = ?", (row[0],))
        db_conn.commit()
        return {"action": row[1], "target": row[2], "value": row[3]}
    return {"action": "none"}
