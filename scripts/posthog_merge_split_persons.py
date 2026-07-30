#!/usr/bin/env python3
"""One-off fix for the PostHog person split (2026-07).

The container app identified users with UPPERCASE UUIDs (iOS uuidString)
while the edge function captures server-side events with the lowercase
Supabase user id, so every user exists as two PostHog persons. The app-side
fix (lowercased identify) landed in 699acf0 but only helps builds that ship
it; this script merges the split history with $merge_dangerously so both
distinct_ids resolve to one person — including future events from old builds.

Usage:
  export SUPABASE_SERVICE_ROLE_KEY=...   # Supabase dashboard > Settings > API
  python3 scripts/posthog_merge_split_persons.py --test 23fe6edc-c502-4053-850e-e84fc5119673
  python3 scripts/posthog_merge_split_persons.py --dry-run
  python3 scripts/posthog_merge_split_persons.py
"""

import json
import os
import sys
import time
import urllib.request

SUPABASE_URL = "https://eercsucvxnszqletxued.supabase.co"
POSTHOG_HOST = "https://us.i.posthog.com"
POSTHOG_TOKEN = "phc_rkuAvbqxdVqqG5jZuySrJq8CH4NrYG97Z2B7vv7GXhJw"
BATCH_SIZE = 200


def fetch_profile_ids(service_key: str) -> list[str]:
    ids, offset, page = [], 0, 1000
    while True:
        req = urllib.request.Request(
            f"{SUPABASE_URL}/rest/v1/profiles?select=id&order=id&limit={page}&offset={offset}",
            headers={"apikey": service_key, "Authorization": f"Bearer {service_key}"},
        )
        with urllib.request.urlopen(req) as resp:
            rows = json.load(resp)
        ids += [r["id"] for r in rows]
        if len(rows) < page:
            return ids
        offset += page


def send_merges(ids: list[str]) -> None:
    for i in range(0, len(ids), BATCH_SIZE):
        chunk = ids[i : i + BATCH_SIZE]
        payload = {
            "api_key": POSTHOG_TOKEN,
            "batch": [
                {
                    "event": "$merge_dangerously",
                    "distinct_id": uid.lower(),
                    "properties": {"alias": uid.upper()},
                }
                for uid in chunk
            ],
        }
        req = urllib.request.Request(
            f"{POSTHOG_HOST}/batch/",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req) as resp:
            if resp.status != 200:
                sys.exit(f"batch {i // BATCH_SIZE} failed: HTTP {resp.status}")
        print(f"sent {min(i + BATCH_SIZE, len(ids))}/{len(ids)}")
        time.sleep(0.5)


def main() -> None:
    if "--test" in sys.argv:
        uid = sys.argv[sys.argv.index("--test") + 1]
        send_merges([uid])
        print(f"test merge sent for {uid.lower()} <- {uid.upper()}")
        return

    if "--ids-file" in sys.argv:
        ids = []
        for path in sys.argv[sys.argv.index("--ids-file") + 1 :]:
            with open(path) as f:
                ids += [x.strip() for x in f.read().replace("\n", ",").split(",") if x.strip()]
        print(f"{len(ids)} ids loaded from files")
        send_merges(ids)
        print("done — merges are processed async; person counts settle within minutes")
        return

    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or sys.exit(
        "set SUPABASE_SERVICE_ROLE_KEY (Supabase dashboard > Settings > API)"
    )
    ids = fetch_profile_ids(key)
    print(f"{len(ids)} profiles fetched")
    if "--dry-run" in sys.argv:
        return
    send_merges(ids)
    print("done — merges are processed async; person counts settle within minutes")


if __name__ == "__main__":
    main()
