/*
 * Shared conversation data for the content templates.
 * Loaded by both line-chat.html and product-ui.html (via <script src="../scenes.js">)
 * so a product frame can show the real conversation context above the raised keyboard.
 * Keep every chat fictional — no real names, employers, or private messages.
 */
const SCENES = {
  progress: {
    name: "上司",
    day: "今日",
    messages: [
      { side: "boss", text: "今日中にいけそう？", time: "16:42" },
      { side: "me", text: "正直、厳しいです…", time: "16:43", read: "既読" },
      { side: "boss", text: "どこまでならいける？", time: "16:44" },
      { side: "me", text: "最寄駅までならいけます", time: "16:44", read: "既読" },
      { side: "boss", text: "仕事の進捗の話です", time: "16:45" },
      { side: "me", text: "……", time: "16:45", read: "既読" },
      { side: "me", text: "申し訳ありません。本日中の完了が難しいため、明日午前までお時間をいただけますでしょうか。", time: "16:47", read: "既読" },
      { side: "boss", text: "了解です。明日午前でお願いします", time: "16:48" }
    ]
  },
  "sick-day": {
    name: "上司",
    day: "今日",
    messages: [
      { side: "me", text: "今日熱出たので会社お休みさせていただきます。", time: "8:06", read: "既読" },
      { side: "boss", text: "37.3度は熱じゃないですよ？", time: "8:06" },
      { side: "me", text: "それは人によると思いますが…", time: "8:07", read: "既読" },
      { side: "me", text: "出社した方が良いでしょうか？", time: "8:07", read: "既読" },
      { side: "boss", text: "体調が悪いなら休んでいいですよ", time: "8:08" },
      { side: "me", text: "承知いたしました。ご迷惑をおかけして申し訳ありません。本日は休暇をいただき、回復に努めます。", time: "8:10", read: "既読" }
    ]
  },
  "creepy-boss": {
    name: "上司",
    day: "今日",
    messages: [
      { side: "boss", text: "今日いつもより可愛いね。彼氏できた？笑", time: "9:12" },
      { side: "boss", text: "今度、二人で飲みに行こうよ。仕事の相談もあるし", time: "9:12" },
      { side: "me", text: "恐れ入りますが、業務に関係のない個人的なご質問や、二人きりでのお誘いは控えていただけますでしょうか。今後は業務に関するご連絡のみお願いいたします。", time: "9:20", read: "既読" },
      { side: "boss", text: "そんな固くならなくても笑", time: "9:21" },
      { side: "me", text: "誤解を避けるため、明確にお伝えしております。今後は業務に関するご連絡のみお願いいたします。", time: "9:25", read: "既読" }
    ]
  },
  "saturday-work": {
    name: "上司",
    day: "土曜日",
    messages: [
      { side: "boss", text: "これ、月曜でいいからちょっと見といて", time: "7:04" },
      { side: "me", text: "ご連絡ありがとうございます。本件は月曜日に確認のうえ、対応いたします。休日中は即時の対応が難しいため、緊急の場合は事前にご相談いただけますと幸いです。", time: "7:12", read: "既読" },
      { side: "boss", text: "了解！じゃあ月曜朝イチで！", time: "7:13" },
      { side: "me", text: "月曜日の始業後に確認し、対応いたします。内容を確認のうえ、完了見込みをご連絡いたします。", time: "7:16", read: "既読" }
    ]
  },
  "secret-drink": {
    name: "上司",
    day: "今日",
    messages: [
      { side: "boss", text: "今度こそ二人で飲みに行こうよ", time: "21:14" },
      { side: "boss", text: "嫁には内緒で笑", time: "21:14" },
      { side: "me", text: "業務外で二人きりのお誘いはお断りいたします。ご家族にお伝えできない内容のご連絡もお控えください。", time: "21:26", read: "既読" },
      { side: "boss", text: "冗談に決まってるじゃん笑", time: "21:27" },
      { side: "me", text: "冗談として受け取れない内容でしたので、今後同様のご連絡はお控えください。", time: "21:31", read: "既読" }
    ]
  },
  "friday-revision": {
    name: "取引先",
    day: "金曜日",
    messages: [
      { side: "boss", text: "簡単な修正なので、本日中にお願いできますか？", time: "17:58" },
      { side: "me", text: "恐れ入りますが、本日中の対応は難しい状況です。月曜日の午前中であれば対応可能ですが、いかがでしょうか。", time: "18:05", read: "既読" },
      { side: "boss", text: "5分で終わると思うんですが……", time: "18:06" },
      { side: "me", text: "作業時間にかかわらず、現在の対応状況では本日中のお約束ができかねます。月曜日午前中の対応でお願いいたします。", time: "18:09", read: "既読" }
    ]
  },
  "progress-check": {
    name: "上司",
    day: "今日",
    messages: [
      { side: "boss", text: "これ、明日の朝までにお願い！", time: "23:58" },
      { side: "boss", text: "どんな感じ？進んでる？", time: "0:01" },
      { side: "me", text: "現時点では着手直後のため、進捗をご報告できる段階ではありません。対応可能な期限を確認のうえ、改めてご連絡いたします。", time: "0:04", read: "既読" },
      { side: "boss", text: "ざっくりでいいから、朝までに形にして", time: "0:05" },
      { side: "me", text: "品質を担保できないため、明朝までの完了はお約束できません。確認後、対応可能な期限をご連絡いたします。", time: "0:09", read: "既読" }
    ]
  },
  "read-receipt": {
    name: "上司",
    day: "今日",
    messages: [
      { side: "boss", text: "既読ついてるよね？返信くらいできるでしょ", time: "22:47" },
      { side: "me", text: "勤務時間外のため、本件は明日の始業後に確認し、ご返信いたします。緊急連絡が必要な場合は、事前に連絡方法をご共有ください。", time: "22:52", read: "既読" },
      { side: "boss", text: "30秒で返せるよね？", time: "22:53" },
      { side: "me", text: "所要時間にかかわらず、勤務時間外の対応はいたしかねます。明日の始業後に確認いたします。", time: "22:58", read: "既読" }
    ]
  },
  "vague-brief": {
    name: "上司",
    day: "今日",
    messages: [
      { side: "boss", text: "これ、なんか違うんだよね", time: "15:32" },
      { side: "boss", text: "もっといい感じに直しといて", time: "15:32" },
      { side: "me", text: "修正の方向性を揃えるため、変更箇所と期待する状態を具体的にご共有いただけますでしょうか。", time: "15:41", read: "既読" },
      { side: "boss", text: "そこはセンスで分かるでしょ", time: "15:43" },
      { side: "me", text: "認識のずれを避けるため、判断基準を言語化していただけますと助かります。", time: "15:48", read: "既読" }
    ]
  },
  "paid-leave": {
    name: "上司",
    day: "今日",
    messages: [
      { side: "boss", text: "来週の有給、何するの？", time: "13:12" },
      { side: "boss", text: "旅行なら、繁忙期ずらせない？", time: "13:12" },
      { side: "me", text: "私用のため詳細は控えさせていただきます。業務は事前に引き継ぎますので、申請どおりの日程で休暇を取得いたします。", time: "13:20", read: "既読" },
      { side: "boss", text: "チームのこと、ちゃんと考えてる？", time: "13:21" },
      { side: "me", text: "チームへの影響を考え、必要な引き継ぎは事前に完了いたします。休暇の日程に変更はございません。", time: "13:24", read: "既読" }
    ]
  },
  "credit-theft": {
    name: "先輩",
    day: "今日",
    messages: [
      { side: "boss", text: "さっき俺が提案した企画、部長かなり気に入ってたね", time: "18:42" },
      { side: "me", text: "認識の相違を避けるため補足いたします。本日の企画案は、昨日私が共有した資料をもとに作成したものです。今後は作成経緯もあわせてご共有ください。", time: "18:50", read: "既読" },
      { side: "boss", text: "チームの成果だから、誰の案とか関係なくない？", time: "18:51" },
      { side: "me", text: "企画の帰属は今後の連携のためにも重要です。私の資料をもとにされる際は、事前にご一報いただけますと幸いです。", time: "18:55", read: "既読" }
    ]
  },
  "wrong-recipient": {
    name: "上司",
    day: "今日",
    messages: [
      { side: "boss", text: "あの子、褒めとけば残業してくれるから笑", time: "19:32" },
      { side: "boss", text: "あ、送る相手間違えた。今の気にしないで", time: "19:33" },
      { side: "me", text: "先ほどのメッセージは確認しております。今後、評価や称賛を理由に時間外対応を期待することはお控えください。", time: "19:41", read: "既読" },
      { side: "boss", text: "そんな意味じゃないから忘れて", time: "19:42" },
      { side: "me", text: "記載された内容は確認済みです。今後の時間外対応は、必要性と期限を明確にしたうえでご相談ください。", time: "19:47", read: "既読" }
    ]
  },
  "moving-day": {
    name: "上司",
    day: "今日",
    messages: [
      { side: "boss", text: "日曜空いてる？引っ越し手伝ってよ", time: "20:14" },
      { side: "boss", text: "若いし車あるよね？ピザ奢るから！", time: "20:14" },
      { side: "me", text: "申し訳ありませんが、日曜日は私用のため、引っ越しのお手伝いや車の提供はいたしかねます。", time: "20:22", read: "既読" },
      { side: "boss", text: "ピザ奢るって言ってるのに、ケチだな〜笑", time: "20:23" },
      { side: "me", text: "報酬の有無にかかわらず、業務外の個人的な依頼はお引き受けいたしかねます。", time: "20:26", read: "既読" }
    ]
  },
  "voice-memo": {
    name: "上司",
    day: "今日",
    messages: [
      { side: "boss", text: "音声メッセージ（7:42）", time: "10:12" },
      { side: "boss", text: "これ聞いて、要点まとめて全員に共有しといて", time: "10:12" },
      { side: "me", text: "認識の相違を防ぐため、決定事項と対応内容を文章でご共有いただけますでしょうか。", time: "10:31", read: "既読" },
      { side: "boss", text: "聞けば分かるよ。倍速で聞いて", time: "10:32" },
      { side: "me", text: "正確に共有するため、発信者側で決定事項と対応内容をご提示ください。", time: "10:35", read: "既読" }
    ]
  }
};
