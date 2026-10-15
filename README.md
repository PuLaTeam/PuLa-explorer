# 🚀 PuLaExPeLoReR

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.8+-3776AB?style=for-the-badge&logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/FastAPI-0.100+-009688?style=for-the-badge&logo=fastapi&logoColor=white" />
  <img src="https://img.shields.io/badge/Linux-Server-FCC624?style=for-the-badge&logo=linux&logoColor=black" />
  <img src="https://img.shields.io/badge/VS_Code-Embedded-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" />
</p>

<p align="center">
  <b>🌐 Language:</b> English | <a href="README_FA.md">فارسی (Persian)</a>
</p>

---

## 🌟 Overview

**PuLaExPeLoReR** is a modern, lightweight, and blazing-fast **Web Desktop Environment & Cloud File Explorer** designed for Linux servers and VPS instances.

Powered by **FastAPI, WebSockets, xterm.js, and SQLite**, it provides a complete Windows 11-inspired workspace right in your web browser — completely bypassing the need to install heavy desktop environments like GNOME, XFCE, or VNC servers on your host.

---

## ✨ Features

- 🪟 **Fluent Windows 11-Style UI:**
  - Frosted acrylic glassmorphism effects.
  - Freely movable, resizable (bottom-right corner), and draggable windows.
  - Native double-click and button fullscreen maximization.
  - Window drag-isolation prevents the cursor from getting stuck on iframes.

- 📁 **Supercharged File Explorer:**
  - Right-click context menu with 11+ quick actions.
  - 1-Click archive creation (`.zip`) and extraction (`unzip`).
  - Permissions editor (`chmod`).
  - File duplication, inline renaming, instant downloading, and drag-and-drop uploading.
  - Quick directory navigation and address bar.

- 💻 **Real VS Code Embedded:**
  - Official `code-server` running seamlessly in a dedicated window.
  - Full extension marketplace, themes, and integrated Git support.
  - Automatically configured and firewalled on `port + 1`.

- 📟 **Real-Time Interactive Bash Terminal:**
  - Live PTY-based Linux shell (`/bin/bash -l`) streaming over WebSocket.
  - Opens directly into `/root` with full color support and interactive CLI apps (`htop`, `nano`, etc.).

- ⚙️ **Control Center & Personalization:**
  - Curated 4K wallpapers (Dark Bloom, Cyberpunk Neon, Tokyo Night, AMOLED Black, Deep Nebula) + custom image URL support.
  - 5 System accent colors (Blue, Emerald, Purple, Orange, Red).
  - Adjustable glass blur levels.
  - Centered (Win 11) or Left-aligned (Win 10) taskbar layouts.
  - Terminal font size selector.
  - Password manager backed by SHA-256 in local SQLite database.

- 📊 **Task Manager:**
  - Live monitoring of CPU load, RAM usage, and root disk consumption.

- 🔒 **Security Lockscreen:**
  - Clean lockscreen overlay requiring password authorization on boot.

---

## ⚡ Quick Start

### 1. Clone & Run
```bash
git clone https://github.com/YOUR_USERNAME/PuLa-fileexpelorer.git
cd PuLa-fileexpelorer
chmod +x start.sh
./start.sh
```

### 2. Port Selection
The interactive installer will ask you for a primary port (default: `8586`):
- Verifies that both `PORT` and `PORT + 1` are unoccupied.
- Assigns the Web OS to `PORT` and embedded VS Code to `PORT + 1`.
- Automatically opens ports in `ufw` / `iptables`.
- Detects the server's public IP and displays direct links.

### 3. Default Login
- **Username:** `admin`
- **Password:** `admin` *(Can be changed from the Settings app)*

---

## 🛠️ Tech Stack

- **Backend:** Python 3, FastAPI, Uvicorn, WebSockets, PTY, SQLite3, psutil
- **Frontend:** Vanilla HTML5 / CSS3 (Fluent Design), Monaco Editor, xterm.js
- **Services:** code-server (VS Code Server)

---

## 📄 License
This project is open-source and distributed under the [MIT License](LICENSE).
