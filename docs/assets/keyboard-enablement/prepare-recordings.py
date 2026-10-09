"""Prepare the real iOS Settings recordings for the existing floating player.

Requires Pillow and ffmpeg at build time only. Settings pixels come exclusively
from the captured simulator movies and verified final-state screenshots.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import io
import subprocess

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(__file__).parent / 'recordings-2026-10-08'
OUT = ROOT / 'iOS/Container/Resources/Videos'
SIZE = (666, 990)
FPS = 30
FRAME_BYTES = SIZE[0] * SIZE[1] * 3
CROP = 'crop=1206:1792:0:160,scale=666:990'
FONT = '/System/Library/Fonts/ヒラギノ角ゴシック W5.ttc'
ZH_FONT = '/System/Library/Fonts/STHeiti Medium.ttc'
COPY = {
    'ja': ('1.「キーボード」をタップ', '2.「敬語ボタン」をオン',
           '設定完了。アプリに戻って練習', '「フルアクセスを許可」をオン',
           '設定完了。アプリに戻る'),
    'en': ('1. Tap Keyboards', '2. Turn 敬語ボタン on',
           'Setup complete. Return to practice', 'Turn Allow Full Access on',
           'Setup complete. Return to the app'),
    'zh-Hans': ('1. 轻点「键盘」', '2. 开启「敬語ボタン」',
                '设置完成。返回应用开始练习', '开启「允许完全访问」',
                '设置完成。返回应用'),
}
TIMES = {
    ('enable', 'en'): (0, (3.3, 4.1), 4.5, (7.6, 8.3)),
    ('enable', 'ja'): (0, (6.7, 7.7), 8.4, (9.9, 11.1)),
    ('enable', 'zh-Hans'): (0, (5.7, 6.6), 7.5, (10.6, 11.3)),
    ('full-access', 'en'): (0.6, (3.1, 4.1), 4.8, (6.4, 7.5), 8.5),
    ('full-access', 'ja'): (1, (4.5, 6.3), 7.0, (8.5, 9.8), 10.5),
    ('full-access', 'zh-Hans'): (0, (3.9, 4.7), 5.2, (8.1, 9.2), 10.0),
}


def still(path, time=None, framing=CROP):
    cmd = ['ffmpeg', '-v', 'error']
    if time is not None:
        cmd += ['-ss', str(time)]
    data = subprocess.check_output(cmd + ['-i', str(path), '-frames:v', '1',
        '-vf', framing, '-f', 'image2pipe', '-vcodec', 'png', '-'])
    return Image.open(io.BytesIO(data)).convert('RGB')


def transition(path, bounds, seconds=0.5, framing=CROP):
    start, end = bounds
    filters = f'setpts=(PTS-STARTPTS)*{seconds / (end-start)},fps={FPS},{framing}'
    data = subprocess.check_output(['ffmpeg', '-v', 'error', '-ss', str(start),
        '-t', str(end-start), '-i', str(path), '-vf', filters,
        '-frames:v', str(round(seconds*FPS)), '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'])
    frames = [Image.frombytes('RGB', SIZE, data[i:i+FRAME_BYTES])
              for i in range(0, len(data), FRAME_BYTES)]
    if not frames:
        raise RuntimeError(f'No transition frames: {path}, {bounds}')
    for i in range(round(seconds*FPS)):
        yield frames[min(i, len(frames)-1)]


def annotate(frame, caption, target, language, caption_y=937):
    frame = frame.copy()
    draw = ImageDraw.Draw(frame)
    if target:
        draw.rounded_rectangle(target, radius=28, outline='#6e5be5', width=5)
    if caption:
        font = ImageFont.truetype(ZH_FONT if language == 'zh-Hans' else FONT, 29)
        while draw.textlength(caption, font=font) > 606:
            font = ImageFont.truetype(font.path, font.size-1)
        width = draw.textlength(caption, font=font)
        bounds = draw.textbbox((0, 0), caption, font=font)
        height = bounds[3]-bounds[1]
        left = (666-width)/2
        top = caption_y-height/2
        overlay = Image.new('RGBA', SIZE)
        subtitles = ImageDraw.Draw(overlay)
        subtitles.rounded_rectangle((left-16, top-12, left+width+16, top+height+12),
                                    radius=12, fill=(0, 0, 0, 190))
        subtitles.text((left, top-bounds[1]), caption, font=font, fill='white')
        frame = Image.alpha_composite(frame.convert('RGBA'), overlay).convert('RGB')
    return frame


def prepare(kind, language):
    path = SOURCE / f'{kind}-{language}.mov'
    first, navigation, before, change, *warning = TIMES[kind, language]
    copy = COPY[language]
    enablement = kind == 'enable'
    prefix = 'keyboard-enable' if enablement else 'keyboard-setup'
    target = OUT / f'{prefix}-{language}.mp4'
    ending = still(SOURCE / f'full-access-{language}-end.png')
    def green(frame, point):
        red, green, blue = frame.getpixel(point)
        return green > 130 and green > red+40 and green > blue+40
    if not green(ending, (520, 178)) or not green(ending, (520, 264)):
        raise RuntimeError(f'Incorrect final permission state: {kind}, {language}')
    if enablement:
        added = still(SOURCE / f'enable-{language}-end.png')
        if not green(added, (520, 178)) or green(added, (520, 264)):
            raise RuntimeError(f'Incorrect intermediate permission state: {language}')
    command = ['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pixel_format', 'rgb24',
        '-video_size', '666x990', '-framerate', str(FPS), '-i', 'pipe:0', '-an',
        '-c:v', 'libx264', '-crf', '21', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(target)]
    with subprocess.Popen(command, stdin=subprocess.PIPE) as encoder:
        def hold(frame, seconds, caption=None, marker=None, marker_from=0, caption_y=937):
            for i in range(round(seconds*FPS)):
                decorated = annotate(frame, caption,
                    marker if i/FPS >= marker_from else None, language, caption_y)
                encoder.stdin.write(decorated.tobytes())

        hold(still(path, first), 2, copy[0], (27, 428, 638, 519), marker_from=0.7)
        for frame in transition(path, navigation):
            encoder.stdin.write(frame.tobytes())
        switch = (492, 142, 624, 211) if enablement else (492, 229, 624, 297)
        hold(still(path, before), 2, copy[1] if enablement else '2. ' + copy[3], switch, marker_from=0.7)
        for frame in transition(path, change):
            encoder.stdin.write(frame.tobytes())
        if enablement:
            path = SOURCE / f'full-access-{language}.mov'
            _, _, before, change, *warning = TIMES['full-access', language]
            hold(still(path, before), 2, '3. ' + copy[3], (492, 229, 624, 297), marker_from=0.7)
            for frame in transition(path, change):
                encoder.stdin.write(frame.tobytes())
        # Keep the complete system notice visible; no caption covers it.
        hold(still(path, warning[0]), 5, marker=(341, 804, 578, 900), marker_from=4)
        hold(ending, 3, copy[2] if enablement else copy[4])
        encoder.stdin.close()
        if encoder.wait() != 0:
            raise RuntimeError(f'Encoding failed: {target}')
    print(target)


if __name__ == '__main__':
    for language in COPY:
        for kind in ('enable', 'full-access'):
            prepare(kind, language)
