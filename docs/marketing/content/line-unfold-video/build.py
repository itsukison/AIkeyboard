#!/usr/bin/env python3
import argparse
import copy
import hashlib
import json
import re
import subprocess
import tempfile
import urllib.parse
from pathlib import Path
from typing import Optional

HERE = Path(__file__).resolve().parent
TEMPLATE = (HERE / "template/line-unfold.html").as_uri()
PRODUCT_TEMPLATE = (HERE.parent / "line-story/templates/product-ui/product-ui.html").as_uri()
WIDTH, HEIGHT = 1080, 1920
# A post lives at posts/<slug> or posts/<bank>/<slug>, so the two content banks
# (Saya anthology, yuri serial) keep physically separate trees and independent
# numbering.
SLUG = re.compile(r"^(?:[a-z0-9-]+/)?\d{3}-[a-z0-9-]+$")
BGM_DIR = HERE / "bgm"
DATING_TRACKS = {"dating.m4a", "dating2.m4a", "dating3.m4a"}
BGM_FADE = 1.5


def find_chrome() -> Path:
    shells = sorted(
        (Path.home() / "Library/Caches/ms-playwright").glob(
            "chromium_headless_shell-*/chrome-headless-shell-*/chrome-headless-shell"
        ),
        reverse=True,
    )
    if shells:
        return shells[0]
    return Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")


CHROME = find_chrome()


def fail(message: str) -> None:
    raise SystemExit(message)


# .bubble is max-width 620 with 28px side padding, so text has 564px before it
# wraps to a second line. Measured against the template's own font at 36px:
# full-width Japanese ~35px/char, ASCII ~18px. A wrapped bubble is legal (the
# template wraps since 2026-08-09) but usually reads better shortened.
BUBBLE_TEXT_WIDTH = 564


def estimate_width(text: str) -> int:
    return sum(18 if ord(ch) < 0x2E80 else 35 for ch in text)


def report_wraps(spec: dict) -> None:
    pages = spec.get("pages") or [{"messages": spec.get("messages", [])}]
    for page_index, page in enumerate(pages, 1):
        for message_index, message in enumerate(page.get("messages", []), 1):
            for line in message.get("text", "").split("\n"):
                if estimate_width(line) > BUBBLE_TEXT_WIDTH:
                    print(f"wraps to 2 lines: page {page_index} message {message_index} — {line}")


def validate(slug: str, spec: dict) -> None:
    if spec.get("version") not in {1, 2}:
        fail("post.json version must be 1 or 2")
    if not SLUG.fullmatch(slug) or spec.get("slug") != Path(slug).name:
        fail(f"invalid or mismatched slug: {slug}")
    if not isinstance(spec.get("duration"), (int, float)) or spec["duration"] <= 0:
        fail("duration must be positive")
    pages = spec.get("pages") if spec.get("version") == 2 else [{
        "duration": spec["duration"],
        "messages": spec.get("messages"),
    }]
    if not isinstance(pages, list) or not 1 <= len(pages) <= 4:
        fail("pages must contain between 1 and 4 items")
    for page_index, page in enumerate(pages, 1):
        if not isinstance(page.get("duration"), (int, float)) or page["duration"] <= 0:
            fail(f"page {page_index} duration must be positive")
        messages = page.get("messages")
        if not isinstance(messages, list) or not 1 <= len(messages) <= 12:
            fail(f"page {page_index} must contain between 1 and 12 messages")
        for message_index, message in enumerate(messages, 1):
            label = f"page {page_index} message {message_index}"
            if message.get("side") not in {"me", "other"}:
                fail(f"{label} has an invalid side")
            if not message.get("time"):
                fail(f"{label} requires a time")
            if message.get("type", "text") == "image":
                if not message.get("src"):
                    fail(f"{label} requires an image src")
                if not 200 <= message.get("width", 0) <= 620:
                    fail(f"{label} image width must be between 200 and 620")
                if not 150 <= message.get("height", 0) <= 600:
                    fail(f"{label} image height must be between 150 and 600")
            elif not message.get("text"):
                fail(f"{label} requires text")

    for index, asset in enumerate(spec.get("productAssets", []), 1):
        if asset.get("type") != "productResult":
            fail(f"product asset {index} has an invalid type")
        if not all(asset.get(key) for key in ("output", "command", "draft", "result")):
            fail(f"product asset {index} is incomplete")


def render_state(spec: dict, page: int, step: int, destination: Path) -> None:
    query = urllib.parse.urlencode({
        "spec": json.dumps(spec, ensure_ascii=False, separators=(",", ":")),
        "page": page,
        "step": step,
    })
    subprocess.run([
        str(CHROME),
        "--headless",
        "--disable-gpu",
        "--hide-scrollbars",
        "--allow-file-access-from-files",
        "--force-device-scale-factor=1",
        "--no-first-run",
        f"--window-size={WIDTH},{HEIGHT}",
        f"--screenshot={destination}",
        f"{TEMPLATE}?{query}",
    ], check=True, timeout=120, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def render_product_assets(spec: dict, post_dir: Path, output: Path) -> None:
    for index, asset in enumerate(spec.get("productAssets", []), 1):
        source = output / f"product-source-{index:02d}.png"
        destination = post_dir / asset["output"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        query = urllib.parse.urlencode({
            "state": "result",
            "format": "tiktok",
            "chat": "off",
            "command": asset["command"],
            "draft": asset["draft"],
            "result": asset["result"],
        })
        subprocess.run([
            str(CHROME),
            "--headless",
            "--disable-gpu",
            "--hide-scrollbars",
            "--allow-file-access-from-files",
            "--force-device-scale-factor=1",
            "--no-first-run",
            f"--window-size={WIDTH},{HEIGHT}",
            f"--screenshot={source}",
            f"{PRODUCT_TEMPLATE}?{query}",
        ], check=True, timeout=120, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # Default 1105 is where the composer sits with a single-line draft. A
        # longer draft wraps and pushes the composer up, so those assets lower
        # cropTop to keep the first line inside the frame.
        crop_top = asset.get("cropTop", 1105)
        subprocess.run([
            "ffmpeg", "-y", "-i", str(source),
            "-vf", f"crop={WIDTH}:{HEIGHT - crop_top}:0:{crop_top}",
            str(destination),
        ], check=True, timeout=120, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def pick_bgm(slug: str, spec: dict) -> Optional[Path]:
    pinned = spec.get("bgm")
    if pinned:
        if pinned not in DATING_TRACKS:
            fail(f"bgm must be one of {sorted(DATING_TRACKS)} — got {pinned}")
        track = BGM_DIR / pinned
        if not track.is_file():
            fail(f"missing bgm track: {track}")
        return track
    pool = sorted(p for p in BGM_DIR.glob("*") if p.name in DATING_TRACKS)
    if not pool:
        return None
    digest = hashlib.sha256(slug.encode("utf-8")).digest()
    return pool[int.from_bytes(digest[:8], "big") % len(pool)]


def mux_bgm(video: Path, track: Path, duration: float) -> None:
    fade_start = max(0.0, duration - BGM_FADE)
    mixed = video.with_name(f"{video.stem}-bgm{video.suffix}")
    subprocess.run([
        "ffmpeg", "-y",
        "-i", str(video),
        "-stream_loop", "-1", "-i", str(track),
        "-filter_complex",
        f"[1:a]atrim=0:{duration:.3f},asetpts=N/SR/TB,"
        f"loudnorm=I=-14:TP=-1.5:LRA=11,"
        f"afade=t=out:st={fade_start:.3f}:d={BGM_FADE},"
        f"aresample=48000[a]",
        "-map", "0:v", "-map", "[a]",
        "-c:v", "copy", "-c:a", "aac", "-b:a", "128k", "-ar", "48000",
        "-movflags", "+faststart", "-t", f"{duration:.3f}",
        str(mixed),
    ], check=True, timeout=180, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    mixed.replace(video)


def resolve_asset_uris(spec: dict, post_dir: Path) -> dict:
    resolved = copy.deepcopy(spec)
    pages = resolved.get("pages") or [{"messages": resolved["messages"]}]
    for page in pages:
        for message in page["messages"]:
            if message.get("type") == "image":
                asset = (post_dir / message["src"]).resolve()
                if not asset.is_file():
                    fail(f"missing image asset: {asset}")
                message["src"] = asset.as_uri()
    return resolved


def build(slug: str) -> None:
    if not CHROME.is_file():
        fail(f"Chrome not found: {CHROME}")
    post_dir = HERE / "posts" / slug
    manifest = post_dir / "post.json"
    if not manifest.is_file():
        fail(f"unknown post: {slug}")
    spec = json.loads(manifest.read_text(encoding="utf-8"))
    validate(slug, spec)

    output = post_dir / "render"
    states = output / "states"
    states.mkdir(parents=True, exist_ok=True)
    render_product_assets(spec, post_dir, output)
    render_spec = resolve_asset_uris(spec, post_dir)
    pages = render_spec.get("pages") or [{"duration": spec["duration"], "messages": render_spec["messages"]}]
    frames = []
    page_previews = []
    for page_index, page in enumerate(pages):
        interval = page["duration"] / (len(page["messages"]) + 1)
        for step in range(len(page["messages"]) + 1):
            destination = states / f"p{page_index + 1:02d}-{step:02d}.png"
            render_state(render_spec, page_index, step, destination)
            frames.append((destination, interval))
            print(destination.relative_to(HERE))
        page_preview = output / f"preview-page-{page_index + 1}.png"
        page_preview.write_bytes(frames[-1][0].read_bytes())
        page_previews.append(page_preview)

    preview = output / "preview.png"
    preview.write_bytes(page_previews[1 if len(page_previews) > 1 else 0].read_bytes())

    with tempfile.NamedTemporaryFile("w", suffix=".txt", encoding="utf-8", delete=False) as handle:
        concat = Path(handle.name)
        for image, interval in frames:
            handle.write(f"file '{image}'\n")
            handle.write(f"duration {interval:.6f}\n")
        handle.write(f"file '{frames[-1][0]}'\n")

    video = output / "line-unfold.mp4"
    duration = sum(page["duration"] for page in pages)
    try:
        subprocess.run([
            "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(concat),
            "-t", f"{duration:.3f}",
            "-vf", "fps=30,format=yuv420p", "-c:v", "libx264", "-preset", "medium",
            "-movflags", "+faststart", str(video),
        ], check=True, timeout=180, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    finally:
        concat.unlink(missing_ok=True)

    track = pick_bgm(slug, spec)
    if track:
        mux_bgm(video, track, duration)
        origin = "pinned" if spec.get("bgm") else 'UNPINNED — set "bgm" in post.json to choose a mood'
        print(f"bgm: {track.name} ({origin})")
    else:
        print("bgm: none (empty pool) — video is silent")
    print(video.relative_to(HERE))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("slug")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    manifest = HERE / "posts" / args.slug / "post.json"
    if not manifest.is_file():
        fail(f"unknown post: {args.slug}")
    spec = json.loads(manifest.read_text(encoding="utf-8"))
    validate(args.slug, spec)
    report_wraps(spec)
    if args.validate_only:
        print(f"Valid: {manifest}")
    else:
        build(args.slug)


if __name__ == "__main__":
    main()
