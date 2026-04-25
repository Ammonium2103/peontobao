import requests
import time
import webbrowser
import pyautogui
import os
import subprocess
import logging
import threading
import sys

# Windows UTF-8 Fix
if sys.platform == "win32":
    os.system('chcp 65001 > nul')

logging.basicConfig(
    level=logging.INFO, 
    format='%(asctime)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

SERVER = "http://localhost:8000"

def execute(cmd):
    action = cmd.get("action", "none")
    target = cmd.get("target") or ""
    
    if action == "none": return

    try:
        if action == "open_website":
            url = target if target.startswith("http") else f"https://{target}"
            logger.info(f"Mở trình duyệt: {url}")
            webbrowser.open(url)
        
        elif action == "search_google":
            logger.info(f"Tìm kiếm: {target}")
            webbrowser.open(f"https://www.google.com/search?q={target}")

        elif action == "system_control":
            logger.info(f"Điều khiển hệ thống: {target}")
            if "volume_up" in target: pyautogui.press("volumeup")
            elif "volume_down" in target: pyautogui.press("volumedown")
            elif "mute" in target: pyautogui.press("volumemute")
            elif "screenshot" in target:
                pyautogui.screenshot(f"screenshot_{int(time.time())}.png")
                logger.info("Đã chụp màn hình.")

        elif action == "open_app":
            logger.info(f"Mở ứng dụng: {target}")
            # Mở ứng dụng cơ bản thông qua lệnh 'start' an toàn
            os.startfile(target) if hasattr(os, 'startfile') else subprocess.Popen([target])

    except Exception as e:
        logger.error(f"Lỗi thực thi: {e}")

def poll_loop():
    while True:
        try:
            r = requests.get(f"{SERVER}/poll", timeout=5)
            if r.status_code == 200:
                cmd = r.json()
                if cmd["action"] != "none": execute(cmd)
        except: pass
        time.sleep(2)

def main():
    threading.Thread(target=poll_loop, daemon=True).start()
    print("\n--- Jarvis PC Agent v2.2 ---")
    while True:
        try:
            text = input("\nBạn: ").strip()
            if not text: continue
            if text.lower() in ["exit", "thoát"]: break
            
            res = requests.post(f"{SERVER}/agent", json={"text": text}, timeout=15)
            if res.status_code == 200:
                data = res.json()
                print(f"Jarvis: {data.get('response')}")
                execute(data)
        except Exception as e:
            print(f"Lỗi: {e}")

if __name__ == "__main__":
    main()
