#!/usr/bin/env python3
"""Render one office-talk post as a 1080 x 1920 TikTok slideshow."""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import urllib.parse
from pathlib import Path


def find_chrome() -> str:
    chrome = Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    if chrome.is_file():
        return str(chrome)
    shells = sorted(
        (Path.home() / "Library/Caches/ms-playwright").glob(
            "chromium_headless_shell-*/chrome-headless-shell-*/chrome-headless-shell"
        ),
        reverse=True,
    )
    if shells:
        return str(shells[0])
    return str(chrome)


CHROME = find_chrome()
PROFILE = Path(tempfile.gettempdir()) / "office-talk-chrome-profile"
HERE = Path(__file__).resolve().parent
TEMPLATE = (HERE / "template" / "office-talk.html").as_uri()
WIDTH, HEIGHT = 1080, 1920
OUT_SUBDIR = Path("render/tiktok/cap")
SLUG = re.compile(r"^\d{3}-[a-z0-9-]+$")


def fail(message: str) -> None:
    raise SystemExit(message)


def reject_markup(value, label: str) -> None:
    if isinstance(value, str) and ("<" in value or ">" in value):
        fail(f"{label} must not contain HTML markup")
    if isinstance(value, dict):
        for key, item in value.items():
            reject_markup(item, f"{label}.{key}")
    if isinstance(value, list):
        for index, item in enumerate(value, 1):
            reject_markup(item, f"{label}[{index}]")


def validate_lines(value: str, label: str, max_chars: int) -> None:
    if not isinstance(value, str) or not value.strip():
        fail(f"{label} is required")
    lines = value.split("\n")
    if any(not line.strip() for line in lines):
        fail(f"{label} contains an empty line")
    if any(len(line) == 1 for line in lines):
        fail(f"{label} contains a one-character orphan line")
    if any(len(line) > max_chars for line in lines):
        fail(f"{label} has a line longer than {max_chars} characters")


def asset_uri(relative_path: str) -> str:
    path = (HERE / relative_path).resolve()
    if not path.exists():
        raise SystemExit(f"missing asset: {path}")
    return path.as_uri()


def slides(post: dict) -> list[dict]:
    hook = post["hook"]
    out = [{
        "slide": "hook",
        "eyebrow": hook["eyebrow"],
        "headline": hook["headline"],
        "support": hook["support"],
        "img": asset_uri(hook["image"]),
        "position": hook.get("position", "center"),
    }]
    for index, phrase in enumerate(post["phrases"], 1):
        out.append({
            "slide": "phrase",
            "index": str(index),
            "total": str(len(post["phrases"])),
            "blunt": phrase["blunt"],
            "polished": phrase["polished"],
        })
    cta = post["cta"]
    out.append({
        "slide": "cta",
        "headline": cta["headline"],
        "detail": cta["detail"],
        "action": cta["action"],
        "img": asset_uri(cta["image"]),
    })
    return out


def validate(slug: str, post: dict) -> None:
    if post.get("version") != 1:
        fail("post.json version must be 1")
    reject_markup(post, "post")
    if not SLUG.fullmatch(slug) or post.get("slug") != slug:
        fail(f"invalid or mismatched slug: {slug}")
    if len(post.get("phrases", [])) != 5:
        fail(f"{slug}: office-talk posts require exactly five phrases")
    if len(slides(post)) > 10:
        fail(f"{slug}: TikTok Photo Mode allows at most 10 slides")
    hook = post.get("hook", {})
    validate_lines(hook.get("headline"), "hook.headline", 10)
    validate_lines(hook.get("support"), "hook.support", 12)
    asset_uri(hook.get("image", ""))
    for index, phrase in enumerate(post["phrases"], 1):
        validate_lines(phrase.get("blunt"), f"phrases[{index}].blunt", 11)
        validate_lines(phrase.get("polished"), f"phrases[{index}].polished", 16)
    cta = post.get("cta", {})
    validate_lines(cta.get("headline"), "cta.headline", 13)
    validate_lines(cta.get("detail"), "cta.detail", 24)
    if cta.get("action") != "App Storeで「敬語ボタン」":
        fail("cta.action must be App Storeで「敬語ボタン」")
    asset_uri(cta.get("image", ""))
    publish = post.get("publish", {})
    if not publish.get("title"):
        fail("publish.title is required")
    hashtags = publish.get("hashtags")
    if not isinstance(hashtags, list) or not 1 <= len(hashtags) <= 5:
        fail("publish.hashtags must contain between 1 and 5 items")
    if any(not isinstance(tag, str) or not tag.startswith("#") for tag in hashtags):
        fail("every hashtag must be a string beginning with #")


def fingerprint(post: dict) -> str:
    content = {key: post[key] for key in (
        "version", "slug", "mechanism", "hook", "phrases", "cta", "publish", "hypothesis"
    )}
    payload = json.dumps(content, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()


def check_publishable(post: dict, config: dict) -> None:
    approval = post.get("approval", {})
    publishing = config["publishing"]
    if publishing["mode"] == "approved_only" and approval.get("status") != "approved":
        fail("publish gate: post is not approved")
    if publishing["requireVisualQA"] and approval.get("visualQA") is not True:
        fail("publish gate: visual QA is incomplete")


def render(spec: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    url = f"{TEMPLATE}?{urllib.parse.urlencode(spec)}"
    subprocess.run([
        CHROME,
        "--headless",
        "--disable-gpu",
        "--hide-scrollbars",
        "--allow-file-access-from-files",
        "--force-device-scale-factor=1",
        "--no-first-run",
        f"--user-data-dir={PROFILE}",
        f"--window-size={WIDTH},{HEIGHT}",
        f"--screenshot={path}",
        url,
    ], check=True, timeout=120, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def build(slug: str) -> None:
    post_dir = HERE / "posts" / slug
    manifest = post_dir / "post.json"
    if not manifest.exists():
        raise SystemExit(f"unknown post: {slug}")
    post = json.loads(manifest.read_text(encoding="utf-8"))
    validate(slug, post)
    for index, spec in enumerate(slides(post), 1):
        path = post_dir / OUT_SUBDIR / f"{index:02d}.png"
        render(spec, path)
        print(path.relative_to(HERE))
    print(f"content_sha256={fingerprint(post)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("slug", nargs="?")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--check-publishable", action="store_true")
    parser.add_argument(
        "--config",
        type=Path,
        default=HERE.parents[1] / "automation/config.json",
    )
    args = parser.parse_args()

    if args.all:
        slugs = [path.parent.name for path in sorted((HERE / "posts").glob("*/post.json"))]
    elif args.slug:
        slugs = [args.slug]
    else:
        raise SystemExit("pass a post slug or --all")

    for slug in slugs:
        manifest = HERE / "posts" / slug / "post.json"
        post = json.loads(manifest.read_text(encoding="utf-8"))
        validate(slug, post)
        if args.check_publishable:
            check_publishable(post, json.loads(args.config.read_text(encoding="utf-8")))
        if args.validate_only:
            print(f"Valid: {manifest}")
            print(f"content_sha256={fingerprint(post)}")
        else:
            build(slug)


if __name__ == "__main__":
    main()
