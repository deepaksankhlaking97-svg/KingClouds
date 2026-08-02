cat > /root/kingcloud-cloudflare.sh <<'EOF'
#!/bin/bash

# ============================================================
# KINGCLOUD CLOUDFLARE TUNNEL
# Non-Systemd / Container Friendly
# HTTP/2 + TCP 7844
# Automatic restart + connection verification
# ============================================================

PURPLE='\033[38;5;135m'
PINK='\033[38;5;213m'
WHITE='\033[1;37m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

BASE="/etc/cloudflared"
TOKEN_FILE="$BASE/kingcloud.token"
PID_FILE="/run/kingcloud-cloudflared.pid"
LOG_FILE="/var/log/cloudflared-kingcloud.log"
RUNNER="/usr/local/bin/kingcloud-cloudflare-run"
SERVICE="/etc/init.d/kingcloud-cloudflare"

CF_BIN="$(command -v cloudflared 2>/dev/null || true)"

clear

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════╗"
echo "║          👑 KINGCLOUD CLOUDFLARE             ║"
echo "║          STABLE TUNNEL INSTALLER             ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${RESET}"

# ============================================================
# ROOT
# ============================================================

if [ "$EUID" != "0" ]; then
    echo -e "${RED}❌ Run this script as root.${RESET}"
    exit 1
fi

# ============================================================
# CLOUDFLARED
# ============================================================

if [ -z "$CF_BIN" ]; then
    echo -e "${RED}❌ cloudflared is not installed.${RESET}"
    echo
    echo "Install cloudflared first."
    exit 1
fi

echo -e "${GREEN}✓ cloudflared:${RESET} $CF_BIN"
"$CF_BIN" --version
echo

# ============================================================
# CLEAN OUR OLD SERVICE
# ============================================================

echo -e "${YELLOW}[1/7] Cleaning previous KINGCLOUD tunnel...${RESET}"

if [ -x "$SERVICE" ]; then
    "$SERVICE" stop >/dev/null 2>&1 || true
fi

# Kill only processes using our token file
pkill -f -- "--token-file $TOKEN_FILE" >/dev/null 2>&1 || true

rm -f "$PID_FILE"

sleep 2

echo -e "${GREEN}✓ Cleanup complete${RESET}"
echo

# ============================================================
# TOKEN
# ============================================================

echo -e "${YELLOW}[2/7] Cloudflare Tunnel Token${RESET}"
echo
echo -e "${WHITE}Paste ONLY the token.${RESET}"
echo -e "${CYAN}Example: eyJhIjoi...${RESET}"
echo
echo -e "${YELLOW}Input is hidden.${RESET}"
echo

read -r -s -p "🔑 Token: " CF_TOKEN
echo
echo

# Remove spaces/newlines accidentally pasted
CF_TOKEN="$(printf '%s' "$CF_TOKEN" | tr -d '[:space:]')"

if [ -z "$CF_TOKEN" ]; then
    echo -e "${RED}❌ Token is empty.${RESET}"
    exit 1
fi

# Cloudflare tunnel tokens are JWT-like strings
if [[ "$CF_TOKEN" != eyJ* ]]; then
    echo -e "${RED}❌ Token format looks invalid.${RESET}"
    echo
    echo "Paste the complete Cloudflare Tunnel token beginning with eyJ..."
    exit 1
fi

# ============================================================
# SAVE TOKEN
# ============================================================

echo -e "${YELLOW}[3/7] Saving token securely...${RESET}"

mkdir -p "$BASE"

printf '%s\n' "$CF_TOKEN" > "$TOKEN_FILE"

chmod 600 "$TOKEN_FILE"
chown root:root "$TOKEN_FILE"

unset CF_TOKEN

echo -e "${GREEN}✓ Token saved: $TOKEN_FILE${RESET}"
echo

# ============================================================
# LOG
# ============================================================

touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
chown root:root "$LOG_FILE"

# ============================================================
# NETWORK TEST
# ============================================================

echo -e "${YELLOW}[4/7] Testing Cloudflare TCP 7844...${RESET}"
echo

TEST_IPS=(
    "198.41.192.57"
    "198.41.192.107"
    "198.41.192.167"
    "198.41.192.227"
)

TCP_OK=false

if command -v nc >/dev/null 2>&1; then

    for IP in "${TEST_IPS[@]}"; do
        echo -ne "Testing ${IP}:7844 ... "

        if nc -z -w 5 "$IP" 7844 >/dev/null 2>&1; then
            echo -e "${GREEN}OPEN${RESET}"
            TCP_OK=true
            break
        else
            echo -e "${RED}FAILED${RESET}"
        fi
    done

else

    echo -e "${YELLOW}nc not installed. Installing netcat test utility...${RESET}"

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq >/dev/null 2>&1 || true
        apt-get install -y netcat-openbsd >/dev/null 2>&1 || true
    fi

    if command -v nc >/dev/null 2>&1; then
        for IP in "${TEST_IPS[@]}"; do

            echo -ne "Testing ${IP}:7844 ... "

            if nc -z -w 5 "$IP" 7844 >/dev/null 2>&1; then
                echo -e "${GREEN}OPEN${RESET}"
                TCP_OK=true
                break
            else
                echo -e "${RED}FAILED${RESET}"
            fi

        done
    fi

fi

echo

if [ "$TCP_OK" != true ]; then

    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║          ❌ TCP 7844 IS BLOCKED              ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo -e "${YELLOW}Cloudflare Tunnel needs outbound TCP 7844 for HTTP/2.${RESET}"
    echo
    echo "This is normally caused by:"
    echo "  • VPS/provider firewall"
    echo "  • Container network restrictions"
    echo "  • Host firewall"
    echo "  • Security-group egress rules"
    echo
    echo -e "${CYAN}Check:${RESET}"
    echo "  ufw status"
    echo "  iptables -S"
    echo "  nft list ruleset"
    echo
    echo -e "${CYAN}Your provider must allow:${RESET}"
    echo "  OUTBOUND TCP 7844"
    echo
    echo "The token itself is not the problem."
    exit 1
fi

echo -e "${GREEN}✓ TCP 7844 reachable${RESET}"
echo

# ============================================================
# RUNNER
# ============================================================

echo -e "${YELLOW}[5/7] Creating Cloudflare runner...${RESET}"

cat > "$RUNNER" <<EOF_RUNNER
#!/bin/bash

CF_BIN="$CF_BIN"
TOKEN_FILE="$TOKEN_FILE"
LOG_FILE="$LOG_FILE"
PID_FILE="$PID_FILE"

mkdir -p "\$(dirname "\$LOG_FILE")"
mkdir -p "\$(dirname "\$PID_FILE")"

echo "" >> "\$LOG_FILE"
echo "============================================" >> "\$LOG_FILE"
echo "KINGCLOUD CLOUDFLARE START" >> "\$LOG_FILE"
date -u >> "\$LOG_FILE"
echo "Protocol: HTTP/2" >> "\$LOG_FILE"
echo "Transport: TCP 7844" >> "\$LOG_FILE"
echo "============================================" >> "\$LOG_FILE"

while true
do

    echo "Starting cloudflared..." >> "\$LOG_FILE"

    "\$CF_BIN" tunnel \
        --no-autoupdate \
        --protocol http2 \
        --loglevel info \
        --logfile "\$LOG_FILE" \
        run \
        --token-file "\$TOKEN_FILE" \
        >> "\$LOG_FILE" 2>&1

    EXIT_CODE=\$?

    echo "cloudflared exited with code \$EXIT_CODE" >> "\$LOG_FILE"

    if [ "\$EXIT_CODE" = "0" ]; then
        echo "Process stopped normally." >> "\$LOG_FILE"
    else
        echo "Process stopped unexpectedly." >> "\$LOG_FILE"
    fi

    echo "Restarting in 5 seconds..." >> "\$LOG_FILE"

    sleep 5

done
EOF_RUNNER

chmod 700 "$RUNNER"
chown root:root "$RUNNER"

echo -e "${GREEN}✓ Runner created${RESET}"
echo

# ============================================================
# INIT SERVICE
# ============================================================

echo -e "${YELLOW}[6/7] Creating non-systemd service...${RESET}"

cat > "$SERVICE" <<EOF_SERVICE
#!/bin/sh

RUNNER="$RUNNER"
PID_FILE="$PID_FILE"
LOG_FILE="$LOG_FILE"

start() {

    if [ -f "\$PID_FILE" ]; then

        PID=\$(cat "\$PID_FILE" 2>/dev/null)

        if [ -n "\$PID" ] && kill -0 "\$PID" 2>/dev/null; then
            echo "Cloudflare Tunnel already running."
            echo "PID: \$PID"
            return 0
        fi

        rm -f "\$PID_FILE"
    fi

    echo "Starting KINGCLOUD Cloudflare Tunnel..."

    nohup "\$RUNNER" >/dev/null 2>&1 &

    PID=\$!

    echo "\$PID" > "\$PID_FILE"

    sleep 4

    if kill -0 "\$PID" 2>/dev/null; then
        echo "Cloudflare runner started."
        echo "PID: \$PID"
        return 0
    fi

    rm -f "\$PID_FILE"

    echo "Failed to start Cloudflare runner."
    return 1
}

stop() {

    if [ ! -f "\$PID_FILE" ]; then
        echo "Cloudflare Tunnel is not running."
        return 0
    fi

    PID=\$(cat "\$PID_FILE" 2>/dev/null)

    if [ -n "\$PID" ] && kill -0 "\$PID" 2>/dev/null; then
        echo "Stopping Cloudflare Tunnel..."

        kill "\$PID" 2>/dev/null || true

        sleep 3

        kill -9 "\$PID" 2>/dev/null || true
    fi

    rm -f "\$PID_FILE"

    # Stop cloudflared processes using our token
    pkill -f -- "--token-file $TOKEN_FILE" 2>/dev/null || true

    echo "Cloudflare Tunnel stopped."
}

restart() {
    stop
    sleep 2
    start
}

status() {

    if [ -f "\$PID_FILE" ]; then

        PID=\$(cat "\$PID_FILE" 2>/dev/null)

        if [ -n "\$PID" ] && kill -0 "\$PID" 2>/dev/null; then
            echo "Cloudflare Runner: RUNNING"
            echo "PID: \$PID"
            return 0
        fi
    fi

    echo "Cloudflare Runner: STOPPED"
    return 1
}

logs() {
    tail -n 100 "\$LOG_FILE"
}

case "\$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    logs)
        logs
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF_SERVICE

chmod 700 "$SERVICE"
chown root:root "$SERVICE"

echo -e "${GREEN}✓ Service created${RESET}"
echo

# ============================================================
# START
# ============================================================

echo -e "${YELLOW}[7/7] Starting tunnel...${RESET}"

"$SERVICE" start

sleep 8

echo
echo -e "${CYAN}Checking tunnel logs...${RESET}"
echo

# ============================================================
# SUCCESS DETECTION
# ============================================================

if grep -Eqi \
"Registered tunnel connection|Connection .* registered|Tunnel connection registered" \
"$LOG_FILE" 2>/dev/null; then

    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║       ✅ CLOUDFLARE TUNNEL CONNECTED         ║"
    echo "║              👑 KINGCLOUD                    ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"

else

    echo -e "${YELLOW}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║      ⚠️ PROCESS RUNNING — VERIFYING...      ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"

fi

echo
echo -e "${CYAN}Service:${RESET} $SERVICE"
echo -e "${CYAN}Token:${RESET}   $TOKEN_FILE"
echo -e "${CYAN}Log:${RESET}     $LOG_FILE"
echo
echo -e "${YELLOW}Latest logs:${RESET}"
tail -n 40 "$LOG_FILE" 2>/dev/null || true

echo
echo -e "${GREEN}Management commands:${RESET}"
echo
echo "Start:"
echo "  $SERVICE start"
echo
echo "Stop:"
echo "  $SERVICE stop"
echo
echo "Restart:"
echo "  $SERVICE restart"
echo
echo "Status:"
echo "  $SERVICE status"
echo
echo "Logs:"
echo "  $SERVICE logs"
echo
echo "Live logs:"
echo "  tail -f $LOG_FILE"

EOF

chmod +x /root/kingcloud-cloudflare.sh
bash /root/kingcloud-cloudflare.sh
