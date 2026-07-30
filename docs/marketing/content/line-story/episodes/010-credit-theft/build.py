#!/usr/bin/env python3
"""
Render episode 010 (「丁寧にキレる。」#9 — senior takes credit).

Full two-round spicy flow: senior brags about "his" proposal (the junior's
document) → inner monologue → transformation R1 → 「チームの成果」 dodge →
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

SCENE = "credit-theft"

# Round 1 — reply to the credit claim (chat context = step 1)
R1_DRAFT   = "あれは私が考えて資料にした案です。自分の案みたいに言わないでください。"
R1_RESULT  = "認識の相違を避けるため補足いたします。本日の企画案は、昨日私が共有した資料をもとに作成したものです。今後は作成経緯もあわせてご共有ください。"

# Round 2 — reply to the 「チームの成果」 dodge (chat context = steps 1-3)
R2_DRAFT   = "誰の案かは大事です。次から私の資料を使う時は言ってください。"
R2_RESULT  = "企画の帰属は今後の連携のためにも重要です。私の資料をもとにされる際は、事前にご一報いただけますと幸いです。"

# (template, base-params, caption)
SLIDES = [
    (LINE, {"scene": SCENE, "step": "0", "hook": "私の企画が、\n「先輩の提案」になっていた", "hooktag": "丁寧にキレる。"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, "会議で評価されていたのは、私の企画"),
    (LINE, {"scene": SCENE, "step": "1", "innervoice": "それ、私が昨日送った資料の丸パクリですよね？"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, "あなたなら、何て返す？"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "1", "draft": R1_DRAFT}, "自分の案みたいに言わないで"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "1", "draft": R1_DRAFT, "result": R1_RESULT}, "作成経緯は、丁寧に訂正できる"),
    (LINE, {"scene": SCENE, "step": "3"}, "丁寧に訂正しても、「チームの成果」で流された"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "3", "draft": R2_DRAFT}, "誰の案かは、関係ある"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "3", "draft": R2_DRAFT, "result": R2_RESULT}, "言い方は丁寧。手柄は渡さない"),
    (LINE, {"scene": SCENE, "step": "4"}, "黙ると、次も「先輩の提案」になる。敬語ボタンで、言いたいことを丁寧に。"),
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
