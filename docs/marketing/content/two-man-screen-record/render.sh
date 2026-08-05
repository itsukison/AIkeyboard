#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ASSETS_DIR="$SCRIPT_DIR/assets"
OUTPUT_DIR="$SCRIPT_DIR/output"
CAPTION_DIR="$OUTPUT_DIR/captions"
NODE_BIN="/Users/itsukison/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
NODE_MODULES="/Users/itsukison/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules"

mkdir -p "$CAPTION_DIR"

NODE_PATH="$NODE_MODULES" "$NODE_BIN" "$SCRIPT_DIR/render-captions.mjs" "$CAPTION_DIR"

ffmpeg -y \
  -i "$ASSETS_DIR/higgsfield-opener.mp4" \
  -loop 1 -i "$CAPTION_DIR/opener-junior.png" \
  -loop 1 -i "$CAPTION_DIR/opener-senior.png" \
  -filter_complex \
  "[0:v]fps=30,scale=720:1280,format=yuv420p[base]; \
   [base][1:v]overlay=0:0:enable='between(t,0.35,3.50)'[v1]; \
   [v1][2:v]overlay=0:0:enable='between(t,3.65,5.85)'[vout]" \
  -map "[vout]" -map 0:a \
  -t 6.06 -c:v libx264 -preset medium -crf 18 \
  -c:a aac -b:a 192k -ar 44100 -ac 2 -movflags +faststart \
  "$OUTPUT_DIR/opener-captioned.mp4"

ffmpeg -y \
  -i "$OUTPUT_DIR/opener-captioned.mp4" \
  -i "$ASSETS_DIR/finalcontent.MOV" \
  -filter_complex \
  "[0:v]fps=30,scale=720:1280,setsar=1[v0]; \
   [1:v]fps=30,scale=720:1280:force_original_aspect_ratio=decrease, \
       pad=720:1280:(ow-iw)/2:(oh-ih)/2:black,setsar=1[v1]; \
   [0:a]aresample=44100:async=1:first_pts=0[a0]; \
   [1:a]acompressor=threshold=-24dB:ratio=4:attack=20:release=250:makeup=8, \
       loudnorm=I=-16:TP=-1.5:LRA=11,aresample=44100:async=1:first_pts=0[a1]; \
   [v0][a0][v1][a1]concat=n=2:v=1:a=1[vout][aout]" \
  -map "[vout]" -map "[aout]" \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -ar 44100 -movflags +faststart \
  "$OUTPUT_DIR/two-man-hook-final.mp4"
