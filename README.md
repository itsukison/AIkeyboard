# KeigoButton

An iOS keyboard I built because rewriting a message in ChatGPT, copying it back, and then returning to the original app felt like way too much work for something as small as “make this sound more polite.”

KeigoButton keeps that interaction inside the keyboard. You type normally, tap a rewrite button such as **敬語**, **メール**, or **自然に**, and the text is rewritten in place.

I released the first version in June 2026. It has since passed **5,000 downloads**, and the product has gradually grown from a simple keigo button into an experiment in what an AI-native input method can feel like.

**Product:** https://keigobutton.com/

## What it does

The keyboard works as a normal Japanese IME first.

- Romaji → kana → kanji conversion runs locally.
- AI is only invoked when the user explicitly asks for a rewrite.
- Rewrite buttons are customizable and sync with the user's account.
- The keyboard can replace the current text directly instead of forcing a copy/paste workflow.
- The container app handles onboarding, settings, prompt management, history, and account state.

The current direction is broader than “make this polite.” The goal is to make the input field itself feel intelligent: write the rough intent, give the model enough context, and let it produce the final message without leaving the app you are already in.

## A few engineering choices I cared about

### Keep normal typing independent from AI

A keyboard still has to be a good keyboard when the network is slow or unavailable. Kana-to-kanji conversion lives in the local IME core, while AI rewriting is a separate layer.

That boundary also makes the privacy model easier to reason about: ordinary typing stays local, and text is sent to the backend only after an explicit rewrite action.

### Treat the keyboard extension as a constrained environment

iOS keyboard extensions have tighter memory, lifecycle, and permission constraints than a normal app. The project is split into small Swift packages so the IME, preferences, and AI behavior can be tested without booting the whole extension.

### Keep provider keys out of the app

AI requests go through a Supabase Edge Function using the user's auth token. Provider credentials never ship inside the keyboard bundle.

## Architecture

```text
Sources/
├── JapaneseKeyboardCore/    # romaji → kana → kanji, IME state
├── JapaneseKeyboardUI/      # reusable SwiftUI keyboard views
├── JapaneseKeyboardAI/      # rewrite capture, replacement, service layer
└── KeyboardPreferences/     # shared settings, prompts and auth state

iOS/
├── Container/               # onboarding, settings, account, history
└── KeyboardExtension/       # UIInputViewController + keyboard integration

supabase/
└── functions/
    └── keyboard-rewrite/    # authenticated AI rewrite endpoint
```

The project uses **Swift / SwiftUI**, **XcodeGen**, **Supabase**, and an AzooKey-based Japanese conversion stack.

## Running it locally

You'll need Xcode and XcodeGen.

```bash
brew install xcodegen
xcodegen generate
open KeigoButton.xcodeproj
```

Build and run the `KeigoButton` scheme, then enable the keyboard in the simulator or on a device.

For the testable Swift packages:

```bash
swift test
```

Local Firebase/Supabase configuration is intentionally not committed. See `docs/development.md` for setup details.

## Documentation

The README is meant to explain the project at a glance. The deeper implementation notes live in:

- [AGENTS.md](./AGENTS.md) — current engineering overview and repo map
- [docs/architecture.md](./docs/architecture.md) — module boundaries and architecture
- [docs/ai-rewrite.md](./docs/ai-rewrite.md) — rewrite UX and replacement behavior
- [docs/backend.md](./docs/backend.md) — backend contract
- [docs/development.md](./docs/development.md) — local setup and debugging

---

KeigoButton is still evolving. The most interesting part of the project for me is not the rewrite model itself, but how little interaction an AI tool can require before it starts to feel like part of the operating system rather than a separate destination.
