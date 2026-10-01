# yuri_keigo 連載バンク —「先輩と敬語」

Owner: Itsuki. Account: **yuri_keigobutton** (Zernio, TikTok, account id
`6a7409d6d0fe733d1a8d67df`). Started 2026-08-06. Status: **season 1 (#1–#9) ran
Aug 7–9; season 2 (#10–#18) is rendered and scheduled for Aug 10–12**, 3 per day.
Stories were not individually pre-approved — pull anything that misses before its
slot. Season 2 detail is at the bottom of this file.

## このアカウントの担当範囲 —「進行中の一つの恋」（Itsuki, 2026-08-09）

3アカウントとも恋愛縛りになり、**yuri は「進行中」の枠**を持つことが確定した。
ユリと先輩の一本の物語で、結果は誰も知らないまま進む（実況型）。3アカウントの
全体像は `README.md` §The three accounts が持っている。

この決定で yuri の中身は**変わらない** — 元から社内恋愛の連載なので、そのまま
シーズン2に進んでよい。変わったのは隣の2アカウントの方（Saya＝始まる前、
natsumi＝壊れる時）。**恋の始まりも終わりも隣が書くので、yuri は「付き合う前の
宙ぶらりん」を長く引っ張れる**のが、この分担での強み。

**One account, one story.** This file owns a serial: a fixed cast, one continuous
arc, episodes that only make sense in order. `CONTENT-BANK.md` owns the Saya
anthology — unrelated tellers, closed endings, a new scenario every time. The two
never mix:

| | `CONTENT-BANK.md` — Saya | this file — yuri |
|---|---|---|
| Account | Saya (mari040715) + Instagram | yuri_keigo |
| Shape | Anthology. New teller each episode | Serial. Same two people all season |
| Job | Test which scenarios convert | Build a following the app can inherit |
| Ending | Closed — a twist that lands | Open — a hook into the next episode |
| Reuse | Episodes are independent | Episode N assumes N−1 was watched |

Do not move an episode between the files, do not post a yuri episode on Saya, and
do not reuse a Saya twist here (or the two accounts read as one account).

## What this file does not own

The **format contract** is shared and stays in one place — read these and nothing
else from the other files:

- `README.md` — video spec, `post.json` schema, product-asset rendering, BGM,
  publishing.
- `CONTENT-BANK.md` §Product-image rule and §Page budgets — the image rule
  (including the screenshot nuance below), the ≤75-character result, the 12-bubble
  ceiling and the ~6-text-plus-image page-2 budget.
- `CONTENT-BANK.md` §The use case must fit the product — the keyboard-native test.

**The two banks have physically separate trees** (2026-08-06). The serial lives in
`posts/yuri/NNN-slug/` and numbers from `001`; the anthology keeps `posts/NNN-slug/`
and continues from `018`. `build.py` accepts an optional one-level bank prefix, so
the serial builds with `python3 build.py yuri/001-misfire`. Uploads go to a separate
storage folder too: `marketing-media/tiktok/yuri-serial/<slug>.mp4` (the anthology
uses `marketing-media/tiktok/line-unfold-<slug>.mp4`).

## The image is a screenshot of the app, not of the conversation

Clarified by Itsuki, 2026-08-06, and it applies to both banks.

What the teller sends the friend is **proof of how they used the app and what for**
— the keyboard's result screen. It is *not* a capture of the thread with 相手, and
the story never has to claim the pictured draft/result is word-for-word what was
sent. Consequences worth using:

- The pictured use **may** be the story's pivotal message (most episodes) or simply
  the teller showing the app. Both read as natural; the format does not require the
  former.
- So the image is free to widen the product. If every episode's image is a love
  message, 敬語ボタン looks like a dating toy. Vary what the pictured use is even
  while the story stays a romance.
- **The friend thread is never converted.** ユリ talks to ミカ in raw, sloppy
  Japanese, always. The app lives in the other conversation, offscreen. A narrator
  whose own bubbles are polished has quietly turned the video into an ad.
- What must stay honest: the button label and the draft→result pair have to be
  something the shipping app would actually do.

## Cast

| | |
|---|---|
| ユリ | 24, 社会人2年目. Narrator, always `side: me`. Speaks raw to ミカ. |
| ミカ | 同期. The skeptic, always `side: other`. Never appears in the romance. |
| 先輩 | 27, 隣の部署. Quoted only, never a `side` — the viewer only sees him through ユリ. |

## Format: 実況型 — present tense, outcome unknown (Itsuki, 2026-08-06)

The anthology recounts a finished story to a skeptic. **The serial does not.** The
first attempt at #01 was written that way and was rejected for exactly this: the
teller already knew the ending, so nothing was at stake and the viewer was being
briefed rather than made to wait.

Everything happens **now**, while the video plays:

| | anthology (past) | serial (実況) |
|---|---|---|
| Tense | 過去。結果は出ている | 現在。誰も結果を知らない |
| ミカ's role | 疑う人 | **一緒に返信を考える共犯者** |
| Where the app lands | 種明かし。結果のあと | **送信する直前**。まだ何も決まっていない |
| Viewer's posture | 聞く | 自分ならどう返すか考える |
| Last bubble | オチ | 「既読ついた」 / 相手からの一通 |

Placing the app *before* the outcome is the whole point. A reveal after the result
is an explanation; a reveal while someone is waiting is suspense — and it makes the
keyboard-native advantage structural, because there is visibly no time to go open
another app.

Still 3 pages, still one 相談トーク between ユリ and ミカ, still no build change.
先輩's messages are quoted inside that thread. A two-thread variant (page 1/3 = the
romance thread live) is a later upgrade and needs a page-label field in `post.json`.

## The season spine — the button *is* the thermometer

The縦軸 is not "will they get together". It is **どのボタンを押しているか**. 敬語 is the
distance between them, so the command she taps tracks the relationship, and the
finale is her not tapping anything:

```text
敬語 → 重くしない（自作） → タメ口（自作） → 変換しない
```

This is why the serial is worth doing at all: it demonstrates that the buttons are
the user's own, across eight episodes, **without one line of dialogue saying the
app is customizable**. The onboarding actually ships this (`OnboardingUseCase` →
その他（AIにおまかせ）→ free-text description → generated button), so a viewer who
downloads after #02 can build 「重くしない」 in the flow. Keep the story inside what
the app really does; never invent a command the builder could not produce.

## Serial rules (these override the anthology where they differ)

- **The name beat is demoted after #01.** The anthology's mandatory 「何これ」→
  「敬語ボタン」 exchange reads as amnesia when the same two people have it every
  week. #01 plays it in full. From #02 on, 敬語ボタン is still spoken every episode
  but as a throwaway from ミカ — 「また敬語ボタン？」「敬語ボタンに恋させてもらってるね」
  「今日はどのボタン」. **The name is never optional; only the ceremony is.**
- **Custom-button episodes still name the app, not the button.** The beat is
  「敬語ボタン」→「敬語じゃなくない？」→「ボタン自分で作れる」. Run it once (#02), then
  assume the audience knows.
- **Every episode opens by re-entering the story** (「昨日の続きなんだけど」「先輩の件」)
  and **ends on an unresolved hook**, not a punchline. This is the one place the
  serial breaks the anthology's payoff rule.
- **Episode number goes in the caption**, `【#3】先輩に30分遅刻された日` — the template
  bakes no title, and a serial is unfollowable if a new viewer cannot find #1.
- **Two episodes per season use no conversion at all** (currently #06 and #08).
  Eight straight wins reads as an ad; the raw message landing better than the
  converted one is what makes the other six believable.
- **At least two images per season show a use that is not a message to 先輩** —
  a work apology, a message to her mother, whatever she happens to be showing ミカ.
  A romance serial whose every screenshot is a love message teaches the viewer that
  敬語ボタン is for flirting. The image only has to prove the app, not the plot (see
  the screenshot rule above). Currently unassigned; #05 and #07 are the natural
  slots.
- **Something irreversible has already happened before the first bubble ends.**
  「返信がきた」 is not an event. 誤爆した / 既読がついた / 送ってしまった is. The
  first attempt at #01 opened on a thank-you message getting a reply and had nothing
  at stake; that is the failure mode to check for.

## The draft has to be unsendable (the 落差 rule)

Rejected first cut of #01: 「めっちゃ楽しかったです〜」→「とても楽しかったです」. Nearly
the same sentence, so the product looked like it did nothing.

**The draft must be a message that would end the relationship if it were sent.**
Not a casual one — a fatal one. The viewer should wince at the draft and laugh at
the result; that gap *is* the demo, and it costs no extra screen time.

| ✕ too close | ○ unsendable |
|---|---|
| めっちゃ楽しかったです〜 | は？30分待たせて何なん |
| また飲みましょう！！ | 好きです付き合ってください無理なら忘れて |
| いつでも大丈夫です | ごめんなさい！！誤送信です！！でも嘘じゃないです！！ |

The result still has to be a faithful rewrite of that draft — it may not introduce
facts the draft did not contain. #01 works because her own panicked 「でも嘘じゃない
です」 is what the polite version turns into a deliberate admission; the app made her
sound like she meant it, which is a rewrite, not an invention.

## Season 1 — what shipped (2026-08-06)

Nine episodes, written together so the arc actually connects, rendered and
scheduled on yuri_keigobutton at 12:00 / 19:00 / 22:00 JST across Aug 7–9.
Sequence matters: each episode's last bubble is the next one's premise.

**`posts/yuri/<slug>/post.json` is the source of truth for every bubble.** This
file records the intent, the command, the draft→result pair and the hook — the
full bubble list is not duplicated here, because a second copy of the dialogue
would drift from the rendered one.

| # | Slug | 場面（すべて現在進行） | Command | 引き | Zernio post |
|---|---|---|---|---|---|
| 1 | `001-misfire` | ミカ宛の「先輩のこと好きすぎてしんどい」を本人に誤爆。取消の前に既読 | 敬語 | 「今から電話していい？」 | `6a74176ea76cca329b3586e1` |
| 2 | `002-next-day` | 電話で全部言ったのに保留。そこへ「明日会える？」 | 重くしない（自作） | 待ち合わせが彼の家から徒歩3分 | `6a741775762ecee04556fbba` |
| 3 | `003-thirty-minutes` | 雨の店先で30分待たされ、素で「は？」と打つ | 敬語 | 帰り際「敬語やめない？」 | `6a741777defbb5cf2c8da278` |
| 4 | `004-casual-button` | 言われた通り敬語をやめたら、素のテンションが出て既読無視 | タメ口（自作） | 「どっちが本物？」 | `6a741778762ecee04556fc91` |
| 5 | `005-rival` | 同期と先輩が二人で飲んでいるストーリー。嫉妬の3行を打ってしまう | 重くしない | 同期から個別DM「先輩のこと好きなの？」 | `6a74177fdefbb5cf2c8da3f1` |
| 6 | `006-cannot-send` | 同期に嘘をつくため変換したが、送れない | 敬語（**送らない**） | 「先輩も知ってるよ」 | `6a741781762ecee04556fd8f` |
| 7 | `007-call-me` | 勢いで「知ってたんですか」を送信。折り返しの電話が途中で切れる | 敬語 | かけ直しても出ない | `6a741783defbb5cf2c8da4d5` |
| 8 | `008-deadline` | 寝ていない朝、締切を飛ばして部長に謝罪（**非恋愛の画像回**） | 敬語 | 先輩が急に有給を取っている | `6a741789defbb5cf2c8da755` |
| 9 | `009-doorstep` | 雨の中、先輩の家の前に20分立っている | 敬語 | 出てきた先輩の一言の途中で、ユリが返信をやめる | `6a74178ba76cca329b358c6c` |

### Why it stops at 9 instead of ending

The documented finale（先輩「文章、直してるでしょ」→「毎回そんなに時間かけて送ってくれてる
んだと思って、それが嬉しかった」）は **使っていません**。3日で完結させるとフォローする理由が
消えるので、#9 は「先輩が言いかけたことを、視聴者もミカも聞けないまま終わる」形にしてあります。
ユリが返信を止めて、最後の吹き出しがミカの「ユリ？」で終わるのが引き。シーズン2の頭で回収します。

### Episode notes

- **#04** は変換で*くだけさせる*回。敬語ボタンで敬語をやめるという矛盾を ミカ が
  「敬語ボタンで敬語やめてるの草」と言語化する。カスタムボタンの二度目の提示。
- **#06** はシーズンの主題回。完璧な言い訳が出力されたのに「嘘が上手くなるだけだった」と
  送らない。**製品を一度否定することで、残り8話の説得力を買っている。**
- **#08** は画像が仕事の謝罪。連載ルール「シーズンに2枚は非恋愛の用途」を満たす枠。
  部長の一言で恋愛本編に戻る構造なので、寄り道には見えない。
- 音楽は場面で振り分け済み（`dating` / `rushing` / `playful` / `chill`）。全話 pin 済み。

### Known risks

- ストーリーは個別承認を経ていない。各話は投稿時刻前なら Zernio 側で削除できる。
- #9 の「家の前で20分待つ」は、コメント欄で「怖い」と言われる可能性がある。ミカに
  「事案」と言わせて自己申告済みだが、反応が悪ければ #9 を差し替える。

---

# シーズン2 — 2026-08-09（レンダー・スケジュール済み）

**縦軸は「異動までのカウントダウン」。** #10 で先輩の大阪異動が明かされ、残り一ヶ月
という締切が全話に効く。シーズン1が「関係が始まるかどうか」だったのに対し、
シーズン2は「終わりが決まっている中で、何を言えるか」。

`posts/yuri/<slug>/post.json` が全吹き出しの source of truth。ここは意図・
コマンド・draft→result・引きだけを記録する（台詞を二重に持つとズレるため）。

## ボタンの縦軸が完走する

シーズン1で提示した `敬語 → 重くしない（自作）→ タメ口（自作）→ 変換しない` を、
シーズン2で**最後まで通す**。#18 でユリが初めて敬語ボタンを開いて閉じるのが到達点で、
シーズン1で温存していた documented finale（先輩「文章、直してるでしょ」→「毎回そんなに
時間かけて送ってくれてると思って、それが嬉しかった」）をここで回収した。

| # | Slug | 場面（すべて現在進行） | Command | 引き | Zernio post |
|---|---|---|---|---|---|
| 10 | `010-osaka` | 玄関先で「来月、大阪に異動する」と言われた翌朝 | 敬語 | 「今週どっかで会える？」／あと一ヶ月 | `6a781d22e322b8d2ed71d72c` |
| 11 | `011-what-are-we` | 週三で会うが関係は未定義。聞こうとして軽くしすぎる | 重くしない（自作） | 既読四十分、返信なし | `6a781d23e9a46a5fd80f894b` |
| 12 | `012-she-gave-up` | 同期から「諦める、大阪行くって聞いたから」。誰にも言っていないのに | **変換しない** | 「先輩、断れたのに受けたんだよ」 | `6a781d26e9a46a5fd80f8a06` |
| 13 | `013-his-mother` | 先輩の母から突然LINE（**非恋愛画像回①**） | 敬語 | 「あの子、一年前も同じことしようとしたのよ」 | `6a781d2851ad3e33be2ea4a6` |
| 14 | `014-a-year-ago` | 一年前にも異動話があり、その時は断っていた | 重くしない | 「先に見せたいものがある」 | `6a781d2ae322b8d2ed71d9e4` |
| 15 | `015-the-unsent` | 一年前に送らなかった下書きが残っている | タメ口（自作） | 「見たら、たぶん今の距離ではいられない」 | `6a781d3151ad3e33be2eab49` |
| 16 | `016-wrong-name` | 締切を飛ばし部長に謝罪、宛先が先輩（**非恋愛画像回②**） | 敬語 | 「送別会の幹事、やってくれる？」 | `6a781d33e322b8d2ed71dcda` |
| 17 | `017-the-invitation` | 自分がいなくなる会の日程を本人に事務連絡 | 敬語（送ってしまう） | 「ユリに送られるの、しんどい」 | `6a781d3629e4b4e080429ec0` |
| 18 | `018-closed-it` | 送別会の夜。敬語ボタンを開いて、閉じた | **変換しない** | 「で、大阪は」「来週話すって」 | `6a781d3851ad3e33be2eb040` |

グリッドは **12:00 / 19:00 / 22:00 JST**、8/10〜8/12 の3日間。

## シーズンルールの充足状況

- **変換しない回が2話**（#12・#18）— 八連勝がCMに見えるのを防ぐ既定ルール。#12 は
  問い詰める文を変換したうえで「取り調べじゃん」と送らず素で返す回、#18 は縦軸の到達点。
- **非恋愛用途の画像が2枚**（#13 先輩の母、#16 部長）— 敬語ボタンが恋愛専用ツールに
  見えないための既定ルール。
- **毎話が物語に再入して始まり、未解決の引きで終わる**（#18 のみ回収しつつ大阪を残す）。
- **敬語ボタンは全話で発話**。#01 以外は儀式にせず、ミカの軽口として置いている
  （「また敬語ボタン？」「敬語ボタンでタメ口作ってるの毎回笑う」等）。
- **落差ルール**：全話の draft は送ったら関係が終わる文。#18 の
  「行かないでください…好きです」→「お気をつけて行ってらっしゃい」が最大の落差で、
  **その画像1枚がシーズンの主題そのもの**になっている。

## シーズン3に残したもの

大阪の話は解決していない。#18 の最後は「来週話すって」で終わっているので、
シーズン3は**遠距離になるのか、先輩が残るのか**から始められる。ユリが変換を
やめた状態から始まるので、ボタンの縦軸は新しいものが要る。

---

# アンソロジー転換 —「送ってしまった後」（2026-08-11）

**連載は #18 で終了。#19 以降は読み切り。** 判断の根拠は `README.md`
§The three accounts §なぜ変えたか（#1 19,346 views → #12 94 views の単調減衰。
連載は新規視聴者に入口がない）。#13–#18 は 8/12 まで予約済みでそのまま流す。

このレーンが書くのは **「もう送ってしまった」後の後始末**だけ。誤爆、酔い、
既読、スクショ、順番の間違い。語り手は取り返しがつかない側。
**毎話が誰かの #1** になるように、前の話を知らなくても成立させる。

上の連載向けの記述（固定キャスト、ユリと先輩、実況型、シーズン構成）は
#1–#18 の記録として残す。新作の仕様ではない。

| # | 事故 | 寄りのエスカレーション | どんでん返し | Cmd | BGM | 枠 (JST) | Zernio |
|---|---|---|---|---|---|---|---|
| 019 | 酔って先輩に送信 | 1通 → 3通 → **ボイスメッセージ17秒** | 本人は何通あるか分かっていない | 敬語 | `dating` | 8/13 12:00 | `6a7a06a342d12eb50eaa24c4` |
| 020 | 愚痴を本人に誤爆 | 一言 → 取り消し跡 → **本人が同意** | 相手も同じことを思っていた | 敬語 | `dating2` | 8/13 19:00 | `6a7a06a542d12eb50eaa2529` |
| 021 | 既読無視3日の言い訳 | 3日 → 言い訳 → **ストーリー4回更新** | 「今の文、あなたの言葉じゃない」 | 自然に | `dating3` | 8/13 22:00 | `6a7a06a742d12eb50eaa25e8` |
| 022 | 長文のあと追撃5通 | 800字 → 既読 → **追撃5通** | 相手の父が入院していた | 自然に | `dating` | 8/14 12:00 | `6a7a06af2e1a245bf8b43044` |
| 023 | 元カレ宛を今カレに | 名前の並び → 誤爆 → **既読1秒** | 今カレも同じ文を打っていた | 自然に | `dating2` | 8/14 19:00 | `6a7a06b12e1a245bf8b430f8` |
| 024 | スクショが本人に到達 | 1枚 → 4人経由 → **アイコンで特定** | 自分を撮ったスクショも回っている | 敬語 | `dating3` | 8/14 22:00 | `6a7a06b32e1a245bf8b43172` |
| 025 | 人事にタメ口メール | 「了解です！」→ 取り消し不可 → **相手が最終面接官** | 面接官が同席する | 敬語 | `dating` | 8/15 12:00 | `6a7a06bb2e1a245bf8b432f4` |
| 026 | 彼氏の愚痴を母に誤爆 | 誤爆 → 既読 → **母が本人を知っている** | 先週すでに挨拶に来ていた | 自然に | `dating2` | 8/15 19:00 | `6a7a06bd940f5d0154218186` |
| 027 | 退職を言う順番ミス | 同期1人 → 一晩で全員 → **部長だけ未通知** | 部長も今月で辞める | 敬語 | `dating3` | 8/15 22:00 | `6a7a06bf42d12eb50eaa27b8` |
