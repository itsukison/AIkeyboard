# Japanese Keyboard — Implementation Plan

Pure Japanese iOS keyboard targeting iOS-native look-and-feel for the keyboard surface, and the Bikey Design System for the container app.

Date: 2026-06-06
Owner: itsuki.son@gastroduce-japan.co.jp
Status: Plan locked, awaiting green light to start Phase 1

---

## 1. Goal and Scope

### Goal
Ship a pure Japanese iOS keyboard that matches the native iOS Japanese keyboard in:
- Visual fidelity (key shape, color, spacing, font, light/dark mode)
- Interaction smoothness (key press animation, callouts, popups, flick gesture, haptics)
- Conversion accuracy (kana to kanji, candidate ranking, learning)
- Live conversion behavior (real-time candidate update while typing)

### In scope (v1)
- Keyboard extension that the user enables via Settings > General > Keyboard > Keyboards > Add New Keyboard
- Input modes: ローマ字 (QWERTY) only, Number/Symbol, Emoji passthrough to system
- Conversion: kana to kanji via AzooKey dictionary mode (no neural model in v1)
- Candidate bar above keyboard with horizontal scroll
- Live conversion (real-time provisional commit while user types)
- Container app: onboarding, keyboard enable guide, user dictionary, settings
- App Group sharing between container app and extension (for dictionary, settings, learning)

### Out of scope (v1, deferred)
- かな (テンキー / flick) input — deferred to v2
- Zenzai neural reranker (69MB GGUF) — too heavy for jetsam in v1, planned for v2 with on-demand download
- Magic Conversion (LLM-based) — desktop only feature, not relevant
- Handwriting input
- Voice input (use system)
- Themes / customization (keyboard surface is fixed to iOS-native look)
- Bilingual / English keyboard (out of scope by design — this is a pure Japanese product)
- Watch / vision / Mac variants

### Non-goals
- Beating the native iOS keyboard. We aim to match it, not exceed it visually.
- Maximum customization. The keyboard surface intentionally has no theming.

---

## 2. Technology Stack

| Layer | Choice | Reason |
|---|---|---|
| Conversion engine | `AzooKeyKanaKanjiConverter` v0.11.x (MIT, SPM) | Only Swift-native, iOS-ready, actively maintained kana-kanji engine. Already proven in `keyboard/` |
| Keyboard chrome (touch / callouts / haptics / key rendering) | `KeyboardKit` OSS v10.x (MIT, SPM) | Default styling closely matches iOS native. Free. Handles painful low-level details |
| Candidate bar | Custom SwiftUI (horizontal `ScrollView`) | Needs to match iOS native candidate bar look |
| Container app UI | SwiftUI + Bikey Design System | Per existing `keyboard/design.md` |
| Persistence (settings, learning) | App Group `UserDefaults` + on-disk `Codable` JSON for user dictionary | Simple, no Supabase dependency in v1 |
| Build | Swift Package Manager + XcodeGen (`project.yml`) | Matches `keyboard/` pattern |
| Min iOS | iOS 16.0 (per AzooKeyKanaKanjiConverter requirement) | Liquid Glass paths gated to iOS 26+ in container only |

### Dependencies to add to Package.swift
- `https://github.com/azooKey/AzooKeyKanaKanjiConverter` (.upToNextMinor from 0.11.1), product `KanaKanjiConverterModuleWithDefaultDictionary`
- `https://github.com/KeyboardKit/KeyboardKit` (.upToNextMinor from 10.x)

### Explicitly NOT used
- `SymSpellSwift` (English-only, irrelevant)
- KeyboardKit Pro (paid, English-centric autocomplete, no Japanese IME)
- Mozc / JapaneseKeyboardKit (no iOS support, ObjC++ legacy)
- Supabase (no cloud sync in v1)
- Zenzai model weights (deferred to v2)

---

## 3. Project Structure

```
Japanese/
  Package.swift                       # SPM manifest, products: JapaneseKeyboardCore, JapaneseKeyboardUI, KeyboardPreferences
  project.yml                         # XcodeGen config: container app + extension targets
  CLAUDE.md                           # behavioral guidelines (copy from keyboard/)
  PLAN.md                             # this file
  README.md                           # short build/run instructions
  .gitignore
  .swiftpm/                           # SPM artifacts
  Sources/
    JapaneseKeyboardCore/             # IME logic, no UI
      Romaji.swift                    # ported from keyboard/Sources/EnglishKeyboardCore/Romaji.swift
      KanaKanjiAdapter.swift          # wraps AzooKey KanaKanjiConverter with async + cache + cancel
      InputManager.swift              # state machine: input -> composing kana -> candidates -> commit
      LiveConversionEngine.swift      # debounced re-query on input change
      Candidate.swift                 # candidate model (text, reading, score, source)
      Resources/
        (dictionary loaded via AzooKey default bundle, no extra files needed initially)
    JapaneseKeyboardUI/               # SwiftUI views, no IME logic
      KeyboardRootView.swift          # top-level view embedded in KeyboardViewController
      Qwerty/
        QwertyLayoutView.swift        # uses KeyboardKit's SystemKeyboard with kana-producing actions
      Common/
        CandidateBar.swift            # horizontal scroll candidate strip
        CandidateBarExpanded.swift    # full-screen candidate grid (long-press)
        FunctionKeyButton.swift       # 改行 / スペース / 削除 / ABC切替 / 地球儀
      Styling/
        NativeKeyStyle.swift          # colors, fonts, corner radii matching iOS native
    KeyboardPreferences/              # settings persistence, ported from keyboard/
      Preferences.swift
      AppGroup.swift                  # App Group identifier constant
  iOS/
    Container/                        # main app target
      ContainerApp.swift
      Screens/
        OnboardingFlow.swift          # Welcome -> Enable Keyboard -> How It Works (per design.md)
        HomeScreen.swift
        DictionaryScreen.swift        # user dictionary CRUD
        KeyboardSettingsScreen.swift  # composition mode, layout default, haptics
        ProfileScreen.swift           # minimal in v1: about, version, licenses
      DesignSystem/                   # ported / pruned from keyboard/design.md helpers
        BikeyColor.swift
        BikeyShape.swift
        BikeyGlass.swift
        BikeyFont.swift
      Assets.xcassets
      Info.plist
    KeyboardExtension/                # extension target
      KeyboardViewController.swift    # UIInputViewController subclass, hosts SwiftUI root via UIHostingController
      Info.plist                      # RequestsOpenAccess = NO (no network)
  Tests/
    JapaneseKeyboardCoreTests/
      RomajiTests.swift
      KanaKanjiAdapterTests.swift
      InputManagerTests.swift
      LiveConversionEngineTests.swift
    JapaneseKeyboardUITests/
      CandidateBarTests.swift
```

Notes:
- App Group identifier: `group.co.gastroduce-japan.bikey.japanese` (TBD with provisioning)
- Bundle IDs: container `co.gastroduce-japan.bikey.japanese`, extension `co.gastroduce-japan.bikey.japanese.keyboard`

---

## 4. Native iOS Keyboard Behavior Spec

The keyboard surface must look and feel "exactly like the native iOS keyboard". This is the explicit spec to match.

### Visual
- Background: system gray (matches `UIKeyboardAppearance` light/dark)
- Letter key: white in light mode (`#FFFFFF`-ish), dark gray in dark mode
- Function key (shift, delete, switch): slightly darker than letter key
- Key corner radius: 5 pt
- Key shadow: 1 pt offset, low opacity black
- Key font: SF Pro, ~22-24 pt for letter keys, ~16 pt for function keys
- Inter-key gap: ~6 pt horizontal, ~12 pt vertical
- Row height: ~42 pt on standard iPhone
- Total keyboard height: ~216 pt portrait (system default)

### Interaction
- Tap: key scales 1.1x briefly, plays light haptic (`.light` impact)
- Long press on letter: callout appears above showing larger preview of the character
- Long press on key with variants: popup expands showing alternatives
- Flick on テンキー key: 5-direction popup (center=あ, up=い, down=う, left=え, right=お), commit on release in direction
- Drag from key to key: input slides (system behavior)
- Space long press: enters cursor-drag mode, swipe to move cursor
- Delete long press: accelerating delete
- Globe (next keyboard): tap to switch, long press for picker

### Modes (Japanese only, v1)
1. **ローマ字 (QWERTY)** — standard QWERTY producing romaji that resolves to hiragana via `Romaji.swift`. **Default and only kana input mode in v1.**
2. **数字 (Numbers)** — 12-key numeric layout
3. **記号 (Symbols)** — punctuation, brackets, etc.
4. **ABC** — basic Latin for inline English (system-style toggle, no autocorrect for English in v1)

Mode switch key in lower-left corner cycles ローマ字 > ABC > 数字 > 記号 > ローマ字 (matches native).

**Deferred to v2**: かな (テンキー with flick) input.

### Candidate bar
- Sits above the keyboard, ~36 pt tall
- White-ish background blending into keyboard background
- Horizontal scroll of candidates
- First candidate is highlighted/selected by default for live conversion
- Long press a candidate: expand to grid view filling keyboard area
- Tap a candidate: commit and reset composing buffer
- Empty state: shows nothing (or system clipboard suggestion in v2)

### Live conversion (matching iOS native)
- As user types kana, top candidate is shown inline (provisional) in the host text field
- Space key cycles through candidates
- Enter or tap candidate commits
- Tap outside or new word commits the current top candidate and starts fresh

---

## 5. Implementation Phases

Each phase has a clear verification criterion. Do not advance to the next phase until verified.

### Phase 1 — Project skeleton
**Goal**: empty extension shows up in iOS Settings and can be added as a keyboard, displays a black bar.

- Create `Japanese/Package.swift` with the three library products
- Create `Japanese/project.yml` for XcodeGen
- Create container app stub (single SwiftUI view "Hello")
- Create extension stub `KeyboardViewController` that returns an empty `UIInputView`
- Set up App Group entitlement
- Add `.gitignore`, copy `CLAUDE.md` from `keyboard/`

**Verify**: `xcodegen generate && xcodebuild -scheme BikeyJP` succeeds. Install on simulator. Add the keyboard in Settings. Tap globe in any app and see the empty keyboard space.

### Phase 2 — QWERTY romaji input (no conversion)
**Goal**: type "konnichiha" on a QWERTY layout and "こんにちは" appears in the host text field (raw kana, no kanji conversion yet).

- Port `Romaji.swift` from `keyboard/Sources/EnglishKeyboardCore/Romaji.swift`
- Add KeyboardKit dependency
- Wire `QwertyLayoutView` using KeyboardKit's `SystemKeyboard` with custom action handler that maps romaji buffer to kana and calls `textDocumentProxy.insertText`
- Implement basic delete/space/return

**Verify**: All 300+ romaji entries produce correct kana. Manual test of `kya`, `vya`, `xtu`, `nn`, etc. Unit tests in `RomajiTests`.

### Phase 3 — Kana-kanji conversion (QWERTY mode)
**Goal**: typing "きょう" and pressing space shows "今日 / 京 / 共 ..." candidates above the keyboard, tapping commits.

- Add AzooKeyKanaKanjiConverter dependency
- Implement `KanaKanjiAdapter` wrapping `KanaKanjiConverter.withDefaultDictionary()`
- Implement `InputManager` state machine: composing kana buffer, candidate list, commit/reset
- Implement `CandidateBar` SwiftUI view
- Wire space key to cycle candidates, enter to commit, delete to backspace within composition or delete committed text

**Verify**: 20 manual test phrases produce sensible top candidate. Backspace inside composing buffer works. Tap candidate commits.

### Phase 4 — Live conversion
**Goal**: as user types kana, the top candidate is shown provisionally in the host text field and updates in real time. Matches iOS native behavior.

- Implement `LiveConversionEngine` with debounce (~50 ms) on input change
- Use `textDocumentProxy.setMarkedText` to show provisional text
- Recompute candidates on every keystroke (async, cancellable)
- Commit on space (advance) or other commit triggers

**Verify**: Typing "あした" shows "明日" provisional. Adding "は" shows "明日は". Backspace reverts cleanly. No flicker.

### Phase 5 — Native polish
**Goal**: keyboard surface visually indistinguishable from iOS native at a glance.

- Implement `NativeKeyStyle` with exact iOS colors, radii, fonts, shadows
- Light / dark mode support via `UIKeyboardAppearance`
- Haptic feedback on key press (`UIImpactFeedbackGenerator`)
- Long-press callout for letter preview
- Cursor-drag on space long-press
- Accelerating delete on delete long-press
- Globe key with next-keyboard / picker behavior

**Verify**: Visual diff against screenshots of iOS native keyboard (filed in `reference/`). Each interaction tested manually.

### Phase 6 — Container app
**Goal**: container app provides onboarding, dictionary, and settings per Bikey Design System.

- Implement onboarding flow (4 pages per `keyboard/design.md` lines 322-333)
- Implement Home screen with enable status, recent conversions
- Implement Dictionary screen (CRUD on user dictionary stored in App Group)
- Implement Keyboard Settings (default layout, haptics on/off, composition mode)
- Wire user dictionary into `KanaKanjiAdapter` as additional candidate source

**Verify**: Design review checklist from `keyboard/design.md` lines 450-463 passes for each screen.

### Phase 7 — Learning and persistence
**Goal**: keyboard remembers user choices across sessions.

- Implement learning: when user picks a non-top candidate, boost its score for that reading
- Store learning data in App Group `UserDefaults` (encrypted if feasible)
- Verify learning persists after extension is killed (jetsam-resilient)

**Verify**: Type same reading 5 times, pick same non-top candidate each time. On 6th time, it should be the top candidate.

### Phase 8 — Hardening
**Goal**: ship-ready quality.

- Memory profiling on iPhone 12 (oldest supported), confirm < 50 MB peak
- Unit test coverage > 70% on Core modules
- Manual QA pass on 30 common phrases
- Accessibility: VoiceOver, Dynamic Type on container app
- App Store screenshots, metadata, privacy nutrition label (no data collected, no network)

**Verify**: Internal beta on TestFlight with 5 users for 1 week, no crashes, positive feedback on smoothness.

### Optional v2 — Zenzai neural reranker
- Add `--zenzai` trait to AzooKeyKanaKanjiConverter dependency
- Container app downloads ~70 MB GGUF on demand to App Group container
- Extension loads model only if free memory allows (gated by `os_proc_available_memory`)
- Re-rank top-N candidates using left-side context
- Feature flag with kill switch

---

## 6. Memory and Performance Plan

iOS keyboard extensions are killed by jetsam around 30-60 MB resident. This is the single hardest constraint.

| Item | Footprint | Strategy |
|---|---|---|
| AzooKey default dictionary | ~10-20 MB | Bundled in extension, loaded lazily on first conversion |
| Romaji table | < 1 MB | Static Swift dictionary |
| KeyboardKit + own UI | ~5-10 MB | Standard |
| Candidate cache | bounded to last 50 queries | LRU eviction |
| User dictionary | < 1 MB | Loaded from App Group on launch |
| Live conversion async tasks | transient | Cancel previous task on new input |
| Zenzai GGUF | 69 MB | **v2 only**, gated by available memory check |

Total v1 target: < 40 MB peak resident memory.

Performance targets:
- First key press to candidate display: < 100 ms
- Per-keystroke recompute (live conversion): < 50 ms
- Cold start of extension: < 500 ms

---

## 7. App Container Plan (Bikey Design System)

The container app follows the existing `keyboard/design.md` design language. Apply it as-is, with pruning:

### Screens (in order of build priority)
1. **Onboarding (4 pages)** — per `keyboard/design.md` lines 322-333: Welcome > Account (sign-in deferred to v2) > Enable Keyboard > How It Works
2. **Home** — enable status, recent conversions (last 10), quick links
3. **Dictionary** — user dictionary CRUD, search, import/export
4. **Keyboard Settings** — default layout (テンキー / QWERTY), haptics, composition mode
5. **Profile / About** — minimal in v1: version, licenses, privacy policy

### Design system pieces to port from `keyboard/`
- `BikeyColor` palette (canvas, ink, purple accent — keyboard/design.md lines 86-98)
- `BikeyShape` (corner radii — lines 138-146)
- `BikeyGlass` helpers (Liquid Glass on iOS 26+ with fallback — lines 178-197)
- `BikeyFont` (SF Pro scale — implied throughout)
- Onboarding ambient `gradientwithglobe` background
- Bottom tab bar (4 tabs: Home, Dictionary, Settings, Profile)

### Removed from container (vs `keyboard/`)
- Supabase auth (v1 is local-only, anonymous)
- Bilingual / English-related UI
- Trigram debugging tools
- Bilingual mode selector

---

## 8. Open Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Jetsam kills extension under memory pressure | High | High | Profile early in Phase 3, set hard cap and back off candidate cache, defer Zenzai |
| Live conversion flicker / lag | Medium | High | Debounce + cancellation discipline, profile in Phase 4 |
| AzooKey dictionary quality not matching native | Low | Medium | Augment with user dictionary, monitor user-reported misses, optional Zenzai in v2 |
| KeyboardKit's default styling drifts from iOS native after iOS update | Low | Low | Wrap KeyboardKit theming in our own style layer, can swap out later |
| App Store rejection (keyboard extension policies) | Low | High | No network access in extension, RequestsOpenAccess = NO, no analytics in v1 |

---

## 9. First Commands to Bootstrap (when approved)

```bash
cd /Users/itsuki/Desktop/key/Japanese
# create Package.swift, project.yml, .gitignore
# create directory skeleton per section 3
# add CLAUDE.md
# xcodegen generate
# open BikeyJP.xcodeproj
```

Once approved, Phase 1 wraps with a green build and a visible (empty) keyboard in the simulator.

---

## 10. Decisions Locked In

- Engine: `AzooKeyKanaKanjiConverter` (no alternative considered going forward)
- UI base: `KeyboardKit OSS` + custom テンキー (no azooKey fork, no full custom from zero, no KeyboardKit Pro)
- Keyboard surface visual: **exact iOS native look**, no theming, no Bikey palette
- App container visual: **Bikey Design System** per existing `keyboard/design.md`
- v1 ships without Zenzai (neural reranker deferred to v2)
- No Supabase, no auth, no cloud sync in v1
- Min iOS 16, Liquid Glass paths gated to iOS 26+ on container only
