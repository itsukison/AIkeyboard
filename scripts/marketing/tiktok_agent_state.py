#!/usr/bin/env python3
import argparse
import fcntl
import json
import statistics
from contextlib import contextmanager
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = ROOT / "docs/marketing/automation/config.json"
DEFAULT_STATE = ROOT / "docs/marketing/automation/state.json"


def parse_time(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise SystemExit("timestamps must include a UTC offset")
    return parsed


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def write_state(path: Path, state: dict) -> None:
    state["updatedAt"] = datetime.now().astimezone().isoformat(timespec="seconds")
    temporary = path.with_suffix(".tmp")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(state, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    temporary.replace(path)


@contextmanager
def state_lock(path: Path):
    lock_path = path.with_suffix(".lock")
    with lock_path.open("w") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def find_post(state: dict, buffer_id: str) -> Optional[dict]:
    return next((post for post in state["posts"] if post["bufferPostId"] == buffer_id), None)


def next_slots(config: dict, state: dict, now: datetime, count: int) -> list[str]:
    timezone = ZoneInfo(config["timezone"])
    local_now = now.astimezone(timezone)
    occupied = {
        parse_time(post["dueAt"]).astimezone(timezone).replace(second=0, microsecond=0)
        for post in state["posts"]
        if post.get("dueAt") and post.get("status") in {"scheduled", "sending", "sent"}
    }
    result = []
    day = local_now.date()
    while len(result) < count:
        for slot in config["postingSlots"]:
            hour, minute = map(int, slot.split(":"))
            candidate = datetime(day.year, day.month, day.day, hour, minute, tzinfo=timezone)
            if candidate <= local_now or candidate in occupied:
                continue
            result.append(candidate.isoformat(timespec="minutes"))
            if len(result) == count:
                break
        day += timedelta(days=1)
    return result


def command_next_slots(args: argparse.Namespace, config: dict, state: dict) -> None:
    now = parse_time(args.now) if args.now else datetime.now().astimezone()
    count = args.count if args.count is not None else config["targetScheduledPosts"]
    print(json.dumps(next_slots(config, state, now, count), ensure_ascii=False, indent=2))


def command_record_post(args: argparse.Namespace, config: dict, state: dict, state_path: Path) -> None:
    existing = find_post(state, args.buffer_id)
    duplicate = next((
        post for post in state["posts"]
        if post.get("contentSha256") == args.content_sha256
        and post.get("bufferPostId") != args.buffer_id
        and post.get("status") in {"scheduled", "sending", "sent"}
    ), None)
    if duplicate:
        raise SystemExit(f"content hash already used by Buffer post {duplicate['bufferPostId']}")
    if args.slot not in config["postingSlots"]:
        raise SystemExit(f"slot must be one of {config['postingSlots']}")
    due = parse_time(args.due_at).astimezone(ZoneInfo(config["timezone"]))
    if existing is None:
        posts_on_day = [
            post for post in state["posts"]
            if post.get("dueAt")
            and post.get("status") in {"scheduled", "sending", "sent"}
            and parse_time(post["dueAt"]).astimezone(ZoneInfo(config["timezone"])).date() == due.date()
        ]
        if len(posts_on_day) >= config["publishing"]["maxPostsPerDay"]:
            raise SystemExit("daily posting limit reached")
        scheduled_count = sum(
            1 for post in state["posts"] if post.get("status") in {"scheduled", "sending"}
        )
        if scheduled_count >= config["bufferScheduledPostLimit"]:
            raise SystemExit("Buffer scheduled-post limit reached")
    record = existing or {"bufferPostId": args.buffer_id, "metricsSnapshots": []}
    record.update({
        "episode": args.episode,
        "contentSha256": args.content_sha256,
        "dueAt": due.isoformat(timespec="seconds"),
        "status": args.status,
        "slot": args.slot,
        "allocation": args.allocation,
        "hypothesis": args.hypothesis,
    })
    if existing is None:
        state["posts"].append(record)
    write_state(state_path, state)
    print(json.dumps(record, ensure_ascii=False, indent=2))


def command_set_status(args: argparse.Namespace, state: dict, state_path: Path) -> None:
    post = find_post(state, args.buffer_id)
    if post is None:
        raise SystemExit(f"unknown Buffer post: {args.buffer_id}")
    post["status"] = args.status
    if args.external_link:
        post["externalLink"] = args.external_link
    if args.sent_at:
        post["sentAt"] = parse_time(args.sent_at).isoformat(timespec="seconds")
    if args.error:
        post["error"] = args.error
    write_state(state_path, state)
    print(json.dumps(post, ensure_ascii=False, indent=2))


def command_record_metrics(args: argparse.Namespace, state: dict, state_path: Path) -> None:
    post = find_post(state, args.buffer_id)
    if post is None:
        raise SystemExit(f"unknown Buffer post: {args.buffer_id}")
    metrics = json.loads(args.metrics)
    if not isinstance(metrics, dict):
        raise SystemExit("metrics must be a JSON object")
    snapshot = {
        "windowHours": args.window_hours,
        "capturedAt": parse_time(args.captured_at).isoformat(timespec="seconds"),
        "metricsUpdatedAt": parse_time(args.metrics_updated_at).isoformat(timespec="seconds") if args.metrics_updated_at else None,
        "metrics": metrics,
    }
    snapshots = post.setdefault("metricsSnapshots", [])
    existing = next((item for item in snapshots if item["windowHours"] == args.window_hours), None)
    if existing:
        existing.update(snapshot)
    else:
        snapshots.append(snapshot)
        snapshots.sort(key=lambda item: item["windowHours"])
    write_state(state_path, state)
    print(json.dumps(snapshot, ensure_ascii=False, indent=2))


def command_due_snapshots(args: argparse.Namespace, config: dict, state: dict) -> None:
    now = parse_time(args.now) if args.now else datetime.now().astimezone()
    due = []
    for post in state["posts"]:
        origin = post.get("sentAt") or post.get("dueAt")
        if not origin or post.get("status") not in {"sent", "sending"}:
            continue
        age = (now - parse_time(origin)).total_seconds() / 3600
        captured = {snapshot["windowHours"] for snapshot in post.get("metricsSnapshots", [])}
        for window in config["snapshotWindowsHours"]:
            if window <= age <= window + config["snapshotToleranceHours"] and window not in captured:
                due.append({"bufferPostId": post["bufferPostId"], "windowHours": window, "ageHours": round(age, 1)})
    print(json.dumps(due, ensure_ascii=False, indent=2))


def command_analyze(args: argparse.Namespace, config: dict, state: dict) -> None:
    window = args.window_hours
    rows = []
    for post in state["posts"]:
        snapshot = next((item for item in post.get("metricsSnapshots", []) if item["windowHours"] == window), None)
        if snapshot and isinstance(snapshot["metrics"].get("views"), (int, float)):
            rows.append((post, snapshot["metrics"]))
    if not rows:
        print(json.dumps({"windowHours": window, "sampleSize": 0}, indent=2))
        return
    median_views = statistics.median(metrics["views"] for _, metrics in rows)
    engagement_values = [
        metrics["engagementRate"]
        for _, metrics in rows
        if isinstance(metrics.get("engagementRate"), (int, float))
    ]
    median_engagement = statistics.median(engagement_values) if engagement_values else None
    winners = []
    for post, metrics in rows:
        view_multiple = metrics["views"] / median_views if median_views else 0
        engagement_ok = (
            median_engagement is None
            or metrics.get("engagementRate") is None
            or metrics["engagementRate"] >= median_engagement * config["experiments"]["winnerEngagementFloorRatio"]
        )
        if view_multiple >= config["experiments"]["winnerViewMultiple"]:
            winners.append({
                "bufferPostId": post["bufferPostId"],
                "episode": post["episode"],
                "viewMultiple": round(view_multiple, 2),
                "qualifiedEngagementFloorPassed": engagement_ok,
            })
    slot_counts = {
        slot: sum(1 for post, _ in rows if post.get("slot") == slot)
        for slot in config["postingSlots"]
    }
    result = {
        "windowHours": window,
        "sampleSize": len(rows),
        "medianViews": median_views,
        "medianEngagementRate": median_engagement,
        "winners": winners,
        "slotCounts": slot_counts,
        "timingOptimizationReady": all(
            count >= config["experiments"]["minimumSamplesPerSlot"]
            for count in slot_counts.values()
        ),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--state", type=Path, default=DEFAULT_STATE)
    commands = parser.add_subparsers(dest="command", required=True)

    slots = commands.add_parser("next-slots")
    slots.add_argument("--now")
    slots.add_argument("--count", type=int)

    record = commands.add_parser("record-post")
    record.add_argument("--buffer-id", required=True)
    record.add_argument("--episode", required=True)
    record.add_argument("--content-sha256", required=True)
    record.add_argument("--due-at", required=True)
    record.add_argument("--status", choices=["scheduled", "sending", "sent", "error"], required=True)
    record.add_argument("--slot", required=True)
    record.add_argument("--allocation", choices=["exploit", "explore"], required=True)
    record.add_argument("--hypothesis", required=True)

    status = commands.add_parser("set-status")
    status.add_argument("--buffer-id", required=True)
    status.add_argument("--status", choices=["scheduled", "sending", "sent", "error"], required=True)
    status.add_argument("--external-link")
    status.add_argument("--sent-at")
    status.add_argument("--error")

    metrics = commands.add_parser("record-metrics")
    metrics.add_argument("--buffer-id", required=True)
    metrics.add_argument("--window-hours", type=int, required=True)
    metrics.add_argument("--captured-at", required=True)
    metrics.add_argument("--metrics-updated-at")
    metrics.add_argument("--metrics", required=True)

    due = commands.add_parser("due-snapshots")
    due.add_argument("--now")

    analyze = commands.add_parser("analyze")
    analyze.add_argument("--window-hours", type=int, default=72)

    args = parser.parse_args()
    config = load_json(args.config.resolve())
    state_path = args.state.resolve()
    with state_lock(state_path):
        state = load_json(state_path)
        if args.command == "next-slots":
            if args.count is None:
                now = parse_time(args.now) if args.now else datetime.now().astimezone()
                scheduled = sum(
                    1 for post in state["posts"]
                    if post.get("status") in {"scheduled", "sending"}
                    and post.get("dueAt")
                    and parse_time(post["dueAt"]) > now
                )
                args.count = max(0, config["targetScheduledPosts"] - scheduled)
            command_next_slots(args, config, state)
        elif args.command == "record-post":
            command_record_post(args, config, state, state_path)
        elif args.command == "set-status":
            command_set_status(args, state, state_path)
        elif args.command == "record-metrics":
            command_record_metrics(args, state, state_path)
        elif args.command == "due-snapshots":
            command_due_snapshots(args, config, state)
        elif args.command == "analyze":
            command_analyze(args, config, state)


if __name__ == "__main__":
    main()
