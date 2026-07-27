#!/usr/bin/env python3
"""
Render episode 002 (「丁寧にキレる。」#1 — creepy boss) from the shared templates.

Full two-round spicy flow: violation → inner monologue → transformation R1 →
boss comeback → transformation R2 → final boundary + CTA. 11 slides.

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

SCENE = "creepy-boss"

# Round 1 — reply to the drink invite (chat context = steps 1-2: the two violation messages)
R1_DRAFT    = "二人で飲みに行くのは嫌です。仕事と関係ない質問もやめてください。"
R1_RESULT   = "恐れ入りますが、業務に関係のない個人的なご質問や、二人きりでのお誘いは控えていただけますでしょうか。今後は業務に関するご連絡のみお願いいたします。"

# Round 2 — reply to the "そんな固くならなくても笑" brush-off (chat context = steps 1-4)
R2_DRAFT    = "固くないです。本気で言ってます。業務以外の連絡はやめてください。"
R2_RESULT   = "誤解を避けるため、明確にお伝えしております。今後は業務に関するご連絡のみお願いいたします。"

# (template, base-params, caption)
SLIDES = [
    (LINE, {"scene": SCENE, "step": "0"}, "朝イチ、上司からこのLINE"),
    (LINE, {"scene": SCENE, "step": "1"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "「仕事の相談」は、ただの口実"),
    (LINE, {"scene": SCENE, "step": "2", "innervoice": "まじ黙れよこの豚"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "あなたなら、何て返す？"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "2", "draft": R1_DRAFT}, "本音のままじゃ、角が立つ"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "2", "draft": R1_DRAFT, "result": R1_RESULT}, "敬語ボタンなら、こう変わる"),
    (LINE, {"scene": SCENE, "step": "4"}, "丁寧に送っても、軽く流された"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "4", "draft": R2_DRAFT}, "固くない。本気で言ってる"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "4", "draft": R2_DRAFT, "result": R2_RESULT}, "言い方は丁寧。でも一歩も引かない"),
    (LINE, {"scene": SCENE, "step": "5"}, "我慢しなくていい。敬語ボタンで、言いたいことを丁寧に。"),
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
            for variant, extra in (("clean", {}), ("cap", {"caption": caption} if caption else {})):
                q = {**params, "format": fmt, **extra}
                url = f"{tpl}?{urllib.parse.urlencode(q)}"
                render(url, OUT / fmt / variant / f"{i:02d}.png", h)
                print(f"  {fmt}/{variant}/{i:02d}.png")
    print(f"\nDone → {OUT}")


if __name__ == "__main__":
    main()
