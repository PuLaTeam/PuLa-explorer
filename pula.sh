#!/bin/bash
pip3 install -r requirements.txt --break-system-packages
# شناسایی مسیر اصلی پوشه اسکریپت (تا از هر مسیری صدا زده بشه درست کار کنه)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# ثبت دستور سراسری pula در لینوکس (تا با زدن فقط کلمه pula پنل باز بشه)
if [ ! -L /usr/local/bin/pula ] || [ "$(readlink -f /usr/local/bin/pula)" != "$SCRIPT_DIR/pula.sh" ]; then
    ln -sf "$SCRIPT_DIR/pula.sh" /usr/local/bin/pula 2>/dev/null
    chmod +x /usr/local/bin/pula 2>/dev/null
fi

CONFIG_FILE="$SCRIPT_DIR/.pula_config"
LOG_FILE="$SCRIPT_DIR/pula.log"
VS_LOG="$SCRIPT_DIR/code-server.log"
REPO_URL="https://github.com/PuLaTeam/PuLa-explorer.git"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    MAIN_PORT=8586
    VSCODE_PORT=8587
    echo "MAIN_PORT=$MAIN_PORT" > "$CONFIG_FILE"
    echo "VSCODE_PORT=$VSCODE_PORT" >> "$CONFIG_FILE"
fi

check_port() {
    python3 -c "import socket; s = socket.socket(); s.bind(('', $1)); s.close()" 2>/dev/null
    return $?
}

is_running() {
    pgrep -f "server.py" > /dev/null 2>&1
    return $?
}

get_server_ip() {
    curl -s -m 3 https://api.ipify.org || curl -s -m 3 https://ifconfig.me || hostname -I | awk '{print $1}'
}

start_service() {
    if is_running; then
        echo -e "\033[1;33m[!] PuLaExPeLoReR is already running!\033[0m"
        return
    fi

    echo -e "\033[1;34m[*] Starting PuLaExPeLoReR in background (nohup)...\033[0m"
    
    pip install -r "$SCRIPT_DIR/requirements.txt" > /dev/null 2>&1
    which code-server >/dev/null 2>&1 || curl -fsSL https://code-server.dev/install.sh | sh

    ufw allow $MAIN_PORT/tcp 2>/dev/null || iptables -A INPUT -p tcp --dport $MAIN_PORT -j ACCEPT 2>/dev/null
    ufw allow $VSCODE_PORT/tcp 2>/dev/null || iptables -A INPUT -p tcp --dport $VSCODE_PORT -j ACCEPT 2>/dev/null

    pkill -f "code-server" 2>/dev/null
    nohup code-server --bind-addr 0.0.0.0:$VSCODE_PORT --auth none --disable-telemetry > "$VS_LOG" 2>&1 &
    
    pkill -f "server.py" 2>/dev/null
    nohup env PULA_MAIN_PORT=$MAIN_PORT PULA_VSCODE_PORT=$VSCODE_PORT python3 "$SCRIPT_DIR/server.py" > "$LOG_FILE" 2>&1 &

    sleep 2
    if is_running; then
        IP=$(get_server_ip)
        echo -e "\033[1;32m[✔] Started successfully in background!\033[0m"
        echo -e "🌐 Web Desktop: \033[1;36mhttp://${IP}:${MAIN_PORT}\033[0m"
        echo -e "💻 VS Code:      \033[1;36mhttp://${IP}:${VSCODE_PORT}\033[0m"
    else
        echo -e "\033[1;31m[-] Failed to start! Check logs (Option 4).\033[0m"
    fi
}

stop_service() {
    echo -e "\033[1;33m[*] Stopping PuLaExPeLoReR...\033[0m"
    pkill -f "server.py" 2>/dev/null
    pkill -f "code-server" 2>/dev/null
    sleep 1
    echo -e "\033[1;32m[✔] All services stopped.\033[0m"
}

restart_service() {
    stop_service
    start_service
}

show_logs() {
    echo -e "\033[1;33m--- Live Logs (Press Ctrl+C to exit) ---\033[0m"
    tail -n 50 -f "$LOG_FILE"
}

change_password() {
    echo -e "\n\033[1;34m[*] Change Admin Password\033[0m"
    read -p "Enter new password: " NEW_PW
    if [ -z "$NEW_PW" ]; then
        echo -e "\033[1;31m[-] Password cannot be empty!\033[0m"
        return
    fi

    python3 -c "
import sqlite3, hashlib
conn = sqlite3.connect('$SCRIPT_DIR/desktop.db')
c = conn.cursor()
c.execute('CREATE TABLE IF NOT EXISTS users (username TEXT PRIMARY KEY, password TEXT)')
c.execute('INSERT OR REPLACE INTO users (username, password) VALUES (\'admin\', ?)', (hashlib.sha256('$NEW_PW'.encode()).hexdigest(),))
conn.commit()
conn.close()
"
    echo -e "\033[1;32m[✔] Admin password changed successfully!\033[0m"
}

change_ports() {
    echo -e "\n\033[1;34m[*] Port Configuration\033[0m"
    read -p "Enter New Main Port [current: $MAIN_PORT]: " NEW_M_PORT
    NEW_M_PORT=${NEW_M_PORT:-$MAIN_PORT}
    NEW_VS_PORT=$((NEW_M_PORT + 1))

    if ! check_port $NEW_M_PORT || ! check_port $NEW_VS_PORT; then
        echo -e "\033[1;31m[-] Port $NEW_M_PORT or $NEW_VS_PORT is currently in use!\033[0m"
        return
    fi

    MAIN_PORT=$NEW_M_PORT
    VSCODE_PORT=$NEW_VS_PORT
    echo "MAIN_PORT=$MAIN_PORT" > "$CONFIG_FILE"
    echo "VSCODE_PORT=$VSCODE_PORT" >> "$CONFIG_FILE"
    echo -e "\033[1;32m[✔] Ports updated to $MAIN_PORT and $VSCODE_PORT.\033[0m"
    restart_service
}

update_from_github() {
    echo -e "\n\033[1;34m[*] Updating PuLaExPeLoReR to latest version from PuLaTeam/PuLa-explorer...\033[0m"
    cd "$SCRIPT_DIR" || exit 1
    
    if [ ! -d ".git" ]; then
        git init
        git remote add origin "$REPO_URL"
    else
        git remote set-url origin "$REPO_URL" 2>/dev/null
    fi

    git fetch origin main
    git reset --hard origin/main
    
    pip install -r "$SCRIPT_DIR/requirements.txt" > /dev/null 2>&1
    chmod +x "$SCRIPT_DIR/pula.sh"
    
    echo -e "\033[1;32m[✔] Update completed! Restarting service...\033[0m"
    restart_service
}

while true; do
    clear
    echo -e "\033[1;36m"
    cat << "BANNER"
  ____        _             ______            _                 ____  
 |  _ \ _   _| |    __ _   |  ____|          | |               |  _ \ 
 | |_) | | | | |   / _` |  | |__  __  ___ __ | | ___  _ __ ___ | |_) |
 |  __/| | | | |  | (_| |  |  __| \ \/ / '_ \| |/ _ \| '__/ _ \|  _ < 
 | |   | |_| | |___ \__,_|  | |____ >  <| |_) | | (_) | | |  __/| | \ \
 |_|    \__,_|_____|       |______/_/\_\ .__/|_|\___/|_|  \___|_|  \_|
                                       | |                            
                                       |_|                            
BANNER
    echo -e "\033[0m"
    echo -e "\033[1;33m           >>> PuLaExPeLoReR Management Panel <<<\033[0m"

    if is_running; then
        echo -e " Status: \033[1;32m● Running\033[0m (Web: $MAIN_PORT | VSCode: $VSCODE_PORT)"
    else
        echo -e " Status: \033[1;31m● Stopped\033[0m"
    fi
    echo -e " \033[1;30mTip: Type 'pula' anywhere in terminal to open this menu\033[0m"
    echo -e "============================================================"
    echo -e " \033[1;32m1)\033[0m Start Service (Background / nohup)"
    echo -e " \033[1;31m2)\033[0m Stop Service"
    echo -e " \033[1;33m3)\033[0m Restart Service"
    echo -e " \033[1;34m4)\033[0m View Live Logs"
    echo -e " \033[1;35m5)\033[0m Change Admin Password"
    echo -e " \033[1;36m6)\033[0m Change Port Configuration"
    echo -e " \033[1;32m7)\033[0m Update to Latest Version (From GitHub)"
    echo -e " \033[1;37m0)\033[0m Exit"
    echo -e "============================================================"
    read -p "Select an option [0-7]: " OPTION

    case $OPTION in
        1) start_service; read -p "Press Enter to continue..." ;;
        2) stop_service; read -p "Press Enter to continue..." ;;
        3) restart_service; read -p "Press Enter to continue..." ;;
        4) show_logs ;;
        5) change_password; read -p "Press Enter to continue..." ;;
        6) change_ports; read -p "Press Enter to continue..." ;;
        7) update_from_github; read -p "Press Enter to continue..." ;;
        0) exit 0 ;;
        *) echo "Invalid option!"; sleep 1 ;;
    esac
done
