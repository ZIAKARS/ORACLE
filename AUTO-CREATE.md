# 🤖 AUTO-CREATE — the server creates itself (GitHub Actions edition)

This replaces **GUIDE.md Part 4.4** (the Cloud Shell retry script). You no
longer need to keep a browser tab open, run anything on your PC, or press
anything. **GitHub's own computers hunt for Oracle capacity every 10 minutes,
24/7**, and the moment a slot frees up they create the exact server from
GUIDE.md Part 4:

| Setting | Value (locked to the free tier) |
|---|---|
| Shape | `VM.Standard.A1.Flex` (Ampere ARM) |
| OCPU / RAM | **2 OCPU / 12 GB** |
| Boot volume | **200 GB** |
| OS | Ubuntu 24.04 (aarch64) |
| Availability domains | **all of them, tried in rotation** |
| Public IP | **RESERVED** (`coolify-reserved-ip`) — attached only after creation, never an auto-assigned ephemeral one. It survives stop/start, so your Cloudflare DNS never breaks. |
| Ports opened (if it builds the VCN) | 22, 80, 443, 8000, 6001, 6002 — same as Part 5 |

When the server lands, the workflow **disables itself automatically** — it
can never create a second server or spend anything.

---

## Why the repo is PUBLIC (important)

Public repositories get **unlimited free GitHub Actions minutes**, which is
what pays for a 24/7 every-10-minutes hunt. Nothing sensitive is in the repo
or the logs: all credentials live in GitHub **Secrets**, and the script masks
OCIDs and IPs in the logs.

If you ever switch the repo back to **private**, edit
`.github/workflows/auto-create.yml` and change the cron to `*/30` and
`ROUNDS: "1"` — private repos only include 2,000 free minutes/month.

---

## Setup (once, ~10 minutes)

### Step 1 — Create the OCI API key (2 minutes)

1. Go to **https://cloud.oracle.com** and sign in.
2. Click your **profile icon** (top-right) → **My profile**.
3. Left sidebar, near the bottom: **API keys** → **Add API key**.
4. Choose **Generate API key pair** → click **Download Private Key**
   (saves a `.pem` file — keep it!) → click **Add**.
5. A window shows a **config file snippet**. It looks like this:

   ```
   [DEFAULT]
   user=ocid1.user.oc1..aaaa...your...user...id
   fingerprint=aa:bb:cc:dd:...:99
   tenancy=ocid1.tenancy.oc1..aaaa...your...tenancy...id
   region=us-ashburn-1
   key_file=<path to the .pem you downloaded>
   ```

   Copy those 4 values — you need them in Step 2.

### Step 2 — Add the GitHub Secrets (3 minutes)

Open this repo → **Settings** → **Secrets and variables** → **Actions** →
**New repository secret**. Add these **6 required** secrets:

| Secret name | Paste this value |
|---|---|
| `OCI_CLI_USER` | the `user=` OCID from the snippet |
| `OCI_CLI_TENANCY` | the `tenancy=` OCID from the snippet |
| `OCI_CLI_FINGERPRINT` | the `fingerprint=` value |
| `OCI_CLI_REGION` | the `region=` value (e.g. `us-ashburn-1`) |
| `OCI_CLI_KEY_CONTENT` | **the entire contents of the downloaded `.pem` file** — open it with Notepad, select all, copy, paste (including the BEGIN/END lines) |
| `SSH_PUBLIC_KEY` | your one-line public key (`ssh-rsa AAAA…` or `ssh-ed25519 AAAA…`). If you followed GUIDE.md Part 4 you already have `oracle.key` — get the public line with `ssh-keygen -y -f oracle.key` |

Optional secrets (add later if you want them):

| Secret name | What it does |
|---|---|
| `OCI_COMPARTMENT_ID` | only if you use a custom compartment (default: tenancy root — correct for this guide) |
| `OCI_SUBNET_ID` | only if you have multiple VCNs and want to force a specific subnet |
| `OCI_IMAGE_ID` | force a specific image OCID (default: latest Ubuntu 24.04 aarch64) |
| `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` | get a Telegram alert the second the server is created (make a bot with @BotFather, get your chat id from @userinfobot) |

### Step 3 — Done. Nothing else.

The next scheduled run (within 10 minutes) picks the secrets up and starts
hunting. Watch it live any time: **Actions** tab → **Auto-create A1
instance** → click the latest run. Green ✓ = hunting as expected
("no free slot yet" is the normal state — Oracle's free A1 hosts are simply
full; a slot typically opens within hours to days).

You will **not** get emails while it patiently retries. You **will** get an
email only if something is genuinely broken (bad key, wrong OCID…), with the
exact reason in the log.

---

## How you know it worked

- The Actions run log ends with `★ CAPACITY FOUND — SERVER CREATED!`
- You get the Telegram alert (if configured)
- https://cloud.oracle.com/compute/instances shows `coolify-server` RUNNING
- Its public IP is your reserved one: **Networking → IP management → Reserved
  public IPs** → `coolify-reserved-ip` (it stays the same forever)
- The workflow disables itself so no more runs happen

Then continue with **GUIDE.md Part 6** (connect with `oracle.key`) and
**Part 7** (`setup.sh` / Coolify).

## SSH reminder

```
ssh -i oracle.key ubuntu@YOUR_RESERVED_IP
```

---

## Safety rules built into the script

1. **Never a second server** — if any A1 instance already exists, it only
   re-attaches the reserved IP and stops.
2. **Home region only** — it queries your tenancy's actual home region and
   refuses to create anything anywhere else (non-home = paid).
3. **Exact free-tier spec** — 2 OCPU / 12 GB / 200 GB boot, nothing more.
4. **One reserved IP, reused** — named `coolify-reserved-ip`, tagged, created
   only after the server exists, attached immediately (Oracle does not bill
   for reserved public IPs — verified against the OCI price list).
5. **Self-disabling** — the workflow turns itself off after success.
6. **Secrets never printed** — every OCID / IP / key value is masked in logs.

## Troubleshooting

| Symptom (in the Actions log) | Meaning / fix |
|---|---|
| `[PAUSED] GitHub secrets not set yet` | Add the secrets from Step 2 |
| `Authentication with Oracle failed` | One of the 5 credential secrets is wrong/partial — re-copy from the OCI config snippet |
| `SSH_PUBLIC_KEY does not look like a public key` | It must be ONE line starting `ssh-rsa ` or `ssh-ed25519 ` |
| `Could not create the VCN` + mentions limits | You already have 2 VCNs — delete one (GUIDE.md Part 2) or set `OCI_SUBNET_ID` |
| `out of capacity (as expected)` | Normal hunting state — do nothing |
| Workflow stopped running after ~2 months of hunting | GitHub auto-disables quiet scheduled workflows — any commit (edit this file) re-enables it |

## Manual controls

- **Run a hunt right now:** Actions → *Auto-create A1 instance* → **Run workflow**
- **Stop everything:** Actions → *Auto-create A1 instance* → `…` → **Disable workflow**
- **Change the spec** (e.g. 1 OCPU / 6 GB): edit the values in
  `.github/workflows/auto-create.yml` and commit
