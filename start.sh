#!/bin/bash

pip3 install -r requirements.txt --break-system-packages

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
echo -e "\033[1;32m       >>> PuLaExPeLoReR — Cloud Desktop & Server Explorer <<<\033[0m\n"

check_port() {
    python3 -c "import socket; s = socket.socket(); s.bind(('', $1)); s.close()" 2>/dev/null
    return $?
}

while true; do
    read -p "Enter Main Port [default: 8586]: " USER_PORT
    USER_PORT=${USER_PORT:-8586}
    VSCODE_PORT=$((USER_PORT + 1))

    echo -e "\n[*] Checking availability for Port $USER_PORT and Port $VSCODE_PORT..."

    check_port $USER_PORT
    MAIN_OK=$?

    check_port $VSCODE_PORT
    VS_OK=$?

    if [ $MAIN_OK -eq 0 ] && [ $VS_OK -eq 0 ]; then
        echo -e "\033[1;32m[+] Both ports ($USER_PORT & $VSCODE_PORT) are free and available!\033[0m\n"
        break
    else
        echo -e "\033[1;31m[-] Error: Port $USER_PORT or Port $VSCODE_PORT is already in use by another process!\033[0m"
        echo "Please choose another port."
    fi
done

echo "[*] Checking Python dependencies..."
pip install -r requirements.txt > /dev/null 2>&1

which code-server >/dev/null 2>&1 || (echo "[*] Installing code-server..." && curl -fsSL https://code-server.dev/install.sh | sh)

ufw allow $USER_PORT/tcp 2>/dev/null || iptables -A INPUT -p tcp --dport $USER_PORT -j ACCEPT 2>/dev/null
ufw allow $VSCODE_PORT/tcp 2>/dev/null || iptables -A INPUT -p tcp --dport $VSCODE_PORT -j ACCEPT 2>/dev/null

pkill -f "code-server" 2>/dev/null
nohup code-server --bind-addr 0.0.0.0:$VSCODE_PORT --auth none --disable-telemetry > /tmp/code-server.log 2>&1 &

SERVER_IP=$(curl -s -m 3 https://api.ipify.org || curl -s -m 3 https://ifconfig.me || hostname -I | awk '{print $1}')

echo -e "\033[1;32m====================================================================\033[0m"
echo -e "\033[1;33m  PuLaExPeLoReR is running successfully\033[0m"
echo -e "  🌐 Web Desktop: \033[1;36mhttp://${SERVER_IP}:${USER_PORT}\033[0m"
echo -e "  💻 VS Code Port: \033[1;36mhttp://${SERVER_IP}:${VSCODE_PORT}\033[0m"
echo -e "  🔑 Default Password: \033[1;35madmin\033[0m"
echo -e "\033[1;32m====================================================================\033[0m\n"

pkill -f "server:app" 2>/dev/null
PULA_MAIN_PORT=$USER_PORT PULA_VSCODE_PORT=$VSCODE_PORT python3 server.py
