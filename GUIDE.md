# 🚀 ORACLE CLOUD ALWAYS FREE — COMPLETE SERVER & COOLIFY SETUP GUIDE

> **From zero → your own hosting platform, $0/month, forever.**
> Written for complete beginners: every step, every click, every command — nothing assumed, nothing skipped. If a first-grade student can read, they can follow this.
>
> - 🏠 **Home region:** US East (Ashburn) — set at signup, permanent
> - 💰 **Cost:** $0 (Always Free tier — and this guide shows exactly how it can *never* charge you)
> - 🧱 **Stack:** Ubuntu 24.04 + Coolify (Docker + Traefik included) + smart keepalive
> - 💾 **Storage:** ONE 200 GB boot volume — everything on one disk, one backup covers it all
> - 🌐 **Network:** one VCN via the "Internet Connectivity" wizard + your choice of public IP — the simple path AND the permanent (reserved) path are both in Part 4
> - 📅 Checked against the **latest** Oracle and Coolify documentation (coolify.io/docs)

---

## 📋 Table of Contents

| Part | What you do there | When |
|---|---|---|
| **0** | What you're building + your free allowance + the 5 golden rules | Read first |
| **1** | Concepts in plain English (VM, Docker, Coolify, Traefik, ports…) | Read first |
| **2** | Create your Oracle account | Once |
| **3** | ⚠️ Starting over? Clean slate first (full teardown) | Only if rebuilding |
| **4** | Create your server: VCN → VM (every console section) → public IP (ephemeral or reserved) — + the "Out of capacity" auto-retry fix (4.4) | Once |
| **5** | Open the ports in the Oracle console (firewall #1) | Once |
| **6** | Connect to your server from your PC (the `oracle.key` file) | Every time |
| **7** | Run the magic script (`setup.sh` — it does EVERYTHING) | Once |
| **8** | Coolify first login (your new dashboard) | Once |
| **9** | How your server stays alive forever (anti-reclaim) | Understand once |
| **10** | The 100% security checklist | Set once + habits |
| **11** | Connect your domain (Cloudflare) | Once per domain |
| **12** | Deploy your first Next.js app (and every app after) | Every new app |
| **13** | WordPress (one click) + other one-click apps | Anytime |
| **14** | Usage, monitoring & reporting (see everything, anytime) | Reference |
| **15** | What you can host + your RAM budget | Reference |
| **16** | OPTIONAL: add a block volume (skip unless truly needed) | Skip unless needed |
| **17** | Backups (free, automatic, whole-server) | Set once |
| **18** | Maintenance habits (2 minutes every 2 weeks) | Habit |
| **19** | Troubleshooting (every error + its fix) | When stuck |
| **20** | The "Never Get Charged" final checklist | Bookmark |
| **21** | Quick command reference | Bookmark |
| **A** | Appendix: the whole journey on one page | Bookmark |

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
| 🌐 Public IP | **1 per VM — free** | **Ephemeral** (auto-assigned): survives stop/start. **Reserved** (permanent): survives even full rebuilds — Oracle's pricing pages publish no charge for it (checked Nov 22, 2026). Both paths in Part 4.3. |
| 📦 Object Storage | **20 GB combined** (Standard + Infrequent Access + Archive tiers) + 50,000 API requests/month | For database backups (separate from your 200 GB). During the first 30-day trial you get 10+10+10 GB; once Always Free, it's 20 GB total |
| 📸 Volume backups | **5 total** | Full disk snapshots — your disaster recovery |
| ⏰ Hours | 1,500 OCPU-hours + 9,000 GB-hours per month | Running 2 OCPU + 12 GB 24/7 for a whole month ≈ 1,488 OCPU-hours / 8,928 GB-hours — exactly within the free allowance (Oracle's own wording: "equivalent to 2 OCPUs and 12 GB") |
| ⚡ Duration | **Forever** | As long as the account isn't idle/abandoned (Part 9 handles this) |

> ✅ **Coolify's official minimum requirements** (from coolify.io/docs): 2 CPU cores, 2 GB RAM, 10 GB disk. Your free VM has **2 cores, 12 GB RAM, 200 GB disk** — you exceed every minimum by a wide margin.

## ⚠️ The 5 Golden Rules (read twice — this is how you NEVER pay a cent)

| # | Rule | Why |
|---|---|---|
| 1️⃣ | **NEVER click "Upgrade to Pay As You Go"** | On a free account, Oracle *blocks* anything that would cost money (you get an error instead of a bill). Upgrading removes that safety block. It is the **only** way to ever be charged. |
| 2️⃣ | **Everything in your HOME region (US East — Ashburn) only** | Resources in other regions cost money *even on the free tier*. The region selector is in the top-right corner of the Oracle console — always check it shows your home region before creating anything. |
| 3️⃣ | **Total storage stays ≤ 200 GB** | Your single 200 GB boot volume uses exactly the full free amount. Never create extra volumes — you can't shrink the boot volume, so there's no room left (see Part 16 for the rare exception). |
| 4️⃣ | **Maximum 5 volume backups** | 1 weekly backup (Part 17) = you're safe forever. Creating a 6th just errors — but don't spam them anyway. |
| 5️⃣ | **Boot volume performance stays "Balanced" (default)** | Higher performance tiers (VPUS) are paid. Never touch that setting. |

💳 **About your card:** Oracle placed a temporary ~$1 hold at signup to verify it's real — that was refunded. On Always Free you receive **no invoice, no bill, nothing**. The Billing page shows $0.00 forever if you follow the rules above. This is Oracle's own written policy — direct quote from their Free Tier documentation: **"Your credit card will not be charged unless you upgrade your account."**

---

# 📚 Part 1 — Concepts in Plain English (5 minutes, read once)

You'll see these words everywhere. Here's what they actually mean — no jargon.

| Word | What it really is |
|---|---|
| **VM (instance)** | A computer that lives in Oracle's building instead of your home. It runs 24/7. Yours is ARM-based (a different CPU family than your PC — same idea, better price-per-power, which is why it's free). |
| **Boot volume** | The VM's hard disk. It comes with Ubuntu (the operating system) pre-installed. **Yours is 200 GB and holds everything.** |
| **Block volume** | An *extra* hard disk you *could* plug in. **You don't need one** — this guide puts everything on the boot volume. (Part 16 explains it just in case.) |
| **Ubuntu** | The operating system on your server — like Windows, but for servers, and free. |
| **VCN** (Virtual Cloud Network) | Your own private network inside Oracle — a fresh, empty "network building" where your server lives. Created once, in Part 4.1, with a wizard. |
| **Subnet** | A floor of that building. Your VM sits on the **public subnet** — the floor with a direct door to the internet. |
| **Internet Gateway** | The building's main gate: connects your VCN to the internet. The VCN wizard creates it for you automatically. |
| **VNIC** | Your VM's network socket inside the subnet — it holds the private + public IP addresses. You'll meet this word only when attaching a reserved IP (Part 4.3). |
| **SSH + key file** | The locked door to your server. The key file (`oracle.key`) stays on YOUR PC — anyone holding it can enter, so never share it, never upload it to GitHub. |
| **Port** | A numbered door on your server. Port 22 = SSH (you), 80/443 = websites (visitors), 8000 = Coolify dashboard (you), 6001/6002 = dashboard live-updates + web terminal (you). Everything else stays closed. |
| **Security List** | Oracle's cloud firewall (firewall #1). You open ports here in the website console. |
| **iptables** | The firewall *inside* Ubuntu (firewall #2). Oracle ships it with almost everything blocked — this trips everyone up (`setup.sh` fixes it automatically). |
| **Docker** | A way to package an app with everything it needs into a "container" — a sealed box that runs the same everywhere. |
| **Coolify** | A free, open-source **web dashboard** that turns your server into your own Vercel: connect GitHub → click deploy → app is live with HTTPS. It manages Docker *for* you. |
| **Traefik** | The traffic police that comes inside Coolify. Your server has ONE IP — Traefik reads each visitor's domain name and sends them to the right container. It also gets free SSL certificates automatically. You never touch it. |
| **Swap** | Overflow RAM on disk (8 GB). When an app build needs more RAM than you have, the server uses this instead of crashing. |
| **Keepalive** | A tiny bodyguard service this guide installs. It stops Oracle from deleting your server for being "idle" (full story in Part 9). |
| **Cloudflare** | Free service that connects your domain name to your server, and adds speed + DDoS protection + hides your real IP. |

## Why Coolify? (and not something else)

- ❌ **Plain Docker alone:** you'd hand-write config files for every app, every domain, every SSL certificate. Real work.
- ❌ **Vercel/Netlify:** great, but costs money when you grow, and can't host databases or WordPress.
- ✅ **Coolify:** one stack that includes Docker + dashboard + Traefik + one-click databases (PostgreSQL, MySQL, Redis, MongoDB…) + automatic SSL + scheduled backups. Huge community (66,000+ GitHub stars — checked November 2026). The most Vercel-like self-hosted experience that exists.

**The rule:** one server, one stack (Coolify). Don't install Nginx manually, don't install Portainer, don't `apt install postgresql` — Coolify provides all of it. Extra managers on top = the real thing to avoid.

---

# 👤 Part 2 — Create Your Oracle Account (one time, ~10 minutes)

> ✅ **Already have an account? Skip to Part 3.** (Your home region is US East — Ashburn.)

1. 🌐 Go to **https://signup.oraclecloud.com**
2. Fill in your **name, email, country** → verify your email
3. 💳 Enter a **real credit or debit card** — prepaid/virtual cards are usually rejected
   - This is identity verification only. You'll see a temporary ~$1 hold that disappears in days.
4. 📱 Verify your phone by SMS
5. 🌍 **CHOOSE YOUR HOME REGION: `US East (Ashburn)`**
   - ⚠️ **This choice is PERMANENT — it can never be changed.**
   - All your free resources must live in this one region, forever.
6. Wait for the account to provision (minutes to a few hours — you get an email)

## What happens next (important to understand)

- Your account starts as a **Free Trial**: $300 of credit for 30 days.
- **Do nothing.** After 30 days it automatically converts to **Always Free** (the forever-free tier described in Part 0).
- ⚠️ During the trial you *can* create bigger stuff than the free limits — and Oracle's documented trial-end rule is: **any Ampere A1 instances above 2 OCPUs / 12 GB total are disabled, then deleted after 30 days.** **Simplest path: only ever create exactly what this guide creates (Ubuntu 24.04, 2 OCPU, 12 GB, 200 GB boot volume), and you'll never notice the trial even ended.**

> 💡 **The one button that must never be pressed:** "Upgrade to Pay As You Go" (sometimes shown as "Upgrade"). Golden Rule #1. A non-upgraded account *cannot* be charged — Oracle blocks paid resources with an error instead of billing you.

---

# 🧨 Part 3 — Starting Over? Clean Slate First (ONLY if rebuilding)

> ⚠️ **Are you creating a server for the FIRST time ever? Skip to Part 4.**
> This part is for when an old/broken server (or leftover parts of one) exists in your account. Leftovers block new creation and silently eat your free quota.
>
> 🗺️ **Your exact rebuild path:** this Part (delete) → Part 4 (VCN + VM + IP) → Part 5 (ports) → Part 6 (connect) → Part 7 (setup.sh) → Part 8 (Coolify login) → Part 11 (update DNS only if your IP changed). ~45–60 minutes total.

Old parts must be deleted **in this exact order** (each step takes ~30 seconds):

## 3.1 — Terminate the old instance

1. 🌐 **https://cloud.oracle.com** → ☰ Menu → **Compute → Instances**
2. Click the instance name → **Terminate** button
3. ⚠️ **CHECK the box "Delete attached boot volume"** (or "Permanently delete the boot volume") before confirming
   - If you forget: the volume becomes an "orphan" — it still counts against your 200 GB and blocks new servers. Fix in 3.2.
4. Confirm → wait until the instance disappears from the list (1–2 min)

> 💡 **Stuck in a transitional state** (e.g. "Stopping") with Terminate greyed out? Just wait — Oracle force-completes stuck transitions on its own (can take up to ~30 minutes). Come back when the list is empty.

## 3.2 — Delete any orphaned boot/block volumes

1. ☰ Menu → **Storage → Block Storage → Boot Volumes**
   - Also check **Block Volumes** in the same menu
2. If the list is empty → skip this step (nothing to delete)
3. If a volume shows **Attached** → open it → **Attached Instances** → **Detach** → wait for **Available**
4. Then click its **⋮** (three dots) menu → **Terminate** → confirm
5. ✅ The list must end up **empty**

## 3.3 — Delete the old VCN (if it exists)

> Only needed if you're deleting everything (e.g., after a broken setup). If your VCN is healthy and you just want a new VM, you can keep it.

1. ☰ Menu → **Networking → Virtual Cloud Networks**
2. If a VCN exists with no instance using it: click its **⋮** (three dots) menu → **Delete**
   - If it complains about attached resources: open the VCN → use its **Subnets**, **Gateways**, and **Security** tabs (tab row at the top of the VCN page) to delete the subnet, the Internet Gateway, and the security list first — then delete the VCN itself.
3. A fresh VCN is created with your next server (Part 4.1), so deleting is safe — but keeping a healthy VCN is also fine (Part 4.2 reuses it).

## 3.4 — Check for leftover reserved public IPs

1. ☰ Menu → **Networking → IP Management → Reserved Public IPs**
2. Decide per IP:
   - 🗑️ **Delete it** if you're starting clean (unattached leftovers are clutter — and the reference repo's teardown deletes them too)
   - 💾 **KEEP it** if your new server will re-use a permanent IP (Part 4.3, Path B): a kept reserved IP re-attaches to the new VM in ~1 minute and your DNS records keep working unchanged

## 3.5 — Verify everything is gone

- Instances list: **empty** ✅
- Boot Volumes + Block Volumes: **empty** ✅
- (Optional) VCNs: **empty or one clean VCN** ✅

You now have a 100% clean account. On to Part 4.

---

# 🖥️ Part 4 — Create Your Server (VCN + VM + Public IP, ~15 minutes)

> ⚠️ **Before you start:** look at the **top-right corner** of the Oracle console and confirm the region selector shows **US East (Ashburn)** — your home region. If it shows something else, click it and switch back. (Golden Rule #2.)

This part creates three things, in this order:

| # | What you create | Where | Time |
|---|---|---|---|
| 1 | The **VCN** — your private network | 4.1 | 3 min |
| 2 | The **VM** — your server (every section of the form) | 4.2 | 5 min |
| 3 | Its **public IP** — find it, or attach a permanent reserved one | 4.3 | 2 min |

> 💡 **The console re-orders its sections sometimes.** Oracle's own docs say: *"Information in the Console might be shown in a different order than is presented in this topic. Regardless of the order presented, all required and optional fields are the same."* Every field you'll meet is covered below — if your form shows them in a different order, fill them in the same way.

## 4.1 — Create the VCN FIRST (your private network)

> ⚠️ **Do this BEFORE the VM.** It's Oracle's own recommendation for first-time instance creators: use the **Start VCN Wizard** with the **"Create VCN with Internet Connectivity"** option — one flow creates the public subnet, the Internet Gateway, the NAT Gateway, and all the routing rules. Then every dropdown in the VM form is ready and waiting. (The VM form *can* also auto-create a basic VCN — but the wizard names things your way and takes 3 minutes.)

1. 🌐 Log in at **https://cloud.oracle.com**
2. ☰ Menu (top-left) → **Networking → Virtual Cloud Networks**
3. Click **Start VCN Wizard**
4. Select **"Create VCN with Internet Connectivity"** → click the **Start VCN Wizard** button (bottom right)
5. VCN name: `coolify-vcn` (anything you like). Leave everything else at the defaults:
   - the wizard automatically creates the **Public Subnet** (where your VM will sit), the **Internet Gateway** (the door to the internet), and a **NAT Gateway** (an extra door your public-subnet VM doesn't route through — it sits idle and unused)
   - if the wizard offers **IPv6**, leave it unchecked
6. Click **Next** → **Create** → wait for the green **Completed** → **Close**
7. ✅ **Verify:** back on the VCN list, your VCN shows State **Available** with an IPv4 CIDR like `10.0.0.0/16`. Click it: under **Subnets** you should see a **Public Subnet**, and under **Gateways** an **Internet Gateway**. That's everything the VM form needs.

## 4.2 — Create the VM (every section of the form)

☰ Menu → **Compute → Instances** → click **Create instance**.

The current form walks through these sections (in this order, or close to it):

### Section 1 — Basic information

- **Name**: `coolify-server` (anything you like)
- **Create in compartment**: leave the default (root). Never heard of compartments? Doesn't matter — the default is correct for your whole account.

### Section 2 — Placement (Availability domain)

- **Availability domain**: leave the default. Every AD in your home region is Always Free eligible — all of them are still your region, all of them are free. (Hit "Out of capacity / Out of host capacity" at the Create step? That's normal in Ashburn — 4.4's auto-retry script wins that race for you.)

### Section 3 — Image and shape

Click **Edit** (in the Image and Shape box), then:

| Setting | What to click | Why |
|---|---|---|
| **Image** | **Change image** → **Canonical Ubuntu 24.04** (⚠️ NOT "Minimal") → **Select image** | The default is Oracle Linux — you MUST change it. Ubuntu 24.04 LTS is what Coolify officially supports. (22.04 also works — that's what the reference LeadGrid server used.) |
| **Shape** | **Change shape** → Instance type: **Virtual machine** → Shape series: **Ampere** → **VM.Standard.A1.Flex** (tagged *Always Free eligible*) → **Select shape** | The ARM shape that's free forever |
| **Number of OCPUs** | **2** | Your entire free CPU allowance on one machine |
| **Amount of memory (GB)** | **12** | Your entire free RAM allowance on one machine |

### Section 4 — Security (a short section on current consoles)

- **Shielded instance**: leave OFF (default)
- **Confidential computing**: leave OFF (default)

You never need to touch anything here — the defaults are correct.

### Section 5 — Networking (labeled "Primary VNIC" / "Primary VNIC information" on some consoles)

- **Virtual cloud network**: choose **Select existing virtual cloud network** → pick **coolify-vcn** (from 4.1)
  - the form also offers "Create new virtual cloud network" — we don't need it, ours is ready
- **Subnet**: choose **Select existing subnet** → pick the **Public Subnet** of your VCN (the name contains "public subnet"; if it says "regional" too, that's fine — regional subnets are what Oracle recommends)
- **Private IPv4 address** (under "Configure Primary IP Address"): leave **Automatically assign** — the default is correct
- **Public IPv4 address** — the one real decision in this form. Two paths:

  | | Path A — simple (recommended for a first server) | Path B — permanent reserved IP (the reference repo's way) |
  |---|---|---|
  | **What to click** | Leave **"Automatically assign public IPv4 address"** CHECKED ✅ | UNCHECK it ⬜ — the VM boots with no public IP (that's fine: you attach yours in 4.3 before ever connecting) |
  | **What you get** | A free **ephemeral** public IP, assigned automatically | A **reserved** public IP you attach yourself in 4.3 |
  | **Survives stop/start?** | **Yes** — Oracle's docs, word for word: *"When you stop an instance, its ephemeral public IPs remain assigned to the instance."* | **Yes** |
  | **Survives a full rebuild (terminate + new VM)?** | No — a rebuilt VM gets a new IP, so DNS records must be updated | **Yes** — re-attach the same IP to each new VM; DNS never changes |
  | **Cost** | Free | Oracle's pricing pages publish **no charge** for reserved public IPs (checked Nov 22, 2026) — and your non-upgraded account can't be billed anyway (Golden Rule #1) |

  > ❓ **"Can't I just make the auto-assigned IP permanent later?"** **No — never.** Oracle's docs are explicit: *"After you create a given public IP object, you can't change which type it is."* An ephemeral IP can never be converted to Reserved, and the create form has no option to auto-assign a reserved one. The only way to a permanent IP is Path B + step 4.3.

- **IPv6**: leave unchecked / skip
- **Show advanced options** (networking): skip entirely — DNS record, hostname, network security groups, launch options: all stay default, all correct for this guide

### Section 6 — SSH keys (your server's door key)

Pick ONE:

**Option A — REUSE the key you already have (recommended when rebuilding — nothing changes on your PC):**

1. On your PC, open **Git Bash** (Windows) or Terminal (Mac/Linux) in your `ORACLE` folder and run:
   ```bash
   ssh-keygen -y -f oracle.key
   ```
   It prints one line starting with `ssh-rsa AAAA…` (or `ssh-ed25519 AAAA…`) — that's your **public** key. Copy the entire line (select it in the window → right-click → Copy). If you get `No such file or directory`: the old key isn't on this PC — use Option B.
2. On the Oracle form select **"Paste public keys"** → paste the line into the box. (It must start with `ssh-rsa` / `ssh-ed25519` — never paste the private key, which starts with `-----BEGIN`.)
3. Your private key file stays exactly where it is — nothing moves, nothing is uploaded.

**Option B — Generate a brand-new key pair (first-time setups):**

1. Select **"Generate a key pair"** (some consoles word it "Generate a key pair for me")
2. Click **Save Private Key** → save the file as **`oracle.key`** into your `ORACLE` folder (layout in 4.5)
3. Click **Save Public Key** too (optional, but take it — handy)

> 🔑 The private key IS your server's front-door key: anyone holding it can enter. It never leaves your PC. If you ever lose it, you can't SSH in — you'd have to recreate the instance with a new key.

### Section 7 — Storage (the boot volume)

1. ✅ Check **"Specify a custom boot volume size"**
2. **Boot volume size (GB)**: **200**
   - Your entire free 200 GB on ONE disk: apps, databases, uploads — everything lives here and ONE backup covers the whole server. (The field allows 50 GB – 32 TB; staying ≤ 200 GB is what's free.)
3. Leave everything else as-is:
   - **Volume performance**: **Balanced** (default — higher tiers are paid, Golden Rule #5)
   - **Use in-transit encryption**: unchecked (default) — fine
   - Backup policy / encryption key / tags: untouched

### Section 8 — Review

Scroll the summary and confirm all of this is true:

- Image: **Canonical Ubuntu 24.04** (or 22.04) — *not* Oracle Linux, *not* "Minimal"
- Shape: **VM.Standard.A1.Flex** — 2 OCPUs, 12 GB memory
- Boot volume: **200 GB** — marked *Always Free eligible*
- Network: **coolify-vcn** / Public Subnet — and your public-IP choice (Path A checked / Path B unchecked)
- Your SSH key is listed

Then click **Create**. Wait 1–3 minutes until the state turns green **RUNNING**.

> ⚠️ Red banner **"Out of capacity for shape VM.Standard.A1.Flex…"** at this point? Nothing is wrong with your account — it's the famous free-tier shortage, and **4.4 (just below) fixes it** with an auto-retry script.

## 4.3 — Your public IP (both paths)

**Path A (ephemeral — you left the box checked):** on the instance page, find **Public IP Address** under Instance details (also visible in the instance list). 📋 Write it down — you'll use it constantly (SSH, the Coolify URL, DNS records). It's free and it stays assigned through stop/starts. You're done here — skip to 4.4.

**Path B (reserved IP) — Part 1 of 2: reserve the address**

1. ☰ Menu → **Networking → IP management → Reserved public IPs**
2. Click **Reserve public IP address**
3. The **"Reserve public IP address"** dialog opens. Fill it in exactly like this:
   - **Reserved public IP address name** *(marked Required)*: `coolify-ip` (anything you like)
   - **Create in Compartment**: leave as your root compartment (default)
   - **IP address source compartment**: leave as-is — same root compartment
   - **IP address source**: **Oracle** (the default — Oracle's pool of public IPs; you have no pools of your own)
   - **Tags**: ignore this section completely
4. Click the **Reserve public IP address** button at the bottom of the dialog (⚠️ not "Cancel", not "Save as stack")
5. ✅ **Verify:** your reserved IP now appears in the list — State **Available**, VNIC column empty (not attached yet — that's expected, it's next). You cannot choose the IP number yourself: Oracle picks it. (This half can be done before or after creating the VM — order doesn't matter.)

**Path B — Part 2 of 2: attach it to your VM (exact clicks)**

1. ☰ Menu → **Compute → Instances** → click your instance's name (e.g. `coolify-server`)
2. On the instance page, click the **Networking** tab (tab row at the top: Details | **Networking** | Storage | Security | …)
3. In the **VNICs** list, click the **primary VNIC's name** — titled with your instance name, a green **Available** badge, subtitle `VNIC`
4. On the VNIC page, click the **IP administration** tab (tab row: Details | **IP administration** | Monitoring | Security | Tags)
5. You're now on the **IPv4 addresses** table (columns: Private IP address | Public IP address | IP lifetime | …). Find the row whose Private IP address reads `10.0.0.x (Primary IP)`
6. At the far-right end of that row, click the **⋯** (ellipsis) menu → **Edit**. The **Edit Private IP Address** dialog opens
7. What you see depends on the checkbox from Section 5:

   **If you UNCHECKED it (the recommended Path B):** the dialog shows **No public IP** (selected) and **Reserved public IP** →
   1. Select **Reserved public IP** → a **Reserved Public IP Address** dropdown appears
   2. In the dropdown, select your reserved IP by name: **coolify-ip** → click **Update**. Done — go to step 8.

   **If you LEFT it checked (the VM booted with a temporary ephemeral IP):** the dialog shows only **No public IP** and **Ephemeral public IP** (selected). ⚠️ **OCI quirk:** while the ephemeral IP is assigned, the "Reserved public IP" option is hidden — the private IP must have NO public IP first. It takes two passes:
   1. **Pass 1 — remove the temporary IP:** select **No public IP** → click **Update**. The table refreshes with an empty **Public IP address** cell (the ephemeral IP is released; the instance temporarily has no public IP — expected and safe, nothing is running on the server yet)
   2. **Pass 2 — attach the reserved IP:** open the **⋯** menu on the same `10.0.0.x (Primary IP)` row → **Edit** again. Now **Reserved public IP** is visible → select it → in the **Reserved Public IP Address** dropdown pick **coolify-ip** → click **Update**

8. ✅ **Verify:** the **IPv4 addresses** table refreshes — the **Public IP address** column shows your reserved IP (e.g. `132.226.x.x`) and **IP lifetime** reads **Reserved**
9. 📋 Write that IP down — it's your server's address for everything that follows. It survives stop/start, reboots, AND full rebuilds (re-attach it to each new VM in these same clicks).

> 💡 **Keeping a reserved IP from your OLD server?** If you kept the reserved IP from before your rebuild (Part 3.4), skip "Part 1 of 2" entirely — just attach the existing one in Part 2 of 2 above.

## 4.4 — "Out of capacity for shape VM.Standard.A1.Flex" (the famous free-tier wait — and the fix)

> ℹ️ Same error, two wordings: **"Out of host capacity"** or **"Out of capacity for shape VM.Standard.A1.Flex in availability domain AD-X"**. Identical meaning, identical fix.

### What the error actually means (verified — and it's NOT you)

| What you might think | What's actually true |
|---|---|
| "My account is broken / flagged" | ❌ No. It's a pure **physical shortage**: no free spot on Oracle's ARM host machines in that availability domain at this second |
| "My card / billing has a problem" | ❌ No. Billing is never involved — a limit problem would say *"service limits were exceeded"* instead. Your $0 promise is untouched |
| "I picked a wrong setting in the form" | ❌ No. Every field can be perfect — the pool is simply full right now |

The verified mechanics:

1. **Everyone wants the same hardware.** The Ampere A1 shape is the only Always Free shape with serious compute (up to 4 OCPU / 24 GB) — every free-tier user on Earth competes for the same ARM hosts.
2. **Oracle doesn't guarantee free capacity.** Always Free compute is subject to availability — which is exactly why the error's own text just says "try a different availability domain or try again later". Paid (PAYG) launches get capacity priority; free launches get the leftovers.
3. **Ashburn is the most crowded region.** US East is the world's most popular home region, so its free A1 pool is the most contested (and the most abused by miners/account farmers, which keeps it tight).
4. **Capacity changes by the minute.** Every time someone deletes their VM, a 7-day-idle VM gets reclaimed, or Oracle adds host hardware — slots open, sometimes for seconds. Whoever asks in that window wins.

### Why you tried AD-1 → AD-2 → AD-3 and ALL of them failed

The three ADs are three separate buildings, but demand is **region-wide**: when the free pool is exhausted, all three doors are locked at the same time. Switching ADs helps only when one AD happens to have a leftover fragment — a lottery ticket, not a strategy.

**The winning strategy is to stand at all three doors, all day, asking every 30 seconds.** No human can do that. A script does it perfectly.

### The fix: `retry-launch.sh` (in this repo) + Oracle Cloud Shell

This repo ships **`retry-launch.sh`** — it hunts the slot for you:

| What it does | Detail |
|---|---|
| Retries the EXACT server from this Part | Ubuntu 24.04, Ampere A1, 2 OCPU, 12 GB RAM, 200 GB boot volume, your SSH key, automatic public IP |
| Cycles all ADs | AD-1 → AD-2 → AD-3, over and over, ~every 30 seconds, for as long as you leave it running |
| The instant a slot opens | Creates your server, waits ~1 min, prints your **Public IP** + the next guide parts |
| Safety built in | Exits if a server already exists · refuses to run outside your home region · stops on any error that isn't capacity · Ctrl+C = clean stop · safe to re-run anytime |

**Step 0 — prerequisites** (all done already if you're following this guide top-to-bottom):

- ✅ The VCN exists (Part 4.1 — creating a VCN never fails, no capacity needed)
- ✅ You have your SSH **public** key line (Section 6 above: Option A's `ssh-keygen -y -f oracle.key`, or the saved `.pub` file from Option B)
- 💡 You can open the ports NOW (Part 5) — the rules live on the VCN, not the VM, so they'll be ready and waiting when your server lands

**Step 1 — open Cloud Shell** (a free terminal inside the console — nothing to install, already logged in as you, OCI CLI pre-installed):

1. At **cloud.oracle.com**, confirm the region selector (top-right) shows your home region
2. Click the **>_** icon ("Developer tools", top-right of the black bar) → **Cloud Shell**
3. A terminal opens at the bottom of the page (~20 seconds the first time)

**Step 2 — get the script in:**

```bash
git clone https://github.com/ZIAKARS/ORACLE.git
cd ORACLE
```

**Step 3 — fill in your 3 values.** Easiest way: click the **pencil icon ("Open editor")** in Cloud Shell's toolbar → a text editor opens above the terminal → open `ORACLE/retry-launch.sh` → change the three variables at the top → **Ctrl+S**:

| Variable | What to paste |
|---|---|
| `COMPARTMENT_ID` | Your **Tenancy OCID** — console top-right profile icon → **Tenancy** → copy the OCID (starts `ocid1.tenancy.oc1..`) |
| `SUBNET_ID` | Leave **empty** — it auto-detects your VCN's public subnet |
| `SSH_PUBLIC_KEY` | The one-line public key from Section 6 (starts with `ssh-rsa` / `ssh-ed25519`) |

**Step 4 — run and wait:**

```bash
bash retry-launch.sh
```

- Leave the browser tab open. Each printed line is one real launch attempt — "out of capacity" is the *normal* thing to see; the win comes from never stopping.
- Typical wait in Ashburn: **minutes to hours, occasionally a day or two.** The script is working the whole time — you are not.
- If Cloud Shell disconnects (laptop slept, session timed out): reopen it, `cd ORACLE`, run `bash retry-launch.sh` again. It can never create a second server.

**Step 5 — the success screen** prints your Public IP, then:

1. Part 4.3 — note the IP (or switch it to a permanent reserved IP, Path B)
2. Part 5 — ports (skip if you already opened them while waiting)
3. Part 6 — `ssh -i oracle.key ubuntu@YOUR_IP`
4. Part 7 — `sudo bash setup.sh`

> ⏰ **Best hunting hours:** slots appear mostly while America sleeps — roughly **midnight–7 AM US Eastern** (= afternoon/evening in Europe & Asia). Run the script in that window (or simply always) for the best odds.

### Manual options (if you'd rather not use the script)

1. 🔄 The **Retry** button — every click is one attempt; people do win after dozens of clicks spread over hours
2. 🕐 Off-peak hours (above)
3. 🔀 A different AD each try
4. 📉 **Go small, resize later:** create with **1 OCPU / 6 GB** (a smaller request squeezes into fragmented leftovers far more easily). Once running: stop the instance → **Edit** → change to 2 OCPU / 12 GB → start. ⚠️ The resize can hit the same "Out of capacity" error — if so, retry the resize later (same game, smaller stakes). And don't leave the VM stopped for more than a day or two (Part 9).

### What NOT to do (every one of these is a trap)

| ❌ Never | Why |
|---|---|
| Switch the region selector to another region | Your A1 free allowance exists **only in your home region** — everything else is paid (Golden Rule #2) |
| Click "Upgrade to Pay As You Go" to "fix" it | It works instantly — because it's the ONE button that can bill you (Golden Rule #1). The script gets you the same server for $0 |
| Settle for the tiny x86 micro shape (VM.Standard.E2.1.Micro) | Free, yes — but 1 GB of RAM: far too small for Coolify. Don't spend your patience on the wrong server |
| Create from two browser tabs at once | Two forms can both succeed → two VMs → your whole allowance gone in one shot |


## 4.5 — Where to put `oracle.key` (VERY IMPORTANT)

Create one folder on your PC, for example `ORACLE`, and keep everything together:

```
ORACLE/            ← your folder on your PC (Desktop or Documents)
├── GUIDE.md       ← this guide (from GitHub)
├── setup.sh       ← the magic script (from GitHub)
├── retry-launch.sh ← the capacity auto-retry script (from GitHub — Part 4.4)
└── oracle.key     ← YOUR key goes HERE (downloaded / already there)
```

The key never goes to the server and never goes to GitHub — it lives on your PC only. This repo's `.gitignore` blocks `*.key` files, so it can never be pushed by accident. **Never email it, never share it, never put it in any repo.**

## ⚠️ Two hard rules about the boot volume (learned the hard way)

1. **It can GROW but never SHRINK.** A 200 GB boot volume can become 250 GB (paid!) but never 100 GB.
2. **It can only be attached at instance creation.** If you ever see *"boot volume not attached"* on an instance — that instance is unfixable. The only cure: terminate it, **delete the orphaned boot volume too** (Part 3.2), create fresh (Part 4) and re-run `setup.sh` (Part 7).

---

# 🔓 Part 5 — Open the Ports in the Oracle Console (firewall #1, ~5 minutes)

By default your server only accepts SSH. Visitors need ports 80/443, and you need 8000/6001/6002 for the Coolify dashboard. *(Port list verified from Coolify's official firewall docs.)*

1. ☰ Menu → **Networking → Virtual Cloud Networks** (VCN)
2. Click your VCN's name (**coolify-vcn**, from Part 4.1)
3. Open its security lists — two doors lead to the same place: click the **Security** tab on the VCN page, or the left-sidebar **Resources → Security Lists**
4. Click **Default Security List for coolify-vcn**
5. Look at the **Ingress Rules** list first: it already contains the **SSH (port 22)** rule (the VCN wizard created it — that's the door you'll use to connect). Leave it alone — don't duplicate it.
6. Click **Add Ingress Rules** and enter the first rule:

| Field | Value |
|---|---|
| Stateless | leave unchecked (default) |
| Source Type | CIDR |
| Source CIDR | `0.0.0.0/0` (means "from anywhere") |
| IP Protocol | TCP |
| Source Port Range | *(leave empty)* |
| Destination Port Range | `443` |

7. Click **+ Another Ingress Rule** and repeat for the next port — add all FIVE in one dialog:

| Port | Who uses it |
|---|---|
| ✅ `80` | HTTP — websites + Let's Encrypt certificate checks |
| ✅ `443` | HTTPS — websites with SSL |
| ✅ `8000` | Coolify dashboard (`http://YOUR_IP:8000`) |
| ✅ `6001` | Dashboard live-updates (deployment logs streaming in real time) |
| ✅ `6002` | Coolify web terminal (command box inside the dashboard) |

8. Click **Add Ingress Rules** (the button at the bottom) to save them all. ✅ The rules appear in the list immediately — no waiting.

> 💡 Prefer adding them one at a time? Same result — just reopen **Add Ingress Rules** for each port. And if port 22 is missing from the list for any reason, add it the same way (Source `0.0.0.0/0`, TCP, Destination Port `22`).

> 🔒 **Optional (nicer security):** for ports 22, 8000, 6001 and 6002, put *your home's IP* instead of `0.0.0.0/0` (Google "what is my IP"). Then only your house can reach those doors. If your home IP ever changes and you get locked out, just update the rule back. Ports 80/443 must stay `0.0.0.0/0` — that's your visitors.

> 🔒 **Bonus (later, optional):** once your Coolify dashboard works through a domain behind the proxy (Part 11), you can DELETE the 8000/6001/6002 rules — the dashboard then travels through 443 like everything else. Fewer open doors = tighter security.

> 🧱 Done with firewall #1. Firewall #2 (inside the server) is handled automatically by `setup.sh` in Part 7.

---

# 🔑 Part 6 — Connect to Your Server (the `oracle.key` file)

Your server's door has no password — only the key file opens it.

## 6.1 — Your PC folder setup (one time)

Make sure your folder from Part 4 looks exactly like this:

```
ORACLE/            ← your folder (e.g. C:\Users\YOU\Desktop\ORACLE)
├── GUIDE.md       ← this guide
├── setup.sh       ← the install script
├── retry-launch.sh ← the capacity auto-retry script (Part 4.4 — runs in Cloud Shell)
└── oracle.key     ← your private key (MUST be here)
```

If you cloned this repo from GitHub, `oracle.key` is the one file you add yourself — drop it in the same folder as `setup.sh`.

## 6.2 — Protect the key (one time)

**On Mac/Linux/Windows Git Bash:**
```bash
cd /path/to/your/ORACLE-folder

# Make the key private (SSH refuses "too public" keys)
chmod 400 oracle.key
```

**On Windows (PowerShell):** open PowerShell as Administrator, then:
```powershell
cd C:\Users\YOU\Desktop\ORACLE
icacls .\oracle.key /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

## 6.3 — Connect (every time)

```bash
ssh -i oracle.key ubuntu@YOUR_SERVER_IP
```
(Replace `YOUR_SERVER_IP` with the Public IP from Part 4. The username is always `ubuntu`.)

**First connection:** it asks `Are you sure you want to continue connecting?` → type `yes`.

> 💡 **Stop typing the IP every time (optional):** run this once in Git Bash / Terminal on your PC:
> ```bash
> echo 'export SERVER_IP=YOUR_SERVER_IP' >> ~/.bashrc && source ~/.bashrc
> ```
> From then on, `ssh -i oracle.key ubuntu@$SERVER_IP` works in any new window with zero editing. Any command in this guide that says `YOUR_SERVER_IP` can use `$SERVER_IP` instead.

✅ When you see a welcome message ending in a `$` prompt — **you're inside your server!** Everything you type now runs on the server, not your PC.

## 6.4 — ⚠️ Rebuilt your server? "REMOTE HOST IDENTIFICATION HAS CHANGED!" (normal, 30-second fix)

If you recreated your server (Part 3) — or moved a reserved IP to a new VM — SSH refuses to connect and prints a big scary block ending in `REMOTE HOST IDENTIFICATION HAS CHANGED!`. **That's normal and safe:** your PC memorized the OLD server's fingerprint and is (correctly) suspicious that the new server isn't it. Fix, on your PC (Git Bash / Terminal):

```bash
ssh-keygen -R YOUR_SERVER_IP
```

Then connect again → it asks `Are you sure you want to continue connecting?` → `yes`.

- **Git Bash quirk:** if the entry still shows after `-R`, open `~/.ssh/known_hosts` in a text editor, delete the line containing your server's IP, save, reconnect.
- **Still fighting it?** `rm ~/.ssh/known_hosts` deletes the whole list — it rebuilds itself as you reconnect (you'll re-confirm each server once).
- **Harmless warning:** `hostfile_replace_entries: link ... Permission denied` sometimes appears on Windows Git Bash — it only means Git Bash couldn't update its known-computers list. Your connection works fine; ignore it.

## 6.5 — Disconnect

```bash
exit
```

---

# ⚙️ Part 7 — Run the Magic Script (`setup.sh`)

This is the moment everything gets installed. **One script does all of it:**

| # | What it does | Why |
|---|---|---|
| 1 | Updates all system packages | Security patches |
| 2 | Creates 8 GB swap | App builds won't crash the server |
| 3 | Opens ports 80/443/8000/6001/6002 in iptables (firewall #2) | The #1 hidden gotcha on Oracle — sites "not loading" are almost always this |
| 4 | Enables automatic security updates | Ubuntu patches itself |
| 5 | Installs **Coolify** (Docker + dashboard + Traefik) | Your hosting platform |
| 6 | Installs the **keepalive bodyguard** | Oracle can never delete your server for being "idle" (Part 9) |
| 7 | Installs disk hygiene | Journal capped, monthly Docker cleanup — disk never fills |
| 8 | Prints your Coolify address + next steps | — |

## 7.1 — Run it

**SSH into your server** (Part 6), then type these three lines one by one:

```bash
# 1. Get this repo onto the server
git clone https://github.com/ZIAKARS/ORACLE.git

# 2. Enter it
cd ORACLE

# 3. Run the magic script
sudo bash setup.sh
```

⏳ **Wait 5–15 minutes** (mostly the Coolify download/install). You'll see green ✓ progress step by step. When it ends, it prints your server's health + your Coolify dashboard address:

```
➡️  Open in your browser:  http://YOUR_SERVER_IP:8000
```

> 🔄 The script is **safe to re-run** — every step checks first and skips if already done. If anything ever breaks, just run it again.

> ⏱️ **IMPORTANT — the 10-minute rule (from Coolify's latest docs):** Coolify only accepts the FIRST admin account registration **within 10 minutes of starting**. So: as soon as the script finishes, open the dashboard and register (Part 8). If you wait too long and see **"Setup window closed"**, SSH in and run `docker restart coolify`, then reload the page — the window reopens.

---

# 🎛️ Part 8 — Coolify First Login (once — do it within 10 minutes!)

1. 🌐 Open **`http://YOUR_SERVER_IP:8000`** in your browser
   - ❌ Doesn't load? → Part 19, problem #1 (ports).
2. Click **Register** → create your admin account (email + a STRONG password — this is your server's front door; use a password manager or a long passphrase you never use anywhere else)
3. ✅ You're in! This dashboard is your own Vercel.

> ⏱️ **See "Setup window closed"?** You waited longer than 10 minutes. SSH in (`ssh -i oracle.key ubuntu@YOUR_SERVER_IP`) and run:
> ```bash
> sudo docker restart coolify
> ```
> Then reload the page and register immediately.

## What's what in the dashboard

- **Projects** → your apps and databases live here
- **Servers** → your server's status (should show your VM, healthy)
- **Keys** → GitHub connection for private repos (public repos work without it)
- **Settings** → server-wide options

> 🏆 **First recommended setting:** go to **Servers → your server → (Cleanup / or Settings)** and enable **automatic Docker image cleanup**. Old deployment images pile up (each 0.5–1.5 GB) — this plus the monthly cleanup from `setup.sh` keeps the 200 GB disk healthy.

---

# ❤️ Part 9 — How Your Server Stays Alive Forever (understand once)

## The threat (verified from Oracle's official documentation)

Oracle deletes free servers that look **abandoned**. Two separate rules:

### Rule A — the "idle instance" rule (Oracle's exact documented criteria)
> Oracle reclaims an Always Free instance when, **for 7 days in a row, ALL THREE** are true:
> - CPU utilization (95th percentile) **below 20%**
> - Network utilization **below 20%**
> - Memory utilization **below 20%** *(applies to ARM A1 shapes — that's you)*
>
> *(Source: docs.oracle.com → Always Free Resources → "Idle Compute Instances" — verified word-for-word.)*

**The magic word is ALL.** Break *one* condition → your server can never be called idle.

### Rule B — the "abandoned account" rule
> An account that sits unused for an extended period — commonly reported as **~30 days without a console login** (from Oracle's Free Tier FAQ) — may be deemed abandoned and terminated. The exact number is no longer printed on Oracle's current doc pages, so treat it as "log in regularly and this rule can never touch you." The 2-week habit below makes it irrelevant regardless.

## Your protection (installed automatically by `setup.sh` — nothing for you to do)

**The keepalive bodyguard** (a tiny background service — YES, it comes with the script, starts automatically, and turns itself on at every boot):

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

# Turn it off (ONLY when your real apps use >25% RAM on their own — check Part 15)
sudo systemctl disable --now oracle-keepalive

# Turn it back on
sudo systemctl enable --now oracle-keepalive
```

**When is it safe to disable?** Only when your real workloads keep memory above ~25% by themselves (check: `free -h` → used should be 3+ GB of 12 GB, or look at the Memory metric in the OCI console: Compute → Instances → your VM → Metrics). Honestly — just leave it on; it costs nothing and frees itself automatically.

## Your only manual job: the 2-minute habit 🗓️

> 📱 **Every 2 weeks:** open **cloud.oracle.com**, log in, glance that the instance is green and Billing shows $0. That's it. This single habit defeats Rule B forever. Set a phone reminder now: *"Oracle check-in — every other Sunday."*

## ⚠️ One more danger: never leave the server STOPPED

A **stopped** instance reports ~0% on everything = maximum idle = prime reclaim target. If you ever stop it, start it again within a day or two. (Compute → Instances → your VM → **Start**.)

---

# 🛡️ Part 10 — The 100% Security Checklist

Your server is already built securely by default. This checklist makes it airtight — **2 minutes now, habits forever.**

## ✅ Already automatic (done for you)

| Protection | How |
|---|---|
| 🔑 No password login on SSH | Only your `oracle.key` file can open the door — brute-force password attacks have nothing to attack |
| 🧱 Two firewalls | Oracle Security List (console) + iptables (server) — only 6 doors open, everything else blocked |
| 🔒 Automatic HTTPS for every app | Traefik gets a free Let's Encrypt certificate per domain — no plain HTTP ever served |
| 🗃️ Databases never face the internet | Coolify creates them on a private Docker network — only your apps can reach them |
| 🩹 Daily security patches | `unattended-upgrades` runs by itself |
| 🚫 Key can never leak to GitHub | `.gitignore` blocks `*.key`, `*.pem`, `.env*` files |

## 👤 Your 3 jobs (2 minutes total)

- [ ] **1. Strong, unique Coolify admin password** (Part 8) — 16+ characters, stored in a password manager. This password is the keys to all your apps.
- [ ] **2. Keep `oracle.key` private forever** — it stays on your PC, in your `ORACLE` folder. Never email it, never upload it, never paste it anywhere.
- [ ] **3. Optional but recommended — lock the admin doors to your house:** edit the Security List rules for ports 22 / 8000 / 6001 / 6002 and replace `0.0.0.0/0` with your home IP (Google "what is my IP"). Only your home can then reach SSH and the dashboard. Visited websites (80/443) stay open to the world — that's correct.

## 🔐 Later upgrades (optional, when you have a domain)

- **Put the dashboard behind a domain + HTTPS** (Part 11: DNS record `coolify.yourdomain.com` → set it as the dashboard's Instance FQDN in Coolify settings) → then **delete the 8000/6001/6002 firewall rules**. The dashboard now travels encrypted through port 443 like your apps.
- **Enable Cloudflare's free protections** (Part 11): proxy (orange cloud) hides your server's real IP + free DDoS protection + optional "Bot Fight Mode" under Security → Bots.
- **Coolify 2FA**: Settings → Security → enable two-factor authentication for your admin account.

> 🚨 **If the worst happens:** if you ever suspect the key leaked — regenerate it immediately (instance page → Edit → SSH keys) and change your Coolify password. If an app's secrets leak — rotate them in the app's Environment Variables. Weekly backups (Part 17) mean you can always restore.

---

# 🌐 Part 11 — Connect Your Domain (Cloudflare, once per domain)

Your server has an IP like `140.238.x.x` — but visitors type `yourdomain.com`. Cloudflare (free) connects them AND adds CDN speed + DDoS protection + hides your IP.

> 🔄 **Just rebuilt your server (Part 3)?** If you re-attached your **reserved** IP (Part 4.3, Path B): **zero DNS changes needed** — same IP, same records, done. If you're on a **new ephemeral IP**: edit both A records (`@` and `www`) below and swap in the new IP — Cloudflare applies it in seconds.

> 💡 **No domain yet?** Buy one anywhere (Namecheap, Cloudflare Registrar, ~$10/year). Then add it to Cloudflare: dash.cloudflare.com → **Add site** → follow the nameserver steps (Cloudflare shows you exactly which 2 nameservers to set at your registrar — copy-paste, wait up to 24h, usually minutes).

## The setup

1. 🌐 Cloudflare dashboard → your domain → **DNS → Records → Add record**:

| Type | Name | Content | Proxy |
|---|---|---|---|
| `A` | `@` (means the root domain) | `YOUR_SERVER_IP` | 🟠 **ON** (orange cloud) |
| `A` | `www` | `YOUR_SERVER_IP` | 🟠 **ON** |

2. 🔐 **SSL/TLS** tab (left sidebar) → set encryption mode to **Full (strict)**
   - (Coolify gets its own real Let's Encrypt certificate per app — "strict" works and is the safest mode.)
3. 🚀 That's it. The domain now reaches your server. Each app you deploy in Coolify claims its own hostname — next part shows how.

> 💡 **Subdomain strategy (free forever):** you don't need to buy a domain per project! One domain gives unlimited subdomains: `app.yourdomain.com`, `blog.yourdomain.com`, `shop.yourdomain.com`… just add another A record (or one wildcard `*` record) pointing at the same IP.

> 💡 **Optional extra:** Security → Bots → enable **Bot Fight Mode** (free) — blocks junk bots from hammering your sites.

---

# 🚀 Part 12 — Deploy Your First Next.js App (~5 minutes, repeat for every app)

Exactly like Vercel, but on YOUR server:

1. 🗃️ Your app's code must be on **GitHub** (any repo, public or private)
2. 🎛️ Coolify dashboard → **Projects → Add New Project** → give it a name
3. **+ Add New Resource → Production → GitHub**
   - First time: click the GitHub link and authorize the Coolify app (lets it read your repos)
   - Private repos: first add a GitHub **Deploy Key** in Coolify → Keys (or use the app authorization)
4. Pick your **repository** and branch (usually `main`)
5. Coolify auto-detects **Next.js** and prepares the build (via Nixpacks). You usually change nothing.
6. 🔧 **Environment Variables** tab → add everything your app needs (like `DATABASE_URL`, API keys — copy them from your Vercel project settings if you're migrating)
7. 🌐 **Domains** tab (in the app's Settings) → enter `app.yourdomain.com` (must have a DNS record pointing at your server — Part 11) → Save
8. ▶️ Click **Deploy**
9. ⏳ First build takes 3–10 minutes on the ARM server (it's building your whole app + Docker image). Watch the live logs stream in.
10. 🎉 When it goes green: `https://app.yourdomain.com` is live **with automatic HTTPS**. Every future `git push` to that repo redeploys automatically (Coolify installs a webhook for you).

## Deploy a second app (and every app after)

Same 10 steps, just: new GitHub repo → new project → **new subdomain** (`blog.yourdomain.com`, `shop.yourdomain.com`… each needs its DNS record from Part 11). That's the entire difference. 3 minutes each once you've done it once.

## Pro tips for Next.js on this server

- 📦 In `next.config.js`, set `output: 'standalone'` → your Docker image shrinks from ~1.5 GB to ~300 MB (disk is 200 GB, not infinite).
- 🖼️ Install the `sharp` package for fast image optimization.
- 🧠 Give the app a **memory limit** (app Settings in Coolify, e.g. 512 MB) → one leaky app can never eat the whole server.
- 🚫 Don't deploy several apps at the same moment — builds share the 2 CPUs. Stagger them.
- 🗑️ Removing an app: Coolify → the app → **Danger Zone → Delete**. Clean in one click — no leftover files.

> ❓ **App needs a database?** Part 13 (one-click PostgreSQL) — then paste the connection string Coolify gives you into the app's env vars as `DATABASE_URL`.

---

# 🌍 Part 13 — WordPress & Other One-Click Apps

## WordPress (verified one-click template)

1. 🎛️ Coolify → **+ Add New Resource → One-Click Service → WordPress**
2. It automatically creates WordPress **+ its MySQL database** together
3. 🌐 Set the domain (e.g. `blog.yourdomain.com` — needs its DNS record) → Deploy
4. Open the domain → the famous WordPress 5-minute installer appears → done

## Other popular one-clicks (same 3 clicks)

| App | What it's for | RAM |
|---|---|---|
| **PostgreSQL / MySQL / Redis / MongoDB** | databases for your apps | 100–300 MB each |
| **Uptime Kuma** | monitors all your sites and alerts you when one goes down (see Part 14) | ~50 MB |
| **n8n** | workflow automation (Zapier alternative) | ~300 MB |
| **Plausible** | privacy-friendly analytics | ~150 MB |
| **Ghost** | blogging platform | ~200 MB |
| **MinIO** | S3-compatible file storage | ~100 MB |

Browse the full list: **+ Add New Resource → One-Click Service** (dozens of official templates — and any Docker image from Docker Hub works too).

---

# 📊 Part 14 — Usage, Monitoring & Reporting (see everything, anytime)

Three levels: quick checks on the server, the Oracle console (the numbers Oracle itself judges you by), and 24/7 automated monitoring. All free.

## 14.1 — Quick checks (SSH in, 10 seconds)

```bash
free -h            # RAM — see the keepalive + your apps
df -h /            # disk — keep under 70% (140 GB of your 200)
docker ps          # every running app
docker stats       # live RAM/CPU per app (Ctrl+C to exit)
sudo docker system df   # how much disk Docker uses
```

## 14.2 — The Oracle console (the official numbers)

- **Server health:** Compute → Instances → your VM → **Metrics** tab → CPU / Network / Memory graphs
  - Memory is the one that matters for the anti-idle rule (Part 9) — the keepalive keeps it ~26%. If you see memory above 20% here, you're protected, always.
- **Cost report (your "$0 receipt"):** ☰ Menu → **Billing & Cost Management → Cost Analysis**
  - Set the filter to "This month" → it shows **$0.00** (or the trial credit burning down during the first 30 days, which is fine — it's free money, not yours)
  - Screenshot it monthly if you like receipts. Nothing will ever appear there on a non-upgraded account.
- **Usage report:** same page → **Usage Report** → every resource you've created, all flagged free.
- **Bandwidth:** Cost Analysis → filter by "Networking" — 10 TB/month free means you'd need ~30 million page views to get close. Don't think about it.

## 14.3 — Automated 24/7 monitoring (set once, alerts forever)

1. 🎛️ In Coolify: **+ Add New Resource → One-Click Service → Uptime Kuma** (uses ~50 MB RAM)
2. Open it, add a "Monitor" for each of your sites (type: HTTP(s), URL: `https://app.yourdomain.com`)
3. Set a notification: email, Telegram, Discord — whatever you use. Uptime Kuma now watches your sites from inside your server, every 60 seconds, forever, free.

> ⚠️ Note: Uptime Kuma watches from *inside* the server. For outside-in monitoring (catches DNS/Cloudflare problems too), also add your sites to a free external service like **UptimeRobot** (no install, just paste URLs).

## 14.4 — Coolify's built-in reporting

- Every app shows live **CPU / RAM / disk** on its page in the dashboard
- Every deployment keeps its **full build log** (click any deployment in the app's Deployments tab)
- Server-wide: **Servers → your server** → utilization at a glance

---

# 📦 Part 15 — What You Can Host + Your RAM Budget

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

> 🛑 **Rule of thumb:** when total RAM sits above ~70% steadily, stop adding apps (and the keepalive will have already freed itself — that's your signal).

---

# 💾 Part 16 — OPTIONAL: Add a Block Volume (skip unless you truly need it)

> ⚠️ **You probably DON'T need this.** Your 200 GB boot volume holds everything, and a fresh block volume would need you to first shrink the boot volume — which is **impossible** (grow-only). This part exists only for completeness — e.g., if you someday rebuild the VM with a smaller boot volume.

**What a block volume is:** an extra empty hard disk you plug into the server and "mount" to a folder (apps then save files there without knowing the difference). People use one to separate big data (uploads, caches) from the OS, or to survive VM rebuilds.

**The math problem:** free storage = 200 GB **total** (boot + block combined). If your boot volume is already 200 GB, adding a block volume = **paid** (breaks Golden Rule #3!). To do it free you'd have to recreate the VM with a smaller boot volume (e.g. 150 GB boot + 50 GB block).

**If you ever do it:**

**Console side:**

1. ☰ Menu → **Storage → Block Volumes** → **Create Block Volume** and fill in:
   - **Name:** `data-vol` (anything you like)
   - **Create in compartment:** your root compartment (default)
   - **Availability domain:** the one your VM lives in (labels show the free-eligible ADs)
   - **Volume size and performance:** select **Custom** → type the size (e.g. `50` GB — remember: boot + block must stay ≤ 200 GB total)
   - **Volume performance:** **Balanced** (default — Golden Rule #5)
   - Tags / Reservations / Backup policies / Cross-region replication / encryption: all default
2. Click **Create block volume** → wait for **Available** (~10 seconds)
3. On the volume's page → left **Resources → Attached Instances** → **Attach to Instance**:
   - **Attachment type:** **Paravirtualized** (the default — simplest and boot-safe: the disk shows up as `/dev/sdb` automatically and is presented before the OS boots, so it can never hang a boot)
   - **Select instance:** your VM
   - **Attach as:** Read/Write (default)
4. Click **Attach** → wait for **Attached** (~10 seconds). (Only if Paravirtualized is somehow unavailable in your region: attach as **iSCSI** instead and run the 3 `sudo iscsiadm …` commands Oracle shows you under Attached Instances → ⋮ → iSCSI Commands & Information. ⚠️ Never run the `-u` or `-o delete` commands from that dialog — those DETACH and DELETE the volume.)

**Server side (SSH in):**

5. On the server:
   ```bash
   lsblk                                  # find the new empty disk, e.g. /dev/sdb
   sudo mkfs.ext4 /dev/sdb                # format ONCE (like a new USB stick)
   sudo mkdir -p /mnt/data
   sudo mount /dev/sdb /mnt/data
   # Make it auto-mount after reboots (boot-safe: never hangs the server):
   echo '/dev/sdb /mnt/data ext4 defaults,noatime,_netdev,nofail 0 2' | sudo tee -a /etc/fstab
   df -h /mnt/data                        # ✅ verify
   ```
6. Point what you want at `/mnt/data` (e.g. Coolify backup destination, app upload folders).

Again: **skip this part** unless you have a specific reason. One disk = one backup = simple life.

---

# 📸 Part 17 — Backups (set once, sleep forever)

Because **everything lives on the ONE 200 GB boot volume, ONE backup = your ENTIRE server** (OS + Coolify config + all apps + all databases + all uploads). This is the hidden superpower of the one-disk design.

## 17.1 — Whole-server backup (free, automatic)

1. Console → **Compute → Instances** → your VM → scroll to **Boot volume** → click its name
2. **Scheduled Backups** → create a schedule:
   - Frequency: **Weekly** (e.g. Sunday 04:00)
   - Backup type: **Full**
   - Retention: 4 weeks (1 month deep)
3. ✅ Done — uses 1–4 of your 5 free backup slots. If disaster ever strikes: Boot volume → Backups → **Restore** → your whole server comes back exactly as it was.

## 17.2 — Database backups (extra layer)

In Coolify, each database you create has a **Backups** tab → set a schedule → destination: local disk (fine) or any S3-compatible storage (Oracle's free Object Storage works great — S3 keys from Console → Profile → Customer Keys).

> ⚠️ **Keep Object Storage totals under 20 GB:** once your account becomes Always Free, the limit is 20 GB combined — and Oracle's documented rule is that objects above the limit **when the trial ends are deleted**. Database dumps are tiny (MBs, not GBs), so this is easy to stay under.

Two layers, both free: weekly whole-server snapshot + per-database dumps. You're covered.

## 17.3 — Testing a restore (recommended once)

Backups you've never tested are hopes, not backups. Once, after a few weeks: pick a quiet moment, try restoring the boot volume backup to see the flow (you can cancel partway once you see the restore screen — or create a scratch VM to test on). Knowing the restore works = sleeping well.

---

# 🧹 Part 18 — Maintenance Habits (2 minutes every 2 weeks)

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
- ✅ Weekly whole-server backup (Part 17 — you set it once)

---

# 🆘 Part 19 — Troubleshooting (every problem + its fix)

## Problem 1 — "My site doesn't load" (99% of all problems)

Oracle has **TWO firewalls** — both must be open:

1. ☁️ **Console side:** Part 5 rules present? (VCN → Security Lists → ports 22/80/443/8000/6001/6002)
2. 🧱 **Server side:** SSH in and check: `sudo iptables -L INPUT -n` — you should see `ACCEPT tcp dpt:80`, `443`, `8000`, `6001`, `6002` BEFORE the `REJECT` rule. Missing? Run `sudo bash setup.sh` again (step 3 fixes it).
3. 🌐 DNS: does the A record point at the right IP? (Cloudflare → DNS)
4. 🎛️ Coolify: is the app green and is its domain set correctly (exact spelling, https)?

## Problem 2 — "Boot volume not attached" / instance won't start

A boot volume can only be attached **at creation** — an instance in this state is **unfixable**. Recovery:

1. Follow **Part 3** (full teardown): terminate the broken instance, **delete the orphaned boot volume too** (orphaned volumes still count against your 200 GB and block new creation)
2. Create a fresh VM (Part 4) and re-run `setup.sh` (Part 7)

## Problem 3 — "Out of host capacity" / "Out of capacity for shape VM.Standard.A1.Flex" when creating the VM

Completely normal on the free tier — a physical A1 host shortage, not your account, not your card. Use **`retry-launch.sh`** in Cloud Shell to auto-grab the first free slot (full walkthrough: Part 4.4). Manual options: retry at off-peak hours, try a different Availability Domain, or create smaller (1 OCPU / 6 GB) and resize later. **Never switch regions, never upgrade to PAYG.**

## Problem 4 — Coolify dashboard unreachable (port 8000)

- Console Security List has the 8000 rule? (Part 5)
- Server iptables has it? (`sudo iptables -L INPUT -n | grep 8000`)
- Is Coolify running? SSH in → `docker ps` — you should see coolify containers. If not: `sudo bash setup.sh` again.

## Problem 5 — Registration says "Setup window closed"

You waited more than 10 minutes after Coolify started. Fix (from Coolify's official docs):

```bash
sudo docker restart coolify
```
Reload the page → register immediately.

## Problem 6 — Dashboard loads but logs/terminal don't stream, or "websocket" errors

Ports **6001** (live updates) and **6002** (web terminal) aren't open. Open them in the Security List (Part 5) — `setup.sh` already handles the iptables side; re-run it if you changed anything.

## Problem 7 — "Instance was stopped by Oracle" (idle reclaim email)

- Start it immediately: Console → Instances → your VM → **Start**
- Then check the keepalive: `systemctl status oracle-keepalive` (want: active/running). If it was dead, `sudo systemctl enable --now oracle-keepalive` — and find out why (`journalctl -u oracle-keepalive --since "7 days ago"`).
- If you deliberately stopped it yourself for a long time — don't (Part 9 warning).

## Problem 8 — SSH: "Permission denied (publickey)"

- Using the right key file? `ssh -i oracle.key ubuntu@IP` (username must be `ubuntu`)
- Key permissions: `chmod 400 oracle.key` (Part 6.2)
- Correct IP? (Instance page, Public IP)

## Problem 9 — Disk filling up

```bash
df -h /                                   # how full?
sudo docker system df                     # Docker's share
sudo docker system prune -f               # immediate cleanup (safe: running containers untouched)
sudo journalctl --vacuum-size=200M        # trim logs now
```
(The monthly cron already does this — this is the manual "right now" version.)

## Problem 10 — An app is down but the server is fine

- Coolify → the app → is it red? Click **Redeploy** (often a transient build issue)
- Check the app's **Logs** tab in Coolify
- Still stuck? **Delete + recreate** the resource (Part 12 step 🗑️) — with weekly backups + code on GitHub, recreating an app is always safe

## Problem 11 — SSH refuses: "REMOTE HOST IDENTIFICATION HAS CHANGED!"

Normal after rebuilding your server or moving a reserved IP — your PC just remembers the old server's fingerprint. 30-second fix: `ssh-keygen -R YOUR_SERVER_IP` → reconnect → `yes`. Full instructions: Part 6.4.

---

# 💳 Part 20 — The "Never Get Charged" Final Checklist

Print this. Live by it. It is **mathematically impossible** to be billed if all five stay true:

- [ ] 🚫 **Never** click "Upgrade to Pay As You Go" (the ONLY path to billing)
- [ ] 📍 Everything created in **US East (Ashburn)** — check the region selector before every "Create"
- [ ] 💾 Total storage = your **200 GB boot volume only** (no extra volumes)
- [ ] 📸 **≤ 5 volume backups** (your weekly schedule uses 1–4)
- [ ] ⚡ Boot volume performance stays **Balanced** (never touch VPUS settings)

**Verified billing behavior** (from Oracle's own documentation): Oracle's written policy, direct quote: **"Your credit card will not be charged unless you upgrade your account."** In practice a non-upgraded account also can't create resources beyond the free limits — Oracle blocks the creation with an error instead of billing you. There is no invoice, no bill, no charge. The card on file is identity verification only.

**The one temporary charge you may have seen:** the ~$1 signup verification hold — refunded within days. That's the only time your card was ever touched.

---

# 📋 Part 21 — Quick Command Reference

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
sudo docker restart coolify    # reopen the 10-minute registration window

# ── Emergency: disk filling up ───────────────────────────
sudo journalctl --vacuum-size=200M
sudo docker system prune -f
```

---

# 🎓 Appendix A — The Journey in One Page

```
① Sign up            oraclecloud.com → card + phone → home region US East (Ashburn)
        ↓
② Network + server   VCN wizard ("Create VCN with Internet Connectivity") → Create instance:
                     Ubuntu 24.04 · Ampere 2 OCPU/12 GB · 200 GB boot volume
                     → save oracle.key into your ORACLE folder → note the Public IP
                     (reserved IP = permanent: re-attach it after every rebuild)
        ↓
③ Open ports         Console: VCN → Security List → 22, 80, 443, 8000, 6001, 6002
        ↓
④ Connect            chmod 400 oracle.key → ssh -i oracle.key ubuntu@IP
        ↓
⑤ Install            git clone the repo → sudo bash setup.sh  (~10 min, does EVERYTHING:
                     updates, swap, firewall #2, Coolify, keepalive, hygiene)
        ↓
⑥ Dashboard          http://YOUR_IP:8000 → Register (within 10 minutes!)
                     → set strong password → enable image cleanup
        ↓
⑦ Domain             Cloudflare: A record → server IP, orange cloud ON, Full (strict)
        ↓
⑧ Deploy             Coolify: GitHub → repo → env vars → domain → Deploy
                     (repeat ⑦+⑧ for every new app — 3 minutes each)
        ↓
⑨ Forever habits     Biweekly: log into oracle console (2 min)
                     Set once: weekly backup schedule + Uptime Kuma
                     Never: PAYG upgrade, other regions, extra volumes, stopped VM
```

**Total cost: $0.00/month. Forever.** 🎉

---

# 🗺️ Appendix B — What's Next (future ideas on this server)

Once you're comfortable, everything below installs with the same Part 12/13 flow:

- **Postiz** (social media scheduler — Pinterest & co.): deploy via Docker Compose from Coolify, add `PINTEREST_CLIENT_ID/SECRET` env vars, create a Pinterest developer app with redirect URI `https://your-domain/integrations/social/pinterest`
- **Plausible / Umami** — privacy-friendly analytics for all your sites
- **n8n** — automation workflows (replaces Zapier)
- **MinIO** — your own S3 storage for app uploads
- **Ghost** — a fast publishing blog

Check the RAM budget (Part 15) as you grow, and enjoy your free platform.

---

*Every factual claim was verified against the LIVE official documentation on November 22, 2026 — Oracle's Always Free Resources + Free Tier pages (docs.oracle.com: 1,500 OCPU-hours / 9,000 GB-hours = 2 OCPU + 12 GB, 200 GB combined storage, 5 backups, 10 TB egress, 20 GB Object Storage, idle-instance criteria, card policy, trial-end rules), Oracle's **Public IP Addresses** page (ephemeral IPs *"remain assigned"* through stop/start; an ephemeral IP can never be converted to reserved; reserved-IP creation limits), Oracle's **Launching an Instance** page (current form structure: Basic Information → Security → Networking (Primary VNIC) → SSH keys → Storage/Boot volume → Review; the official "Start VCN Wizard → Create VCN with Internet Connectivity" recommendation; "Specify a custom boot volume size" 50 GB–32 TB; Balanced default performance; the exact SSH key options), Oracle's networking pricing + price-list pages (no public-IP line item published anywhere), and Coolify's official docs (coolify.io/docs: installer, requirements, ports 22/80/443/8000/6001/6002, first-login window). The Part 4 console walkthrough mirrors every step of the reference deployment guide (LeadGrid `DEPLOYMENT_GUIDE_SERVER.md`): VCN wizard first, every create-instance section, SSH-key reuse via `ssh-keygen -y`, the reserved-public-IP reserve + primary-VNIC attach flow (both the no-public-IP path and the two-pass ephemeral path), and the security-list rule fields. Part 4.4's capacity explanation matches Oracle's documented position — Always Free compute is subject to available capacity, and the error's own text directs you to another availability domain or a later retry — and `retry-launch.sh` uses only officially documented OCI CLI launch parameters (`oci compute instance launch`: `--subnet-id`, `--image-id`, `--shape`, `--shape-config`, `--assign-public-ip`, `--boot-volume-size-in-gbs`, `--ssh-authorized-keys-file`), the community-standard remedy for the well-known free-tier A1 shortage. Items that are community-reported or estimates are labeled as such in the text. All IPs and keys in this guide are placeholders — yours stay on your PC only.*
