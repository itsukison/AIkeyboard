#!/usr/bin/env python3
"""
Render episode 005 (「丁寧にキレる。」#4 — Friday 17:58 「簡単な修正」).

Full two-round spicy flow: client demands same-day work at 17:58 → inner monologue
→ transformation R1 → client haggles "it's 5 minutes" → transformation R2 →
final boundary. 12 slides — the last is the App Store download CTA overlay.
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

SCENE = "friday-revision"

# Round 1 — reply to the 17:58 same-day request (chat context = step 1)
R1_DRAFT   = "今日中は無理です。月曜日ならできます。"
R1_RESULT  = "恐れ入りますが、本日中の対応は難しい状況です。月曜日の午前中であれば対応可能ですが、いかがでしょうか。"

# Round 2 — reply to the 「5分で終わる」 haggle (chat context = steps 1-3)
R2_DRAFT   = "5分でも今日はやりません。月曜日に対応します。"
R2_RESULT  = "作業時間にかかわらず、現在の対応状況では本日中のお約束ができかねます。月曜日午前中の対応でお願いいたします。"

# (template, base-params, caption)
SLIDES = [
    (LINE, {"scene": SCENE, "step": "0", "hook": "金曜 17:58、\n取引先からこのLINE", "hooktag": "丁寧にキレる。"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, "「簡単」は、やったことがない人の言葉"),
    (LINE, {"scene": SCENE, "step": "1", "innervoice": "簡単なら自分でやれ"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, "あなたなら、何て返す？"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "1", "draft": R1_DRAFT}, "今日中は無理。月曜ならできる"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "1", "draft": R1_DRAFT, "result": R1_RESULT}, "納期は、丁寧に交渉できる"),
    (LINE, {"scene": SCENE, "step": "3"}, "丁寧に断っても、「5分」で値切られた"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "3", "draft": R2_DRAFT}, "5分でも、今日中は約束しない"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "3", "draft": R2_DRAFT, "result": R2_RESULT}, "断り方は丁寧。約束は増やさない"),
    (LINE, {"scene": SCENE, "step": "4"}, "「簡単」かどうかを決めるのは、作業する側。敬語ボタンで、言いたいことを丁寧に。"),
    (LINE, {"scene": SCENE, "step": "4", "cta": "1", "ctatag": "丁寧にキレる。"}, ""),
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
