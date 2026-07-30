#!/usr/bin/env python3
"""
Render episode 009 (「丁寧にキレる。」#8 — paid-leave loyalty test).

Full two-round spicy flow: boss interrogates the leave reason and pressures a
date change → inner monologue → transformation R1 → 「チーム」 guilt-trip →
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

SCENE = "paid-leave"

# Round 1 — reply to the leave interrogation (chat context = steps 1-2)
R1_DRAFT   = "私用なので理由は言いません。有給の日程も変えません。"
R1_RESULT  = "私用のため詳細は控えさせていただきます。業務は事前に引き継ぎますので、申請どおりの日程で休暇を取得いたします。"

# Round 2 — reply to the 「チームのこと」 guilt-trip (chat context = steps 1-4)
R2_DRAFT   = "引き継ぎはします。休暇の日程は変えません。"
R2_RESULT  = "チームへの影響を考え、必要な引き継ぎは事前に完了いたします。休暇の日程に変更はございません。"

# (template, base-params, caption)
SLIDES = [
    (LINE, {"scene": SCENE, "step": "0", "hook": "有給の使い道まで、\n上司に審査される", "hooktag": "丁寧にキレる。"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "有給の理由も、日程も、上司が決めるの？"),
    (LINE, {"scene": SCENE, "step": "2", "innervoice": "休む理由までお前に審査されるんですか？"}, ""),
    (LINE, {"scene": SCENE, "step": "2"}, "あなたなら、何て返す？"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "2", "draft": R1_DRAFT}, "理由は言わない。日程も変えない"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "2", "draft": R1_DRAFT, "result": R1_RESULT}, "休暇の取得は、丁寧に伝えられる"),
    (LINE, {"scene": SCENE, "step": "4"}, "丁寧に伝えても、「チーム」で責められた"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "4", "draft": R2_DRAFT}, "引き継ぎはする。日程は変えない"),
    (PROD, {"state": "result",  "scene": SCENE, "step": "4", "draft": R2_DRAFT, "result": R2_RESULT}, "言い方は丁寧。休暇は譲らない"),
    (LINE, {"scene": SCENE, "step": "5"}, "引き継ぎはする。休む理由の審査は受けない。敬語ボタンで、言いたいことを丁寧に。"),
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
