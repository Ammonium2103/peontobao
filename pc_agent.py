import requests
import time
import webbrowser
import pyautogui
import os
import subprocess
import logging
import threading
import sys
import psutil

# --- Senior Engineer: Advanced PC Agent ---
if sys.platform == "win32":
    os.system('chcp 65001 > nul')

logging.basicConfig(
    level=logging.INFO, 
    format='%(asctime)s - [%(levelname)s] - %(message)s',
    handlers=[logging.FileHandler("agent.log", encoding="utf-8"), logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("JarvisActionModule")

SERVER = "http://localhost:8000"

def get_system_status():
    battery = psutil.sensors_battery()
    cpu = psutil.cpu_percent()
    return f"CPU: {cpu}%, Pin: {battery.percent if battery else 'N/A'}%"

def execute_neural_link(cmd):
    action = cmd.get("action", "none")
    target = cmd.get("target") or ""
    cmd_id = cmd.get("id")
    
    if action == "none": return

    logger.info(f"⚡ Thực thi: {action} -> {target}")

    try:
        if action == "open_website":
            url = target if target.startswith("http") else f"https://{target}"
            webbrowser.open(url)
        
        elif action == "search_google":
            webbrowser.open(f"https://www.google.com/search?q={target}")

        elif action == "system_control":
            if "volume_up" in target: pyautogui.press("volumeup")
            elif "volume_down" in target: pyautogui.press("volumedown")
            elif "mute" in target: pyautogui.press("volumemute")
            elif "media_play_pause" in target: pyautogui.press("playpause")
            elif "screenshot" in target:
                pyautogui.screenshot(f"screenshot_{int(time.time())}.png")
                logger.info("📸 Đã chụp màn hình.")

        elif action == "open_app":
            # ML Engineer Tip: Use whitelisting for app paths
            os.startfile(target) if hasattr(os, 'startfile') else subprocess.Popen([target])

        # Phản hồi lại cho server là đã xong
        if cmd_id:
            requests.post(f"{SERVER}/command_done/{cmd_id}")

    except Exception as e:
        logger.error(f"❌ Execution Error: {e}")

def neural_poll_loop():
    logger.info("🧠 Hệ thống kết nối thần kinh đang lắng nghe...")
    while True:
        try:
            r = requests.get(f"{SERVER}/poll", timeout=5)
            if r.status_code == 200:
                cmd = r.json()
                if cmd["action"] != "none":
                    execute_neural_link(cmd)
        except: pass
        time.sleep(1.5) # Optimized polling rate

def cli_interface():
    print("\n--- JARVIS PC INTERFACE v3.0 ---")
    print(get_system_status())
    while True:
        try:
            text = input("\nSếp: ").strip()
            if not text: continue
            if text.lower() in ["exit", "sleep"]: break
            
            res = requests.post(f"{SERVER}/agent", json={"text": text}, timeout=15)
            if res.status_code == 200:
                data = res.json()
                print(f"Jarvis: {data.get('response')}")
                execute_neural_link(data)
        except Exception as e:
            logger.error(f"Lỗi CLI: {e}")

if __name__ == "__main__":
    threading.Thread(target=neural_poll_loop, daemon=True).start()
    cli_interface()
