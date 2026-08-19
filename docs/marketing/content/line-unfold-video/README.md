# LINE unfold video

A deterministic 1080 × 1920 video template inspired by the progressive chat
reveal format. The whole message rhythm is visible as blank bubbles from the
opening frame; each bubble then receives its text in order.

Approved concepts and production scripts live in one bank per account:

- `CONTENT-BANK.md` — **Saya**, lane 金銭・不公平. It also holds the shared story
  contract all three banks obey: the product-image rule, the keyboard-native
  use-case test, and the page budgets.
- `BANK-YURI.md` — **yuri_keigo**, lane 送ってしまった後. An anthology since
  2026-08-11; the serial ran #1–#18 and is closed.
- `BANK-NATSUMI.md` — **natsumi**, lane 職場の理不尽 (re-pointed 2026-08-11 from
  the 恋が壊れる時 stage).

All three are anthologies now: standalone episode, new teller each time, three
pages, product image late on page 2. See §The three accounts.

Each bank owns its own tree and its own numbering: Saya is `posts/NNN-slug/`,
yuri is `posts/yuri/NNN-slug/`, natsumi is `posts/natsumi/NNN-slug/`. `build.py`
takes an optional one-level bank prefix — `python3 build.py yuri/001-misfire`,
`python3 build.py natsumi/001-<slug>`.

A page holds at most 12 messages and a post at most **4 pages** (enforced in
`build.py`). Every current episode uses 3. natsumi 001–006 used 4 under the old
product-at-the-end format; that shape is retired.

This is a separate experiment from the fictional LINE-story slideshow. Do not
put its posts into `line-story/episodes/` or publish them through that format's
automation.

## The three accounts

**Decided by Itsuki 2026-08-11. This is the top-level editorial map — read it
before writing for any account. It replaces the 2026-08-09 relationship-stage
split entirely; that map is gone, not amended.**

The accounts are split by **conflict type** — specifically by what the comment
section will argue about. Everything else (shape, product placement, ending) is
now identical across the three, because the evidence said the differences that
mattered were in the story, not in the packaging.

| | **Saya** (mari040715) | **yuri** (yuri_keigo) | **natsumi** (keigobutton) |
|---|---|---|---|
| Lane | **金銭・不公平** | **送ってしまった後** | **職場の理不尽** |
| 争点 | 奢る／割り勘／誠意 | 事故として許されるか | 新人が悪いか上司が悪いか |
| 中身 | カップル・友人・家族間のお金 | 誤爆、酔い、既読、送信済みの後始末 | 上司、取引先、時間外、評価 |
| Shape | アンソロジー | **アンソロジー**（連載は #18 で終了） | アンソロジー |
| 語り手 | 追い詰められる側 | 取り返しがつかない側 | 立場が弱い側 |
| 製品の位置 | 3ページ中の2、後半 | 同左 | 同左 |
| 主なコマンド | **自然に** | 敬語／自然に | 敬語／英訳 |
| 終わり方 | 答える前に切る | 同左 | 同左 |
| Pages | 3 | 3 | 3 |
| Platform | Zernio | Zernio | **Buffer** |
| Grid (JST) | 09:00 / 15:00 / 21:00 | 12:00 / 19:00 / 22:00 | 10:00 / 16:00 / 22:00 |

### なぜ変えたか — 根拠

- **語り手が勝つ話にはコメントがつかない。** Saya は 8/1–8/10 で median 1,556
  views と yuri とほぼ同じリーチなのに、like 率は **0.44% 対 1.07%**（ruka の
  app-intro は 2.68%）。届いてはいるが、誰も反応しない。勝利譚をやめて
  **どちらが正しいか割れる話**に変えたのはこのため。
- **連載はエントリーポイントがない。** yuri は #1 が 19,346 views、そこから
  #3 8,940 → #6 1,399 → #12 94 と単調減衰。#1 が強かったのは誤爆が単体で
  成立するからで、連載だからではない。以後は**毎話が誰かの #1** になる読み切りにする。
- **非恋愛を締め出したのは早すぎた。** 全アカウント通算の上位3本は
  42,150（新卒の謝罪＝職場）・38,502（元カノの結婚式）・30,364（外国人同僚への
  英語謝罪＝職場）。3本中2本が、8/09 の方針が禁止した職場ものだった。natsumi を
  職場レーンに戻したのはこの数字による。

### 全レーン共通の作法（reference viral story より）

1. **争点を必ず持たせる。** 両方に言い分がある対立にする。悪役が明確な話は
   コメントが伸びない。
2. **エスカレーションは寄る、上げない。** 温泉12万 → 毎週のご飯 → **180円のアイス**。
   小さい方が刺さる。金額を上げていく構成は逆効果。
3. **吹き出しは一息ぶん。** 「いやいや(笑)」「普通にさ」。完成した文を書かない。
4. **相手役は一度は語り手を否定する。** 友人はコメント欄の代理人。
   「…それは言われるわ」が入っていない回は、争点が立っていない。
5. **答えを見せずに切る。** 最後の吹き出しは語り手が答えを迫られているところ。
6. 各アカウントは1本でも見れば「何のアカウントか」がわかること。
7. **同じ twist を2アカウントで使わない。**

### この改訂が捨てたもの（正直に記録）

- 2026-08-09 の「製品の位置だけが違う A/B」は**完全に放棄**した。natsumi の
  product-at-the-end 配置は 6 話で median 502 views にとどまり、比較として成立する
  前に打ち切っている。配置単体の効果は依然として未測定で、測るなら**同一アカウント内**
  でやること。
- 旧方針で書かれた既存回（Saya 001 / 007 / 014 / 015 / 016、natsumi 001–006、
  yuri 連載 001–018）は**取り下げていない**。公開済み・予約済みのものはそのまま流す。
  ただし新作のモデルにはしない。

## Visual contract

- 1080 × 1920, 30 fps H.264 MP4.
- LINE-blue conversation field (`#8FAED2`).
- Incoming bubbles are white; outgoing bubbles use LINE green (`#84E26F`).
- No avatar, chat header, LINE wordmark, copyrighted sticker, or real identity.
- All future bubbles remain visible as empty silhouettes. Revealed copy appears
  in-place without changing the bubble geometry.
- TikTok supplies its own search, progress, and navigation chrome. None of it is
  baked into the exported video.
- Keep the top and bottom safe areas free of messages for TikTok's overlays.
- **A bubble holds 564px of text (620px max-width − 28px padding each side)
  before wrapping — roughly 16 full-width Japanese characters.** Longer text
  wraps to a second line inside the bubble.

### Text must never leave the bubble (fixed 2026-08-09)

The template used `white-space: pre`, which meant bubbles **never wrapped** and
`max-width: 620px` was silently ignored: any line over 564px ran straight off the
right edge of the 1080px frame. 25 bubbles across the library shipped that way
before it was caught — the worst was 833px, nearly 270px past the edge.

Fixed by `white-space: pre-wrap` + `overflow-wrap: anywhere` on `.bubble`, so
long text now wraps like real LINE. Explicit `\n` still works. **Do not put
`white-space: pre` back.**

`build.py` now prints a `wraps to 2 lines:` line per over-width bubble at build
time. Wrapping is legal, so this is a notice and not a failure — but a bubble
that wraps is usually better rewritten shorter, because the format's rhythm
depends on short bubbles. Check the notice against the rendered page before
shipping; a page whose bubbles all wrap will run into the bottom safe area.

## Input

Each `posts/NNN-slug/post.json` owns the duration and one to four conversation
pages. A text message specifies `side`, `text`, and `time`. The browser measures
the invisible future text so every blank silhouette already has its final
content-fitted size. An image message adds `type: image`, a local `src`, and its
display dimensions.

`productAssets` can render the audited `line-story` product-result UI into a
local image before the chat frames are captured. Use this for the single proof
image rather than building another app mockup. An asset may set `cropTop` (default
1105) when a multi-line `draft` wraps and lifts the composer above the default
crop line; the crop always runs from `cropTop` to the bottom of the 1920 px frame,
so the message's `width`/`height` must keep that aspect ratio.

A page carrying the product image fits noticeably fewer text messages than the
12-message schema ceiling — budget roughly 8. The validator only enforces the
ceiling, so check the rendered page for bottom clipping.

`001-visual-prototype` contains placeholder copy from the supplied reference.
`001-foreign-girlfriend` is the first production draft; it is not approved for
publication until its AI result is verified in the shipping app.

## BGM

Neither Buffer nor Zernio can attach a TikTok library sound to a **video** —
TikTok's Content Posting API exposes no sound-selection field, and its
`auto_add_music` flag is photo-carousel only. Music therefore has to be baked
into the master, and the same master serves TikTok and Instagram.

Drop cleared track files into `bgm/` and the build mixes one in automatically;
see `bgm/README.md` for selection, processing, and the licensing rule. An empty
pool produces a silent video, which is the pre-existing behaviour.

Pin `"bgm": "<filename>"` in `post.json` once a post is approved, so a later
pool edit cannot change the audio of an already-reviewed video.

## Publishing

Verified working 2026-08-05. The `marketing-media` bucket accepted `video/mp4`
after that MIME type was added to its allowlist (it previously rejected uploads
with `InvalidMimeType`); the 5 MB per-object cap is untouched and these videos
are ~1.2 MB.

```bash
# anthology
supabase storage cp posts/<slug>/render/line-unfold.mp4 \
  ss:///marketing-media/tiktok/line-unfold-<slug>.mp4 --linked --experimental

# yuri serial — separate folder so the two accounts' media never mix
supabase storage cp posts/yuri/<slug>/render/line-unfold.mp4 \
  ss:///marketing-media/tiktok/yuri-serial/<slug>.mp4 --linked --experimental

# natsumi anthology — its own folder for the same reason
supabase storage cp posts/natsumi/<slug>/render/line-unfold.mp4 \
  ss:///marketing-media/tiktok/natsumi/<slug>.mp4 --linked --experimental
```

The public URL is then passed straight to Zernio as a video media item — Zernio
auto-proxies Supabase storage URLs, so no presign or browser upload is needed:

```text
https://eercsucvxnszqletxued.supabase.co/storage/v1/object/public/marketing-media/tiktok/line-unfold-<slug>.mp4
```

Note that Zernio's MCP only exposes the *browser* upload flow
(`media_generate_upload_link`), which is manual per file. The Supabase route
above is the automatable one — prefer it.

Before publishing anything, confirm the URL returns `200` with
`content-type: video/mp4`; a bucket misconfiguration surfaces as an HTML error
page, which Zernio rejects.

## Render

```bash
python3 docs/marketing/content/line-unfold-video/build.py 001-foreign-girlfriend
```

Outputs:

```text
posts/001-foreign-girlfriend/render/preview.png
posts/001-foreign-girlfriend/render/preview-page-1.png ...
posts/001-foreign-girlfriend/render/states/p01-00.png ...
posts/001-foreign-girlfriend/render/line-unfold.mp4
```

The build requires Chrome and ffmpeg. It snapshots one deterministic frame per
reveal state, then holds each state for the configured interval. No asset is
uploaded or published.
