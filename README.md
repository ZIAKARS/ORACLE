# ORACLE — Always Free server, fully automated

Your Oracle Cloud Always Free server (Ubuntu 24.04 · Ampere A1 · 2 OCPU ·
12 GB RAM · 200 GB disk · reserved public IP) — hunted and created **by
GitHub Actions**, no browser tab or PC left running.

## Start here

| File | What it is |
|---|---|
| **[AUTO-CREATE.md](AUTO-CREATE.md)** | 🤖 **The automation** — hunts for capacity every 10 min, 24/7, until your server exists. Setup is one 10-minute task. |
| **[GUIDE.md](GUIDE.md)** | 📖 The full manual: concepts, VCN, ports, connecting, Coolify install, DNS, backups, troubleshooting. |
| `auto_create.py` | The script GitHub runs (no need to touch it). |
| `retry-launch.sh` | Old Cloud-Shell retry method (superseded by AUTO-CREATE.md). |
| `setup.sh` | Post-creation server setup (GUIDE.md Part 7) — run it once on the server. |

## The short version

1. Do the 10-minute setup in **[AUTO-CREATE.md](AUTO-CREATE.md)** (one-time).
2. Wait — GitHub keeps trying every 10 minutes until Oracle frees a slot
   (usually hours to a few days).
3. When it lands: `ssh -i oracle.key ubuntu@YOUR_RESERVED_IP`, then follow
   GUIDE.md Part 7 (`setup.sh`).

> ⚠️ Never commit `oracle.key`, any `.pem` file, or `.env` files — the
> `.gitignore` already blocks them, keep it that way.
