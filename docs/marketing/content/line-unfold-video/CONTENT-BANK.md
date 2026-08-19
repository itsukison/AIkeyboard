# LINE unfold video — Saya anthology bank

Owner: Itsuki. Account: **Saya (mari040715)** + Instagram. Status: concepts
approved; production copy drafted. Product result copy is **story content and
needs no shipping-app verification** (Itsuki, 2026-08-05 — see the product-image
rule below).

## このアカウントの担当範囲 —「金銭・不公平」（Itsuki, 2026-08-11）

**Saya はお金をめぐる対立だけを書く。** カップル、友人、家族、兄弟。
奢る／割り勘／立て替え／分担。語り手はたいてい**追い詰められる側**で、
勝たない。製品は 3 ページ中の 2 ページ目後半に出る。

**必須条件は「争点があること」。** 両方に言い分がある対立でなければ書かない。
片方が明らかに悪い話はコメントが伸びないので、この口座の題材ではない。

**書かないもの**：金銭が絡まない純粋な恋愛の駆け引き、誤爆・送信事故（yuri）、
職場の上下関係（natsumi）。

これは 2026-08-09 の「恋が始まる前・語り手は勝つ」から**差し替え**。理由と数字は
`README.md` §The three accounts §なぜ変えたか。旧方針で書かれた `001`–`025` は
取り下げないが、**新作のモデルにはしない**。

This file owns the **anthology**: standalone episodes with a new teller and a
closed ending each time, used to test which scenarios convert. Each story uses
three sequential chat pages. The first page establishes a dramatic problem, the
second reveals the real product in context, and the third rewards completion with
a punchline or reversal.

**The draft has to be unsendable.** A draft that is merely casual makes the product
look like it did nothing — 「めっちゃ楽しかったです〜」→「とても楽しかったです」 is not a
demo. Write a draft that would end the relationship if it were sent, then let the
result be a faithful rewrite of *that*. Full rule and examples: `BANK-YURI.md`
§The draft has to be unsendable. It applies to both banks.

**The other two banks are anthologies too, since 2026-08-11.** `BANK-YURI.md`
(送ってしまった後) and `BANK-NATSUMI.md` (職場の理不尽) are separated from this one
by **lane, not by shape**. Do not move an episode between the files and do not
reuse a twist across them. `posts/NNN-slug/` is this bank's tree; yuri and
natsumi have their own.

The three sections below — **Product-image rule**, **The use case must fit the
product**, and the **page budgets** — are the shared format contract and apply to
both banks. Everything after them is Saya's alone.

## The concept — 「それ、どうやったん？」

**This format is not 丁寧にキレる.** That series belongs to `line-story` and is
owned by `../../gtm/spicy-content-bank.md`. Keep the two separate: do not write
episodes here to that framework, and do not move episodes between the banks.

| | `line-story` — 丁寧にキレる | `line-unfold` — それ、どうやったん？ |
|---|---|---|
| Engine | Receive outrage, hold a boundary | Be accused of something you half did |
| Tense | Present — it is happening now | **Present — it is happening now** |
| Antagonist | On screen, being answered | Offscreen, quoted verbatim in 「」 |
| Second character | The person wronging you | A friend who takes the other side |
| Payoff | The boundary holds | A twist that reveals the accuser's reason |
| Product role | Converts anger into something sendable | The reply the teller cannot write alone |

**Revised 2026-08-11: this format is live, not a retelling.** The old framing —
past tense, 「それ、どうやったん？」, a skeptic refusing to believe it — put a layer
of distance between the viewer and the drama, and it correlates with the worst
like rate on any account (0.44%). The confrontation now happens *during* the
thread: the antagonist's messages are quoted into it in 「」 as they arrive, and
the teller is answering in real time.

**The friend is the comment section, not a sidekick.** They have to side against
the teller at least once — 「…それは言われるわ」. An episode where the friend only
supports the teller has no 争点 and will not be argued about.

## Product-image rule

Use one image message per story, late on page 2. The conversation should create
the question before the image answers it.

The image is a real render of the existing result screen from:

```text
../line-story/templates/product-ui/product-ui.html
```

Render with `state=result`, `format=tiktok`, and `chat=off`, then crop the real
keyboard result area into the chat's image-message frame. Reuse this renderer's
audited geometry and shipped light-mode UI; do not create a separate marketing
mockup, send an App Store screenshot, or show only the app icon.

**It is a screenshot of the app, not of the conversation** (Itsuki, 2026-08-06).
What the teller sends is proof of *how they used the app and what for* — the
keyboard's result screen. It is not a capture of the thread with 相手, and the
story never has to claim the pictured draft/result is word-for-word the message
that was sent. So the pictured use **may** be the story's pivotal message (as in
001–017) or simply the teller showing the app; both read as natural. Use that
freedom to keep the product looking general — if every image on an account is the
same kind of message, 敬語ボタン starts to look single-purpose. Two things stay
fixed: the pictured use has to be something the shipping app would really do, and
**the teller's own thread is never converted** — they talk to their friend in raw,
sloppy Japanese, always. A narrator whose bubbles are polished has turned the
video into an ad.

Requirements:

- **The draft/result pair is story content, not a product claim.** Itsuki's
  ruling, 2026-08-05: the result copy is part of the fiction like every other
  bubble, so it does **not** need to be reproduced in the shipping app before
  publication, and shipping-app verification is not a publication gate. Write
  the result to be plausible and in-character for what the command does; that is
  the whole bar. (This replaces the earlier rule requiring verification — which
  had never actually been applied to any episode, including the live 001–007.)
  Episodes carry `"resultCopy": "fiction …"` in their `approval` block to record
  this; the old `resultVerified` flag is retired.
- Keep the result to roughly 75 characters or fewer so it remains readable.
- The keigo episode uses the renderer's existing `敬語` label.
- The translation episode must show the shipped `英訳` label. `product-ui.html`
  now takes the label as a `command` query parameter (added 2026-08-05), so this
  needs no further work — pass `"command": "英訳"` in the post's `productAssets`.
- Show only one product image. The surrounding chat explains the workflow in
  plain language; additional product frames would make the story feel like an
  advertisement.
- **The name 敬語ボタン must be spoken on screen, every episode, without
  exception.** The established beat is the listener asking 「何これ」 and the
  teller answering 「敬語ボタン」 immediately after the image. Budget those two
  bubbles into page 2 before anything else — a page that fits the image but not
  the name has been trimmed in the wrong order. A video that never names the
  product is unpublishable no matter how good the story is.

## The use case must fit the product — read before choosing a situation

**The value proposition is that 敬語ボタン lives inside the keyboard.** It rewrites
in place, in the message field, without leaving the conversation. That is the
whole reason to use it instead of ChatGPT.

So the honest test for any episode is: **would switching to another app have been
absurd here?** It is absurd when the character is mid-conversation, the other
person is waiting, and opening a second app to copy-paste would break the moment.
It is *not* absurd when they are composing something long, alone, with time —
ChatGPT is genuinely fine for that, and an episode built on it quietly argues the
viewer doesn't need this product.

Good: LINE and DM threads, dating-app messages, replies to a boss who is waiting,
anything typed on a phone with someone on the other end.

Bad: speeches, essays, documents, anything drafted over days at a desk.

Never state this in the dialogue — 「アプリ切り替えなくていい」 as a line turns the
episode into a commercial. It should be *structurally* true instead: put the
character in a moment where stopping to open another app obviously isn't an option,
and the advantage lands without being named.

Known violation, published anyway 2026-08-05: **004 元カノの結婚式でスピーチした**.
A speech drafted over three days is the wrong use case — he had a laptop and a
week. The story is strong so it shipped, but do not use it as a model.

## What makes an episode spicy

Measured against 001 and 002, which work. The engine is not cleverness — it is
that **the teller is hiding something and could be exposed.** 001's protagonist
is caught by his 部長; 002's deceived his girlfriend for weeks. The viewer stays
because someone has something to lose.

An episode qualifies when it has all four:

1. **A personal secret**, not a clever tactic. Using the app is slightly shameful
   and the teller would rather nobody knew.
2. **Someone who could find out** — a partner, a parent, a boss, an audience.
3. **A relationship at stake**, not money or admin. Rent reductions and refunds
   are satisfying but nobody follows an account for them.
4. **A twist that changes what the story was about**, usually by revealing the
   other person's side: she could speak Japanese all along; he uses the app too.

Rejected 2026-08-05 for failing this bar: 家賃交渉, 航空会社への返金, 単位の懇願,
フリマ出品, 内定辞退. All were transactional wins with no shame, nobody to be
caught by, and twists about outcomes rather than people.

---

## 001 — 新卒、取引先を怒らせる

### Intent

A new employee uses the wrong keigo in a client email, gets publicly corrected,
and needs to send an apology while her manager is watching. A coworker recommends
敬語ボタン as an immediate rescue. The final exchange turns the discovery into
an office-wide joke.

Product command: `敬語`

### Page 1 — disaster

**新人**

> 終わった

**同期**

> 今度は何した

**新人**

> 取引先から部長に  
> 電話いった

**同期**

> は？

**新人**

> メールで  
> 「資料、拝見していただけましたか？」  
> って送ったら

**同期**

> あー

**新人**

> 「拝見するのは私ですか？」  
> って返ってきた

**同期**

> 怒ってる？

**新人**

> めっちゃ怒ってる

**新人**

> しかも部長CC入ってる

**同期**

> それは終わった

### Page 2 — product reveal

**新人**

> 今から謝罪メール送れって

**同期**

> 下書きは？

**新人**

> 敬語を間違えてしまい  
> すみませんでした。  
> 次から気をつけます

**同期**

> 小学生の反省文で草

**新人**

> もう退職届書く

**同期**

> 待て  
> これ使ってみ

**同期 — image message**

Render the real result screen with this intended transformation:

> 敬語を間違えてしまい、すみませんでした。次から気をつけます。  
> ↓  
> このたびは不適切な表現により、ご不快な思いをおかけし、誠に申し訳ございませんでした。今後は十分注意してまいります。

The final result must be regenerated and verified in the shipping app. Shorten
it if the actual candidate exceeds the result-card limit.

**新人**

> 何これ

**同期**

> 敬語ボタン

**同期**

> キーボードで文章打って  
> 敬語押すだけ

**新人**

> ChatGPT開かなくていいの？

**同期**

> そのまま置き換えられる

### Page 3 — payoff

**新人**

> 送った

**同期**

> 返信きた？

**新人**

> きた

**同期**

> なんて？

**新人**

> 「今後はお気をつけください」

**同期**

> 生き残ったな

**新人**

> 部長からも来た

**同期**

> 怖

**新人**

> 「さっきの謝罪文  
> 誰に書いてもらった？」

**同期**

> バレた？

**新人**

> 敬語ボタンって答えた

**同期**

> おい

**新人**

> 部長も入れた

**同期**

> 営業部全員救われるやん

### Production status

- Story: approved
- Page breaks: **revised during production** — built as `posts/002-new-hire-apology`.
  Page 2 held 12 messages plus the tall product image and overflowed 1920 px, so
  the `打って敬語押すだけ / ChatGPT開かなくていいの？ / そのまま置き換えられる`
  exchange moved to the top of page 3, and page 3 dropped `怖` and `おい` and
  merged `敬語ボタンって答えた` with `部長も入れた` to stay within 12.
- Crop: the 2-line draft pushes the composer above the default crop line, so the
  asset sets `"cropTop": 1060`.
- Result copy: fiction (no shipping-app verification required — see product-image rule)
- Visual QA: pages fit, no clipping — pending Itsuki review
- Publication: not approved

---

## 002 — 英語ゼロで外国人彼女

### Intent

A man claims he started dating a French woman despite speaking no English. His
friend refuses to believe him, prompting the late reveal that he writes in
Japanese and taps the English translation command. The final page adds a second
reveal: she could speak Japanese the entire time.

Product command: `英訳`

### Page 1 — impossible claim

**男**

> 俺、彼女できた

**友達**

> は？

**友達**

> 誰

**男**

> 先週バーにいた  
> フランス人の子

**友達**

> お前英語話せないじゃん

**男**

> 全然話せない

**友達**

> じゃあどうやって  
> 口説いたんだよ

**男**

> 毎日英語でLINEした

**友達**

> だから英語できないだろ

**男**

> これ使った

### Page 2 — product reveal

**男 — image message**

Render the real result screen with this intended transformation:

> また会いたい。今度は二人でご飯に行かない？  
> ↓  
> I'd love to see you again. Would you like to have dinner together sometime?

The English candidate must come from and be verified against the shipping app.
The result screen must say `英訳`, not `敬語`.

**友達**

> 何これ

**男**

> 敬語ボタン

**友達**

> 敬語じゃないじゃん

**男**

> 英訳ボタンもある

**男**

> 日本語打って英訳押したら  
> そのまま送れる

**友達**

> チートやん

**友達**

> 会った時どうすんの

**男**

> そこは笑顔

**友達**

> 会話できないだろ

### Page 3 — twist

**男**

> 昨日それ聞いた

**友達**

> なんて言われた？

**男**

> 「実は日本語話せるよ」って

**友達**

> は？

**男**

> 普通にペラペラだった

**友達**

> じゃあお前だけずっと  
> 翻訳使ってたの？

**男**

> うん

**友達**

> なんで教えてくれなかったんだよ

**男**

> 英語頑張ってるのが  
> 可愛かったって

**友達**

> 敬語ボタン関係なく  
> 勝ち組で腹立つ

### Production status

- Story: approved
- Page breaks: approved
- Result copy: fiction (no shipping-app verification required — see product-image rule)
- `英訳` renderer label: implemented
- Visual QA: complete for `posts/001-foreign-girlfriend`
- Publication: not approved

---

# Batch 2 — 2026-08-05 (awaiting story approval)

Written against the spicy bar above, not the earlier transactional draft. In all
five the teller is hiding the app from someone who can find out, and the twist
comes from the other person's side.

**敬語ボタン is named on screen in every episode**, in the 「何これ」→「敬語ボタン」
beat directly after the image.

## Page budgets (measured while building 002)

| Page | Ceiling | Real budget |
|---|---|---|
| 1 | 12 | 11–12 short bubbles |
| 2 | 12 | **~8** — image ≈ four bubbles, and two are reserved for the app name |
| 3 | 12 | 11–12 short bubbles |

Result copy stays ≤75 characters in either language.

## Portfolio

| # | Claim | Command | Who could find out | Twist comes from |
|---|---|---|---|---|
| 003 | 13歳上の女性と会えた | 敬語 | 相手本人 | 相手も同じアプリを使っていた |
| 004 | 元カノの結婚式でスピーチした | 敬語 | 元カノ・新郎 | 元カノの本音 |
| 005 | 登録300万人の推しから返信がきた | 英訳 | 配信の視聴者全員 | 推しが読み上げてしまう |
| 006 | 父が同棲を認めた | 敬語 | 両親 | 母が個別に送ってくる |
| 007 | 後輩が社長賞をとった | 敬語 | 部長 | 後輩の善意が刺さる |

---

## 003 — 13歳上の人と会えた

### Intent

A 25-year-old has been ignored by every match on the app. One 38-year-old woman
starts replying, and they meet. The shame is real — he knows the messages aren't
his voice, and he expects to be found out the moment they're face to face. He is,
in three minutes. The twist redeems and indicts both of them at once: she spotted
it because **she was using 敬語ボタン too**, which means months of careful,
beautiful messages were two people hiding behind the same app. The closing beat —
「今日から敬語やめよう」 — is the whole product argument inverted, and the comment
section will not agree about whether this counts as lying.

Product command: `敬語`

### Page 1 — impossible claim

**俺**
> マッチングアプリで会えた

**友達**
> 誰と

**俺**
> 38歳の人

**友達**
> お前25だろ

**俺**
> そう

**友達**
> 相手にされんの？

**俺**
> 今まで全員既読無視だった

**友達**
> だよね

**俺**
> 先週から1人だけ返ってくる

**友達**
> サクラでは

**俺**
> 昨日会った

**友達**
> は？

### Page 2 — product reveal

**友達**
> なんて送ったの

**俺**
> 前はこれ

**俺**
> はじめまして！
> 可愛いですね！
> 今度会いませんか？

**友達**
> 通報されるやつ

**俺**
> だから変えた

**俺 — image message**

> はじめまして！可愛いですね！今度会いませんか？
> ↓
> はじめまして。プロフィールを拝見してご連絡しました。もしよろしければ、一度お話しできると嬉しいです。

**友達**
> 何これ

**俺**
> 敬語ボタン

### Page 3 — twist

**俺**
> 会って3分で言われた

**友達**
> なんて

**俺**
> 「文章、アプリ使ってるでしょ」

**友達**
> バレてるやん

**俺**
> 顔真っ赤になった

**友達**
> で？

**俺**
> 「私も使ってる」

**友達**
> は？

**俺**
> 向こうも敬語ボタンだった

**友達**
> 丁寧な文章同士で
> 何ヶ月やってたんだよ

**俺**
> 今日から敬語やめようって言われた

**友達**
> 良い話にすんな

### Production status

- Story: pending Itsuki approval
- Result copy: fiction (no shipping-app verification required — see product-image rule)
- Publication: not approved

---

## 004 — 元カノの結婚式でスピーチした

### Intent

He cannot refuse — twenty mutual friends, and the groom knows who he is. Three
days before, the draft is blank, and everything he writes honestly is worse than
nothing (「色々ありましたが」). The rewrite gives him something graceful to read
aloud, and it works far too well: the bride cries, the groom cries, and at the
afterparty she tells him 「そんな風に言えるなら別れてなかった」. The app didn't
save him — it retroactively cost him the relationship, in front of her husband.

Product command: `敬語`

### Page 1 — impossible claim

**俺**
> 元カノの結婚式行ってきた

**友達**
> なんで行くんだよ

**俺**
> スピーチ頼まれた

**友達**
> は？？

**俺**
> 断れる空気じゃなかった

**友達**
> 断れよ

**俺**
> 共通の友達20人いる

**友達**
> 地獄じゃん

**俺**
> しかも新郎が
> 俺のこと知ってる

**友達**
> 詰んでる

**俺**
> 3日前まで原稿白紙だった

**友達**
> で、どうした

### Page 2 — product reveal

**俺**
> 最初に書いたのがこれ

**俺**
> 幸せになってください
> 色々ありましたが
> 良い思い出です

**友達**
> 色々を掘るな

**俺**
> 全部消した

**俺 — image message**

> 幸せになってください。色々ありましたが良い思い出です
> ↓
> 本日はおめでとうございます。お二人がこれから重ねる時間が、穏やかで温かなものでありますよう願っております。

**友達**
> 何これ

**俺**
> 敬語ボタン

### Page 3 — twist

**俺**
> 読み終わったら

**友達**
> うん

**俺**
> 元カノ泣いてた

**友達**
> それはやばい

**俺**
> 新郎も泣いてた

**友達**
> 一番やばい

**俺**
> 二次会で元カノに言われた

**友達**
> なんて

**俺**
> 「そんな風に言えるなら
> 別れてなかった」

**友達**
> おい

**俺**
> 新郎めっちゃこっち見てた

**友達**
> 二度と行くな

### Production status

- Story: pending Itsuki approval
- Result copy: fiction (no shipping-app verification required — see product-image rule)
- Publication: not approved

---

## 005 — 推しから返信がきた

### Intent

Three years of DMs to a 3-million-subscriber overseas streamer, all ignored,
because 「I love you. Please notice me.」 reads exactly as unhinged as it sounds.
One properly written message gets a reply — and then gets read aloud on stream,
which is the exposure: the audience praises her English, Japanese fans flood her
asking what she uses, and the secret escapes. The last beat is the funniest
product outcome in the batch: the streamer's DMs fill up with unnaturally polite
Japanese people.

Product command: `英訳`

### Page 1 — impossible claim

**私**
> 推しから返信きた

**友達**
> 海外の人だよね

**私**
> 登録300万人

**友達**
> 絶対botだって

**私**
> 名前呼ばれた

**友達**
> は？

**私**
> 配信で読まれた

**友達**
> 嘘だろ

**私**
> アーカイブ残ってる

**友達**
> 英語できたっけ

**私**
> 一文字も無理

**友達**
> じゃあどうやって

### Page 2 — product reveal

**私**
> 前は翻訳そのまま貼ってた

**私**
> I love you.
> Please notice me.

**友達**
> 怖い

**私**
> 3年間無視されてた

**私 — image message**

> 3年間見ています。日本にも来てほしいです
> ↓
> I've been watching for three years. I'd love to see you visit Japan someday.

**友達**
> 何これ

**私**
> 敬語ボタン

**友達**
> 英訳もできんのか

### Page 3 — twist

**私**
> 配信で読み上げられた

**友達**
> なんて言ってた

**私**
> 「一番丁寧なDMだ」って

**友達**
> 3年分報われてる

**私**
> コメント欄が地獄

**友達**
> なんで

**私**
> 「この日本人英語うますぎ」

**友達**
> バレるぞ

**私**
> 日本のファンから
> 「何使ってる？」が20件

**友達**
> 全員同じこと考えてる

**私**
> 教えたら推しのDM欄が
> 丁寧な日本人だらけになった

**友達**
> 治安良くなってて草

### Production status

- Story: pending Itsuki approval
- Result copy: fiction (no shipping-app verification required — see product-image rule)
- Publication: not approved

---

## 006 — 父が同棲を認めた

### Intent

The first attempt six months ago ended with 「顔も見たくない」. The second gets a
reply in three hours. What makes this land is not the father's approval — it is
the message his mother sends privately afterwards: 「その文章の書き方教えて」
「お父さんに言いたいことがあるの」. The story stops being about permission and
becomes about a marriage the narrator suddenly knows too much about, and he
decides not to ask. Ends on unease rather than a win.

Product command: `敬語`

### Page 1 — impossible claim

**俺**
> 同棲OK出た

**友達**
> あのお父さんが？

**俺**
> そう

**友達**
> 挨拶行ったの

**俺**
> LINE

**友達**
> LINEで許可出る家じゃないだろ

**俺**
> 前に一回言ったときは

**俺**
> 「顔も見たくない」って言われた

**友達**
> 重い

**俺**
> 半年空けてもう一回送った

**友達**
> 特攻じゃん

**俺**
> 3時間で返事きた

### Page 2 — product reveal

**友達**
> 何送ったの

**俺**
> 前はこう書いてた

**俺**
> もう大人だし
> 好きにさせてほしい

**友達**
> 燃料

**俺**
> 今回は変えた

**俺 — image message**

> もう大人だし好きにさせてほしい
> ↓
> 一緒に暮らすことを考えています。心配をかけると思いますが、一度きちんと話す時間をいただけないでしょうか。

**友達**
> 何これ

**俺**
> 敬語ボタン

### Page 3 — twist

**俺**
> 父から返信きた

**友達**
> なんて

**俺**
> 「一度連れてきなさい」

**友達**
> 勝ったじゃん

**俺**
> そのあと母から個別に来た

**友達**
> 反対？

**俺**
> 「その文章の書き方教えて」

**友達**
> え

**俺**
> 「お父さんに言いたいことがあるの」

**友達**
> 待って

**俺**
> 何も聞かないことにした

**友達**
> 賢い

### Production status

- Story: pending Itsuki approval
- Result copy: fiction (no shipping-app verification required — see product-image rule)
- Publication: not approved

---

## 007 — 後輩が社長賞をとった

### Intent

He ghost-writes an apology for a crying junior, the customer is so impressed they
call head office, and the junior gets an award for it. He claps. The junior then
does the decent thing — 「先輩に教わりました」 — which is exactly what exposes him,
because the 部長 hears it and hands him every complaint in the department from now
on. Good deed, correctly punished. The junior gets promoted; he gets a workload.

Product command: `敬語`

### Page 1 — impossible claim

**俺**
> 後輩が社長賞とった

**友達**
> すごいじゃん

**俺**
> 謝罪文書いたの俺

**友達**
> え

**俺**
> 後輩が客怒らせて

**俺**
> 泣きながら相談してきた

**友達**
> いい先輩じゃん

**俺**
> 代わりに文章作った

**友達**
> それで？

**俺**
> 客が本社に感謝の電話入れた

**友達**
> 展開が読めた

**俺**
> 後輩が表彰された

### Page 2 — product reveal

**友達**
> 何書いたの

**俺**
> 後輩の下書きがこれ

**俺**
> すみませんでした
> 以後気をつけます

**友達**
> 火に油

**俺**
> 直したのがこれ

**俺 — image message**

> すみませんでした。以後気をつけます
> ↓
> このたびはご迷惑をおかけし、誠に申し訳ございません。原因を確認のうえ、改めてご報告いたします。

**友達**
> 何これ

**俺**
> 敬語ボタン

### Page 3 — twist

**俺**
> 朝礼で表彰されてた

**友達**
> お前は？

**俺**
> 拍手してた

**友達**
> 切ない

**俺**
> 後輩が
> 「先輩に教わりました」って

**友達**
> いい子じゃん

**俺**
> 部長が振り向いた

**友達**
> やば

**俺**
> 「クレーム対応、全部お前な」

**友達**
> 出世じゃなくて業務増

**俺**
> 後輩は昇進した

**友達**
> 敬語ボタンだけ勝ってる

### Production status

- Story: pending Itsuki approval
- Result copy: fiction (no shipping-app verification required — see product-image rule)
- Publication: not approved

# Batch 3 — 2026-08-05 (awaiting story approval)

Written to replace posts `008`–`012`, which were drafted before the Batch 2 bar
and failed it — transactional wins with no personal shame, nobody who could expose
the teller, and twists about outcomes rather than people. **Those five were deleted
on 2026-08-05** (repo directories removed; their silent MP4s in Supabase storage
still need a manual delete — see the handoff doc). Bank numbers `008`–`012` are
retired and must not be reused.

**Status: approved by Itsuki 2026-08-05 and scheduled** on Saya (TikTok) and
Instagram for Aug 7–8. The "awaiting story approval" in the heading above refers
to when the batch was drafted.

**Numbering note:** bank episode numbers `008`–`012` are deliberately unused so
that from `013` onward the bank number and the `posts/NNN-slug/` directory number
are the same. (In Batch 1 they diverge: bank 001 is `posts/002-new-hire-apology`
and bank 002 is `posts/001-foreign-girlfriend`.)

All five check the four-point bar: a personal secret, someone who could find out,
a relationship rather than a transaction at stake, and a twist that comes from the
other person's side. All five are phone-side, mid-conversation situations with
someone waiting, so switching to another app would be absurd — the keyboard-native
advantage is structural and never stated in dialogue.

## Portfolio

| # | Claim | Command | Who could find out | Twist comes from |
|---|---|---|---|---|
| 013 | 彼女の母に気に入られた | 敬語 | 彼女・母・弟 | 母が家族グループに転送し弟が見抜く |
| 014 | 同じ内容で同期だけ怒られた | 敬語 | 同期・部長 | 部長が同期に本人の文章を転送する |
| 015 | 母の再婚相手に挨拶した | 敬語 | 母・再婚相手 | 相手が読み返し保存していた |
| 016 | 外国人の同僚に英語で謝った | 英訳 | 同僚・チーム全員 | 同僚は二年前から日本語を読めた |
| 017 | 憧れの先輩に告白してOKされた | 敬語 | 先輩 | 決め手は変換しなかった一通 |

---

## 013 — 彼女の母に気に入られた文章

### Intent

A man who has never met his girlfriend's mother is told to introduce himself
over LINE. Every message he sends her is converted, and it works so well she
starts holding him up as a model. The shame is that the praise is aimed at
something he didn't write. The twist takes the secret out of his hands
entirely: she forwards his messages into the family group chat as an example
for her son, and the younger brother recognises the app on sight. Everyone
now knows except the one person whose opinion he was managing. The closing
beat — 「お母さんだけ気づいてない」 — leaves him permanently exposed to a
reveal he can't control.

Product command: `敬語`

### Page 1 — impossible claim

**俺**
> 彼女の母に気に入られた

**友達**
> は？

**俺**
> 「うちの子よりしっかりしてる」って

**友達**
> お前が？

**俺**
> そう

**友達**
> もう会ったの

**俺**
> まだ会ってない

**友達**
> じゃあ何で

**俺**
> LINEだけ

**友達**
> 母親と直接LINEしてんの

**俺**
> 挨拶しろって言われて

**友達**
> それで気に入られるか？

### Page 2 — product reveal

**友達**
> なんて送ったの

**俺**
> 最初はこれ

**俺**
> 今度ごはん行きましょう！
> 都合いい日教えてください

**友達**
> 距離感やばい

**俺**
> だから変えた

**俺 — image message**

> 今度ごはん行きましょう！都合いい日教えてください
> ↓
> 今度お食事でもいかがでしょうか。ご都合のよい日をお聞かせいただけますと幸いです。

**友達**
> 何これ

**俺**
> 敬語ボタン

### Page 3 — twist

**俺**
> 昨日やらかした

**友達**
> 何

**俺**
> お母さんが家族のグループに
> 俺の文章を転送してた

**友達**
> なんで転送すんの

**俺**
> 「弟もこう書きなさい」って

**友達**
> 晒されてるやん

**俺**
> 弟が即レスした

**友達**
> なんて

**俺**
> 「これ敬語ボタンじゃん」

**友達**
> 終わったな

**俺**
> お母さんだけ気づいてない

**友達**
> 一生黙ってろ

### Production status

- Story: approved by Itsuki 2026-08-05
- Result copy: fiction (no shipping-app verification required — see product-image rule)
- Visual QA: passed (rendered, BGM `playful.m4a` baked)
- Publication: scheduled on Saya (TikTok) + Instagram, Aug 7–8

---

## 014 — 同じ内容で同期は怒られた

### Intent

Two colleagues make the identical request of the same 部長 on the same day.
The one who sent it raw gets shot down; the one who ran it through the app
gets approved. This is the bank's outcome-unfairness engine in its purest
form, with nothing clever about the tactic — the content was word-for-word
the same. The twist arrives from the 部長's side: he forwards the approved
message to the rejected colleague as a model, which hands the friend the
evidence directly. The final beat is the real cost — asked point-blank for
the app's name, he says nothing, and keeps the advantage.

Product command: `敬語`

### Page 1 — impossible claim

**俺**
> 同じこと頼んで

**俺**
> 同期は怒られた

**友達**
> お前は？

**俺**
> 通った

**友達**
> 内容一緒なの

**俺**
> 完全に一緒

**友達**
> 意味わからん

**俺**
> リモートにしたいって話

**友達**
> 部長そんな気分屋か

**俺**
> 違うと思う

**友達**
> じゃあ何

**俺**
> 文章

### Page 2 — product reveal

**友達**
> どう違ったの

**俺**
> 同期はこれ送った

**俺**
> 来週リモートにして
> いいですか？家の都合で

**友達**
> 普通じゃん

**俺**
> 俺はこれ

**俺 — image message**

> 来週リモートにしていいですか？家の都合で
> ↓
> 来週、家庭の都合によりリモート勤務に変更させていただけないでしょうか。ご検討いただけますと幸いです。

**友達**
> 何これ

**俺**
> 敬語ボタン

### Page 3 — twist

**俺**
> 部長がやばいことした

**友達**
> 何

**俺**
> 同期に俺の文章を転送した

**友達**
> え

**俺**
> 「これを参考にしろ」って

**友達**
> 悪意ある

**俺**
> 同期から即電話きた

**友達**
> 内容

**俺**
> 「お前これ自分で書いてないだろ」

**友達**
> バレてるやん

**俺**
> アプリ名聞かれて黙った

**友達**
> 教えてやれよ

### Production status

- Story: approved by Itsuki 2026-08-05
- Result copy: fiction (no shipping-app verification required — see product-image rule)
- Visual QA: passed (rendered, BGM `rushing.m4a` baked)
- Publication: scheduled on Saya (TikTok) + Instagram, Aug 7–8

---

## 015 — 母の再婚相手に送った最初のLINE

### Intent

His mother is remarrying and wants him to message the man for the first time,
with her sitting next to him waiting. He is not warm about it; he forces out
something civil and converts it. The twist inverts the shame: the man read
the message over and over, screenshotted it, and is looking forward to
meeting him. The care he faked was received as real, by someone with no
reason to doubt it. There is no exposure here and no punchline at his expense
— the punishment is that it worked. 「一番どうでもいい気持ちで送った」 is the
line the comment section will not agree about.

Product command: `敬語`

### Page 1 — impossible claim

**俺**
> 母親が再婚する

**友達**
> おめでとう…？

**俺**
> 相手にLINEしろって言われた

**友達**
> 会ったことあるの

**俺**
> 一回もない

**友達**
> 気まずすぎる

**俺**
> 母が横で待ってる

**友達**
> 今かよ

**俺**
> 今

**友達**
> 何送るんだよ

**俺**
> もう送った

**友達**
> は？

### Page 2 — product reveal

**友達**
> なんて書いたの

**俺**
> 最初はこれ

**俺**
> 母から聞いてます。
> とりあえずよろしくお願いします

**友達**
> とりあえずって何だよ

**俺**
> だから変えた

**俺 — image message**

> 母から聞いてます。とりあえずよろしくお願いします
> ↓
> はじめまして。母より伺っております。これからよろしくお願いいたします。お会いできる日を楽しみにしております。

**友達**
> 何これ

**俺**
> 敬語ボタン

### Page 3 — twist

**俺**
> 今日母から連絡きた

**友達**
> 何て

**俺**
> 「あの人、何回も読み返してた」

**友達**
> え

**俺**
> 「スクショして保存してた」って

**友達**
> 重い

**俺**
> 会うのが楽しみだって

**友達**
> 良かったじゃん

**俺**
> 一番どうでもいい気持ちで送った

**友達**
> それ言うな

**俺**
> 母にも言えない

**友達**
> 墓まで持ってけ

### Production status

- Story: approved by Itsuki 2026-08-05
- Result copy: fiction (no shipping-app verification required — see product-image rule)
- Visual QA: passed (rendered, BGM `chill.m4a` baked)
- Publication: scheduled on Saya (TikTok) + Instagram, Aug 7–8

---

## 016 — 外国人の同僚に英語で謝った結果

### Intent

She vented about a foreign colleague in a Japanese group chat, not realising
he had been added to it the week before. She can't write English, so the
apology gets translated. The twist is the harshest in the bank: he replies in
Japanese — he has read Japanese fluently for two years and has seen
everything, which means the two years she assumed were private were not.
The translation she was panicking over turns out to be the smallest of her
problems. Uses the 英訳 command; the renderer's `command` query parameter now
supplies the label, so the caveat recorded in the product-image rule above is
resolved.

Product command: `英訳`

### Page 1 — impossible claim

**俺**
> 終わった

**友達**
> 何が

**俺**
> グループチャットで

**俺**
> 外国人の同僚の愚痴書いた

**友達**
> 本人いないとこで？

**俺**
> いると思ってなかった

**友達**
> いたの

**俺**
> 先週から入ってた

**友達**
> 詰んでる

**俺**
> 日本語だから大丈夫かと

**友達**
> 翻訳されるだろ

**俺**
> 英語で謝るしかない

### Page 2 — product reveal

**友達**
> 英語書けるの

**俺**
> 無理

**俺**
> 打ったのはこれ

**俺**
> 悪口じゃないです。
> 誤解させてごめんなさい

**俺 — image message**

> 悪口じゃないです。誤解させてごめんなさい
> ↓
> That wasn't criticism. I'm sorry for the misunderstanding.

**友達**
> 何これ

**俺**
> 敬語ボタン

### Page 3 — twist

**俺**
> 返信きた

**友達**
> 英語で？

**俺**
> 日本語で

**友達**
> え

**俺**
> 「日本語、読めます」

**友達**
> は？

**俺**
> 「二年前から全部読んでます」

**友達**
> 全部？

**俺**
> 全部

**友達**
> 英訳した意味なくない

**俺**
> それどころじゃない

**友達**
> 明日会社行くなよ

### Production status

- Story: approved by Itsuki 2026-08-05
- Result copy: fiction (no shipping-app verification required — see product-image rule)
- Visual QA: passed (rendered, BGM `kpop-funny.m4a` baked)
- Publication: scheduled on Saya (TikTok) + Instagram, Aug 7–8

---

## 017 — 憧れの先輩に告白した結果

### Intent

He confesses to a senior colleague over LINE because he can't do it in person,
and converts the message first. She says yes. The twist is generous rather
than punishing, and it is the only one in the bank that partially disarms the
product: what actually landed was the one raw line he sent immediately
afterwards, unconverted, because he couldn't stop himself. The app didn't
write the thing that worked — but he would never have hit send at all without
it, which is the honest version of the product's claim and the reason the
final beat is the friend conceding the point.

Product command: `敬語`

### Page 1 — impossible claim

**俺**
> 先輩に告白した

**友達**
> 会社の？

**俺**
> 三つ上の

**友達**
> 直接言ったの

**俺**
> LINE

**友達**
> 最悪だろ

**俺**
> 直接は無理だった

**友達**
> で、結果は

**俺**
> OKだった

**友達**
> 嘘だろ

**俺**
> 本当

**友達**
> 何送ったんだよ

### Page 2 — product reveal

**俺**
> 最初はこれ

**俺**
> ずっと好きでした。
> 付き合ってください。
> 無理なら忘れてください

**友達**
> 重すぎる

**俺**
> だから変えた

**俺 — image message**

> ずっと好きでした。付き合ってください。無理なら忘れてください
> ↓
> 以前からお慕いしておりました。もしよろしければ、一度きちんとお話しさせていただけないでしょうか。

**友達**
> 何これ

**俺**
> 敬語ボタン

### Page 3 — twist

**俺**
> 昨日OKした理由聞いた

**友達**
> 何て

**俺**
> 「あとから来た一通」だって

**友達**
> 一通？

**俺**
> 変換した後に

**俺**
> 我慢できなくて送った

**俺**
> 「無理なら忘れてください」

**友達**
> それ素の文章か

**俺**
> そこだけ俺の言葉

**友達**
> 丁寧な方じゃなかったんだな

**俺**
> 送れたのはアプリのおかげ

**友達**
> そこは認めるんだ

### Production status

- Story: approved by Itsuki 2026-08-05
- Result copy: fiction (no shipping-app verification required — see product-image rule)
- Visual QA: passed (rendered, BGM `dating.m4a` baked)
- Publication: scheduled on Saya (TikTok) + Instagram, Aug 7–8

---

---

# Batch 4 — 2026-08-09（レンダー・スケジュール済み）

`018`–`020` は yuri 連載が押さえているので `021` から。5話とも Saya の型は
**変えていない** — 商品画像はページ2の中盤、語り手は成功する、3ページ45秒。
natsumi との A/B の変数を「製品の位置」1個に保つため、ここを動かしていない
（`README.md` §Product placement is the live experiment）。

変えたのは**書き方だけ**で、これは natsumi にも同じく適用している。2026-08-09 に
Itsuki が持ち込んだバズ参照3本（ハラスメントーク／めろとーくの獲得動画）から：

- **冒頭のページは結論を出さない。** 「昨日ね」「詰んだと思った」「変な一日だった」
  のように、何の話かを数吹き出し伏せる。021–025 は全部この入り。
- **明確な悪役を作らない。** コメント欄が割れるのは、どちらも少し正しくない時だけ。
- 4点バー（本人の秘密／バレうる相手／関係が懸かっている／相手側からのどんでん返し）は
  従来どおり全話クリアしている。

## Portfolio

| # | Claim | Cmd | バレうる相手 | どんでん返しの出どころ | BGM | 枠 (JST) | Zernio |
|---|---|---|---|---|---|---|---|
| 021 | 彼氏の浮気相手と組んで別れた | 敬語 | 彼氏 | 浮気相手も本命だと思っていた | `dating3` | 8/9 21:00 | `6a78143dd1cada8ffb39e2ed` |
| 022 | 既婚の上司を振ったら奥さんに感謝された | 敬語 | 上司・奥さん | 奥さんが全部知っていた | `dating2` | 8/10 09:00 | `6a78143e756534f24e63782c` |
| 023 | 半年やりとりした人に初めて会った | **かたくしない**（自作） | 相手 | 相手も台本メモを用意していた | `dating2` | 8/10 15:00 | `6a781440d1cada8ffb39e3cc` |
| 024 | アプリで会う相手が同じ会社だった | 敬語 | 社内全員 | 相手は3日前から気づいていて異動希望を出していた | `dating3` | 8/10 21:00 | `6a781441d1cada8ffb39e459` |
| 025 | 彼氏の元カノからDMが来た | 敬語 | 彼氏 | 元カノは忠告に来ていた | `dating` | 8/11 09:00 | `6a781442e79c93d328cf6321` |

## このバッチで確認できたこと

- **`product-ui.html` の `command` は任意のラベルを描画する。** 023 が
  「かたくしない」で正しくレンダーされた。敬語／英訳に限定されていないので、
  カスタムボタン回はコード変更なしで書ける。023 は Saya で初めて
  「敬語ボタン」→「敬語じゃなくない？」→「ボタン自分で作れる」を回した回。
- **2行に折り返す draft は `cropTop: 1060` + 画像 `540 × 430`。** 021–025 は
  最初からこの値で書いてある（natsumi で3本作り直す羽目になったので）。
- BGM は新規の `dating2` / `dating3` を投入済み。恋愛回が全部同じ音にならないよう
  3トラックで回している。

---

# Batch 4 — 金銭・不公平レーン（026–034、2026-08-11）

新方針の第1バッチ。全話 `自然に` コマンド、3ページ、製品画像は2ページ目後半。
語り手は勝たない。台本は各 `posts/NNN-*/post.json` が正。

| # | 争点 | 寄りのエスカレーション | どんでん返し | BGM | 枠 (JST) | Zernio |
|---|---|---|---|---|---|---|
| 026 | 半年一度も財布を出さない | 温泉12万 → ご飯 → **180円のアイス** | 彼の給料が来月下がる | `dating` | 8/11 15:00 | `6a7a067ee0f487b6666a2b83` |
| 027 | 折半と言ったのは自分 | 家賃9万 → 光熱費 → **トイレットペーパー** | 彼は10万の部屋を諦めていた | `dating2` | 8/11 21:00 | `6a7a0680e0f487b6666a2c17` |
| 028 | 金額差は愛情差か | 3万 → 5千円 → **去年の記憶がない** | その日は会ってすらいない | `dating3` | 8/12 09:00 | `6a7a068142d12eb50eaa1b91` |
| 029 | 3万の催促は細かいか | 半年 → 新しいバッグ → **名前が書いてなかった** | 立て替えた分は誰からか不明のまま | `dating` | 8/12 15:00 | `6a7a068a42d12eb50eaa1e65` |
| 030 | 1円単位は誠実か神経質か | 総額 → 数百円 → **7円** | 幹事が10万立て替えていた | `dating2` | 8/12 21:00 | `6a7a068c42d12eb50eaa1f75` |
| 031 | 手土産は義務か | 3回とも → 母の一言 → **「別にいいのよ」** | 母が「気を遣わないで」と言っていた | `dating3` | 8/13 09:00 | `6a7a0690e0f487b6666a2e7f` |
| 032 | 収入按分か頭割りか | 20万 → 按分 → **「親孝行も按分で」** | 兄が入院費を全部出していた | `dating` | 8/13 15:00 | `6a7a06972e1a245bf8b426a5` |
| 033 | 出すフリは礼儀か嘘か | 半年 → 財布に手 → **一度も開けない** | 「いいよ」を言われるのを待っていた | `dating2` | 8/13 21:00 | `6a7a06992e1a245bf8b4279d` |
| 034 | 折半か人数割りか | 300万 → 人数割り → **3人分の差** | 相手の親は全額出すつもりだった | `dating3` | 8/14 09:00 | `6a7a069b42d12eb50eaa220a` |

## このバッチで決めたこと

- **draft は「視聴者が送ってしまう返信」にする。** 従来の「送ったら終わる文」より
  一段リアルにした。026 の「ごめん全部返す。もう会わない方がいいよね」は
  reference viral story でヒロインが実際に打った手（謝罪→別れ話へのエスカレート）
  をそのまま使っている。強がった暴言より、**防御的な自爆**の方が刺さる。
- **コマンドは `自然に`。** 恋人に敬語を送るのは不自然で、製品が単機能に見える。
  `自然に` は実測でも builtin 中いちばん acceptance が高い（43.6% 対 敬語 27.3%、
  `../../gtm/value-proposition-2026-08.md` §2.1）。
- **製品画像のページは 8 吹き出しが上限。** 9 以上入れると最後の「敬語ボタン」が
  TikTok の下部 UI に潜る。`build.py` の `wraps to 2 lines:` は警告どまりなので、
  レンダー後に下端を目視するか、余裕を見て 8 で書く。
