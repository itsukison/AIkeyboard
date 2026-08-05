#!/usr/bin/env python3
import argparse
import re
import subprocess
from pathlib import Path

PROJECT_REF = "eercsucvxnszqletxued"
BUCKET = "marketing-media"
PUBLIC_BASE = (
    f"https://{PROJECT_REF}.supabase.co/storage/v1/object/public/{BUCKET}/tiktok"
)


def dimensions(path: Path) -> tuple[int, int]:
    result = subprocess.run(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    width = re.search(r"pixelWidth: (\d+)", result.stdout)
    height = re.search(r"pixelHeight: (\d+)", result.stdout)
    if not width or not height:
        raise RuntimeError(f"Could not read dimensions: {path}")
    return int(width.group(1)), int(height.group(1))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("episode", type=Path)
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--render-subdir", default="render/instagram/cap")
    parser.add_argument("--expected-height", type=int, default=1350)
    parser.add_argument("--remote-slug")
    args = parser.parse_args()

    episode = args.episode.resolve()
    source = episode / args.render_subdir
    files = sorted(source.glob("*.png"))
    if not files:
        raise SystemExit(f"No PNG slides found in {source}")
    if len(files) > 10:
        raise SystemExit(f"TikTok Photo Mode allows at most 10 slides; found {len(files)}")

    expected_names = [f"{index:02d}.png" for index in range(1, len(files) + 1)]
    if [path.name for path in files] != expected_names:
        raise SystemExit("Slides must be consecutively named 01.png, 02.png, ...")

    for path in files:
        size = dimensions(path)
        if size != (1080, args.expected_height):
            raise SystemExit(
                f"{path.name} is {size[0]} × {size[1]}, "
                f"expected 1080 × {args.expected_height}"
            )

    slug = args.remote_slug or episode.name
    if args.validate_only:
        print(f"Validated {len(files)} slides for {slug}")
        return

    destination = f"ss:///{BUCKET}/tiktok/{slug}"
    subprocess.run([
        "supabase",
        "storage",
        "cp",
        "-r",
        str(source),
        destination,
        "--linked",
        "--experimental",
        "--content-type",
        "image/png",
        "--cache-control",
        "max-age=31536000",
    ], check=True)

    for path in files:
        print(f"{PUBLIC_BASE}/{slug}/{path.name}")


if __name__ == "__main__":
    main()
