#!/usr/bin/env python3
"""
Render episode 008 (「丁寧にキレる。」#7 — the 「いい感じに」 brief).

Full two-round spicy flow: revision brief is pure vibes → inner monologue →
transformation R1 → boss delegates the criteria to 「センス」 → transformation R2
→ final boundary. 12 slides — the last is the App Store download CTA overlay.
Slide 1 is a full-screen hook (big text like the 心の声 overlay).

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

SCENE = "vague-brief"

# Round 1 — reply to the 「もっといい感じに」 brief (chat context = steps 1-2)
R1_DRAFT   = "いい感じでは分かりません。修正点を具体的に言ってください。"
R1_RESULT  = "修正の方向性を揃えるため、変更箇所と期待する状態を具体的にご共有いただけますでしょうか。"

# Round 2 — reply to the 「センスで分かるでしょ」 dodge (chat context = steps 1-4)
R2_DRAFT   = "センスでは分かりません。判断基準を教えてください。"
R2_RESULT  = "認識のずれを避けるため、判断基準を言語化していただけますと助かります。"

# (template, base-params, caption)
SLIDES = [
    (LINE, {"scene": SCENE, "step": "0", "hook": "上司の修正指示が、\n感想しかない", "hooktag": "丁寧にキレる。"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "直してほしいのは、結局どこ？"),
    (LINE, {"scene": SCENE, "step": "2", "innervoice": "お前の脳内は共有フォルダじゃない"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "あなたなら、何て返す？"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "2", "draft": R1_DRAFT}, "「いい感じ」じゃ、直せない"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "2", "draft": R1_DRAFT, "result": R1_RESULT}, "曖昧な指示には、丁寧に確認できる"),
    (LINE, {"scene": SCENE, "step": "4"}, "丁寧に聞いても、「センス」で返された"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "4", "draft": R2_DRAFT}, "「センス」は、判断基準じゃない"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "4", "draft": R2_DRAFT, "result": R2_RESULT}, "聞き方は丁寧。丸投げは受けない"),
    (LINE, {"scene": SCENE, "step": "5"}, "「いい感じ」は、指示ではなく感想。敬語ボタンで、言いたいことを丁寧に。"),
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
