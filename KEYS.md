# 🔑 KEYS & Credentials — inventory and recovery guide

Everything you need to know about the keys for this setup: what each one
is, where it lives, and what to do if you lose it.

> ⚠️ **This repo is PUBLIC** — so it only ever contains PUBLIC material.
> Private keys must NEVER be committed here (the `.gitignore` already
> blocks `*.key` / `*.pem` files as a safety net). Private backup lives in
> your **private** repo: **https://github.com/ZIAKARS/oracle-private-backup**

---

## 1. SSH key pair — logs YOU into the server

| Item | Value |
|---|---|
| **Public key** (safe to share — the server accepts this one) | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDs0HmJ8jgZFjYJmRXy09TbqO1DIDeCvuqQacLoHfwGD hemak@HEMAK` |
| **SHA256 fingerprint** | `SHA256:6KrWuOZbZ7CnaS5F2VEGiDe2dc8jNvHLaigJVEHgiSU` (verified = matches the PC key) |
| **Private key file** | `oracle.key` — on your **Desktop** (`C:\Users\HEMAK\Desktop\oracle.key`) |
| **Private key backup** | Upload the file yourself to the private backup repo (link above) |

**Login command (Windows cmd):**
```
ssh -i %USERPROFILE%\Desktop\oracle.key ubuntu@SERVER_IP
```

**If you lose `oracle.key`:** recover it from the private backup repo.
If it is gone from BOTH places you are locked out of the server — recovery
is possible but painful (Oracle serial console). Keep at least two copies.

---

## 2. OCI API key — lets GitHub Actions control your Oracle account

| Item | Value |
|---|---|
| **Registered fingerprint** | `1a:c6:b3:9c:b1:99:1b:61:63:00:d1:31:e4:21:da:13` |
| **Private .pem file** | `hellohemak@gmail.com-2026-11-23T22_54_41.769Z.pem` (in your **Downloads** folder) |
| **Also stored** | (encrypted) in GitHub Secrets as `OCI_CLI_KEY_CONTENT` — the automation reads it from there; no file is needed in this repo |

**If you lose the .pem:** no problem at all — generate a new one in 2 minutes:
1. cloud.oracle.com → profile icon → **My profile** → **API keys** → **Add API key** → Generate → Download → **Add**
2. Repo → **Settings** → **Secrets and variables** → **Actions** → update `OCI_CLI_KEY_CONTENT` with the new file's full contents (and `OCI_CLI_FINGERPRINT` with the new fingerprint).

---

## 3. OCI identifiers (user/tenancy OCIDs, region)

Kept in the **private** backup repo (not published here):
**https://github.com/ZIAKARS/oracle-private-backup**

You can always re-read them from the Oracle console anyway:
profile icon → **My profile** (user OCID) / **Tenancy** (tenancy OCID).

---

## 4. GitHub Secrets currently set in THIS repo (encrypted, not readable)

| Secret | Purpose |
|---|---|
| `OCI_CLI_USER` | your Oracle user OCID |
| `OCI_CLI_TENANCY` | your Oracle tenancy OCID |
| `OCI_CLI_FINGERPRINT` | API key fingerprint |
| `OCI_CLI_REGION` | `us-ashburn-1` (home region) |
| `OCI_CLI_KEY_CONTENT` | the API private key (encrypted) |
| `SSH_PUBLIC_KEY` | the public key from section 1 |

---

## 5. Quick reference — your future server

| Item | Value |
|---|---|
| Name | `coolify-server` |
| Spec | Ampere A1 · 2 OCPU · 12 GB RAM · 200 GB boot · Ubuntu 24.04 |
| **Reserved public IP** | `157.151.252.112` (permanent — never changes on stop/start) |
| Login user | `ubuntu` |
| Ports open | 22 (SSH), 80/443 (websites), 8000 (Coolify dashboard), 6001/6002 (dashboard live-updates + web terminal) |
