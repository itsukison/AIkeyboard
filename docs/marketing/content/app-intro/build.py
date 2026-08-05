#!/usr/bin/env python3
"""
Render one app-intro post: hook slide, then one card per app.

There is no closing CTA slide — 敬語ボタン is one of the cards, so a download
slide would break the curation framing that makes the post work.

Card copy lives in apps.json; post.json picks which apps a post shows and in
what order. Instagram sizing only (1080 x 1350).

Run:  python3 build.py 001-identity-callout
      python3 build.py --all
"""
import argparse
import json
import subprocess
import tempfile
import urllib.parse
from pathlib import Path


def find_chrome() -> str:
    """Prefer Playwright's headless shell: the Google Chrome app bundle hangs
    forever if the user already has Chrome open, whatever --user-data-dir says."""
    shells = sorted(
        (Path.home() / "Library/Caches/ms-playwright").glob(
            "chromium_headless_shell-*/chrome-headless-shell-*/chrome-headless-shell"
        ),
        reverse=True,
    )
    if shells:
        return str(shells[0])
    return "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


CHROME = find_chrome()
PROFILE = Path(tempfile.gettempdir()) / "app-intro-chrome-profile"
HERE = Path(__file__).resolve().parent
TEMPLATE = (HERE / "template" / "app-intro.html").as_uri()
ASSETS = HERE / "assets"
WIDTH, HEIGHT = 1080, 1350
OUT_SUBDIR = Path("render/instagram/cap")

SERIES = "入れとくべきアプリ"


def asset_uri(kind: str, name: str) -> str:
    path = ASSETS / kind / name
    if not path.exists():
        raise SystemExit(f"missing asset: {path}")
    return path.as_uri()


def slides(library: dict, post: dict) -> list[dict]:
    image_overrides = post.get("appImageOverrides", {})
    out = [{
        "slide": "hook",
        "pill": SERIES,
        "hook": post["hook"],
        "swipe": post.get("swipe", ""),
        "img": asset_uri("thumbnails", post["thumbnail"]),
    }]
    for position, app_id in enumerate(post["apps"], 1):
        app = library[app_id]
        image = image_overrides.get(app_id, app["image"])
        cropped_height = app["naturalHeight"] - app["cropBottomPx"]
        spec = {
            "slide": "app",
            "pill": SERIES,
            "idx": str(position),
            "name": app["name"],
            "tagline": app["tagline"],
            "detail": app["detail"],
            "accent": app["accent"],
            "ratio": f"{app['naturalWidth'] / cropped_height:.4f}",
            "img": asset_uri("apps", image),
        }
        if app.get("pending"):
            spec["pending"] = "1"
        out.append(spec)
    return out


def load_posts() -> dict[str, dict]:
    return {
        path.parent.name: json.loads(path.read_text(encoding="utf-8"))
        for path in sorted((HERE / "posts").glob("*/post.json"))
    }


def validate_app_reuse(posts: dict[str, dict], library: dict) -> None:
    app_usage: dict[str, list[str]] = {}
    image_usage: dict[str, list[str]] = {}
    for slug, post in posts.items():
        for app_id in post["apps"]:
            if app_id not in library or library[app_id].get("ours"):
                continue
            app_usage.setdefault(app_id, []).append(slug)
            image_usage.setdefault(library[app_id]["image"], []).append(slug)

    overused = [
        f"{app_id}: {', '.join(slugs)}"
        for app_id, slugs in app_usage.items()
        if len(slugs) > 3
    ]
    overused += [
        f"{image}: {', '.join(slugs)}"
        for image, slugs in image_usage.items()
        if len(slugs) > 3
    ]
    if overused:
        raise SystemExit(
            "third-party apps or screenshots used more than three times: "
            + "; ".join(overused)
        )


def render(url: str, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
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


def build(slug: str, library: dict) -> None:
    post_dir = HERE / "posts" / slug
    post = json.loads((post_dir / "post.json").read_text(encoding="utf-8"))
    unknown = [a for a in post["apps"] if a not in library]
    if unknown:
        raise SystemExit(f"{slug}: unknown app ids in post.json: {', '.join(unknown)}")
    specs = slides(library, post)
    if len(specs) > 10:
        raise SystemExit(f"{slug}: {len(specs)} slides; TikTok Photo Mode allows 10")
    for index, spec in enumerate(specs, 1):
        url = f"{TEMPLATE}?{urllib.parse.urlencode(spec)}"
        path = post_dir / OUT_SUBDIR / f"{index:02d}.png"
        render(url, path)
        print(path.relative_to(HERE))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("slug", nargs="?")
    parser.add_argument("--all", action="store_true", help="render every post")
    args = parser.parse_args()

    library = json.loads((HERE / "apps.json").read_text(encoding="utf-8"))["apps"]
    posts = load_posts()
    validate_app_reuse(posts, library)
    pending = [a["name"] for a in library.values() if a.get("pending")]
    if pending:
        print(f"⚠️  placeholder screenshots still in use: {', '.join(pending)} — do not publish")

    if args.all:
        slugs = sorted(posts)
    elif args.slug:
        slugs = [args.slug]
    else:
        raise SystemExit("pass a post slug or --all")

    for slug in slugs:
        build(slug, library)


if __name__ == "__main__":
    main()
