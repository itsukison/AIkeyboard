#!/usr/bin/env python3
import argparse
import copy
import json
import re
import subprocess
import tempfile
import urllib.parse
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEMPLATE = (HERE / "template/line-unfold.html").as_uri()
PRODUCT_TEMPLATE = (HERE.parent / "line-story/templates/product-ui/product-ui.html").as_uri()
WIDTH, HEIGHT = 1080, 1920
SLUG = re.compile(r"^\d{3}-[a-z0-9-]+$")


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


def validate(slug: str, spec: dict) -> None:
    if spec.get("version") not in {1, 2}:
        fail("post.json version must be 1 or 2")
    if not SLUG.fullmatch(slug) or spec.get("slug") != slug:
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
        subprocess.run([
            "ffmpeg", "-y", "-i", str(source),
            "-vf", "crop=1080:815:0:1105",
            str(destination),
        ], check=True, timeout=120, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


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
    if args.validate_only:
        print(f"Valid: {manifest}")
    else:
        build(args.slug)


if __name__ == "__main__":
    main()
