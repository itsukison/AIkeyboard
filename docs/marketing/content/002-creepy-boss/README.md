# Post 002 — 「丁寧にキレる。」#1 セクハラ上司

First episode of the 丁寧にキレる。 series (`../../gtm/spicy-content-bank.md` §1).
Full two-round flow: a creepy boss crosses a line, the inner monologue is furious,
敬語ボタン turns it into a firm-but-polite boundary, the boss brushes it off, and the
final reply holds the line even harder.

The angry line (心の声) and the app input are deliberately different beats: the
inner voice is「まじ黙れよこの豚」, but the draft typed into the keyboard expresses the
actual intent so the rewrite has real meaning to preserve.

## Slides (11)

Empty composer → violation fills in → 心の声 overlay → viewer question →
R1 draft→result → reply + boss comeback → R2 draft→result → final boundary + CTA.
See `build.py` `SLIDES` for the exact per-slide params and captions.

## Drafts → rewrites

The drafts and their rewrites are authored to the shipped app's output rules, so the
`RESULT` strings in `build.py` are the displayed candidates as-is:

- R1: `二人で飲みに行くのは嫌です。仕事と関係ない質問もやめてください。`
- R2: `固くないです。本気で言ってます。業務以外の連絡はやめてください。`

## Caption

> 上司からの、朝イチのLINE。
> 本音は「まじ黙れよ」。でも、それは送れない。
> 敬語ボタンで、拒否は一切撤回せず、言い方だけ変えました。
> 言い方は丁寧。中身は一歩も引いてない。
> これ、気にしすぎ？それとも普通にアウト？
> 返しづらかった上司・取引先のLINEをコメントで教えてください。次回、敬語にします。
>
> ※会話はすべてフィクションです
> #敬語 #セクハラ #職場あるある #社会人 #上司 #丁寧にキレる #AIキーボード

## Exports

- TikTok: 1080 × 1920 — `render/tiktok/{cap,clean}/01–11.png`
- Instagram: 1080 × 1350 — `render/instagram/{cap,clean}/01–11.png`

## Template audit (2026-07-23)

First automated post; it exposed four product-frame problems, all fixed in the
shared templates (see `../../templates/product-ui/README.md` §Keyboard sizing for
the standing rules future episodes must keep):

- Keyboard tray rendered 1:1 from a 19.5:9 reference — too tall on 16:9, and on
  Instagram it ate ~65% of the frame. Tray now zoomed: ×0.8 TikTok, ×0.62 Instagram.
- Tray height differed between draft and result slides (and the composer vanished
  in result state), so the layout jumped. Tray is now a fixed height in both
  states and the composer stays with the draft — matching the shipped app.
- Chat text was small: bubbles 37→40 px, composer draft 38→41 px (both templates).
- `product-ui.html` had no Instagram compression at all; it now mirrors
  `line-chat.html`'s compact Instagram chrome.
- Follow-up: the tray zoom also shrank the result card. The card is now exempt —
  it renders at true reference size (890 px wide, 40 px text) while the keys stay
  scaled, funded by tightening overlay whitespace. Result copy must stay ≤ ~75
  chars or Instagram's capped card clips it.

The conversation is fictional and uses a generic chat interface, not LINE branding
or a real private conversation. The disclosure lives in the caption, not the artwork.
