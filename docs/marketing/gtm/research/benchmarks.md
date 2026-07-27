# Benchmarks — retention, engagement, growth, channels

Researched 2026-07-18 (web research; sources inline). Feeds `../roadmap.md` targets.

## Retention benchmarks (what "good" means)

- Cross-category medians 2024–26: **D1 ≈ 25%, D7 ≈ 12%, D30 ≈ 6%** (AppsFlyer/Adjust/Statista via [Sendbird](https://sendbird.com/blog/app-retention-benchmarks-broken-down-by-industry)).
- **Utility category (our honest comp): D1 18.3%, D7 6.8%, D30 ~2.4–3.4%.** Productivity: D1 17.1%, D7 7.2%, D30 ~3–4%.
- Top quartile cross-category: D1 ≥30%, D7 ≥15%, D30 ≥8%. Credible "top-decile utility" bar: **D30 ≥10%** ([core-mba](https://www.core-mba.pro/tool-hub/mobile-app-retention), [UXCam](https://uxcam.com/blog/mobile-app-retention-benchmarks/)).
- Subscription apps retain ~2.5× better than ad-supported (D30 14% vs 5.4%, AppsFlyer 2026).
- Japan retains better than global (JP D30 games 6.4% vs US 3.7%); 【推測】JP utility can target 1.3–1.5× global medians.
- DAU/MAU: median ~13%; ≥20% good; ≥25% excellent ([Mixpanel](https://mixpanel.com/blog/mau/), [CleverTap](https://clevertap.com/blog/dau-vs-mau-app-stickiness-metrics/)). WhatsApp 83%, Slack ~60%.

## Keyboard-specific reality

- 【推測】Keyboards are bimodal: users who enable + set default behave like WhatsApp-class utilities (DAU/MAU plausibly 60–90% — typing is unavoidable); users who never enable churn instantly. Blended benchmarks mostly measure the un-activated majority. Evidence for the ceiling: Kika users type ~50 min/day; Simeji ad kit claims 15+ launches/day.
- SimejiAI (ChatGPT feature in Simeji): **870K MAU within 2 months** of July 2023 launch — JP appetite for AI-inside-keyboard is proven ([PR Times](https://prtimes.jp/main/html/rd/p/000000737.000006410.html)).
- No published install→keyboard-enabled conversion benchmark exists anywhere. Our own funnel becomes the benchmark. Nearest analog: ATT opt-in 25–46% → Full-Access opt-in below 50% is normal, not failure.
- Grammarly: 30M+ DAU, >90% retention among paid users.

## Growth benchmarks

- 80% of all apps get <10K downloads/month; only 3.8% ever pass 100K lifetime ([Appfigures](https://appfigures.com/resources/insights/20230714?f=1)). Good early-stage growth = **10–20% MoM sustained 6–12 months**.
- **Retention-before-scale rule: if D30 <10%, scaling installs just accelerates losses** ([enable3](https://enable3.io/blog/mobile-app-growth-strategy)). ~80% of users abandon a new app within 3 days.

## Channels that actually grew JP keyboards

1. **App Store search** — ~65–70% of App Store downloads follow a search (Apple figure). High-intent, high-LTV. → ASO on 敬語/ビジネスメール/キーボード queries is channel #1.
2. **Short-video UGC** ("show the keyboard doing a trick") — Simeji & flick both grew on this; flick reviews cite TikTok discovery. An AI keigo rewrite is inherently screen-recordable. Z-gen JP: YouTube 86%, TikTok ~54%, 56% of 10–20s open TikTok daily.
3. **PR survey engine** — Simeji ランキング surveys → constant media pickup. Transferable: 「敬語に関する調査」→ media pickup. (IP-collab/kisekae tactics don't transfer — our audience is business adults, not Z-gen girls.)
4. **Pain-event switching bursts** — Simeji hit #1 free when an Instagram JP-input bug pushed users to switch; JP users also switch on security discourse (Simeji=Baidu 危険 content). Keyboard switching happens in bursts; be ready to catch them.
5. TV CM entered Simeji's mix only after ~20M downloads — not our phase.

## Target-setting implications for 敬語ボタン

- Blended D30 ≥10% = top decile; among *enabled* users target DAU/WAU ≥40%.
- Current W1 retention (5–18%) is far below even the utility median path — fix before spending on acquisition.
- 10k downloads at 10–20% MoM from ~3.5k: reachable in ~6–8 months organically; faster requires a UGC/PR spike.
