#!/usr/bin/env python3
"""
Render episode 011 (「丁寧にキレる。」#10 — the wrong-recipient strategy).

Full two-round spicy flow: boss accidentally sends his overtime-manipulation
strategy to the employee herself → inner monologue → transformation R1 →
「忘れて」 retreat → transformation R2 → final boundary. 12 slides — the last
is the App Store download CTA overlay. Slide 1 is a full-screen hook (big
text like the 心の声 overlay).

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

SCENE = "wrong-recipient"

# Round 1 — reply to the misfired strategy (chat context = steps 1-2)
R1_DRAFT   = "見ました。褒めて残業させようとするのはやめてください。"
R1_RESULT  = "先ほどのメッセージは確認しております。今後、評価や称賛を理由に時間外対応を期待することはお控えください。"

# Round 2 — reply to the 「忘れて」 retreat (chat context = steps 1-4)
R2_DRAFT   = "忘れられません。時間外の仕事は事前に相談してください。"
R2_RESULT  = "記載された内容は確認済みです。今後の時間外対応は、必要性と期限を明確にしたうえでご相談ください。"

# (template, base-params, caption)
SLIDES = [
    (LINE, {"scene": SCENE, "step": "0", "hook": "上司の誤爆が、\n一番本音だった", "hooktag": "丁寧にキレる。"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "送信取消より先に、既読がついた"),
    (LINE, {"scene": SCENE, "step": "2", "innervoice": "気にしない方法も送ってください"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "あなたなら、何て返す？"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "2", "draft": R1_DRAFT}, "見ました。今のは見ました"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "2", "draft": R1_DRAFT, "result": R1_RESULT}, "誤爆にも、丁寧に境界線を引ける"),
    (LINE, {"scene": SCENE, "step": "4"}, "丁寧に返しても、「忘れて」で逃げられた"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "4", "draft": R2_DRAFT}, "忘れません。記録に残っています"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "4", "draft": R2_DRAFT, "result": R2_RESULT}, "言い方は丁寧。見なかったふりはしない"),
    (LINE, {"scene": SCENE, "step": "5"}, "「気にしないで」の前に、既読はついている。敬語ボタンで、言いたいことを丁寧に。"),
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
