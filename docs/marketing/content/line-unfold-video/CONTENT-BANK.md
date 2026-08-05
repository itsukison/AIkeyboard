# LINE unfold video — content bank

Owner: Itsuki. Status: concepts approved; production copy drafted; product
outputs still require verification in the shipping app.

This file owns scripts for the progressive chat-reveal video format. Each story
uses three sequential chat pages. The first page establishes a dramatic problem,
the second reveals the real product in context, and the third rewards completion
with a punchline or reversal.

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

Requirements:

- The draft and result must be produced and verified with the shipping app
  before publication. The copy below is the intended meaning, not permission to
  invent an AI output.
- Keep the result to roughly 75 characters or fewer so it remains readable.
- The keigo episode uses the renderer's existing `敬語` label.
- The translation episode must show the shipped `英訳` label. The current
  renderer hard-codes `敬語`, so production must expose the command title as a
  query parameter while preserving the existing geometry.
- Show only one product image. The surrounding chat explains the workflow in
  plain language; additional product frames would make the story feel like an
  advertisement.

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
- Page breaks: approved
- Result candidate: pending shipping-app verification
- Visual QA: pending
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
- Result candidate: pending shipping-app verification
- `英訳` renderer label: implemented
- Visual QA: complete for `posts/001-foreign-girlfriend`
- Publication: not approved
