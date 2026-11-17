#!/usr/bin/env python3
"""Re-read HighLevel message statuses a couple of minutes after sending. Read-only.

Why: HighLevel reports "sent" about 8 seconds after a send, and "failed" can arrive later.
A status read once, right after sending, misses those late failures.

Usage:
    export GHL_TOKEN=...            # a HighLevel private integration token. Never commit it.
    python3 scripts/recheck_status.py message-ids.txt     # one message id per line

Prints one line per message and exits 1 if any message is "failed".
"""
import json, os, sys, urllib.request, urllib.error

BASE = "https://services.leadconnectorhq.com"
token = os.environ.get("GHL_TOKEN")
if not token:
    sys.exit("Set GHL_TOKEN in the environment first. Do not put it in this file.")
if len(sys.argv) != 2:
    sys.exit(__doc__)

headers = {
    "Authorization": "Bearer " + token,
    "Version": "2021-07-28",
    "Accept": "application/json",
    # Without a browser-style User-Agent the API can answer 403 (Cloudflare 1010).
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) Chrome/130",
}

failed = 0
for mid in (l.strip() for l in open(sys.argv[1])):
    if not mid:
        continue
    req = urllib.request.Request(f"{BASE}/conversations/messages/{mid}", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            d = json.loads(r.read() or b"{}")
        m = d.get("message") or d
        status = m.get("status", "unknown")
        note = m.get("error") or ""
    except urllib.error.HTTPError as e:
        status, note = f"http {e.code}", ""
    if status == "failed":
        failed += 1
    print(f"{mid}  {status}  {note}".rstrip())

print(f"{failed} failed")
sys.exit(1 if failed else 0)
