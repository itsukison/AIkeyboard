#!/usr/bin/env python3
import argparse
import subprocess
import tempfile
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("post", type=Path)
    args = parser.parse_args()

    post = args.post.resolve()
    source = post / "render" / "instagram" / "cap"
    slides = sorted(source.glob("*.png"))
    if not slides:
        raise SystemExit(f"No PNG slides found in {source}")
    if [path.name for path in slides] != [f"{i:02d}.png" for i in range(1, len(slides) + 1)]:
        raise SystemExit("Slides must be consecutively named 01.png, 02.png, ...")

    output = post / "render" / "instagram" / "reel" / "reel.mp4"
    output.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.NamedTemporaryFile("w", suffix=".ffconcat") as manifest:
        manifest.write("ffconcat version 1.0\n")
        for index, slide in enumerate(slides):
            manifest.write(f"file '{slide}'\n")
            manifest.write(f"duration {2.0 if index == 0 else 1.35}\n")
        manifest.write(f"file '{slides[-1]}'\n")
        manifest.flush()
        subprocess.run([
            "ffmpeg",
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", manifest.name,
            "-vf",
            "scale=1080:1350,split=2[fg][bg];"
            "[bg]scale=1080:1920:force_original_aspect_ratio=increase,"
            "crop=1080:1920,gblur=sigma=38[blur];"
            "[blur][fg]overlay=0:(H-h)/2,format=yuv420p,fps=30",
            "-c:v", "libx264",
            "-profile:v", "high",
            "-level", "4.1",
            "-crf", "18",
            "-movflags", "+faststart",
            "-an",
            str(output),
        ], check=True)

    print(output)


if __name__ == "__main__":
    main()
