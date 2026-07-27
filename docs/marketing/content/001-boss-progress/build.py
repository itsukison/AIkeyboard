#!/usr/bin/env python3
"""
Render episode 001 slides from the shared templates.

Produces, for each slide, four PNGs: {tiktok,instagram} x {cap,clean}.
  - cap   = caption baked in (ready to post)
  - clean = no caption (add your own text in an editor)

Run:  python3 build.py
Copy this file per episode; only SLIDES + OUT change.
"""
import subprocess, urllib.parse
from pathlib import Path

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
HERE = Path(__file__).resolve().parent
TEMPLATES = HERE.parent / "templates"
LINE = (TEMPLATES / "line-chat" / "line-chat.html").as_uri()
PROD = (TEMPLATES / "product-ui" / "product-ui.html").as_uri()
OUT = HERE / "render"

# incoming boss line the product frames are replying to
INCOMING = "仕事の進捗の話です"
DRAFT    = "本日中は無理です。明日やります。"
RESULT   = "申し訳ありません。本日中の完了が難しいため、明日午前までお時間をいただけますでしょうか。"

# (template, base-params, caption)
SLIDES = [
    (LINE, {"scene": "progress", "step": "1"}, "上司のメッセージを完全に勘違いする新卒"),
    (LINE, {"scene": "progress", "step": "2"}, "え、今日どこか行くんですか…？"),
    (LINE, {"scene": "progress", "step": "4"}, "ずっと距離の話だと思っている"),
    (LINE, {"scene": "progress", "step": "5"}, "……え。"),
    (LINE, {"scene": "progress", "step": "6"}, "このあと、何て返す？"),
    (PROD, {"state": "toolbar", "incoming": INCOMING, "draft": DRAFT}, "正直に書くと、少し冷たい"),
    (PROD, {"state": "result",  "incoming": INCOMING, "result": RESULT}, "敬語ボタンで、こうなる"),
    (LINE, {"scene": "progress", "step": "8"}, "返しづらかった上司チャットをコメントで。次回、敬語にします"),
]

FORMATS = {"tiktok": 1920, "instagram": 1350}


def render(url, path, height):
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
        "--force-device-scale-factor=1", f"--window-size=1080,{height}",
        f"--screenshot={path}", url,
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    for fmt, h in FORMATS.items():
        for i, (tpl, params, caption) in enumerate(SLIDES, 1):
            for variant, extra in (("clean", {}), ("cap", {"caption": caption})):
                q = {**params, "format": fmt, **extra}
                url = f"{tpl}?{urllib.parse.urlencode(q)}"
                render(url, OUT / fmt / variant / f"{i:02d}.png", h)
                print(f"  {fmt}/{variant}/{i:02d}.png")
    print(f"\nDone → {OUT}")


if __name__ == "__main__":
    main()
