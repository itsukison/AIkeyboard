#!/usr/bin/env python3
"""
Render episode 004 (「丁寧にキレる。」#3 — creepy boss sequel: 「嫁には内緒で笑」).

Full two-round spicy flow: secret-drink invite → inner monologue → transformation R1
→ boss hides behind "a joke" → transformation R2 → final boundary. 11 slides.
Slide 1 is a full-screen hook (big text like the 心の声 overlay) instead of a
small caption band.

TikTok + Instagram, cap variant only (ready to post).

Run:  python3 build.py
"""
import subprocess, urllib.parse
from pathlib import Path

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
HERE = Path(__file__).resolve().parent
TEMPLATES = HERE.parent / "templates"
LINE = (TEMPLATES / "line-chat" / "line-chat.html").as_uri()
PROD = (TEMPLATES / "product-ui" / "product-ui.html").as_uri()
OUT = HERE / "render"

SCENE = "secret-drink"

# Round 1 — reply to the invite + 「嫁には内緒で笑」 (chat context = steps 1-2)
R1_DRAFT   = "奥様に言えない誘いはやめてください。二人でも行きません。"
R1_RESULT  = "業務外で二人きりのお誘いはお断りいたします。ご家族にお伝えできない内容のご連絡もお控えください。"

# Round 2 — reply to the 「冗談に決まってるじゃん笑」 escape (chat context = steps 1-4)
R2_DRAFT   = "冗談には見えません。今後こういう連絡はやめてください。"
R2_RESULT  = "冗談として受け取れない内容でしたので、今後同様のご連絡はお控えください。"

# (template, base-params, caption)
SLIDES = [
    (LINE, {"scene": SCENE, "step": "0", "hook": "夜、既婚の上司から\nまた誘いのLINE", "hooktag": "丁寧にキレる。"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "「嫁には内緒」で、もう冗談じゃない"),
    (LINE, {"scene": SCENE, "step": "2", "innervoice": "スクショの送信先、奥様でいいですか？"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "あなたなら、何て返す？"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "2", "draft": R1_DRAFT}, "奥様に言えない誘いは、断る"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "2", "draft": R1_DRAFT, "result": R1_RESULT}, "誘いは、丁寧に断れる"),
    (LINE, {"scene": SCENE, "step": "4"}, "丁寧に断っても、「冗談」にされた"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "4", "draft": R2_DRAFT}, "冗談としては、受け取れない"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "4", "draft": R2_DRAFT, "result": R2_RESULT}, "言い方は丁寧。でも一歩も引かない"),
    (LINE, {"scene": SCENE, "step": "5"}, "「内緒」は、逃げ道を自分で消した証拠。敬語ボタンで、言いたいことを丁寧に。"),
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
