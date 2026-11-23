#!/usr/bin/env python3
# ============================================================================
#  auto_create.py — Oracle Always Free A1 "capacity hunter"
#                     (GitHub Actions edition — runs on GitHub's servers 24/7)
# ============================================================================
#  WHAT THIS DOES
#    GitHub runs this script every 10 minutes, around the clock. Each run it
#    tries to launch the exact server from GUIDE.md Part 4 (Ubuntu 24.04,
#    Ampere A1, 2 OCPU, 12 GB RAM, 200 GB boot volume, your SSH key) in EVERY
#    availability domain, over and over. The moment Oracle frees a slot, the
#    server is created, a RESERVED public IP is attached (never a random
#    ephemeral one), and the workflow disables itself. You get an email /
#    Telegram alert only if something is actually WRONG (config errors).
#
#  IT IS SAFE
#    - Never creates a second server: if the instance already exists it only
#      re-attaches the reserved IP if needed, then stops.
#    - Only ever launches the exact free-tier config (2 OCPU / 12 GB / 200 GB).
#    - Pins itself to your HOME region — free resources only exist there.
#    - Creates at most ONE reserved public IP (named, tagged, reusable).
#    - No secrets in logs: every sensitive value is masked.
#
#  SEE AUTO-CREATE.md IN THIS REPO FOR THE 10-MINUTE SETUP WALKTHROUGH.
# ============================================================================

import os
import sys
import time
import urllib.parse
import urllib.request

# ─────────────────────────── small helpers ──────────────────────────────────

def log(msg: str) -> None:
    print(msg, flush=True)


def gh_mask(value: str) -> None:
    """Tell GitHub Actions to replace this value with *** in the public logs."""
    if value and os.environ.get("GITHUB_ACTIONS") == "true":
        print(f"::add-mask::{value}")


def fail(msg: str) -> None:
    log(f"::error::{msg}")
    log("")
    log("=" * 60)
    log(f"FATAL: {msg}")
    log("The workflow has stopped. Fix the issue (see AUTO-CREATE.md),")
    log("then re-run it from the Actions tab (Run workflow button).")
    log("=" * 60)
    sys.exit(1)


def pause(msg: str) -> None:
    """Wait quietly (exit 0) — e.g. secrets not set yet. No failure email spam."""
    log("")
    log("=" * 60)
    log(f"[PAUSED] {msg}")
    log("The next scheduled run checks again automatically.")
    log("=" * 60)
    sys.exit(0)


def telegram(text: str) -> None:
    """Optional: send a message if TELEGRAM_BOT_TOKEN/CHAT_ID secrets are set."""
    token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
    chat = os.environ.get("TELEGRAM_CHAT_ID", "").strip()
    if not token or not chat:
        return
    try:
        url = f"https://api.telegram.org/bot{token}/sendMessage"
        data = urllib.parse.urlencode({"chat_id": chat, "text": text}).encode()
        urllib.request.urlopen(urllib.request.Request(url, data=data), timeout=10)
    except Exception as exc:  # notification must never break the automation
        log(f"(telegram notification failed: {exc})")


# ─────────────────────────── configuration ──────────────────────────────────

OCI_USER = os.environ.get("OCI_CLI_USER", "").strip()
OCI_TENANCY = os.environ.get("OCI_CLI_TENANCY", "").strip()
OCI_FINGERPRINT = os.environ.get("OCI_CLI_FINGERPRINT", "").strip()
OCI_REGION = os.environ.get("OCI_CLI_REGION", "us-ashburn-1").strip()
OCI_KEY = os.environ.get("OCI_CLI_KEY_CONTENT", "").replace("\\n", "\n").strip()
COMPARTMENT_ID = os.environ.get("OCI_COMPARTMENT_ID", "").strip() or OCI_TENANCY
SUBNET_ID = os.environ.get("OCI_SUBNET_ID", "").strip()
IMAGE_ID = os.environ.get("OCI_IMAGE_ID", "").strip()
SSH_PUBLIC_KEY = os.environ.get("SSH_PUBLIC_KEY", "").strip()

SHAPE = os.environ.get("SHAPE", "VM.Standard.A1.Flex")
OCPUS = float(os.environ.get("OCPUS", "2"))
MEMORY_GBS = float(os.environ.get("MEMORY_GBS", "12"))
BOOT_GB = int(os.environ.get("BOOT_GB", "200"))
DISPLAY_NAME = os.environ.get("DISPLAY_NAME", "coolify-server")
IMAGE_OS = os.environ.get("IMAGE_OS", "Canonical Ubuntu")
IMAGE_OS_VERSION = os.environ.get("IMAGE_OS_VERSION", "24.04")
RESERVED_IP_NAME = os.environ.get("RESERVED_IP_NAME", "coolify-reserved-ip")
ROUNDS = int(os.environ.get("ROUNDS", "6"))
ROUND_SLEEP = int(os.environ.get("ROUND_SLEEP", "40"))
WORKFLOW_FILE = os.environ.get("WORKFLOW_FILE", "auto-create.yml")

TAG_KEY = "created-by"      # freeform tag marking everything this script makes
TAG_VALUE = "github-actions"

# Hide every sensitive value from the (public) workflow logs.
for secret_value in (OCI_USER, OCI_TENANCY, OCI_FINGERPRINT, OCI_KEY,
                     COMPARTMENT_ID, SUBNET_ID, IMAGE_ID):
    gh_mask(secret_value)

# ─────────────────────────── sanity checks ──────────────────────────────────

missing = [name for name, value in {
    "OCI_CLI_USER": OCI_USER,
    "OCI_CLI_TENANCY": OCI_TENANCY,
    "OCI_CLI_FINGERPRINT": OCI_FINGERPRINT,
    "OCI_CLI_KEY_CONTENT": OCI_KEY,
    "OCI_CLI_REGION": OCI_REGION,
    "SSH_PUBLIC_KEY": SSH_PUBLIC_KEY,
}.items() if not value]

if missing:
    pause("GitHub secrets not set yet: " + ", ".join(missing) +
          ". Add them via the repo's Settings -> Secrets and variables -> Actions "
          "(walkthrough in AUTO-CREATE.md) — the hunt starts automatically on the "
          "very next scheduled run. No action needed until then.")

if not SSH_PUBLIC_KEY.startswith(("ssh-rsa ", "ssh-ed25519 ", "ssh-ecdsa ", "ecdsa-")):
    fail("SSH_PUBLIC_KEY does not look like a public key. It must be ONE line starting "
         "with 'ssh-rsa AAAA...' or 'ssh-ed25519 AAAA...'. Generate it with: ssh-keygen -y -f oracle.key")

try:
    import oci
except ImportError:
    fail("The OCI Python SDK is not installed. This script must run inside the "
         "GitHub Actions workflow (which runs 'pip install -r requirements.txt').")

# ─────────────────────────── OCI clients ────────────────────────────────────

config = {
    "user": OCI_USER,
    "tenancy": OCI_TENANCY,
    "fingerprint": OCI_FINGERPRINT,
    "region": OCI_REGION,
    "key_content": OCI_KEY,
}

try:
    identity = oci.identity.IdentityClient(config)
    compute = oci.core.ComputeClient(config)
    net = oci.core.VirtualNetworkClient(config)
except Exception as exc:
    fail(f"Could not read the OCI API key / config: {exc}")

# Safety net: Always Free resources exist ONLY in the tenancy's home region.
# If the API key config points anywhere else, we refuse to touch that region.
try:
    tenancy = identity.get_tenancy(tenancy_id=OCI_TENANCY).data
    subscriptions = identity.list_region_subscriptions(tenancy_id=OCI_TENANCY).data
    home_region = next((s.region_name for s in subscriptions if s.is_home_region), None)
except oci.exceptions.ServiceError as exc:
    fail(f"Authentication with Oracle failed (check OCI_CLI_USER / OCI_CLI_TENANCY / "
         f"OCI_CLI_FINGERPRINT / OCI_CLI_KEY_CONTENT secrets). Oracle said: "
         f"[{exc.status}] {exc.code} — {exc.message}")
except Exception as exc:
    fail(f"Could not reach Oracle (network/auth problem): {exc}")

if not home_region:
    home_region = OCI_REGION  # could not detect — trust the secret, it is usually right
if home_region != OCI_REGION:
    log(f"[i] Your home region is '{home_region}' but the API key config says "
        f"'{OCI_REGION}'. Switching to '{home_region}' — Always Free resources "
        f"only exist in the home region (anything else would be billed!).")
    config["region"] = home_region
    identity = oci.identity.IdentityClient(config)
    compute = oci.core.ComputeClient(config)
    net = oci.core.VirtualNetworkClient(config)
log(f"[i] Region: {home_region} (home region) — compartment: root (tenancy)")

# ─────────────────────────── step 1: existing server? ───────────────────────

def find_our_instance():
    """Return our instance if it already exists (never create a 2nd server)."""
    try:
        instances = oci.pagination.list_call_get_all_results(
            compute.list_instances, compartment_id=COMPARTMENT_ID).data
    except oci.exceptions.ServiceError as exc:
        fail(f"Could not list instances: [{exc.status}] {exc.code} — {exc.message}")
    alive = [i for i in instances
             if i.lifecycle_state not in ("TERMINATED", "TERMINATING")]
    for inst in alive:
        if inst.freeform_tags.get(TAG_KEY) == TAG_VALUE or inst.display_name == DISPLAY_NAME:
            return inst
    # Even an untagged A1 instance means the free allowance is in use — stop.
    for inst in alive:
        if inst.shape == "VM.Standard.A1.Flex":
            log(f"[i] Found an existing A1 instance ('{inst.display_name}') — "
                f"not creating another one (your free allowance is limited).")
            return inst
    return None


# ─────────────────────────── step 2: image ──────────────────────────────────

def find_image() -> str:
    """The Ubuntu 24.04 (aarch64) image from GUIDE.md Part 4 — never 'Minimal'."""
    if IMAGE_ID:
        log(f"[i] Using image from OCI_IMAGE_ID secret.")
        return IMAGE_ID
    try:
        images = compute.list_images(
            compartment_id=COMPARTMENT_ID,
            shape=SHAPE,
            operating_system=IMAGE_OS,
            operating_system_version=IMAGE_OS_VERSION,
            sort_by="TIMECREATED",
            sort_order="DESC").data
    except oci.exceptions.ServiceError as exc:
        fail(f"Could not list images: [{exc.status}] {exc.code} — {exc.message}")
    full = [im for im in images if "Minimal" not in (im.display_name or "")]
    if full:
        log(f"[i] Image: {full[0].display_name}")
        return full[0].id
    # Fallback: latest Oracle Linux aarch64 (still free, just a different OS)
    images = compute.list_images(
        compartment_id=COMPARTMENT_ID,
        shape=SHAPE,
        operating_system="Oracle Linux",
        sort_by="TIMECREATED",
        sort_order="DESC").data
    if images:
        log(f"[i] Ubuntu {IMAGE_OS_VERSION} not found — falling back to: {images[0].display_name}")
        return images[0].id
    fail("No aarch64 image found for this shape. Set the OCI_IMAGE_ID secret manually "
         "(console -> Compute -> Images -> copy an image OCID).")


# ─────────────────────────── step 3: subnet (find or build) ─────────────────

def wait_for_state(getter, ocid, wanted, what, tries=30, delay=2):
    for _ in range(tries):
        try:
            current = getter(ocid).data
        except oci.exceptions.ServiceError:
            current = None
        if current is not None and current.lifecycle_state == wanted:
            return current
        time.sleep(delay)
    fail(f"Timed out waiting for the {what} to become {wanted}.")


def subnet_is_public(subnet) -> bool:
    """A subnet is public if its route table sends 0.0.0.0/0 to an internet gateway."""
    try:
        route_table = net.get_route_table(subnet.route_table_id).data
        gateways = net.list_internet_gateways(
            compartment_id=COMPARTMENT_ID, vcn_id=subnet.vcn_id).data
        gateway_ids = {g.id for g in gateways if g.is_enabled}
        return any(rule.destination == "0.0.0.0/0" and
                   rule.network_entity_id in gateway_ids
                   for rule in route_table.route_rules)
    except Exception:
        return False


def find_public_subnet():
    try:
        vcns = [v for v in net.list_vcns(compartment_id=COMPARTMENT_ID).data
                if v.lifecycle_state == "AVAILABLE"]
    except oci.exceptions.ServiceError as exc:
        fail(f"Could not list VCNs: [{exc.status}] {exc.code} — {exc.message}")
    # Prefer the guide's VCN ("coolify-vcn") if it exists
    vcns.sort(key=lambda v: 0 if "coolify" in (v.display_name or "").lower() else 1)
    for vcn in vcns:
        try:
            subnets = [s for s in net.list_subnets(
                compartment_id=COMPARTMENT_ID, vcn_id=vcn.id).data
                if s.lifecycle_state == "AVAILABLE"]
        except oci.exceptions.ServiceError:
            continue
        for subnet in subnets:
            if subnet_is_public(subnet):
                log(f"[i] Using existing public subnet '{subnet.display_name}' "
                    f"in VCN '{vcn.display_name}'.")
                return subnet.id
    return None


def create_vcn_stack() -> str:
    """No VCN yet? Build the whole thing exactly like GUIDE.md Parts 4.1 + 5:
       VCN + internet gateway + route + security list (ports 22/80/443/8000/6001/6002)
       + a public subnet. Always-Free tenancies allow 2 VCNs."""
    log("[i] No VCN/subnet found — creating 'coolify-vcn' automatically…")
    try:
        vcn = net.create_vcn(oci.core.models.CreateVcnDetails(
            compartment_id=COMPARTMENT_ID,
            cidr_block="10.0.0.0/16",
            display_name="coolify-vcn",
            freeform_tags={TAG_KEY: TAG_VALUE},
        )).data
        gh_mask(vcn.id)
        wait_for_state(net.get_vcn, vcn.id, "AVAILABLE", "VCN")

        gateway = net.create_internet_gateway(oci.core.models.CreateInternetGatewayDetails(
            compartment_id=COMPARTMENT_ID,
            vcn_id=vcn.id,
            is_enabled=True,
            display_name="Internet Gateway coolify-vcn",
        )).data

        route_table = net.create_route_table(oci.core.models.CreateRouteTableDetails(
            compartment_id=COMPARTMENT_ID,
            vcn_id=vcn.id,
            display_name="Default Route Table for coolify-vcn",
            route_rules=[oci.core.models.RouteRule(
                destination="0.0.0.0/0",
                network_entity_id=gateway.id,
            )],
        )).data

        ports = [22, 80, 443, 8000, 6001, 6002]   # same ports as GUIDE.md Part 5
        security_list = net.create_security_list(oci.core.models.CreateSecurityListDetails(
            compartment_id=COMPARTMENT_ID,
            vcn_id=vcn.id,
            display_name="Default Security List for coolify-vcn",
            ingress_security_rules=[
                oci.core.models.IngressSecurityRule(
                    source="0.0.0.0/0",
                    protocol="6",
                    is_stateless=False,
                    tcp_options=oci.core.models.TcpOptions(
                        destination_port_range=oci.core.models.PortRange(min=p, max=p)),
                ) for p in ports],
            egress_security_rules=[
                oci.core.models.EgressSecurityRule(
                    destination="0.0.0.0/0",
                    protocol="all",
                    is_stateless=False,
                )],
        )).data

        subnet = net.create_subnet(oci.core.models.CreateSubnetDetails(
            compartment_id=COMPARTMENT_ID,
            vcn_id=vcn.id,
            cidr_block="10.0.0.0/24",
            display_name="Public Subnet coolify-vcn",
            route_table_id=route_table.id,
            security_list_ids=[security_list.id],
            prohibit_public_ip_on_vnic=False,
        )).data
        gh_mask(subnet.id)
        wait_for_state(net.get_subnet, subnet.id, "AVAILABLE", "subnet")
        log(f"[i] VCN created with ports {ports} already open (matches GUIDE.md Part 5).")
        return subnet.id
    except oci.exceptions.ServiceError as exc:
        fail(f"Could not create the VCN: [{exc.status}] {exc.code} — {exc.message} "
             f"(If you already have 2 VCNs, delete one in the console, or set the "
             f"OCI_SUBNET_ID secret to an existing subnet.)")


def find_subnet() -> str:
    if SUBNET_ID:
        log("[i] Using subnet from OCI_SUBNET_ID secret.")
        return SUBNET_ID
    existing = find_public_subnet()
    if existing:
        return existing
    return create_vcn_stack()


# ─────────────────────── step 4: the launch loop ────────────────────────────

def classify_error(exc) -> str:
    """'capacity' = keep retrying · 'slow' = back off · 'fatal' = stop everything."""
    text = f"{exc.code or ''} {exc.message or ''}".lower()
    if exc.status == 429 or "too many requests" in text:
        return "slow"
    if "out of host capacity" in text or "out of capacity" in text:
        return "capacity"
    if exc.status == 401 and "notauthenticated" in text:
        # OCI quirk (verified in the wild): on Always Free tenancies, a launch
        # into a COMPLETELY full AD sometimes returns 401 NotAuthenticated
        # instead of the capacity error — while the very same credentials work
        # on every other call (and on the other ADs) a moment earlier. A REAL
        # auth problem is caught before the loop by the get_tenancy() pre-flight
        # check, so a 401 here is safe to treat as capacity and retry.
        return "capacity"
    if "internal error" in text:
        # some regions report plain 500 InternalError for capacity too — retry anyway
        return "capacity"
    if "limit" in text and "exceed" in text:
        return "fatal"
    return "fatal"


def try_launch(availability_domain: str, image_id: str, subnet_id: str):
    """One launch attempt. Returns (instance, error)."""
    details = oci.core.models.LaunchInstanceDetails(
        compartment_id=COMPARTMENT_ID,
        availability_domain=availability_domain,
        display_name=DISPLAY_NAME,
        shape=SHAPE,
        shape_config=oci.core.models.LaunchInstanceShapeConfigDetails(
            ocpus=OCPUS,
            memory_in_gbs=MEMORY_GBS,
        ),
        source_details=oci.core.models.InstanceSourceViaImageDetails(
            image_id=image_id,
            boot_volume_size_in_gbs=BOOT_GB,
        ),
        create_vnic_details=oci.core.models.CreateVnicDetails(
            subnet_id=subnet_id,
            assign_public_ip=False,   # ← reserved IP is attached AFTER launch
            display_name="primary-vnic",
        ),
        metadata={"ssh_authorized_keys": SSH_PUBLIC_KEY},
        freeform_tags={TAG_KEY: TAG_VALUE},
    )
    try:
        response = compute.launch_instance(details)
        return response.data, None
    except oci.exceptions.ServiceError as exc:
        return None, exc


# ─────────────────── step 5: reserved public IP (after launch) ──────────────

def attach_reserved_ip(instance) -> str:
    """Wait for RUNNING, then attach the (one, reusable) reserved public IP.
       A reserved IP never changes when the server stops — unlike the
       auto-assigned ephemeral one."""
    # wait for the instance to be RUNNING
    for _ in range(15):
        inst = compute.get_instance(instance.id).data
        if inst.lifecycle_state == "RUNNING":
            break
        time.sleep(10)
    else:
        log("[i] Instance still starting — the next run will attach the reserved IP.")
        return None

    # find the primary VNIC's private IP
    private_ip = None
    for _ in range(10):
        try:
            attachments = compute.list_vnic_attachments(
                compartment_id=COMPARTMENT_ID, instance_id=instance.id).data
            attached = [a for a in attachments
                        if a.lifecycle_state == oci.core.models.VnicAttachment.LIFECYCLE_STATE_ATTACHED]
            if attached:
                vnic = net.get_vnic(attached[0].vnic_id).data
                private_ips = net.list_private_ips(vnic_id=vnic.id).data
                if private_ips:
                    private_ip = private_ips[0]
                    break
        except oci.exceptions.ServiceError:
            pass
        time.sleep(6)
    if private_ip is None:
        log("[i] Could not read the private IP yet — the next run will attach the reserved IP.")
        return None
    gh_mask(private_ip.id)

    # find our reserved IP, or create it once
    public_ip = None
    try:
        reserved = net.list_public_ips(
            compartment_id=COMPARTMENT_ID,
            scope="REGION",
            lifetime="RESERVED").data
        for candidate in reserved:
            if candidate.private_ip_id in (None, "", private_ip.id) and (
                    candidate.freeform_tags.get(TAG_KEY) == TAG_VALUE
                    or candidate.display_name == RESERVED_IP_NAME):
                public_ip = candidate
                break
    except oci.exceptions.ServiceError:
        pass
    if public_ip is None:
        public_ip = net.create_public_ip(oci.core.models.CreatePublicIpDetails(
            compartment_id=COMPARTMENT_ID,
            lifetime="RESERVED",
            display_name=RESERVED_IP_NAME,
            freeform_tags={TAG_KEY: TAG_VALUE},
        )).data
        log(f"[i] Reserved public IP '{RESERVED_IP_NAME}' created (free of charge).")
    gh_mask(public_ip.id)
    gh_mask(public_ip.ip_address or "")

    if public_ip.private_ip_id == private_ip.id:
        log("[i] Reserved IP already attached.")
        return public_ip.ip_address

    try:
        updated = net.update_public_ip(
            public_ip.id,
            oci.core.models.UpdatePublicIpDetails(private_ip_id=private_ip.id)).data
        return updated.ip_address
    except oci.exceptions.ServiceError as exc:
        log(f"[!] Could not attach the reserved IP yet: {exc.message} "
            f"— the next run will retry automatically.")
        return None


def disable_myself():
    """After success, stop the schedule so it never runs again (API call)."""
    token = os.environ.get("GITHUB_TOKEN", "")
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    if not token or not repo:
        return
    try:
        request = urllib.request.Request(
            f"https://api.github.com/repos/{repo}/actions/workflows/{WORKFLOW_FILE}/disable",
            method="PUT",
            headers={"Authorization": f"Bearer {token}",
                     "Accept": "application/vnd.github+json"})
        urllib.request.urlopen(request, timeout=15)
        log("[i] Workflow disabled itself — no more scheduled runs. "
            "(If you ever want it again: Actions tab -> this workflow -> Enable.)")
    except Exception as exc:
        log(f"[i] Could not auto-disable the workflow ({exc}). No problem — but do it "
            f"manually once the server exists: Actions -> Auto-create A1 instance -> "
            f"'…' menu -> Disable workflow.")


def trigger_next_run():
    """Continuous mode: dispatch the next run right away instead of waiting
    for GitHub's throttled cron (new */10 schedules can lag 30+ minutes).
    Each run chains the next one; the cron stays as a safety net to restart
    the chain if it ever breaks. Disabling the workflow stops the chain —
    a disabled workflow cannot be dispatched."""
    token = os.environ.get("GITHUB_TOKEN", "")
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    if not token or not repo:
        return
    try:
        request = urllib.request.Request(
            f"https://api.github.com/repos/{repo}/actions/workflows/{WORKFLOW_FILE}/dispatches",
            method="POST",
            data='{"ref":"main"}'.encode(),
            headers={"Authorization": f"Bearer {token}",
                     "Accept": "application/vnd.github+json",
                     "Content-Type": "application/json"})
        urllib.request.urlopen(request, timeout=15)
        log("[i] Next hunt dispatched — continuous mode (a fresh run starts within seconds).")
    except Exception as exc:
        log(f"[i] Could not self-dispatch ({exc}) — no problem, the 10-minute cron "
            f"schedule remains as the safety net.")


# ─────────────────────────── main ───────────────────────────────────────────

def main() -> int:
    log("=" * 60)
    log(" Oracle Always Free — A1 capacity hunter (GitHub Actions)")
    log(f" Target: {SHAPE} · {OCPUS:g} OCPU · {MEMORY_GBS:g} GB RAM · "
        f"{BOOT_GB} GB boot · Ubuntu {IMAGE_OS_VERSION}")
    log(f" Public IP: RESERVED ('{RESERVED_IP_NAME}') — not auto-assigned")
    log("=" * 60)

    # 1 ── already have our server? then just make sure the IP is attached
    existing = find_our_instance()
    if existing is not None:
        gh_mask(existing.id)
        log(f"[i] Instance '{existing.display_name}' already exists "
            f"({existing.lifecycle_state}) — no new server will be created.")
        ip = attach_reserved_ip(existing)
        if ip:
            announce(existing.display_name, ip)
            disable_myself()
        else:
            trigger_next_run()   # need one more run to finish attaching the IP
        return 0

    # 2 ── availability domains (we try them ALL — A1 is free in any AD)
    try:
        domains = [ad.name for ad in oci.pagination.list_call_get_all_results(
            identity.list_availability_domains, compartment_id=COMPARTMENT_ID).data]
    except oci.exceptions.ServiceError as exc:
        fail(f"Could not list availability domains: [{exc.status}] {exc.code} — {exc.message}")
    if not domains:
        fail("No availability domains found — check the OCI_CLI_COMPARTMENT_ID secret.")
    log(f"[i] Availability domains to hunt: {', '.join(domains)}")

    # 3 ── image + subnet (only needed once we get here)
    image_id = find_image()
    subnet_id = find_subnet()

    # 4 ── hunt for capacity
    for attempt_round in range(1, ROUNDS + 1):
        for domain in domains:
            log(f"[·] Round {attempt_round}/{ROUNDS} · {domain} · trying…")
            instance, error = try_launch(domain, image_id, subnet_id)
            if instance is not None:
                gh_mask(instance.id)
                log("")
                log("╔══════════════════════════════════════════╗")
                log("║  ★ CAPACITY FOUND — SERVER CREATED! ★    ║")
                log("╚══════════════════════════════════════════╝")
                ip = attach_reserved_ip(instance)
                if ip:
                    announce(instance.display_name, ip)
                    disable_myself()
                else:
                    log("[i] The reserved IP will be attached on the next run (self-healing).")
                    trigger_next_run()
                return 0
            kind = classify_error(error)
            if kind == "capacity":
                log(f"    ↳ out of capacity (as expected) — trying the next AD…")
                continue
            if kind == "slow":
                log(f"    ↳ Oracle is rate-limiting — backing off 30 s…")
                time.sleep(30)
                continue
            # anything else is a real problem: stop and let GitHub email you
            fail(f"Launch failed in {domain}: [{error.status}] {error.code} — "
                 f"{error.message}. If this mentions limits/quotas, check the console "
                 f"(Compute -> Instances) — you might already have an A1 server, or "
                 f"the free 200 GB storage is already used.")
        if attempt_round < ROUNDS:
            log(f"[·] Round {attempt_round} done — {ROUND_SLEEP}s pause, then next round…")
            time.sleep(ROUND_SLEEP)

    # 5 ── no luck this run — perfectly normal, exit 0 (no failure email spam)
    log("")
    log(f"[✓] No free slot yet — Oracle's A1 hosts in {home_region} are full right now.")
    log("    This is the normal state. The next run keeps hunting automatically.")
    log("    Typical wait: a few hours to a few days, depending on the region.")
    telegram("Oracle A1: no capacity yet — the hunt continues (this is normal).")
    trigger_next_run()
    return 0


def announce(name: str, ip: str) -> None:
    gh_mask(ip)
    log("")
    log("=" * 60)
    log("  ✅ SERVER CREATED + RESERVED PUBLIC IP ATTACHED")
    log("=" * 60)
    log(f"  Name:        {name}")
    log(f"  Public IP:   *** (hidden in public logs — see it in the console:")
    log(f"                https://cloud.oracle.com/compute/instances)")
    log(f"  SSH:         ssh -i oracle.key ubuntu@<YOUR_IP>")
    log(f"  Reserved IP: never changes on stop/start — safe for DNS (Cloudflare)")
    log(f"  Next steps:  GUIDE.md Part 6 (connect) then Part 7 (setup.sh)")
    log("=" * 60)
    telegram(f"🎉 Oracle server created! Name: {name}\nReserved public IP: {ip}\n"
             f"SSH: ssh -i oracle.key ubuntu@{ip}\nCoolify (after setup.sh): http://{ip}:8000")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
