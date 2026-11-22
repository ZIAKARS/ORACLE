#!/usr/bin/env bash
# ============================================================================
#  retry-launch.sh — Oracle Always Free "Out of capacity" AUTO-RETRY
# ============================================================================
#  WHAT THIS DOES
#    Keeps trying to create the free server from GUIDE.md Part 4 (Ubuntu 24.04,
#    Ampere A1, 2 OCPU, 12 GB RAM, 200 GB boot volume, your SSH key, automatic
#    public IP) — cycling through ALL availability domains (AD-1 / AD-2 / AD-3),
#    over and over, until Oracle frees a slot. The moment one opens, your
#    server is created and this script prints its Public IP.
#
#  WHERE TO RUN IT  (Oracle Cloud Shell — free, nothing to install)
#    1. Log in at https://cloud.oracle.com
#    2. Check the region selector (top-right) shows your HOME region
#       (US East / Ashburn) — Cloud Shell follows it
#    3. Click the  >_  "Developer tools" icon (top-right) -> Cloud Shell
#    4. Wait ~20 seconds for the black terminal, then run this script there.
#    Cloud Shell is already logged in as you — no API keys, no setup.
#
#  BEFORE RUNNING (one-time, all in the console — none of it needs capacity)
#    A. The VCN must exist — GUIDE.md Part 4.1
#       (Networking -> Virtual Cloud Networks -> Start VCN Wizard ->
#        "Create VCN with Internet Connectivity"). This ALWAYS succeeds.
#    B. Open the ports while you wait — GUIDE.md Part 5 (applies to the VCN,
#       so you can do it before the server exists).
#
#  HOW TO RUN
#       git clone https://github.com/ZIAKARS/ORACLE.git
#       cd ORACLE
#       # fill in the 3 values at the top of retry-launch.sh
#       # (easiest: click the pencil "Open editor" icon in Cloud Shell's
#       #  toolbar, edit the file, Ctrl+S)
#       bash retry-launch.sh
#    Keep the browser tab open. If Cloud Shell disconnects, reopen it and run
#    the script again — it is safe to re-run (it refuses to create a 2nd VM).
#
#  SAFE BY DESIGN
#    - Exits if an instance already exists (never creates a second server)
#    - Refuses to run outside your home region (never touches paid regions)
#    - Only ever launches the exact free-tier config from the guide
#    - Stops on any error that is NOT "out of capacity"
#    - Ctrl+C = clean stop
# ============================================================================

set -u

# ────────────────────────── EDIT THESE 3 VALUES ─────────────────────────────

# 1) YOUR TENANCY OCID — get it: console top-right profile icon -> Tenancy ->
#    "OCID" -> Copy. It starts with:  ocid1.tenancy.oc1..
COMPARTMENT_ID="ocid1.tenancy.oc1..PASTE_YOURS_HERE"

# 2) SUBNET — leave EMPTY to auto-detect your VCN's public subnet (recommended).
#    Manual override (rarely needed): your VCN -> Subnets -> public subnet ->
#    copy its OCID (starts with ocid1.subnet.oc1..)
SUBNET_ID=""

# 3) YOUR SSH PUBLIC KEY — exactly ONE line starting with ssh-rsa / ssh-ed25519
#    On your PC (Git Bash / Terminal, inside your ORACLE folder) run:
#         ssh-keygen -y -f oracle.key
#    and paste the printed line between the quotes below.
#    NEVER paste the private key (it starts with -----BEGIN).
SSH_PUBLIC_KEY="PASTE_YOUR_PUBLIC_KEY_ONE_LINE_HERE"

# ─────────────────── server spec — matches GUIDE.md Part 4 ──────────────────
SHAPE="VM.Standard.A1.Flex"    # the Always Free ARM shape
OCPUS="2"                      # free allowance total: 4
MEMORY_GB="12"                 # free allowance total: 24
BOOT_GB="200"                  # free storage total: 200 (all on boot volume)
DISPLAY_NAME="coolify-server"  # same name the guide uses
PAUSE_BETWEEN_CYCLES="20"      # seconds to wait after trying every AD once

# ─────────────────────────────────────────────────────────────────────────────

BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; RESET="\033[0m"

say()  { echo -e "$@"; }
ok()   { echo -e "${GREEN}[OK]${RESET} $@"; }
warn() { echo -e "${YELLOW}[!]${RESET} $@"; }
die()  { echo -e "${RED}[STOP]${RESET} $@"; exit 1; }

trap 'echo; warn "Stopped by you. No half-created server was left behind — Oracle either accepted a launch (you would see SUCCESS above) or nothing happened. Re-run anytime."; exit 130' INT TERM

echo -e "${BOLD}"
echo "=============================================================="
echo "  Oracle Always Free — A1 capacity hunter (auto-retry)"
echo "  Server spec: Ubuntu 24.04 | ${SHAPE} | ${OCPUS} OCPU |"
echo "               ${MEMORY_GB} GB RAM | ${BOOT_GB} GB boot | auto public IP"
echo "=============================================================="
echo -e "${RESET}"

# ── sanity checks ───────────────────────────────────────────────────────────
command -v oci >/dev/null 2>&1 || die "The OCI CLI was not found. You must run this inside ORACLE CLOUD SHELL (the '>_' icon, top-right of the console at cloud.oracle.com) — the CLI is pre-installed and pre-logged-in there."

case "$COMPARTMENT_ID" in
  ""|"ocid1.tenancy.oc1..PASTE_YOURS_HERE"|ocid1.*PASTE*) die "COMPARTMENT_ID is not filled in yet. Open the console profile menu -> Tenancy -> copy the OCID (starts with ocid1.tenancy.oc1..) and paste it into the COMPARTMENT_ID variable at the top of this script.";;
  ocid1.tenancy.oc1.*|ocid1.compartment.oc1.*) : ;;
  *) die "COMPARTMENT_ID doesn't look like an OCID (it must start with ocid1.tenancy.oc1.. or ocid1.compartment.oc1..). Copy it again from the console: profile icon -> Tenancy -> OCID.";;
esac

case "$SSH_PUBLIC_KEY" in
  ""|*PASTE_YOUR_PUBLIC_KEY*) die "SSH_PUBLIC_KEY is not filled in yet. On your PC, in your ORACLE folder, run:  ssh-keygen -y -f oracle.key   — then paste the printed one-line key into the SSH_PUBLIC_KEY variable at the top of this script.";;
  -----BEGIN*|*"PRIVATE KEY"*) die "That looks like your PRIVATE key — never paste that anywhere! You need the PUBLIC key: on your PC run  ssh-keygen -y -f oracle.key  and paste the single line it prints (starts with ssh-rsa or ssh-ed25519).";;
  ssh-*) : ;;
  ssh-ed25519*|ecdsa-*) : ;;
  *) die "SSH_PUBLIC_KEY doesn't look right — it must be ONE line starting with ssh-rsa or ssh-ed25519 (the output of:  ssh-keygen -y -f oracle.key).";;
esac

# normalize: silently strip stray Windows carriage returns and outer whitespace
SSH_PUBLIC_KEY="$(printf '%s' "$SSH_PUBLIC_KEY" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [ "$(printf '%s' "$SSH_PUBLIC_KEY" | wc -l)" -gt 0 ]; then
  die "SSH_PUBLIC_KEY must be ONE single line. Remove any line breaks (the key is one long line, no Enter in the middle)."
fi

# ── region guard: NEVER create anything outside the home region ─────────────
ACTIVE_REGION="$(oci configure get region 2>/dev/null | tail -n1 | cut -d= -f2 | tr -d '[:space:]')"
HOME_REGION="$(oci iam region-subscription list --query 'data[?"is-home-region" == `true`]."region-name" | [0]' --raw-output 2>/dev/null | tr -d '[:space:]')"
if [ -n "$ACTIVE_REGION" ] && [ -n "$HOME_REGION" ]; then
  if [ "$ACTIVE_REGION" = "$HOME_REGION" ]; then
    ok "Region check: ${ACTIVE_REGION} (this is your home region — correct)"
  else
    die "SAFETY STOP: Cloud Shell is in '${ACTIVE_REGION}' but your HOME region is '${HOME_REGION}'. Free resources only exist in the home region (Golden Rule #2). Fix: in the console, top-right region selector -> switch to your home region -> reopen Cloud Shell -> run again."
  fi
else
  warn "Could not auto-verify the region. Manually confirm the console's region selector (top-right) shows your HOME REGION before letting this run."
fi

# ── refuse to create a second server ────────────────────────────────────────
EXISTING_COUNT="$(oci compute instance list --compartment-id "$COMPARTMENT_ID" --all \
  --query 'length(data[?"lifecycle-state" != '\''TERMINATED'\'' && "lifecycle-state" != '\''TERMINATING'\''])' --raw-output 2>/dev/null)"
if [ -n "$EXISTING_COUNT" ] && [ "$EXISTING_COUNT" != "null" ] && [ "$EXISTING_COUNT" != "0" ]; then
  warn "You already have ${EXISTING_COUNT} instance(s) in this compartment:"
  oci compute instance list --compartment-id "$COMPARTMENT_ID" --all \
    --query 'data[?"lifecycle-state" != '\''TERMINATED'\'']."display-name"' --raw-output 2>/dev/null | tr -d '[]" ' | tr ',' '\n' | sed 's/^/     - /'
  die "This script only creates your FIRST server (it will not stack a second one). If the instance above is broken, delete it via the console (GUIDE.md Part 3), then re-run."
fi
ok "No existing instances — good, the field is clear"

# ── availability domains ────────────────────────────────────────────────────
ADS_RAW="$(oci iam availability-domain list --compartment-id "$COMPARTMENT_ID" --query 'data[].name' --raw-output 2>/dev/null)"
IFS=',' read -r -a ADS <<< "$(printf '%s' "$ADS_RAW" | tr -d '[] "')"
[ "${#ADS[@]}" -ge 1 ] && [ -n "${ADS[0]:-}" ] || die "Could not list availability domains. Is COMPARTMENT_ID correct?"
ok "Availability domains in the hunt: ${ADS[*]}"

# ── subnet ──────────────────────────────────────────────────────────────────
if [ -z "$SUBNET_ID" ]; then
  SUBNET_ID="$(oci network subnet list --compartment-id "$COMPARTMENT_ID" \
    --query 'data[?contains("display-name", '\''ublic'\'')].id | [0]' --raw-output 2>/dev/null)"
  if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" = "null" ]; then
    SUBNET_ID="$(oci network subnet list --compartment-id "$COMPARTMENT_ID" \
      --query 'data[0].id' --raw-output 2>/dev/null)"
  fi
  if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" = "null" ]; then
    die "No subnet found. Create the VCN first (GUIDE.md Part 4.1): console -> Networking -> Virtual Cloud Networks -> Start VCN Wizard -> 'Create VCN with Internet Connectivity' -> Create. Takes ~3 minutes and never fails. Then run this script again."
  fi
fi
case "$SUBNET_ID" in
  ocid1.subnet.oc1.*) : ;;
  *) die "SUBNET_ID doesn't look like a subnet OCID (must start with ocid1.subnet.oc1..). Best: empty the variable and let the script auto-detect.";;
esac
ok "Using subnet: ${SUBNET_ID}"

# ── image: newest Canonical Ubuntu 24.04 (NOT Minimal, NOT Oracle Linux) ────
IMAGE_ID="$(oci compute image list --compartment-id "$COMPARTMENT_ID" \
  --operating-system 'Canonical Ubuntu' --operating-system-version '24.04' \
  --sort-by TIMECREATED --sort-order DESC --all \
  --query 'data[?contains(name, '\''Minimal'\'') != `true`].id | [0]' --raw-output 2>/dev/null)"
if [ -z "$IMAGE_ID" ] || [ "$IMAGE_ID" = "null" ]; then
  IMAGE_ID="$(oci compute image list --compartment-id "$COMPARTMENT_ID" \
    --operating-system 'Canonical Ubuntu' --operating-system-version '24.04' \
    --sort-by TIMECREATED --sort-order DESC --all \
    --query 'data[0].id' --raw-output 2>/dev/null)"
fi
[ -n "$IMAGE_ID" ] && [ "$IMAGE_ID" != "null" ] || die "Could not find the Ubuntu 24.04 image. Check the region (must be your home region) and COMPARTMENT_ID."
ok "Image: newest Canonical Ubuntu 24.04 (aarch64)"

# ── pick the SSH-key flag this CLI version supports ─────────────────────────
if oci compute instance launch --help 2>/dev/null | grep -q -- '--ssh-authorized-keys-file'; then
  printf '%s\n' "$SSH_PUBLIC_KEY" > /tmp/oracle-launch-key.pub
  SSH_KEY_ARGS=(--ssh-authorized-keys-file /tmp/oracle-launch-key.pub)
else
  SSH_KEY_ARGS=(--ssh-authorized-keys "$SSH_PUBLIC_KEY")
fi
SHAPE_CONFIG="{\"ocpus\": ${OCPUS}, \"memoryInGBs\": ${MEMORY_GB}}"

echo
say "${BOLD}Everything checks out. Starting the hunt — leave this tab open.${RESET}"
say "   Each line below is one real launch attempt. 'Out of capacity' is the"
say "   normal thing to see — the win comes from never giving up."
say "   Typical wait in Ashburn: minutes to hours (occasionally a day)."
echo

ATTEMPT=0
LAUNCH_OUT=""

while true; do
  for AD in "${ADS[@]}"; do
    ATTEMPT=$((ATTEMPT + 1))
    printf '[%s] attempt #%-4s -> %s ... ' "$(date '+%H:%M:%S')" "$ATTEMPT" "$AD"

    LAUNCH_OUT="$(oci compute instance launch \
      --compartment-id       "$COMPARTMENT_ID" \
      --availability-domain  "$AD" \
      --display-name         "$DISPLAY_NAME" \
      --subnet-id            "$SUBNET_ID" \
      --assign-public-ip     true \
      --image-id             "$IMAGE_ID" \
      --shape                "$SHAPE" \
      --shape-config         "$SHAPE_CONFIG" \
      "${SSH_KEY_ARGS[@]}" \
      --boot-volume-size-in-gbs "$BOOT_GB" 2>&1)"

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}GOT ONE!${RESET}"
      break 2
    fi

    ERR="$(printf '%s' "$LAUNCH_OUT" | tr '\n' ' ')"
    if printf '%s' "$ERR" | grep -qi 'out of capacity\|out of host capacity'; then
      echo "out of capacity (normal) — next!"
    elif printf '%s' "$ERR" | grep -qi 'too many requests\|429\|throttl'; then
      echo "rate-limited for a moment — pausing ${PAUSE_BETWEEN_CYCLES}s"
      sleep "$PAUSE_BETWEEN_CYCLES"
    elif printf '%s' "$ERR" | grep -qi 'service limits were exceeded\|limit.*exceed\|quota'; then
      die "Oracle says a service LIMIT was exceeded — an A1 instance may already exist in this tenancy. Check the console: Compute -> Instances. If one exists, you don't need this script anymore. If it's broken, follow GUIDE.md Part 3 (full teardown), then re-run."
    elif printf '%s' "$ERR" | grep -qi 'NotAuthenticated\|AuthorizationFailed\|not authorized\|token'; then
      die "Your Cloud Shell login expired. Refresh the browser page, reopen Cloud Shell, run this script again — it resumes right where it left off."
    elif printf '%s' "$ERR" | grep -qi 'NotAuthorizedOrNotFound'; then
      die "OCI says the compartment/subnet was not found. Re-check COMPARTMENT_ID (Tenancy OCID) and SUBNET_ID (best: leave SUBNET_ID empty for auto-detect)."
    else
      echo ""
      die "Unexpected error (stopping so you can read it): $(printf '%s' "$ERR" | tail -c 400)"
    fi
  done
  sleep "$PAUSE_BETWEEN_CYCLES"
done

# ── success — find the public IP ────────────────────────────────────────────
INSTANCE_ID="$(printf '%s' "$LAUNCH_OUT" | grep -o 'ocid1\.instance[^" ,}]*' | head -n1)"

echo
ok "Instance created in ${AD} (provisioning now, ~1-2 minutes to RUNNING)"
[ -n "$INSTANCE_ID" ] && ok "Instance OCID: ${INSTANCE_ID}"

PUBLIC_IP=""
for _ in $(seq 1 30); do
  PUBLIC_IP="$(oci compute instance list-vnics --instance-id "$INSTANCE_ID" \
    --query 'data[0]."public-ip"' --raw-output 2>/dev/null)"
  if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "null" ]; then break; fi
  sleep 5
done

echo
echo -e "${BOLD}${GREEN}==============================================================${RESET}"
echo -e "${BOLD}${GREEN}  SUCCESS — YOUR FREE SERVER EXISTS${RESET}"
echo -e "${BOLD}${GREEN}==============================================================${RESET}"
if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "null" ]; then
  echo -e "  Public IP:   ${BOLD}${PUBLIC_IP}${RESET}"
else
  warn "Public IP not visible yet — find it in the console: Compute -> Instances -> ${DISPLAY_NAME} -> 'Public IP Address'"
fi
echo
echo "  What to do next (GUIDE.md):"
echo "   1. Part 4.3 — note your Public IP (above)"
echo "      (want a permanent reserved IP instead? Follow Part 4.3 Path B now)"
echo "   2. Part 5    — open the ports 22/80/443/8000/6001/6002 (if not done yet)"
echo "   3. Part 6    — connect:  ssh -i oracle.key ubuntu@YOUR_PUBLIC_IP"
echo "   4. Part 7    — run:      sudo bash setup.sh   (installs everything)"
echo
echo "  You can close Cloud Shell now. Good luck!"
echo
