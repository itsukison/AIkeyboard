#!/usr/bin/env python3
"""
Render episode 013 (「丁寧にキレる。」#12 — the 7:42 voice memo).

Full two-round spicy flow: boss sends a seven-minute voice memo and delegates
the summary → inner monologue → transformation R1 → 「倍速で聞いて」 dodge →
transformation R2 → final boundary. 12 slides — the last is the App Store
download CTA overlay. Slide 1 is a full-screen hook (big text like the 心の声
overlay).

TikTok + Instagram, cap variant only (ready to post).

Run:  python3 build.py
"""
import subprocess, urllib.parse
from pathlib import Path

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
HERE = Path(__file__).resolve().parent
TEMPLATES = HERE.parents[1] / "templates"
LINE = (TEMPLATES / "line-chat" / "line-chat.html").as_uri()
PROD = (TEMPLATES / "product-ui" / "product-ui.html").as_uri()
OUT = HERE / "render"

SCENE = "voice-memo"

# Round 1 — reply to the delegated summary (chat context = steps 1-2)
R1_DRAFT   = "長すぎて要点が分かりません。決まったことを文章で送ってください。"
R1_RESULT  = "認識の相違を防ぐため、決定事項と対応内容を文章でご共有いただけますでしょうか。"

# Round 2 — reply to the 「倍速で聞いて」 dodge (chat context = steps 1-4)
R2_DRAFT   = "倍速でも長いです。要点は送る側が書いてください。"
R2_RESULT  = "正確に共有するため、発信者側で決定事項と対応内容をご提示ください。"

# (template, base-params, caption)
SLIDES = [
    (LINE, {"scene": SCENE, "step": "0", "hook": "7分42秒の音声と、\n「まとめといて」", "hooktag": "丁寧にキレる。"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "7分42秒の音声を送る時間はある。要点を書く時間はない"),
    (LINE, {"scene": SCENE, "step": "2", "innervoice": "お前がまとめてから喋れ"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "あなたなら、何て返す？"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "2", "draft": R1_DRAFT}, "長すぎて要点が分からない"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "2", "draft": R1_DRAFT, "result": R1_RESULT}, "文章での共有は、丁寧にお願いできる"),
    (LINE, {"scene": SCENE, "step": "4"}, "丁寧にお願いしても、「倍速で聞いて」"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "4", "draft": R2_DRAFT}, "倍速でも、まとめるのは送る側"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "4", "draft": R2_DRAFT, "result": R2_RESULT}, "言い方は丁寧。文字起こし係にはならない"),
    (LINE, {"scene": SCENE, "step": "5"}, "「倍速で聞いて」は、指示ではなく丸投げ。敬語ボタンで、言いたいことを丁寧に。"),
    (LINE, {"scene": SCENE, "step": "5", "cta": "1", "ctatag": "丁寧にキレる。"}, ""),
]

FORMATS = {"tiktok": 1920, "instagram": 1350}


def render(url, path, height):
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
        "--allow-file-access-from-files",   # let the templates load the shared ../scenes.js
        "--force-device-scale-factor=1", f"--window-size=1080,{height}",
        f"--screenshot={path}", url,
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    for fmt, h in FORMATS.items():
        for i, (tpl, params, caption) in enumerate(SLIDES, 1):
            extra = {"caption": caption} if caption else {}
            q = {**params, "format": fmt, **extra}
            url = f"{tpl}?{urllib.parse.urlencode(q)}"
            render(url, OUT / fmt / "cap" / f"{i:02d}.png", h)
            print(f"  {fmt}/cap/{i:02d}.png")
    print(f"\nDone → {OUT}")


if __name__ == "__main__":
    main()
