#!/usr/bin/env python3
import argparse
import hashlib
import json
import subprocess
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMPLATES = ROOT / "docs/marketing/content/templates"
DEFAULT_CHROME = Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
TEMPLATE_PATHS = {
    "line-chat": TEMPLATES / "line-chat/line-chat.html",
    "product-ui": TEMPLATES / "product-ui/product-ui.html",
}


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


def load_spec(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        spec = json.load(handle)
    if spec.get("version") != 1:
        fail("episode.json version must be 1")
    reject_markup(spec, "episode")
    episode = spec.get("episode")
    if not isinstance(episode, dict) or not episode.get("id") or not episode.get("slug"):
        fail("episode.id and episode.slug are required")
    scene = spec.get("scene")
    if not isinstance(scene, dict) or not isinstance(scene.get("messages"), list):
        fail("scene.messages is required")
    if not scene.get("name") or not scene.get("day") or not scene["messages"]:
        fail("scene.name, scene.day, and at least one message are required")
    for index, message in enumerate(scene["messages"], 1):
        if message.get("side") not in {"boss", "me"}:
            fail(f"scene message {index} has invalid side")
        if not message.get("text") or not message.get("time"):
            fail(f"scene message {index} requires text and time")
    slides = spec.get("slides")
    if not isinstance(slides, list) or not 1 <= len(slides) <= 10:
        fail("slides must contain between 1 and 10 items")
    for index, slide in enumerate(slides, 1):
        if slide.get("template") not in TEMPLATE_PATHS:
            fail(f"slide {index} has an unknown template")
        if not isinstance(slide.get("params", {}), dict):
            fail(f"slide {index} params must be an object")
        params = slide.get("params", {})
        if slide["template"] == "product-ui" and params.get("state") == "result":
            if not params.get("draft") or not params.get("result"):
                fail(f"result slide {index} requires draft and result")
            if len(params["result"]) > 75:
                fail(f"result slide {index} exceeds the 75-character card limit")
    publish = spec.get("publish")
    if not isinstance(publish, dict) or not publish.get("title"):
        fail("publish.title is required")
    hashtags = publish.get("hashtags")
    if not isinstance(hashtags, list) or not 1 <= len(hashtags) <= 5:
        fail("publish.hashtags must contain between 1 and 5 items")
    if any(not isinstance(tag, str) or not tag.startswith("#") for tag in hashtags):
        fail("every hashtag must be a string beginning with #")
    return spec


def fingerprint(spec: dict) -> str:
    payload = json.dumps(spec, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()


def check_publishable(spec: dict, config: dict) -> None:
    approval = spec.get("approval", {})
    publishing = config["publishing"]
    if publishing["mode"] == "approved_only" and approval.get("status") != "approved":
        fail("publish gate: episode is not approved")
    if publishing["requireRewriteVerified"] and approval.get("rewriteVerified") is not True:
        fail("publish gate: rewrite is not verified")
    if publishing["requireVisualQA"] and approval.get("visualQA") is not True:
        fail("publish gate: visual QA is incomplete")


def render(spec_path: Path, output: Path, chrome: Path) -> None:
    spec = load_spec(spec_path)
    if not chrome.is_file():
        fail(f"Chrome not found: {chrome}")
    output.mkdir(parents=True, exist_ok=True)
    scene = json.dumps(spec["scene"], ensure_ascii=False, separators=(",", ":"))
    for index, slide in enumerate(spec["slides"], 1):
        query = {
            **slide.get("params", {}),
            "format": "instagram",
            "scenejson": scene,
        }
        if slide.get("caption"):
            query["caption"] = slide["caption"]
        template = TEMPLATE_PATHS[slide["template"]].as_uri()
        url = f"{template}?{urllib.parse.urlencode(query)}"
        destination = output / f"{index:02d}.png"
        subprocess.run([
            str(chrome),
            "--headless",
            "--disable-gpu",
            "--hide-scrollbars",
            "--allow-file-access-from-files",
            "--force-device-scale-factor=1",
            "--window-size=1080,1350",
            f"--screenshot={destination}",
            url,
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(destination)
    print(f"content_sha256={fingerprint(spec)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("spec", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--chrome", type=Path, default=DEFAULT_CHROME)
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--check-publishable", action="store_true")
    parser.add_argument("--config", type=Path, default=ROOT / "docs/marketing/automation/config.json")
    args = parser.parse_args()
    spec_path = args.spec.resolve()
    spec = load_spec(spec_path)
    if args.check_publishable:
        with args.config.resolve().open(encoding="utf-8") as handle:
            check_publishable(spec, json.load(handle))
    if args.validate_only:
        print(f"Valid: {spec_path}")
        print(f"content_sha256={fingerprint(spec)}")
        return
    output = args.output_dir.resolve() if args.output_dir else spec_path.parent / "render/instagram/cap"
    render(spec_path, output, args.chrome)


if __name__ == "__main__":
    main()
