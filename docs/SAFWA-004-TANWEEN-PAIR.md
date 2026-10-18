# SAFWA-004 — Compare separate sequential-tanween OFF / ON downloads

Two downloads should be made **directly from https://tanzil.net/download/**
with Uthmani v1.1, the same text output format (prefer numbered txt-2),
the same pause marks, sajdah, rub-el-hizb and tatweel options, and with
**sequential tanween** switched OFF for one, ON for the other.
Document actual user-selected settings and the official browser download
origin. Preserve both files exactly as downloaded and keep them private.

Check the real filenames:

    ls -lt ~/Downloads | head -20

Run the pair comparison using your ACTUAL paths and known checkbox states:

    python3 scripts/verify_tanzil_export_pair.py --off "$HOME/Downloads/ACTUAL_OFF_FILENAME.txt" --on "$HOME/Downloads/ACTUAL_ON_FILENAME.txt" --marks unknown --sajdah unknown --rub unknown --tatweel unknown

Replace the four `unknown` values with what you actually selected.
Do not guess; unknown settings keep provenance and configuration incomplete.

The script rechecks SHA-256 of both downloads and the pinned source,
the 6,236 ordered verse references and copyright notice, and byte-exact
OFF-to-ON string relations. It fails the setting-isolation acceptance
condition if letters or other non-U+06ED/U+06E2 codepoints changed.
Results are kept in `.staging/tanzil_tanween_pair_report.json`, not app assets.

A successful narrow pair comparison shows only that these TWO preserved
download candidates differ by inserted small-meem marks. It does not prove
they were obtained from Tanzil's official site, that both checkbox sets
were recorded faithfully, or that either text is suitable for public
Quran reading. No source or Quran text is rewritten or normalized.

**Religious-content gate stays CLOSED:** verify download provenance,
select the intended rendition, secure two authenticated independent
qualified Quran reviews bound to the entire exact corpus and license,
and test all diacritics/RTL/fonts on devices before release. Do not
merge the draft PR merely because the pair comparison passes.
