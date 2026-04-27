import os
import json
import sqlite3
import logging
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from openai import OpenAI
from dotenv import load_dotenv
from datetime import datetime

# --- AI Architect & Data Scientist Module ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - [%(levelname)s] - %(message)s')
logger = logging.getLogger("JarvisNeuralCore")

load_dotenv()

app = FastAPI()

# LLM Tuner: NVIDIA API with Deep Reasoning Prompt
NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY", "")
client = OpenAI(
    base_url="https://integrate.api.nvidia.com/v1",
    api_key=NVIDIA_API_KEY
)

# Neural Memory System
def init_db():
    conn = sqlite3.connect("memory.db", check_same_thread=False)
    c = conn.cursor()
    c.execute("""CREATE TABLE IF NOT EXISTS memory (
        id INTEGER PRIMARY KEY, 
        text TEXT, 
        role TEXT, 
        tokens INTEGER,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)""")
    c.execute("""CREATE TABLE IF NOT EXISTS commands (
        id INTEGER PRIMARY KEY, 
        action TEXT, 
        target TEXT, 
        value TEXT, 
        priority INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending')""")
    conn.commit()
    return conn

db_conn = init_db()

class Request(BaseModel):
    text: str
    source: str = "pc"

@app.get("/")
def health_check():
    return {
        "status": "Jarvis Neural Core Online",
        "uptime": datetime.now().isoformat(),
        "version": "3.0.0-PRO"
    }

def get_neural_context():
    cursor = db_conn.cursor()
    rows = cursor.execute("SELECT role, text FROM memory ORDER BY id DESC LIMIT 10").fetchall()
    return [{"role": r[0], "content": r[1]} for r in reversed(rows)]

@app.post("/agent")
async def process_neural_request(req: Request):
    if not NVIDIA_API_KEY:
        raise HTTPException(status_code=500, detail="Missing API Key")

    context = get_neural_context()
    
    # Prompt Engineering: Agentic Reasoning & Persona
    system_prompt = (
        "You are JARVIS, a sophisticated AI entity developed by Stark Industries. "
        "Your tone is professional, British, and slightly witty. "
        "You control the user's PC and provide intelligent assistance. "
        "Output MUST be a valid JSON object. "
        "Actions: open_website (target: URL), search_google (target: query), "
        "system_control (target: volume_up/down/mute, screenshot, media_play_pause), "
        "open_app (target: app name), none (for general chat). "
        "Structure: {'action': '...', 'target': '...', 'value': '...', 'response': '...'}"
    )

    try:
        messages = [{"role": "system", "content": system_prompt}] + context
        messages.append({"role": "user", "content": req.text})

        response = client.chat.completions.create(
            model="meta/llama-3.1-70b-instruct",
            messages=messages,
            response_format={"type": "json_object"},
            temperature=0.4
        )

        data = json.loads(response.choices[0].message.content)
        
        # Data Science: Log and Track
        cursor = db_conn.cursor()
        cursor.execute("INSERT INTO memory (text, role) VALUES (?, ?)", (req.text, "user"))
        cursor.execute("INSERT INTO memory (text, role) VALUES (?, ?)", (data.get('response', ''), "assistant"))
        
        if data.get('action') != "none":
            cursor.execute("INSERT INTO commands (action, target, value) VALUES (?, ?, ?)",
                          (data['action'], data.get('target', ''), data.get('value', '')))
        
        db_conn.commit()
        logger.info(f"Intent Resolved: {data.get('action')} -> {data.get('target')}")
        return data

    except Exception as e:
        logger.error(f"Synaptic Failure: {e}")
        return {"action": "none", "response": "Sếp ơi, có lỗi trong hệ thần kinh. Tôi đang tự sửa chữa."}

@app.get("/poll")
def poll_neural_commands():
    cursor = db_conn.cursor()
    row = cursor.execute("SELECT id, action, target, value FROM commands WHERE status = 'pending' ORDER BY priority DESC, id ASC LIMIT 1").fetchone()
    if row:
        cursor.execute("UPDATE commands SET status = 'executing' WHERE id = ?", (row[0],))
        db_conn.commit()
        return {"id": row[0], "action": row[1], "target": row[2], "value": row[3]}
    return {"action": "none"}

@app.post("/command_done/{cmd_id}")
def mark_command_done(cmd_id: int):
    cursor = db_conn.cursor()
    cursor.execute("UPDATE commands SET status = 'completed' WHERE id = ?", (cmd_id,))
    db_conn.commit()
    return {"status": "ok"}
