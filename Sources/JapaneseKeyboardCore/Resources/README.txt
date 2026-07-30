Bundle placeholder for JapaneseKeyboardCore SPM resources.

zenz-xsmall.gguf — Zenzai neural conversion weight.
  Model: zenz-v3.1-xsmall (~25.6M params), Q5_K_M quantization.
  Source: https://huggingface.co/Miwa-Keita/zenz-v3.1-xsmall-gguf
  License: CC-BY-SA-4.0 (attribution: Miwa-Keita / zenz) — credit in-app.
  Loaded by KanaKanjiAdapter; if absent, conversion silently falls back
  to the classical lattice (zenzaiMode: .off).

conversion_gapfill.tsv — curated words the bundled azooKey dictionary
  cannot compose or ranks too low to be useful.
  Format: katakana reading <TAB> word, one per line.
  Vocabulary sources: FineWeb-2 corpus mining and NINJAL NWJC 2022.02
  (CC BY 4.0), with readings independently checked before inclusion.
  Station source: Seo-4d696b75/station_database (CC BY 4.0).
  KanaKanjiAdapter builds these into the converter's user dictionary
  (user.louds) at init so they rank as first-class lattice words.
