#!/usr/bin/env python3
"""
Render episode 003 (「丁寧にキレる。」#2 — Saturday work request).

Full two-round spicy flow: weekend violation → inner monologue → transformation R1
→ boss invents a Monday-morning deadline → transformation R2 → final boundary.

Produces, for each slide, four PNGs: {tiktok,instagram} x {cap,clean}.

Run:  python3 build.py
"""
import subprocess
import urllib.parse
from pathlib import Path

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
HERE = Path(__file__).resolve().parent
TEMPLATES = HERE.parents[1] / "templates"
LINE = (TEMPLATES / "line-chat" / "line-chat.html").as_uri()
PROD = (TEMPLATES / "product-ui" / "product-ui.html").as_uri()
OUT = HERE / "render"

SCENE = "saturday-work"

R1_DRAFT = "休日なので今日は対応しません。月曜日に確認します。"
R1_RESULT = "ご連絡ありがとうございます。本件は月曜日に確認のうえ、対応いたします。休日中は即時の対応が難しいため、緊急の場合は事前にご相談いただけますと幸いです。"

R2_DRAFT = "朝イチでできるとは言ってません。月曜の出社後に確認します。"
R2_RESULT = "月曜日の始業後に確認し、対応いたします。内容を確認のうえ、完了見込みをご連絡いたします。"

SLIDES = [
    (LINE, {"scene": SCENE, "step": "0", "hook": "土曜 朝7:04、\n上司からLINE", "hooktag": "丁寧にキレる。"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, "「月曜でいいから」が、いちばん怖い"),
    (LINE, {"scene": SCENE, "step": "1", "innervoice": "月曜でいいなら月曜に送れよ"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, "休日の上司LINE、既読つける？"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "1", "draft": R1_DRAFT}, "休みなので、今日はやりません"),
    (PROD, {"state": "result", "scene": SCENE, "step": "1", "draft": R1_DRAFT, "result": R1_RESULT}, "休日対応は、丁寧に断る"),
    (LINE, {"scene": SCENE, "step": "3"}, "月曜でいいはずが、朝イチになった"),
    (LINE, {"scene": SCENE, "step": "3", "innervoice": "朝イチを追加するな"}, ""),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "3", "draft": R2_DRAFT}, "朝イチでできるとは言ってない"),
    (PROD, {"state": "result", "scene": SCENE, "step": "3", "draft": R2_DRAFT, "result": R2_RESULT}, "出社後に確認。勝手な締切は引き受けない"),
    (LINE, {"scene": SCENE, "step": "4"}, "休日まで働かなくていい。敬語ボタンで、言いたいことを丁寧に。"),
]

FORMATS = {"tiktok": 1920, "instagram": 1350}


def render(url, path, height):
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
        "--allow-file-access-from-files",
        "--force-device-scale-factor=1", f"--window-size=1080,{height}",
        f"--screenshot={path}", url,
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    for fmt, height in FORMATS.items():
        for index, (template, params, caption) in enumerate(SLIDES, 1):
            for variant, extra in (("clean", {}), ("cap", {"caption": caption} if caption else {})):
                query = {**params, "format": fmt, **extra}
                url = f"{template}?{urllib.parse.urlencode(query)}"
                render(url, OUT / fmt / variant / f"{index:02d}.png", height)
                print(f"  {fmt}/{variant}/{index:02d}.png")
    print(f"\nDone → {OUT}")


if __name__ == "__main__":
    main()
