#!/usr/bin/env python3
"""Render episode 014 (「丁寧にキレる。」— sick-day pressure)."""
import subprocess
import urllib.parse
from pathlib import Path

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
HERE = Path(__file__).resolve().parent
TEMPLATES = HERE.parents[1] / "templates"
LINE = (TEMPLATES / "line-chat" / "line-chat.html").as_uri()
PROD = (TEMPLATES / "product-ui" / "product-ui.html").as_uri()
OUT = HERE / "render" / "instagram" / "cap"

SCENE = "sick-day-spicy"
R1_DRAFT = "体調が悪いので今日は休みます。出社は無理です。"
R1_RESULT = "発熱があり、感染拡大を防ぐため、本日は休ませていただきます。受診後、今後の勤務について改めてご報告いたします。"
R2_DRAFT = "人手不足でも今日は出社しません。受診後に連絡します。"
R2_RESULT = "申し訳ありませんが、本日は出社いたしかねます。受診後、今後の勤務について改めてご報告いたします。"

SLIDES = [
    (LINE, {"scene": SCENE, "step": "0", "hook": "37.8度でも\n出社しろと言う上司", "hooktag": "丁寧にキレる。"}, ""),
    (LINE, {"scene": SCENE, "step": "1"}, "37.8度で「来れるよね？」"),
    (LINE, {"scene": SCENE, "step": "1", "innervoice": "じゃあお前の隣で\n一日中咳してやるよ"}, ""),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "1", "draft": R1_DRAFT}, "「休んでもいいですか？」ではなく「本日は休みます」"),
    (PROD, {"state": "result", "scene": SCENE, "step": "1", "draft": R1_DRAFT, "result": R1_RESULT}, "体調と対応を、丁寧にはっきり伝える"),
    (LINE, {"scene": SCENE, "step": "3"}, "それでも「午前だけでも無理？」"),
    (PROD, {"state": "toolbar", "scene": SCENE, "step": "3", "draft": R2_DRAFT}, "人手不足でも、発熱は消えない"),
    (PROD, {"state": "result", "scene": SCENE, "step": "3", "draft": R2_DRAFT, "result": R2_RESULT}, "言い方は丁寧。欠勤は撤回しない"),
    (LINE, {"scene": SCENE, "step": "4"}, "37.8度で「来れる？」普通？アウト？"),
    (LINE, {"scene": SCENE, "step": "4", "cta": "1", "ctatag": "丁寧にキレる。"}, ""),
]


def render(url, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        CHROME,
        "--headless",
        "--disable-gpu",
        "--hide-scrollbars",
        "--allow-file-access-from-files",
        "--force-device-scale-factor=1",
        "--window-size=1080,1350",
        f"--screenshot={path}",
        url,
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    for index, (template, params, caption) in enumerate(SLIDES, 1):
        extra = {"caption": caption} if caption else {}
        query = {**params, "format": "instagram", **extra}
        url = f"{template}?{urllib.parse.urlencode(query)}"
        path = OUT / f"{index:02d}.png"
        render(url, path)
        print(path.relative_to(HERE))


if __name__ == "__main__":
    main()
