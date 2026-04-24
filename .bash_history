sudo su
yum update -y
sudo su
status
systemctl status 
sudo su
#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  fix-connection.sh — Fix ERR_CONNECTION_REFUSED on EC2
#  Run this on your EC2 instance as root or with sudo
#  Usage: sudo bash fix-connection.sh
# ═══════════════════════════════════════════════════════════════
set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✔  $*${NC}"; }
fail() { echo -e "${RED}  ✘  $*${NC}"; }
info() { echo -e "${CYAN}  ▸  $*${NC}"; }
warn() { echo -e "${YELLOW}  ⚠  $*${NC}"; }
step() { echo -e "\n${BOLD}══ $* ══${NC}"; }
APP_NAME="github-aws-pipeline-app"
APP_PORT=3000
APP_DIR="/opt/app"
echo ""
echo -e "${BOLD}${CYAN}  ╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}  ║   EC2 Connection Fix — Full Diagnosis        ║${NC}"
echo -e "${BOLD}${CYAN}  ╚══════════════════════════════════════════════╝${NC}"
echo ""
# ─── STEP 1: Check what is actually listening on ports ──────
step "1. Port Listening Check"
info "Checking ports 80 and 3000..."
PORT80=$(ss -tlnp 2>/dev/null | grep ':80 ' || netstat -tlnp 2>/dev/null | grep ':80 ' || echo "NOTHING")
PORT3000=$(ss -tlnp 2>/dev/null | grep ':3000 ' || netstat -tlnp 2>/dev/null | grep ':3000 ' || echo "NOTHING")
echo "  Port 80   : $PORT80"
echo "  Port 3000 : $PORT3000"
if echo "$PORT80" | grep -q "NOTHING\|^$"; then   warn "NOTHING is listening on port 80 — NGINX not running!"; else   ok "Something is on port 80."; fi
if echo "$PORT3000" | grep -q "NOTHING\|^$"; then   warn "NOTHING is listening on port 3000 — Node app not running!"; else   ok "Something is on port 3000."; fi
# ─── STEP 2: Fix iptables / firewalld ───────────────────────
step "2. Fix Local Firewall (iptables / firewalld)"
# Disable firewalld if running (it blocks traffic on EC2)
if systemctl is-active --quiet firewalld 2>/dev/null; then   warn "firewalld is running — stopping and disabling it...";   systemctl stop firewalld;   systemctl disable firewalld;   ok "firewalld stopped and disabled."; else   ok "firewalld not running."; fi
# Open ports via iptables directly
info "Opening ports 80, 443, 3000 in iptables..."
iptables -I INPUT -p tcp --dport 80   -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p tcp --dport 443  -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p tcp --dport 3000 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p tcp --dport 22   -j ACCEPT 2>/dev/null || true
ok "iptables rules added for ports 22, 80, 443, 3000."
# ─── STEP 3: Install missing packages ───────────────────────
step "3. Install NGINX + Node.js (if missing)"
# Detect OS
OS="unknown"
if [ -f /etc/os-release ]; then . /etc/os-release; OS="$ID"; fi
pkg_install() {   case "$OS" in     amzn|rhel|centos) yum install -y -q "$@" ;;     ubuntu|debian)    DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$@" ;;     *)                yum install -y -q "$@" 2>/dev/null || apt-get install -y -q "$@" 2>/dev/null ;;   esac; }
# Install Node.js 18 if missing
if ! command -v node &>/dev/null; then   warn "Node.js not found — installing Node.js 18...";   case "$OS" in     amzn|rhel|centos)       curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -;       yum install -y nodejs;       ;;     ubuntu|debian)       curl -fsSL https://deb.nodesource.com/setup_18.x | bash -;       apt-get install -y nodejs;       ;;     *)       curl -fsSL https://deb.nodesource.com/setup_18.x | bash -;       apt-get install -y nodejs 2>/dev/null || { curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -; yum install -y nodejs; };       ;;   esac;   ok "Node.js installed: $(node -v)"; else   ok "Node.js: $(node -v)"; fi
sudo su
