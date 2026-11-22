#!/usr/bin/env bash
# =============================================================================
# 🚀 ORACLE CLOUD ALWAYS FREE — ALL-IN-ONE SERVER SETUP (Coolify Edition)
# =============================================================================
# ONE script turns a fresh Oracle Ubuntu VM into your own hosting platform:
#
#   ✔ 1/8  Updates all system packages (security patches)
#   ✔ 2/8  Creates an 8 GB swap file (prevents crashes during app builds)
#   ✔ 3/8  Opens ports 80 / 443 / 8000 / 6001 / 6002 in iptables (Oracle's
#          HIDDEN 2nd firewall — the #1 reason sites "don't load" on Oracle).
#          6001 = Coolify dashboard live-updates, 6002 = Coolify web terminal
#          (port list verified from Coolify's official firewall docs)
#   ✔ 4/8  Enables automatic security updates (Ubuntu unattended-upgrades)
#   ✔ 5/8  Installs Coolify — your own self-hosted "Vercel"
#          (Docker + Coolify dashboard + Traefik, all automatic)
#   ✔ 6/8  Installs the anti-reclaim KEEPALIVE service (Oracle can never
#          flag your server as "idle" — see the long comment in step 6)
#   ✔ 7/8  Installs disk hygiene (journal cap + monthly Docker cleanup)
#   ✔ 8/8  Prints your Coolify address + exactly what to do next
#
# STORAGE MODEL: everything lives on the ONE 200 GB boot volume (created at
# VM creation). No block volume is used or needed. See GUIDE.md Part 16 if
# you ever want to add one.
#
# SAFE TO RE-RUN (idempotent): every step checks first and skips if done.
#
# WHERE TO RUN: ON the Oracle VM, after SSH-ing in (see GUIDE.md Part 6/7):
#
#   git clone https://github.com/ZIAKARS/ORACLE.git
#   cd ORACLE && sudo bash setup.sh
#
# ⏱ IMPORTANT (from Coolify's latest docs): the FIRST admin account can only
# be registered within 10 MINUTES of Coolify starting. When this script
# finishes, open http://YOUR_IP:8000 and register immediately. If you see
# "Setup window closed": sudo docker restart coolify  → reload the page.
#
# Verified against the LIVE official docs on 2026-11-22: Oracle Always Free
# Resources + Free Tier pages (docs.oracle.com — 1,500 OCPU-hours / 9,000
# GB-hours = 2 OCPU + 12 GB A1, 200 GB combined storage, 5 backups, 10 TB
# egress, 20 GB Object Storage, idle-instance criteria, card policy) and
# Coolify docs (coolify.io — installer, ports, first-login window).
# Home region: US East (Ashburn).
# =============================================================================

set -euo pipefail

# Never let apt ask questions: this script must run 100% unattended.
export DEBIAN_FRONTEND=noninteractive

# ─── Pretty output helpers ───────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

step() { echo -e "\n${BLUE}▶ $1${NC}"; }
info() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
die()  { echo -e "${RED}✗ $1${NC}"; exit 1; }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 Oracle Always Free — All-in-One Server Setup"
echo "     Ubuntu + swap + firewall + Coolify + keepalive"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Re-run as root if needed ────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "  Not running as root: re-running with sudo..."
  exec sudo bash "$0" "$@"
fi

# ─── Basic checks ────────────────────────────────────────────────────────────
[[ -f /etc/os-release ]] || die "This script needs a Linux system with /etc/os-release."
# shellcheck disable=SC1091
. /etc/os-release
info "Detected OS: ${PRETTY_NAME:-unknown}"
case "${ID:-}" in
  ubuntu|debian) ;;
  *) warn "Tested on Ubuntu/Debian only — continuing anyway." ;;
esac

ARCH="$(uname -m)"
if [[ "$ARCH" == "aarch64" ]]; then
  info "CPU architecture: ARM64 (aarch64) — correct for Oracle A1.Flex ✅"
else
  warn "CPU architecture: ${ARCH} — works, but the Oracle free tier VM is ARM (aarch64)."
fi

TOTAL_RAM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
info "Total RAM: ${TOTAL_RAM_MB} MB"
if [[ "$TOTAL_RAM_MB" -lt 2000 ]]; then
  warn "Less than 2 GB RAM: Coolify needs 2 GB minimum. Continuing anyway."
fi

# Tools we need (curl/python3 are preinstalled on Oracle Ubuntu, but be safe).
command -v curl    >/dev/null 2>&1 || apt-get install -y curl
command -v python3 >/dev/null 2>&1 || apt-get install -y python3

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1/8 — Update system packages
# ═════════════════════════════════════════════════════════════════════════════
step "1/8  Updating system packages (security patches)..."

apt-get update -y
# --force-confdef/--force-confold: keep existing configs (no interactive prompts).
DEBIAN_FRONTEND=noninteractive apt-get -y \
  -o Dpkg::Options::=--force-confdef \
  -o Dpkg::Options::=--force-confold \
  upgrade
info "System packages updated"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2/8 — 8 GB swap file
# ═════════════════════════════════════════════════════════════════════════════
step "2/8  Creating 8 GB swap file (prevents out-of-memory crashes during builds)..."

if swapon --show 2>/dev/null | grep -q .; then
  info "Swap already active: $(swapon --show --noheadings | awk '{print $1}' | tr '\n' ' ')"
else
  FREE_DISK_MB=$(df -m / | awk 'NR==2 {print $4}')
  if [[ "$FREE_DISK_MB" -lt 8192 ]]; then
    warn "Less than 8 GB free disk: creating a 4 GB swap instead."
    SWAP_SIZE="4G"
  else
    SWAP_SIZE="8G"
  fi
  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  info "${SWAP_SIZE} swap file created and activated"
fi

# Only swap when RAM is genuinely low (keeps apps fast).
if ! grep -q '^vm.swappiness' /etc/sysctl.conf; then
  echo 'vm.swappiness=10' >> /etc/sysctl.conf
fi
sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
info "Swappiness set to 10 (swap only when RAM is low)"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 3/8 — Open ports 80 / 443 / 8000 / 6001 / 6002 (Oracle's 2nd firewall)
# ═════════════════════════════════════════════════════════════════════════════
step "3/8  Opening ports 80 / 443 / 8000 / 6001 / 6002 in iptables (Oracle's hidden firewall)..."

# WHY THIS IS NEEDED (verified the hard way):
#   Oracle Cloud Ubuntu images ship a default REJECT rule in iptables that
#   blocks ALL incoming traffic except SSH — even after you open the ports
#   in the OCI console Security List. Oracle has TWO firewalls:
#     1. the cloud one (Security List — you open it in the website console)
#     2. the in-VM one (iptables — this step)
#   We do NOT delete Oracle's REJECT rule: we INSERT our ACCEPT rules
#   AHEAD of it. All other ports stay closed = safer.
#
#   Port 22   = SSH (already open by default — do not touch)
#   Port 80   = HTTP  (websites, Let's Encrypt certificate checks)
#   Port 443  = HTTPS (websites with SSL)
#   Port 8000 = Coolify dashboard (http://YOUR_IP:8000)
#   Port 6001 = Coolify dashboard LIVE-UPDATES (streaming deploy logs)
#   Port 6002 = Coolify WEB TERMINAL (command box inside the dashboard)
#   (6001/6002 verified from Coolify's official firewall documentation;
#    after you later put the dashboard behind a domain, those three ports
#    can be closed again — the dashboard then travels via 443.)
port_open() {
  iptables -C INPUT -m state --state NEW -p tcp --dport "$1" -j ACCEPT 2>/dev/null && return 0
  iptables -C INPUT -p tcp --dport "$1" -j ACCEPT 2>/dev/null && return 0
  return 1
}
for PORT in 80 443 8000 6001 6002; do
  if port_open "$PORT"; then
    info "Port ${PORT} already open: skipping"
  else
    # Insert at position 5 (right before Oracle's REJECT rule on default
    # images). If the chain is shorter (non-Oracle server), fall back to
    # inserting at the top — always lands BEFORE any REJECT rule.
    iptables -I INPUT 5 -m state --state NEW -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null \
      || iptables -I INPUT -m state --state NEW -p tcp --dport "$PORT" -j ACCEPT
    info "Port ${PORT} opened"
  fi
done

# CRITICAL: iptables-persistent is NOT preinstalled on Oracle Ubuntu images.
# Without it the rules VANISH on the next reboot and every site goes down
# while everything looks healthy. Install it first, then save.
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent >/dev/null 2>&1 || true
netfilter-persistent save 2>/dev/null || iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
systemctl enable netfilter-persistent 2>/dev/null || true
info "iptables rules saved (survive reboots). SSH 22 / HTTP 80 / HTTPS 443 / Coolify 8000+6001+6002 open — everything else stays blocked"

# NOTE: we intentionally do NOT enable ufw (Ubuntu's simple firewall).
# Docker + ufw conflict (Docker bypasses ufw), and Oracle already gives us
# two firewall layers (Security List + iptables). Three layers = confusion.

# ═════════════════════════════════════════════════════════════════════════════
# STEP 4/8 — Automatic security updates
# ═════════════════════════════════════════════════════════════════════════════
step "4/8  Enabling automatic security updates..."

DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades >/dev/null 2>&1 || true
dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null 2>&1 || true
info "Automatic security updates enabled (Ubuntu installs patches by itself)"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 5/8 — Install Coolify (Docker + Coolify dashboard + Traefik)
# ═════════════════════════════════════════════════════════════════════════════
step "5/8  Installing Coolify — your own self-hosted Vercel (takes 3-10 minutes)..."

# Coolify = a web dashboard that turns this server into a hosting platform:
# push code to GitHub → it builds & runs it as a Docker container, gives it
# a domain, and handles HTTPS certificates automatically (via Traefik).
# The official installer also installs Docker itself. One stack, everything
# included — that's exactly why we use it instead of assembling pieces.
if [[ -d /data/coolify ]] && command -v docker >/dev/null 2>&1; then
  info "Coolify is already installed — skipping (update it from its own dashboard)"
else
  curl -fsSL https://get.coollabs.io/coolify/install.sh | bash
  info "Coolify installed"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 6/8 — Anti-reclaim KEEPALIVE (keeps Oracle from deleting your VM)
# ═════════════════════════════════════════════════════════════════════════════
step "6/8  Installing anti-reclaim keepalive service..."

# WHY THIS EXISTS (verified from Oracle's official documentation):
#   Oracle reclaims (deletes!) Always Free instances that look IDLE.
#   An instance is "idle" when, for 7 DAYS IN A ROW, ALL THREE are true:
#     • CPU utilization (95th percentile) below 20%
#     • Network utilization below 20%
#     • Memory utilization below 20%        (applies to A1 ARM shapes)
#   The magic word is ALL: break ONE condition and the instance can NEVER
#   be classified as idle.
#
#   A fresh Coolify server uses only ~1.5-2 GB of 12 GB RAM (~13-17%) —
#   BELOW the 20% memory line. Without help, Oracle may RECLAIM an
#   idle-flagged instance (it gets stopped first, then eventually deleted
#   — the documented criteria are above; the exact deletion timeline is
#   not published by Oracle, so don't gamble on it).
#
#   THE FIX (installed here): a tiny background service that holds JUST
#   ENOUGH RAM to keep memory utilization at ~26% — safely above the line.
#   It is SMART:
#     • As you deploy real apps and they use more RAM, the keepalive
#       automatically RELEASES what it holds (it never wastes memory
#       your apps need).
#     • It costs ~0% CPU (it allocates memory and sleeps).
#     • Under memory pressure the OS is told to kill IT first — never
#       your real apps — and it simply re-balances a minute later.
#
#   Once your real apps use more than ~22% of RAM on their own, the
#   keepalive holds nothing at all. You can also disable it anytime:
#     sudo systemctl disable --now oracle-keepalive
mkdir -p /opt/oracle-keepalive

cat > /opt/oracle-keepalive/keepalive.py <<'PYEOF'
#!/usr/bin/env python3
"""
Oracle Always Free anti-reclaim keepalive.

Oracle's rule (verified, docs.oracle.com — Always Free Resources):
an instance is reclaimed as IDLE when, for 7 days, ALL of these hold:
  - CPU (95th percentile) < 20%
  - network < 20%
  - memory < 20%   (A1 ARM shapes)

This daemon breaks the MEMORY condition by holding just enough RAM to keep
utilization around 26% — and releases it automatically when your real apps
need it (or once they keep utilization above the line by themselves).
Costs ~0 CPU. Logs a status line once an hour.
"""
import time

TARGET = 0.26          # aim for 26% total memory utilization
RELEASE_ABOVE = 0.22   # if real apps already use >= 22%, hold nothing
HARD_CAP = 0.32        # never push total utilization above 32%
CHECK_EVERY = 60       # seconds between adjustments
REALLOC_DIFF = 512 * 1024 * 1024   # only resize if the change is > 512 MB
MIN_HOLD = 128 * 1024 * 1024       # don't bother holding below 128 MB


def read_meminfo():
    info = {}
    try:
        with open('/proc/meminfo') as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 2 and parts[0].endswith(':'):
                    try:
                        info[parts[0][:-1]] = int(parts[1])  # kB
                    except ValueError:
                        pass
    except OSError:
        pass
    return info


def touch_pages(buf):
    """Touch one byte per 4 MB so allocated pages become truly resident."""
    step = 4 * 1024 * 1024
    for i in range(0, len(buf), step):
        buf[i] = 1


def main():
    hold = None
    own_bytes = 0
    last_log = 0.0
    while True:
        try:
            mi = read_meminfo()
            total_kb = mi.get('MemTotal', 0)
            if total_kb:
                total = total_kb * 1024
                used = max(0, (total_kb - mi.get('MemAvailable', total_kb)) * 1024)
                # "used" includes OUR hold; subtract it to see real apps.
                external = max(0, used - own_bytes)
                frac = external / total if total else 0.0

                if frac >= RELEASE_ABOVE:
                    want = 0
                else:
                    want = int(total * TARGET - external)
                    headroom = int(total * HARD_CAP - external)
                    want = max(0, min(want, headroom))

                if want < MIN_HOLD:
                    want = 0

                if want == 0:
                    if hold is not None:
                        hold = None
                        own_bytes = 0
                elif hold is None or abs(own_bytes - want) > REALLOC_DIFF:
                    # Release old chunk, then allocate the new size.
                    hold = None
                    own_bytes = 0
                    time.sleep(2)
                    try:
                        hold = bytearray(want)
                        touch_pages(hold)
                        own_bytes = want
                    except MemoryError:
                        hold = None
                        own_bytes = 0

                now = time.time()
                if now - last_log > 3600:
                    last_log = now
                    stamp = time.strftime('%Y-%m-%d %H:%M:%S')
                    real_mb = int(external / (1024 * 1024))
                    held_mb = int(own_bytes / (1024 * 1024))
                    pct = int(((external + own_bytes) / total) * 100) if total else 0
                    print(f"[{stamp}] real apps: {real_mb} MB | keepalive holding: "
                          f"{held_mb} MB | total memory utilization: {pct}%", flush=True)
        except Exception:
            # Never crash: an exception in one cycle must not stop protection.
            pass
        time.sleep(CHECK_EVERY)


if __name__ == '__main__':
    main()
PYEOF
chmod 755 /opt/oracle-keepalive/keepalive.py

cat > /etc/systemd/system/oracle-keepalive.service <<'EOF'
[Unit]
Description=Oracle Always Free anti-reclaim keepalive (keeps memory utilization above the 20% idle line)
Documentation=https://docs.oracle.com/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/oracle-keepalive/keepalive.py
Restart=always
RestartSec=15
# Lowest CPU priority: never competes with real work.
Nice=19
# If memory ever runs out, the OS kills THIS service first (not your apps).
OOMScoreAdjust=800
# Hard safety cap: this service can never hold more than 4 GB.
MemoryMax=4G

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now oracle-keepalive
info "Keepalive service installed and running"
info "Check it anytime:  systemctl status oracle-keepalive"
info "Watch its log:     journalctl -u oracle-keepalive -f"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 7/8 — Disk hygiene (so the 200 GB disk never fills up)
# ═════════════════════════════════════════════════════════════════════════════
step "7/8  Installing disk hygiene (journal cap + monthly Docker cleanup)..."

# 1. Cap the systemd journal at 200 MB (default is 10% of the disk = 20 GB!).
mkdir -p /etc/systemd/journald.conf.d
printf '%s\n' \
  '# oracle-setup: keep the systemd journal bounded' \
  '[Journal]' \
  'SystemMaxUse=200M' \
  'SystemKeepFree=1G' \
  > /etc/systemd/journald.conf.d/oracle-setup.conf
systemctl restart systemd-journald 2>/dev/null || true
journalctl --vacuum-size=200M >/dev/null 2>&1 || true
info "Systemd journal capped at 200 MB"

# 2. Cron: monthly Docker cleanup (old images from redeploys pile up fast —
#    every Next.js image is 0.5-1.5 GB) + weekly journal trim.
cat > /etc/cron.d/oracle-hygiene <<'CRON'
# oracle-setup: monthly Docker cleanup — removes unused images/containers
# (images used by RUNNING containers are never touched) so the disk stays healthy.
0 4 1 * * root docker system prune -f >> /var/log/oracle-hygiene.log 2>&1
# oracle-setup: weekly journal trim to 200 MB.
0 4 * * 0 root journalctl --vacuum-size=200M >> /var/log/oracle-hygiene.log 2>&1
CRON
chmod 644 /etc/cron.d/oracle-hygiene
info "Hygiene cron installed (monthly Docker prune + weekly journal trim)"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 8/8 — Summary + next steps
# ═════════════════════════════════════════════════════════════════════════════
step "8/8  Done! Collecting your server info..."

# Detect the public IP (Oracle metadata service first, fallback to ifconfig.me).
PUB_IP=""
PUB_IP=$(curl -s --max-time 5 -H "Authorization: Bearer Oracle" \
  http://169.254.169.254/opc/v2/vnics/ 2>/dev/null \
  | grep -oE '"publicIp": *"[^"]+"' | head -1 \
  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || true)
[[ -z "$PUB_IP" ]] && PUB_IP=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null || true)
[[ -z "$PUB_IP" ]] && PUB_IP="YOUR_SERVER_IP"

DISK_USAGE=$(df -h / | awk 'NR==2 {print $3 " used of " $2 " (" $5 ")"}')
RAM_USED=$(free -h | awk '/Mem/ {printf "%s used of %s", $3, $2}')
SWAP_USED=$(free -h | awk '/Swap/ {printf "%s used of %s", $3, $2}')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ SERVER SETUP COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Server health:"
echo "    • RAM:  ${RAM_USED}"
echo "    • Swap: ${SWAP_USED}"
echo "    • Disk: ${DISK_USAGE}"
echo "    • Keepalive: $(systemctl is-active oracle-keepalive) ($(systemctl is-enabled oracle-keepalive) on boot)"
echo "      ↳ the anti-reclaim bodyguard: INSTALLED and running (auto-starts every"
echo "        boot) — Oracle can never flag this server as idle. GUIDE.md Part 9."
echo ""
echo "  ── YOUR COOLIFY DASHBOARD ─────────────────────────"
echo ""
echo "    ➡️  Open in your browser:  http://${PUB_IP}:8000"
echo ""
echo "    ⏱ REGISTER WITHIN 10 MINUTES (Coolify's rule, from its latest docs):"
echo "       click 'Register' NOW and create your admin account."
echo "       If it says 'Setup window closed':  sudo docker restart coolify"
echo "       then reload the page and register immediately."
echo ""
echo "    (If the page does NOT load: you still need to open port 8000"
echo "     in the Oracle console — GUIDE.md Part 5 shows exactly how.)"
echo ""
echo "  ── WHAT HAPPENS NEXT (GUIDE.md has every step) ────"
echo ""
echo "    1. GUIDE.md Part 8  → Coolify first login (10-minute rule!)"
echo "    2. GUIDE.md Part 9  → how your server stays alive (keepalive)"
echo "    3. GUIDE.md Part 10 → the 100% security checklist"
echo "    4. GUIDE.md Part 11 → connect your domain (Cloudflare)"
echo "    5. GUIDE.md Part 12 → deploy your first Next.js app"
echo "    6. GUIDE.md Part 13 → install WordPress (one click)"
echo ""
echo "  ── COST ────────────────────────────────────────────"
echo ""
echo "    Everything above = \$0/month on the Oracle Always Free tier."
echo "    Keep it that way: NEVER click 'Upgrade to Pay As You Go',"
echo "    keep everything in your home region (US East — Ashburn),"
echo "    total storage stays ≤ 200 GB, max 5 volume backups."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
