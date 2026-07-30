#!/usr/bin/env python3
"""
Render episode 006 (「丁寧にキレる。」#5 — the three-minute progress check).

Full two-round spicy flow: overnight request at 23:58 → progress check 3 minutes
later → inner monologue → transformation R1 → boss settles for 「ざっくり」 →
transformation R2 → final boundary. 12 slides — the last is the App Store
download CTA overlay.
Slide 1 is a full-screen hook (big text like the 心の声 overlay).

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

SCENE = "progress-check"

# Round 1 — reply to the 3-minute progress check (chat context = steps 1-2)
R1_DRAFT   = "まだ3分なので進んでません。朝までの完成も無理です。"
R1_RESULT  = "現時点では着手直後のため、進捗をご報告できる段階ではありません。対応可能な期限を確認のうえ、改めてご連絡いたします。"

# Round 2 — reply to the 「ざっくりでいいから」 compromise (chat context = steps 1-4)
R2_DRAFT   = "ざっくりでも朝までは無理です。品質が保てません。"
R2_RESULT  = "品質を担保できないため、明朝までの完了はお約束できません。確認後、対応可能な期限をご連絡いたします。"

# (template, base-params, caption)
SLIDES = [
    (LINE, {"scene": SCENE, "step": "0", "hook": "23:58、上司から\n無茶なお願い", "hooktag": "丁寧にキレる。"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "3分後に、進捗確認が来た"),
    (LINE, {"scene": SCENE, "step": "2", "innervoice": "3分で何が育つんだよ"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "あなたなら、何て返す？"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "2", "draft": R1_DRAFT}, "3分じゃ、まだ何も育ってない"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "2", "draft": R1_DRAFT, "result": R1_RESULT}, "無茶な期限も、丁寧に断れる"),
    (LINE, {"scene": SCENE, "step": "4"}, "丁寧に断っても、「ざっくり」で済まされた"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "4", "draft": R2_DRAFT}, "ざっくりでも、一晩ではできない"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "4", "draft": R2_DRAFT, "result": R2_RESULT}, "言い方は丁寧。無茶な約束はしない"),
    (LINE, {"scene": SCENE, "step": "5"}, "23:58の「明日まで」は、ほぼ今。敬語ボタンで、言いたいことを丁寧に。"),
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
