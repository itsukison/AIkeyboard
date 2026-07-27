#!/usr/bin/env python3
"""
Render episode 007 (「丁寧にキレる。」#6 — 「既読ついてるよね？」 after hours).

Full two-round spicy flow: 22:47 read-receipt pressure → inner monologue →
transformation R1 → boss haggles "30 seconds" → transformation R2 →
final boundary. 12 slides — the last is the App Store download CTA overlay.
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

SCENE = "read-receipt"

# Round 1 — reply to the read-receipt pressure (chat context = step 1)
R1_DRAFT   = "勤務時間外なので今は返事しません。明日確認します。"
R1_RESULT  = "勤務時間外のため、本件は明日の始業後に確認し、ご返信いたします。緊急連絡が必要な場合は、事前に連絡方法をご共有ください。"

# Round 2 — reply to the 「30秒で返せるよね？」 haggle (chat context = steps 1-3)
R2_DRAFT   = "30秒でも仕事なので返しません。明日やります。"
R2_RESULT  = "所要時間にかかわらず、勤務時間外の対応はいたしかねます。明日の始業後に確認いたします。"

# (template, base-params, caption)
SLIDES = [
    (LINE, {"scene": SCENE, "step": "0", "hook": "22:47、\n既読を見張られていた", "hooktag": "丁寧にキレる。"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, "夜10時47分。既読だけで、返信義務？"),
    (LINE, {"scene": SCENE, "step": "1", "innervoice": "既読は勤務開始ボタンじゃない"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, "あなたなら、何て返す？"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "1", "draft": R1_DRAFT}, "勤務時間外は、返さない"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "1", "draft": R1_DRAFT, "result": R1_RESULT}, "時間外返信は、丁寧に断れる"),
    (LINE, {"scene": SCENE, "step": "3"}, "丁寧に断っても、「30秒」で畳みかけられた"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "3", "draft": R2_DRAFT}, "30秒でも、仕事は仕事"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "3", "draft": R2_DRAFT, "result": R2_RESULT}, "言い方は丁寧。境界線は越えさせない"),
    (LINE, {"scene": SCENE, "step": "4"}, "30秒の返信でも、仕事は仕事。敬語ボタンで、言いたいことを丁寧に。"),
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
