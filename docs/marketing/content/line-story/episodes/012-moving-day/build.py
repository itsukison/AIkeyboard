#!/usr/bin/env python3
"""
Render episode 012 (「丁寧にキレる。」#11 — the pizza-paid move).

Full two-round spicy flow: boss books the employee's Sunday, labor, and car
for one pizza → inner monologue → transformation R1 → 「ケチ」 jab →
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

SCENE = "moving-day"

# Round 1 — reply to the moving-day request (chat context = steps 1-2)
R1_DRAFT   = "私用なので行きません。車も出しません。"
R1_RESULT  = "申し訳ありませんが、日曜日は私用のため、引っ越しのお手伝いや車の提供はいたしかねます。"

# Round 2 — reply to the 「ケチ」 jab (chat context = steps 1-4)
R2_DRAFT   = "ピザでは行きません。私用の手伝いは断ります。"
R2_RESULT  = "報酬の有無にかかわらず、業務外の個人的な依頼はお引き受けいたしかねます。"

# (template, base-params, caption)
SLIDES = [
    (LINE, {"scene": SCENE, "step": "0", "hook": "上司の引っ越し、\n報酬はピザ1枚", "hooktag": "丁寧にキレる。"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "ピザ1枚で、人と車と日曜日を確保しようとしている"),
    (LINE, {"scene": SCENE, "step": "2", "innervoice": "業者代をピザで済ますな"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "あなたなら、何て返す？"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "2", "draft": R1_DRAFT}, "私用なので行かない。車も出さない"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "2", "draft": R1_DRAFT, "result": R1_RESULT}, "私用の依頼は、丁寧に断れる"),
    (LINE, {"scene": SCENE, "step": "4"}, "丁寧に断っても、「ケチ」で返された"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "4", "draft": R2_DRAFT}, "ピザを積まれても行かない"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "4", "draft": R2_DRAFT, "result": R2_RESULT}, "言い方は丁寧。日曜は渡さない"),
    (LINE, {"scene": SCENE, "step": "5"}, "報酬の有無ではなく、業務外の依頼は受けない。敬語ボタンで、言いたいことを丁寧に。"),
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
