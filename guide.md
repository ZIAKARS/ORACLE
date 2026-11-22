# 🚀 Oracle Cloud Always Free — Complete Server & Coolify Setup Guide

> **From zero → your own hosting platform, $0/month, forever.**
> Written for complete beginners: every step, every click, every command — nothing assumed, nothing skipped.
>
> - 🏠 **Home region:** US East (Ashburn) — set at signup, permanent
> - 💰 **Cost:** $0 (Always Free tier — and this guide shows exactly how it can *never* charge you)
> - 🧱 **Stack:** Ubuntu 24.04 + Coolify (Docker + Traefik included) + smart keepalive
> - 💾 **Storage:** ONE 200 GB boot volume — everything on one disk, one backup covers it all

---

## 📋 Table of Contents

| Part | What you do there | When |
|---|---|---|
| **0** | What you're building + your free allowance + the 5 golden rules | Read first |
| **1** | Concepts in plain English (VM, Docker, Coolify, Traefik, ports…) | Read first |
| **2** | Create your Oracle account | Once |
| **3** | Create your server (the VM with the 200 GB boot volume) | Once |
| **4** | Open the ports in the Oracle console (firewall #1) | Once |
| **5** | Connect to your server from your PC (the `oracle.key` file) | Every time |
| **6** | Run the magic script (`setup.sh` — it does everything) | Once |
| **7** | Coolify first login (your new dashboard) | Once |
| **8** | How your server stays alive forever (anti-reclaim) | Understand once |
| **9** | Connect your domain (Cloudflare) | Once per domain |
| **10** | Deploy your first Next.js app | Every new app |
| **11** | Install WordPress (one click) + other one-click apps | Anytime |
| **12** | What you can host + your RAM budget | Reference |
| **13** | OPTIONAL: add a block volume (only if you ever want one) | Skip unless needed |
| **14** | Backups (free, automatic, whole-server) | Set once |
| **15** | Maintenance habits (2 minutes every 2 weeks) | Habit |
| **16** | Troubleshooting (including the "boot volume not attached" fix) | When stuck |
| **17** | The "Never Get Charged" final checklist | Bookmark |
| **18** | Quick command reference | Bookmark |

---

# 🧭 Part 0 — What You're Building (5 minutes)

## The big picture

```
                         ┌──────────────────────────────────────────┐
   Visitors ──────────▶  │  YOUR ORACLE SERVER (free forever)       │
                         │                                          │
   Cloudflare DNS ─────▶ │  Traefik (traffic police, port 443)      │
   (points your domains  │    ├── app.yourdomain.com  → Container 1 │
    at your server IP)   │    ├── blog.yourdomain.com → Container 2 │
                         │    └── shop.yourdomain.com → Container 3 │
   You (browser) ──────▶ │  Coolify dashboard (port 8000)           │
                         │    └── deploy apps with clicks, like     │
                         │        Vercel/Netlify                    │
                         │                                          │
                         │  200 GB boot volume = EVERYTHING lives   │
                         │  on one disk: OS, apps, databases,       │
                         │  uploads. One backup = whole server.     │
                         └──────────────────────────────────────────┘
```

**In one sentence:** you get a free computer in Oracle's datacenter, put Coolify on it (a self-hosted Vercel), point your domains at it, and deploy as many apps as you want — all for $0/month.

## Your free allowance (Always Free tier, verified from Oracle's docs)

| Resource | How much you get | Notes |
|---|---|---|
| 🧠 CPU | **2 OCPU** (ARM Ampere A1) | One VM with 2, or two VMs with 1 each — we use ONE |
| 🐏 RAM | **12 GB** | Plenty: Coolify ~1.5 GB + your apps |
| 💾 Disk | **200 GB total** | Boot volume + block volumes COMBINED. We put all 200 on the boot volume |
| 🌍 Bandwidth | **10 TB/month** | You will never come close |
| 📦 Object Storage | 10 GB (+10 GB archive) | Great for database backups (separate from your 200 GB) |
| 📸 Volume backups | **5 total** | Full disk snapshots — your disaster recovery |
| ⏰ Hours | 1,500 OCPU-hours/month | Running 2 OCPU 24/7 all month ≈ 1,488 hours = still free |
| ⚡ Duration | **Forever** | As long as the account isn't idle/abandoned (Part 8 handles this) |

## ⚠️ The 5 Golden Rules (read twice — this is how you NEVER pay a cent)

| # | Rule | Why |
|---|---|---|
| 1️⃣ | **NEVER click "Upgrade to Pay As You Go"** | On a free account, Oracle *blocks* anything that would cost money (you get an error instead of a bill). Upgrading removes that safety block. It is the **only** way to ever be charged. |
| 2️⃣ | **Everything in your HOME region (US East — Ashburn) only** | Resources in other regions cost money *even on the free tier*. The region selector is in the top-right corner of the Oracle console — always check it shows your home region before creating anything. |
| 3️⃣ | **Total storage stays ≤ 200 GB** | Your single 200 GB boot volume uses exactly the full free amount. Never create extra volumes unless you shrink... you can't shrink — so never create extras (see Part 13 for the rare exception). |
| 4️⃣ | **Maximum 5 volume backups** | 1 weekly backup (Part 14) = you're safe forever. Creating a 6th just errors — but don't spam them anyway. |
| 5️⃣ | **Boot volume performance stays "Balanced" (default)** | Higher performance tiers (VPUS) are paid. Never touch that setting. |

💳 **About your card:** Oracle placed a temporary ~$1 hold at signup to verify it's real — that was refunded. On Always Free you receive **no invoice, no bill, nothing**. The Billing page shows $0.00 forever if you follow the rules above.

---

# 📚 Part 1 — Concepts in Plain English (5 minutes, read once)

You'll see these words everywhere. Here's what they actually mean — no jargon.

| Word | What it really is |
|---|---|
| **VM (instance)** | A computer that lives in Oracle's building instead of your home. It runs 24/7. Yours is ARM-based (a different CPU family than your PC — same idea, better price-per-power, which is why it's free). |
| **Boot volume** | The VM's hard disk. It comes with Ubuntu (the operating system) pre-installed. **Yours is 200 GB and holds everything.** |
| **Block volume** | An *extra* hard disk you *could* plug in. **You don't need one** — this guide puts everything on the boot volume. (Part 13 explains it just in case.) |
| **Ubuntu** | The operating system on your server — like Windows, but for servers, and free. |
| **SSH + key file** | The locked door to your server. The key file (`oracle.key`) stays on YOUR PC — anyone holding it can enter, so never share it, never upload it to GitHub. |
| **Port** | A numbered door on your server. Port 22 = SSH (you), 80/443 = websites (visitors), 8000 = Coolify dashboard (you). Everything else stays closed. |
| **Security List** | Oracle's cloud firewall (firewall #1). You open ports here in the website console. |
| **iptables** | The firewall *inside* Ubuntu (firewall #2). Oracle ships it with almost everything blocked — this trips everyone up (Part 6 fixes it automatically). |
| **Docker** | A way to package an app with everything it needs into a "container" — a sealed box that runs the same everywhere. |
| **Coolify** | A free, open-source **web dashboard** that turns your server into your own Vercel: connect GitHub → click deploy → app is live with HTTPS. It manages Docker *for* you. |
| **Traefik** | The traffic police that comes inside Coolify. Your server has ONE IP — Traefik reads each visitor's domain name and sends them to the right container. It also gets free SSL certificates automatically. You never touch it. |
| **Swap** | Overflow RAM on disk (8 GB). When an app build needs more RAM than you have, the server uses this instead of crashing. |
| **Keepalive** | A tiny bodyguard service this guide installs. It stops Oracle from deleting your server for being "idle" (full story in Part 8). |

## Why Coolify? (and not something else)

- ❌ **Plain Docker alone:** you'd hand-write config files for every app, every domain, every SSL certificate. Real work.
- ❌ **Vercel/Netlify:** great, but costs money when you grow, and can't host databases or WordPress.
- ✅ **Coolify:** one stack that includes Docker + dashboard + Traefik + one-click databases (PostgreSQL, MySQL, Redis, MongoDB…) + automatic SSL + scheduled backups. ~62,000 GitHub stars, huge community. The most Vercel-like self-hosted experience that exists.

**The rule:** one server, one stack (Coolify). Don't install Nginx manually, don't install Portainer, don't apt-get install PostgreSQL — Coolify provides all of it. Extra managers on top = the real redundancy to avoid.

---

# 👤 Part 2 — Create Your Oracle Account (one time, ~10 minutes)

> ✅ **Already have an account? Skip to Part 3.** (Your home region is US East — Ashburn.)

1. 🌐 Go to **https://signup.oraclecloud.com**
2. Fill in your **name, email, country** → verify your email
3. 💳 Enter a **real credit or debit card** — prepaid/virtual cards are rejected
   - This is identity verification only. You'll see a temporary ~$1 hold that disappears in days.
4. 📱 Verify your phone by SMS
5. 🌍 **CHOOSE YOUR HOME REGION: `US East (Ashburn)`**
   - ⚠️ **This choice is PERMANENT — it can never be changed.**
   - Your account already has it if you signed up. New signups: pick it carefully — it's where all your free resources must live.
6. Wait for the account to provision (minutes to a few hours — you get an email)

## What happens next (important to understand)

- Your account starts as a **Free Trial**: $300 of credit for 30 days.
- **Do nothing.** After 30 days it automatically converts to **Always Free** (the forever-free tier described in Part 0).
- ⚠️ During the trial you *can* create bigger stuff than the free limits — but when the trial ends, anything above the free limits gets stopped. **Simplest path: only ever create the things in this guide, and you'll never notice the trial even ended.**

> 💡 **The one button that must never be pressed:** "Upgrade to Pay As You Go" (sometimes shown as "Upgrade"). Golden Rule #1. A non-upgraded account *cannot* be charged — Oracle blocks paid resources with an error instead of billing you.

---

# 🖥️ Part 3 — Create Your Server (the VM, ~10 minutes)

> ⚠️ **Before you start:** look at the **top-right corner** of the Oracle console and confirm the region selector shows **US East (Ashburn)** — your home region. If it shows something else, click it and switch back. (Golden Rule #2.)

## 3.1 — The exact clicks

1. 🌐 Log in at **https://cloud.oracle.com**
2. ☰ Menu (top-left) → **Compute → Instances**
3. Click **Create instance**
4. Fill it in exactly like this:

| Setting | What to choose | Why |
|---|---|---|
| **Name** | `coolify-server` | Anything you like |
| **Image** | Click **Edit** → choose **Canonical Ubuntu 24.04** | ⚠️ Default is Oracle Linux — you MUST change it. Click "Change image" if needed. |
| **Shape** | Click **Edit** → **Ampere** (VM.Standard.A1.Flex) → **2 OCPUs, 12 GB RAM** | Your full free allowance on one machine |
| **SSH key** | Select **Generate a key pair** → click **Save Private Key** → save the file as **`oracle.key`** on your PC | This key file IS your server's door key — Part 5 uses it |

5. ⬇️ Scroll down to the **Boot volume** section and click **Specify a custom boot volume size**

| Setting | Value | Why |
|---|---|---|
| **Boot volume size** | **200 GB** | Uses your entire free 200 GB on ONE disk: everything (apps, databases, uploads) lives here, and ONE backup covers the whole server. Verified from Oracle's docs: up to 200 GB is Always Free. |
| **VPUS/performance** | Leave at default (**Balanced**) | Higher tiers are paid (Golden Rule #5) |

6. ✅ Click **Create**

7. 📋 When it finishes (1–2 min), note down your server's **Public IP Address** (shown on the instance page) — you'll use it constantly.

> 🗂️ **Where to put `oracle.key`:** create a folder on your PC (e.g. `ORACLE`), put `oracle.key` inside it, and clone this repo next to it. **Never upload `oracle.key` to GitHub or anywhere** — this repo's `.gitignore` already blocks `*.key` files just in case.

## 3.2 — If you see "Out of host capacity" error

Free ARM servers are shared — sometimes the local pool is full. **Do NOT switch regions** (that costs money). Instead:

1. 🔄 Click Retry a few times (often works within minutes)
2. 🕐 Try again at off-peak hours (late night US time)
3. 🔀 Try a different **Availability Domain** in the create form (AD-1 / AD-2 / AD-3 — all are still your home region, all still free)
4. 📉 Last resort: create it with **1 OCPU / 6 GB** — then later: stop the instance → Edit → change to 2/12 → start. (Don't leave it stopped for more than a day or two — see Part 8.)

## ⚠️ Two hard rules about the boot volume (learned the hard way)

1. **It can GROW but never SHRINK.** A 200 GB boot volume can become 250 GB (paid!) but never 100 GB.
2. **It can only be attached at instance creation.** If you ever see *"boot volume not attached"* on an instance — that instance is unfixable. The only cure: terminate it, **delete the orphaned boot volume too**, create fresh (full walk-through in Part 16).

---

# 🔓 Part 4 — Open the Ports in the Oracle Console (firewall #1, ~5 minutes)

By default your server only accepts SSH. Visitors need ports 80/443, and you need 8000 for the Coolify dashboard.

1. ☰ Menu → **Networking → Virtual Cloud Networks** (VCN)
2. Click your VCN's name (it was auto-created, usually starts with `vcn-`)
3. In the left sidebar under **Resources**, click **Security Lists**
4. Click **Default Security List for …**
5. Click **Add Ingress Rules** and add this rule, then repeat for each port:

| Field | Value |
|---|---|
| Source Type | CIDR |
| Source CIDR | `0.0.0.0/0` (means "from anywhere") |
| IP Protocol | TCP |
| Destination Port Range | see below |

Add **four** separate rules:

- ✅ Port `22` → SSH (you connecting)
- ✅ Port `80` → HTTP (websites + Let's Encrypt checks)
- ✅ Port `443` → HTTPS (websites with SSL)
- ✅ Port `8000` → Coolify dashboard

> 🔒 **Optional (nicer security):** for ports 22 and 8000, put *your home's IP* instead of `0.0.0.0/0` (Google "what is my IP"). Then only your house can reach the SSH/Coolify doors. If your home IP changes someday and you get locked out, just update the rule.

> 🧱 Done with firewall #1. Firewall #2 (inside the server) is handled automatically by `setup.sh` in Part 6.

---

# 🔑 Part 5 — Connect to Your Server (the `oracle.key` file)

Your server's door has no password — only the key file opens it.

## 5.1 — Prepare the key (one time)

**On Mac/Linux/Windows Git Bash:**
```bash
# Go to the folder where you saved oracle.key
cd /path/to/your/folder

# Make the key private (SSH refuses "too public" keys)
chmod 400 oracle.key
```

**On Windows (PowerShell):** open PowerShell as Administrator, then:
```powershell
icacls .\oracle.key /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

## 5.2 — Connect (every time)

```bash
ssh -i oracle.key ubuntu@YOUR_SERVER_IP
```
(Replace `YOUR_SERVER_IP` with the Public IP from Part 3. The username is always `ubuntu`.)

**First connection:** it asks `Are you sure you want to continue connecting?` → type `yes`.

✅ When you see a welcome message ending in a `$` prompt — **you're inside your server!** Everything you type now runs on the server, not your PC.

## 5.3 — Disconnect

```bash
exit
```

---

# ⚙️ Part 6 — Run the Magic Script (`setup.sh`)

This is the moment everything gets installed. **One script does all of it:**

| # | What it does | Why |
|---|---|---|
| 1 | Updates all system packages | Security patches |
| 2 | Creates 8 GB swap | App builds won't crash the server |
| 3 | Opens ports 80/443/8000 in iptables (firewall #2) | The #1 hidden gotcha on Oracle — sites "not loading" are almost always this |
| 4 | Enables automatic security updates | Ubuntu patches itself |
| 5 | Installs **Coolify** (Docker + dashboard + Traefik) | Your hosting platform |
| 6 | Installs the **keepalive** bodyguard | Oracle can never delete your server for being "idle" (Part 8) |
| 7 | Installs disk hygiene | Journal capped, monthly Docker cleanup — disk never fills |
| 8 | Prints your Coolify address + next steps | — |

## 6.1 — Run it

**SSH into your server** (Part 5), then:

```bash
# Get this repo onto the server
git clone https://github.com/ZIAKARS/ORACLE.git

# Enter it and run the script
cd ORACLE
sudo bash setup.sh
```

⏳ **Wait 5–15 minutes** (mostly the Coolify download/install). You'll see a green ✅ step-by-step progress. When it ends, it prints your server's health + your Coolify dashboard address:

```
➡️  Open in your browser:  http://YOUR_SERVER_IP:8000
```

> 🔄 The script is **safe to re-run** — every step checks first and skips if already done. If anything ever breaks, just run it again.

---

# 🎛️ Part 7 — Coolify First Login (once)

1. 🌐 Open **`http://YOUR_SERVER_IP:8000`** in your browser
   - ❌ Doesn't load? → Part 16, problem #1 (ports).
2. Click **Register** → create your admin account (email + a strong password — this is your server's front door)
3. ✅ You're in! This dashboard is your own Vercel.

## What's what in the dashboard

- **Projects** → your apps and databases live here
- **Servers** → your server's status (should show your VM, healthy)
- **Keys** → (GitHub connection for private repos — public repos work without it)
- **Settings** → server-wide options

> 🏆 **First recommended setting:** go to **Servers → your server → Cleanup** (or in Settings) and enable **automatic Docker image cleanup**. Old deployment images pile up (each 0.5–1.5 GB) — this plus the monthly cron from `setup.sh` keeps the 200 GB disk healthy.

---

# ❤️ Part 8 — How Your Server Stays Alive Forever (understand once)

## The threat (verified from Oracle's official documentation)

Oracle deletes free servers that look **abandoned**. Two separate rules:

### Rule A — the "idle instance" rule
> Oracle reclaims an Always Free instance when, **for 7 days in a row, ALL THREE** are true:
> - CPU utilization (95th percentile) **below 20%**
> - Network utilization **below 20%**
> - Memory utilization **below 20%** *(applies to ARM A1 shapes — that's you)*

**The magic word is ALL.** Break *one* condition → your server can never be called idle.

### Rule B — the "abandoned account" rule
> An account with **no console login for 30+ days** may be deemed abandoned.

## Your protection (already installed by `setup.sh`)

**The keepalive bodyguard** (a tiny background service):

- A fresh Coolify server only uses ~1.5–2 GB of 12 GB RAM = **~13–17%** — *below* the 20% line ⚠️
- The keepalive holds just enough RAM to keep utilization at **~26%** — safely above the line ✅
- It's **smart**: when you deploy real apps and they use more RAM, it automatically *releases* what it holds. Your apps always get memory first.
- Costs **0% CPU** and can never hold more than 4 GB (hard safety cap).

**Commands you'll ever need:**

```bash
# Is the bodyguard alive? (want: "active (running)")
systemctl status oracle-keepalive

# Watch what it's doing right now
journalctl -u oracle-keepalive -f     # Ctrl+C to stop watching

# Turn it off (ONLY when your real apps use >25% RAM on their own — check Part 12)
sudo systemctl disable --now oracle-keepalive

# Turn it back on
sudo systemctl enable --now oracle-keepalive
```

**When is it safe to disable?** Only when your real workloads keep memory above ~25% by themselves (check: `free -h` → used should be 3+ GB of 12 GB, or look at the Memory metric in the OCI console: Compute → Instances → your VM → Metrics). Honestly — just leave it on; it costs nothing and frees itself automatically.

## Your only manual job: the 2-minute habit 🗓️

> 📱 **Every 2 weeks:** open **cloud.oracle.com**, log in, glance that the instance is green and Billing shows $0. That's it. This single habit defeats Rule B forever. Set a phone reminder now: *"Oracle check-in — every other Sunday."*

## ⚠️ One more danger: never leave the server STOPPED

A **stopped** instance reports ~0% on everything = maximum idle = prime reclaim target (it gets stopped→deleted after ~90 days). If you ever stop it, start it again within a day or two. (Compute → Instances → your VM → **Start**.)

---

# 🌐 Part 9 — Connect Your Domain (Cloudflare, once per domain)

Your server has an IP like `140.238.x.x` — but visitors type `yourdomain.com`. Cloudflare (free) connects them AND adds CDN speed + DDoS protection + hides your IP.

> 💡 **No domain yet?** Buy one anywhere (Namecheap, Cloudflare Registrar, ~$10/year). Then add it to Cloudflare: dash.cloudflare.com → Add site → follow the nameserver steps.

## The setup

1. 🌐 Cloudflare dashboard → your domain → **DNS → Records → Add record**:

| Type | Name | Content | Proxy |
|---|---|---|---|
| `A` | `@` (means the root domain) | `YOUR_SERVER_IP` | 🟠 **ON** (orange cloud) |
| `A` | `www` | `YOUR_SERVER_IP` | 🟠 **ON** |

2. 🔐 **SSL/TLS** tab (left sidebar) → set encryption mode to **Full (strict)**
   - (Coolify gets its own real Let's Encrypt certificate per app — "strict" works and is the safest mode.)

3. 🚀 That's it. The domain now reaches your server. Each app you deploy in Coolify claims its own hostname — next part shows how.

> 💡 **Subdomain strategy (free forever):** you don't need to buy a domain per project! One domain gives unlimited subdomains: `app.yourdomain.com`, `blog.yourdomain.com`, `shop.yourdomain.com`… just add another A record (or a wildcard `*` record) pointing at the same IP.

---

# 🚀 Part 10 — Deploy Your First Next.js App (~5 minutes)

Exactly like Vercel, but on YOUR server:

1. 🗃️ Your app's code must be on **GitHub** (any repo, public or private)
2. 🎛️ Coolify dashboard → **Projects → Add New Project** → give it a name
3. **+ Add New Resource → Production → GitHub**
   - First time: click the GitHub link and authorize the Coolify app (lets it read your repos)
4. Pick your **repository** and branch (usually `main`)
5. Coolify auto-detects **Next.js** and prepares the build (via Nixpacks). You usually change nothing.
6. 🔧 **Environment Variables** tab → add everything your app needs (like `DATABASE_URL`, API keys — copy them from your Vercel project settings if you're migrating)
7. 🌐 **Domains** tab (in the app's Settings) → enter `app.yourdomain.com` (must be a DNS record pointing at your server — Part 9) → Save
8. ▶️ Click **Deploy**
9. ⏳ First build takes 3–10 minutes on the ARM server (it's building your whole app + Docker image). Watch the live logs.
10. 🎉 When it goes green: `https://app.yourdomain.com` is live **with automatic HTTPS**. Every future `git push` to that repo redeploys automatically (Coolify installs a webhook for you).

## Pro tips for Next.js on this server

- 📦 In `next.config.js`, set `output: 'standalone'` → your Docker image shrinks from ~1.5 GB to ~300 MB (disk is 200 GB, not infinite).
- 🖼️ Install the `sharp` package for fast image optimization.
- 🧠 Give the app a **memory limit** (app Settings in Coolify, e.g. 512 MB) → one leaky app can never eat the whole server.
- 🚫 Don't deploy several apps at the same moment — builds share the 2 CPUs. Stagger them.

> ❓ **App needs a database?** Part 11 (one-click PostgreSQL) — then paste the connection string Coolify gives you into the app's env vars as `DATABASE_URL`.

---

# 🌍 Part 11 — WordPress & Other One-Click Apps

## WordPress (verified one-click template)

1. 🎛️ Coolify → **+ Add New Resource → One-Click Service → WordPress**
2. It automatically creates WordPress **+ its MySQL database** together
3. 🌐 Set the domain (e.g. `blog.yourdomain.com` — needs its DNS record) → Deploy
4. Open the domain → the famous WordPress 5-minute installer appears → done

## Other popular one-clicks (same 3 clicks)

| App | What it's for | RAM |
|---|---|---|
| **PostgreSQL / MySQL / Redis / MongoDB** | databases for your apps | 100–300 MB each |
| **Uptime Kuma** | monitors all your sites and alerts you when one goes down | ~50 MB |
| **n8n** | workflow automation (Zapier alternative) | ~300 MB |
| **Plausible** | privacy-friendly analytics | ~150 MB |
| **Ghost** | blogging platform | ~200 MB |
| **MinIO** | S3-compatible file storage | ~100 MB |

Browse the full list: **+ Add New Resource → One-Click Service** (70+ templates).

---

# 📦 Part 12 — What You Can Host + Your RAM Budget

Your server has **12 GB RAM**. Here's the honest budget:

| Item | RAM |
|---|---|
| Ubuntu + Docker + Coolify + Traefik | ~1.5 GB |
| Keepalive bodyguard (frees itself as apps grow) | 0–3 GB (auto) |
| **Free for YOUR apps** | **~7–8 GB** |

| App type | RAM each | How many fit |
|---|---|---|
| Static site / landing page | 10–20 MB | basically unlimited |
| Next.js app | 150–400 MB | **~20** |
| WordPress + MySQL | 300–500 MB | ~10–12 |
| Heavy app (n8n, analytics…) | 200–400 MB | mix & match |

**Realistic sweet spot: 15–25 small projects.** Your ceiling is RAM, not CPU — a 2-core ARM box serves tens of thousands of daily visits across low-traffic sites.

**Check your usage anytime:**

```bash
# On the server:
free -h                          # RAM overview
docker stats                     # per-container RAM/CPU live
df -h /                          # disk usage

# In the Oracle console (the numbers Oracle itself judges you by):
# Compute → Instances → your VM → Metrics tab → Memory/CPU/Network
```

> 🛑 **Rule of thumb:** when total RAM sits above ~70% steadily, stop adding apps.

---

# 💾 Part 13 — OPTIONAL: Add a Block Volume (skip unless you truly need it)

> ⚠️ **You probably DON'T need this.** Your 200 GB boot volume holds everything, and a fresh block volume would need you to first shrink the boot volume — which is **impossible** (grow-only). This part exists only for completeness — e.g., if you someday rebuild the VM with a smaller boot volume.

**What a block volume is:** an extra empty hard disk you plug into the server and "mount" to a folder (apps then save files there without knowing the difference). People use one to separate big data (uploads, caches) from the OS, or to survive VM rebuilds.

**The math problem:** free storage = 200 GB **total** (boot + block combined). If your boot volume is already 200 GB, adding a block volume = **paid** (breaks Golden Rule #3!). To do it free you'd have to recreate the VM with a smaller boot volume (e.g. 150 GB boot + 50 GB block).

**If you ever do it (concise version):**

1. Console → Storage → Block Volumes → Create (in your home region!) → Attach to your VM (Paravirtualized)
2. On the server:
   ```bash
   lsblk                                  # find the new empty disk, e.g. /dev/sdb
   sudo mkfs.ext4 /dev/sdb                # format ONCE (like a new USB stick)
   sudo mkdir -p /mnt/data
   sudo mount /dev/sdb /mnt/data
   # Make it auto-mount after reboots (boot-safe: never hangs the server):
   echo '/dev/sdb /mnt/data ext4 defaults,noatime,_netdev,nofail 0 2' | sudo tee -a /etc/fstab
   df -h /mnt/data                        # ✅ verify
   ```
3. Point what you want at `/mnt/data` (e.g. Coolify backup destination, app upload folders).

Again: **skip this part** unless you have a specific reason. One disk = one backup = simple life.

---

# 📸 Part 14 — Backups (set once, sleep forever)

Because **everything lives on the ONE 200 GB boot volume, ONE backup = your ENTIRE server** (OS + Coolify config + all apps + all databases + all uploads). This is the hidden superpower of the one-disk design.

## 14.1 — Whole-server backup (free, automatic)

1. Console → **Compute → Instances** → your VM → scroll to **Boot volume** → click its name
2. **Scheduled Backups** → create a schedule:
   - Frequency: **Weekly** (e.g. Sunday 04:00)
   - Backup type: **Full**
   - Retention: 4 weeks (1 month deep)
3. ✅ Done — uses 1–4 of your 5 free backup slots. If disaster ever strikes: Boot volume → Backups → Restore → your whole server comes back.

## 14.2 — Database backups (extra layer)

In Coolify, each database you create has a **Backups** tab → set a schedule → destination: local disk (fine) or any S3-compatible storage (Oracle's free 10 GB Object Storage works great — S3 keys from Console → Profile → Customer Keys).

Two layers, both free: weekly whole-server snapshot + per-database dumps. You're covered.

---

# 🧹 Part 15 — Maintenance Habits (2 minutes every 2 weeks)

| When | Do | Time |
|---|---|---|
| **Every 2 weeks** | Log into cloud.oracle.com → instance green? Billing $0? (defeats the abandoned-account rule) | 2 min |
| **Monthly** | Peek at Coolify dashboard: all apps green? Disk below 70%? | 2 min |
| **Monthly** | `docker stats` + `free -h` via SSH if curious | 1 min |
| **Every 6 months** | `sudo apt update && sudo apt upgrade -y` via SSH (belt & suspenders — unattended-upgrades already does security patches daily) | 5 min |

**Already automatic (installed by `setup.sh` — verify once if you like):**

- ✅ Security patches (unattended-upgrades, daily)
- ✅ Keepalive bodyguard (24/7, self-adjusting)
- ✅ Monthly Docker image cleanup + weekly journal trim (cron `/etc/cron.d/oracle-hygiene`)
- ✅ Weekly whole-server backup (Part 14 — you set it once)

---

# 🆘 Part 16 — Troubleshooting

## Problem 1 — "My site doesn't load" (99% of all problems)

Oracle has **TWO firewalls** — both must be open:

1. ☁️ **Console side:** Part 4 rules present? (VCN → Security Lists → ports 80/443/8000)
2. 🧱 **Server side:** SSH in and check: `sudo iptables -L INPUT -n` — you should see `ACCEPT tcp dpt:80`, `443`, `8000` BEFORE the `REJECT` rule. Missing? Run `sudo bash setup.sh` again (step 3 fixes it).
3. 🌐 DNS: does the A record point at the right IP? (Cloudflare → DNS)
4. 🎛️ Coolify: is the app green and is its domain set correctly (exact spelling, https)?

## Problem 2 — "Boot volume not attached" / instance won't start

A boot volume can only be attached **at creation** — an instance in this state is **unfixable**. Recovery:

1. Console → Compute → Instances → **Terminate** the broken instance
2. ⚠️ **CRITICAL second step everyone forgets:** Storage → Block Storage → **Boot Volumes** → if the old volume still shows → **Terminate it too** (orphaned volumes still count against your 200 GB and block new creation)
3. Verify both lists are empty, then create a fresh VM (Part 3) and re-run `setup.sh` (Part 6)

## Problem 3 — "Out of host capacity" when creating the VM

See Part 3.2 — retry, off-peak hours, different Availability Domain, or create smaller and resize later. **Never switch regions.**

## Problem 4 — Coolify dashboard unreachable (port 8000)

- Console Security List has the 8000 rule? (Part 4)
- Server iptables has it? (`sudo iptables -L INPUT -n | grep 8000`)
- Is Coolify running? SSH in → `docker ps` — you should see coolify containers. If not: `sudo bash setup.sh` again.

## Problem 5 — "Instance was stopped by Oracle" (idle reclaim email)

- Start it immediately: Console → Instances → your VM → **Start**
- Then check the keepalive: `systemctl status oracle-keepalive` (want: active/running). If it was dead, `sudo systemctl enable --now oracle-keepalive` — and find out why (`journalctl -u oracle-keepalive --since "7 days ago"`).
- If you deliberately stopped it yourself for a long time — don't (Part 8 warning).

## Problem 6 — SSH: "Permission denied (publickey)"

- Using the right key file? `ssh -i oracle.key ubuntu@IP` (username must be `ubuntu`)
- Key permissions: `chmod 400 oracle.key` (Part 5.1)
- Correct IP? (Instance page, Public IP — it can change if you stop/start without a reserved IP)

## Problem 7 — Disk filling up

```bash
df -h /                                   # how full?
sudo docker system df                     # Docker's share
sudo docker system prune -f               # immediate cleanup (safe: running containers untouched)
sudo journalctl --vacuum-size=200M        # trim logs now
```
(The monthly cron already does this — this is the manual "right now" version.)

---

# 💳 Part 17 — The "Never Get Charged" Final Checklist

Print this. Live by it. It is **mathematically impossible** to be billed if all five stay true:

- [ ] 🚫 **Never** click "Upgrade to Pay As You Go" (the ONLY path to billing)
- [ ] 📍 Everything created in **US East (Ashburn)** — check the region selector before every "Create"
- [ ] 💾 Total storage = your **200 GB boot volume only** (no extra volumes)
- [ ] 📸 **≤ 5 volume backups** (your weekly schedule uses 1–4)
- [ ] ⚡ Boot volume performance stays **Balanced** (never touch VPUS settings)

**Verified billing behavior** (from Oracle's own documentation): a non-upgraded Always Free account *cannot* create paid resources — Oracle blocks the creation with an error. There is no invoice, no bill, no charge. The card on file is identity verification only.

**The one temporary charge you may have seen:** the ~$1 signup verification hold — refunded within days. That's the only time your card was ever touched.

---

# 📋 Part 18 — Quick Command Reference

```bash
# ── Connect ──────────────────────────────────────────────
ssh -i oracle.key ubuntu@YOUR_SERVER_IP        # enter the server
exit                                           # leave

# ── Health checks ────────────────────────────────────────
free -h                        # RAM (keepalive + apps)
df -h /                        # disk usage (keep under 70%)
docker ps                      # running containers
docker stats                   # live per-app RAM/CPU
systemctl status oracle-keepalive   # bodyguard status

# ── Keepalive bodyguard ──────────────────────────────────
journalctl -u oracle-keepalive -f          # watch it live
sudo systemctl enable --now oracle-keepalive    # turn on
sudo systemctl disable --now oracle-keepalive   # turn off (only if apps use >25% RAM alone)

# ── Maintenance ──────────────────────────────────────────
sudo bash setup.sh             # re-run setup (safe, skips what's done)
sudo apt update && sudo apt upgrade -y    # manual updates (rarely needed)
sudo docker system prune -f    # immediate Docker cleanup

# ── Emergency: disk filling up ───────────────────────────
sudo journalctl --vacuum-size=200M
sudo docker system prune -f
```

---

# 🎓 Appendix — The Journey in One Page

```
① Sign up            oraclecloud.com → card + phone → home region US East (Ashburn)
        ↓
② Create server      Ubuntu 24.04 · Ampere 2 OCPU/12 GB · 200 GB boot volume
                     → save oracle.key → note the Public IP
        ↓
③ Open ports         Console: VCN → Security List → 22, 80, 443, 8000
        ↓
④ Connect            chmod 400 oracle.key → ssh -i oracle.key ubuntu@IP
        ↓
⑤ Install            git clone the repo → sudo bash setup.sh  (~10 min, does EVERYTHING:
                     updates, swap, firewall #2, Coolify, keepalive, hygiene)
        ↓
⑥ Dashboard          http://YOUR_IP:8000 → Register → enable image cleanup
        ↓
⑦ Domain             Cloudflare: A record → server IP, orange cloud ON, Full (strict)
        ↓
⑧ Deploy             Coolify: GitHub → repo → env vars → domain → Deploy
                     (repeat ⑦+⑧ for every new app — 3 minutes each)
        ↓
⑨ Forever habits     Biweekly: log into oracle console (2 min) · that's it
                     Never: upgrade to PAYG, other regions, extra volumes, stopped VM
```

**Total cost: $0.00/month. Forever.** 🎉

---

*Verified against Oracle's official Always Free documentation (docs.oracle.com), Coolify documentation (coolify.io), and real-world Oracle free-tier behavior. This repo will grow over time — future additions may include Postiz (social media scheduler) deployment and more.*
