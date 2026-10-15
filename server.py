import os
import sys
import pty
import select
import shutil
import sqlite3
import subprocess
import asyncio
import hashlib
import zipfile
import platform
import time
from typing import List
from fastapi import FastAPI, WebSocket, UploadFile, File, Form, HTTPException
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
import psutil
import uvicorn

app = FastAPI(title="PuLaExPeLoReR")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_PATH = "desktop.db"
VSCODE_PORT = int(os.environ.get("PULA_VSCODE_PORT", 8587))

def hash_pw(pw: str) -> str:
    return hashlib.sha256(pw.encode()).hexdigest()

def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)''')
    c.execute('''CREATE TABLE IF NOT EXISTS users (username TEXT PRIMARY KEY, password TEXT)''')
    c.execute('''INSERT OR IGNORE INTO users VALUES ('admin', ?)''', (hash_pw("admin"),))
    defaults = {
        'wallpaper': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1920&q=80',
        'accent': '#0078d4',
        'taskbar_align': 'center',
        'term_fontsize': '14',
        'blur_level': '30px'
    }
    for k, v in defaults.items():
        c.execute('''INSERT OR IGNORE INTO settings VALUES (?, ?)''', (k, v))
    conn.commit()
    conn.close()

init_db()

@app.get("/api/config")
def get_config():
    return {"vscode_port": VSCODE_PORT}

@app.post("/api/auth/login")
def login(username: str = Form(...), password: str = Form(...)):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT password FROM users WHERE username = ?", (username,))
    row = c.fetchone()
    conn.close()
    if row and row[0] == hash_pw(password):
        return {"status": "ok"}
    raise HTTPException(status_code=401, detail="Invalid credentials")

@app.post("/api/auth/change-password")
def change_password(current_password: str = Form(...), new_password: str = Form(...)):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT password FROM users WHERE username = 'admin'")
    row = c.fetchone()
    if not row or row[0] != hash_pw(current_password):
        conn.close()
        raise HTTPException(status_code=400, detail="Current password incorrect")
    c.execute("UPDATE users SET password = ? WHERE username = 'admin'", (hash_pw(new_password),))
    conn.commit()
    conn.close()
    return {"status": "ok"}

@app.get("/api/settings")
def get_settings():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT key, value FROM settings")
    s = dict(c.fetchall())
    conn.close()
    return s

@app.post("/api/settings")
def save_setting(key: str = Form(...), value: str = Form(...)):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", (key, value))
    conn.commit()
    conn.close()
    return {"status": "ok"}

@app.get("/api/system/info")
def system_info():
    uptime_sec = time.time() - psutil.boot_time()
    return {
        "os": platform.system() + " " + platform.release(),
        "arch": platform.machine(),
        "cpu_count": psutil.cpu_count(logical=True),
        "uptime": f"{int(uptime_sec // 3600)}h {int((uptime_sec % 3600) // 60)}m",
        "python_v": platform.python_version()
    }

@app.get("/api/files")
def list_files(path: str = "/root"):
    target_path = os.path.abspath(path)
    if not os.path.exists(target_path):
        target_path = "/root"
    items = []
    try:
        with os.scandir(target_path) as entries:
            for entry in entries:
                try:
                    stat = entry.stat()
                    items.append({
                        "name": entry.name,
                        "path": entry.path,
                        "is_dir": entry.is_dir(),
                        "size": stat.st_size if not entry.is_dir() else 0,
                        "permissions": oct(stat.st_mode)[-3:],
                        "modified": stat.st_mtime
                    })
                except PermissionError:
                    continue
    except PermissionError:
        raise HTTPException(status_code=403, detail="Permission Denied")

    items.sort(key=lambda x: (not x["is_dir"], x["name"].lower()))
    return {"current_path": target_path, "items": items}

@app.get("/api/file/read")
def read_file(path: str):
    if not os.path.isfile(path):
        raise HTTPException(status_code=400, detail="Not a file")
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return {"content": f.read(), "path": path}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/file/save")
def save_file(path: str = Form(...), content: str = Form(...)):
    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/file/upload")
async def upload_file(path: str = Form(...), files: List[UploadFile] = File(...)):
    try:
        for file in files:
            with open(os.path.join(path, file.filename), "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/file/download")
def download_file(path: str):
    if os.path.isfile(path):
        return FileResponse(path, filename=os.path.basename(path))
    raise HTTPException(status_code=400, detail="Cannot download directory")

@app.post("/api/file/action")
def file_action(action: str = Form(...), path: str = Form(...), extra: str = Form(None)):
    try:
        if action == "delete":
            if os.path.isdir(path): shutil.rmtree(path)
            else: os.remove(path)
        elif action == "rename":
            os.rename(path, os.path.join(os.path.dirname(path), extra))
        elif action == "mkdir":
            os.makedirs(os.path.join(path, extra), exist_ok=True)
        elif action == "newfile":
            with open(os.path.join(path, extra), "w") as f: f.write("")
        elif action == "zip":
            zip_dest = path + ".zip"
            with zipfile.ZipFile(zip_dest, 'w', zipfile.ZIP_DEFLATED) as zipf:
                if os.path.isdir(path):
                    for r, _, fls in os.walk(path):
                        for fl in fls:
                            fp = os.path.join(r, fl)
                            zipf.write(fp, os.path.relpath(fp, os.path.dirname(path)))
                else:
                    zipf.write(path, os.path.basename(path))
        elif action == "unzip":
            with zipfile.ZipFile(path, 'r') as zipf:
                zipf.extractall(os.path.dirname(path))
        elif action == "chmod":
            os.chmod(path, int(extra, 8))
        elif action == "duplicate":
            if os.path.isdir(path): shutil.copytree(path, path + "_copy")
            else:
                b, e = os.path.splitext(path)
                shutil.copy2(path, f"{b}_copy{e}")
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/system/stats")
def system_stats():
    return {
        "cpu": psutil.cpu_percent(interval=None),
        "ram": psutil.virtual_memory().percent,
        "ram_used": round(psutil.virtual_memory().used / (1024**3), 2),
        "ram_total": round(psutil.virtual_memory().total / (1024**3), 2),
        "disk": psutil.disk_usage("/").percent
    }

@app.websocket("/ws/terminal")
async def terminal_websocket(websocket: WebSocket):
    await websocket.accept()
    master, slave = pty.openpty()
    env = os.environ.copy()
    env["HOME"] = "/root"
    env["TERM"] = "xterm-256color"
    proc = subprocess.Popen(
        ["/bin/bash", "-l"],
        preexec_fn=os.setsid,
        stdin=slave,
        stdout=slave,
        stderr=slave,
        cwd="/root",
        env=env,
        universal_newlines=False
    )
    os.close(slave)

    async def read_from_pty():
        while True:
            await asyncio.sleep(0.01)
            r, _, _ = select.select([master], [], [], 0)
            if master in r:
                data = os.read(master, 1024)
                if not data: break
                await websocket.send_bytes(data)

    async def write_to_pty():
        while True:
            data = await websocket.receive_text()
            os.write(master, data.encode())

    try:
        await asyncio.gather(read_from_pty(), write_to_pty())
    except Exception:
        pass
    finally:
        try:
            proc.terminate()
            os.close(master)
        except Exception:
            pass

@app.get("/", response_class=HTMLResponse)
def index():
    with open("index.html", "r", encoding="utf-8") as f:
        return f.read()

if __name__ == "__main__":
    port = int(os.environ.get("PULA_MAIN_PORT", 8586))
    uvicorn.run("server:app", host="0.0.0.0", port=port, reload=False)
