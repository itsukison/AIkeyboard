# AIキーボード

A Japanese iOS keyboard with an optional AI rewrite mode. Pure local
kana-to-kanji conversion by default; AI rewrites only when the user
explicitly taps a prompt button.

User-facing product name is `AIキーボード`. Some internal targets, schemes,
and project files still use the legacy name `BikeyJP`.

**New here? Read [`AGENTS.md`](./AGENTS.md) first.** Everything else
under `docs/` is reference material that `AGENTS.md` indexes.

## Quick start

```bash
brew install xcodegen
xcodegen generate
open BikeyJP.xcodeproj
```

Build and run the `BikeyJP` scheme. See [`docs/development.md`](./docs/development.md)
for simulator setup and the keyboard-enable walkthrough.

```bash
swift test
```

Runs the SPM unit tests for the IME core.

## Repository map

- `Sources/JapaneseKeyboardCore/` — IME state machine (romaji → kana → kanji)
- `Sources/JapaneseKeyboardUI/` — SwiftUI keyboard views + AI domain models
- `Sources/KeyboardPreferences/` — App Group settings, prompts, auth token cache
- `iOS/Container/` — main app (Bikey Design System, onboarding, settings)
- `iOS/KeyboardExtension/` — `UIInputViewController` subclass + AI glue
- `supabase/functions/keyboard-rewrite/` — Edge Function backing Cloud AI

## Docs

| File | Purpose |
|---|---|
| [`AGENTS.md`](./AGENTS.md) | Single canonical onboarding doc |
| [`CLAUDE.md`](./CLAUDE.md) | Behavioral guidelines for agents |
| [`docs/architecture.md`](./docs/architecture.md) | Module boundaries, state machines, planned restructure |
| [`docs/backend.md`](./docs/backend.md) | Supabase Edge Function contract |
| [`docs/ai-rewrite.md`](./docs/ai-rewrite.md) | Product UX, prompt model, replacement algorithm |
| [`docs/development.md`](./docs/development.md) | Build, test, common gotchas |
| [`docs/archive/`](./docs/archive/) | Historical plans — not current truth |
