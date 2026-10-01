# BGM pool

Drop track files here. `build.py` picks one per post and mixes it into the
rendered mp4, so the exported video carries its own audio and needs no manual
step at publish time.

Accepted extensions: `.mp3`, `.m4a`, `.aac`, `.wav`, `.mp4`, `.mov`. Video files
are accepted for convenience — only their audio stream is read, and the file on
disk is never modified.

## Which track a post gets

Filenames are moods. Pick the one that matches the episode and pin it:

```json
{ "duration": 45, "bgm": "dating.m4a" }
```

| Track | Length | Use for |
|---|---|---|
| `chill.m4a` | 17.6 s | Calm, deadpan, low-stakes episodes |
| `dating.m4a` | 37.2 s | Romance and relationship stories |
| `dating2.m4a` | 78.9 s | Romance. Long enough for a 4-page episode without looping |
| `dating3.m4a` | 86.3 s | Romance. Long enough for a 4-page episode without looping |
| `kpop-funny.m4a` | 22.3 s | Upbeat comedic beats, punchline-driven |
| `playful.m4a` | 36.0 s | Light workplace banter |
| `rushing.m4a` | 36.3 s | Deadline panic, chase, escalating pressure |

## Only the three dating tracks are selectable (Itsuki, 2026-08-11)

`build.py` **fails the build** on any pin outside `dating.m4a` / `dating2.m4a` /
`dating3.m4a`, and the unpinned hash fallback draws from those three only
(`DATING_TRACKS` in `build.py`). The other four files stay in the folder because
17 already-published episodes reference them; nothing new may use them.

Rotate the three so the accounts do not all carry the same audio.
`dating.m4a` (37.2 s) loops once inside a 45 s episode; `dating2` / `dating3` are
long enough not to.

A pinned file that does not exist fails the build. If `bgm` is absent the build
falls back to a slug hash and prints `UNPINNED` — that fallback exists only so a
draft still renders, and it ignores mood entirely, so pin every post before
approval. Pinning also protects an approved video from a later pool edit
changing its audio.

An empty pool is not an error — the build just produces a silent video, exactly
as it did before this folder existed.

## Processing

Per build: the track is looped if shorter than the video, trimmed to the video
duration, loudness-normalised to −14 LUFS (the level TikTok and Instagram
normalise toward, so their own processing does nothing further), given a 1.5 s
fade-out, and encoded as 128 kbps AAC.

## Licensing — read before adding anything

Every file here ends up in a video published from a business account promoting
敬語ボタン. TikTok and Instagram both fingerprint audio: an unlicensed
commercial track gets the post muted or removed, on either platform.

**Do not rip audio from trending TikToks, Reels, or YouTube videos.** Besides
the mute risk, a baked-in copy is not linked to the original sound, so it earns
none of the sound-page discovery that made the track worth using.

Cleared sources that work with this folder: Pixabay Music, Uppbeat, the YouTube
Audio Library, Epidemic Sound, Artlist. TikTok's Commercial Music Library is
cleared but in-app only, so its tracks cannot be dropped here.

Record every file below as you add it.

| File | Source | Licence | Added |
|---|---|---|---|
| `chill.m4a` | Audio ripped from a TikTok screen recording | ❌ none | 2026-08-05 |
| `dating.m4a` | Audio ripped from a TikTok screen recording | ❌ none | 2026-08-05 |
| `dating2.m4a` | Audio ripped from `../../../bgm/dating2.MP4` (TikTok screen recording) | ❌ none | 2026-08-09 |
| `dating3.m4a` | Audio ripped from `../../../bgm/dating3.mov` (TikTok screen recording) | ❌ none | 2026-08-09 |
| `kpop-funny.m4a` | Audio ripped from a TikTok screen recording | ❌ none | 2026-08-05 |
| `playful.m4a` | Audio ripped from a TikTok screen recording | ❌ none | 2026-08-05 |
| `rushing.m4a` | Audio ripped from a TikTok screen recording | ❌ none | 2026-08-05 |

**Status changed 2026-08-11 (Itsuki): the three dating tracks are cleared for use
under TikTok's platform music rules, and a publishing cadence may be built on
them.** The `❌ none` provenance rows above are kept as-is because they record how
the files were obtained, which has not changed — the ruling is about permission to
use, not about origin.

Scope note, recorded once and not re-argued: that ruling covers TikTok. The same
master is cross-posted to Instagram, which runs its own fingerprinting under
different terms. If Reels start getting muted, this is the first thing to check.
Replacing any file with a cleared equivalent under the same filename still needs
no code or `post.json` change.

If a row would say "unknown" in any column, the file does not belong here.
