# SAFWA-004 — Diagnose Unicode differences without editing Quran text

After verifying the downloaded txt-2 text with scripts/verify_official_tanzil.py,
create a compact summary and private detailed report:

    python3 scripts/official_unicode_diagnostics.py --official "$HOME/Downloads/quran-uthmani.txt" --marks unknown --sajdah unknown --rub unknown --tatweel unknown --stanween unknown

Replace unknown with the *actual* settings, where independently recorded.
Use the correct file path and do not edit, normalize, or re-export original Arabic.

The tool validates the same pinned source and all 6,236 references before
recording the source hashes, a top-30 Unicode added/removed character frequency
table (with Unicode names), diagnostic-only comparison categories, and 12
representative paired verse strings in
`.staging/official_unicode_diagnostics.json` (excluded from version control).
Console output shows only the summary, rather than listing thousands of
references; the original full comparison remains available separately in
`.staging/official_tanzil_comparison.json`.

Classification: exact strings, differences resolved by tatweel-only removal
for comparison, differences resolved by comparison-only removal of Unicode
marks and tatweel, and other string differences. The latter categories
must NEVER be treated as scriptural equivalence, authority, or permission
to modify text. Unicode diff alignment is heuristic.

Consult Tanzil's https://tanzil.net/download/ for settings,
https://tanzil.net/docs/version_1.1_updates for version-specific variants,
and https://tanzil.net/docs/Text_License for original copyright and use terms.
Confirm whether the downloaded text type is Uthmani rather than Uthmani
Minimal or a Simple script (see https://tanzil.net/docs/Quran_Text_Types).

Official download provenance and export settings are NOT authenticated
by this tool. Real qualified Quran review, independent attestations,
mobile Arabic display checks, and publication decisions remain pending.
No app activation, corpus modification, merger, or release occurs.

## Small-meem-only sequence check (research evidence, not certification)

A prior local run against a separately obtained `quran-uthmani.txt` showed
2,718 exactly matching verse strings and 3,518 differences attributable
under a broad **marks/tatweel diagnostic**. Unicode edits showed only added
U+06ED (4,708) and U+06E2 (1,935), with no removed characters.

Tanzil documents an optional **sequential tanween** setting for its
`me_quran` font, represented using added small meem signs:
https://tanzil.net/docs/me_quran_font

This code now performs a **narrower, character-exact insertion-only check**.
It classifies a differing verse as `optional_small_meem_insertions_diagnostic`
only if the downloaded string can be aligned to the pinned original by
inserting U+06ED and/or U+06E2 exclusively. Any changed base letter,
removed codepoint, or other added character fails that specific check.
It is neither Quran correction nor an assumption about the chosen export
settings. The complete unchanged strings remain in the private evidence
report. Do not remove either sign from stored texts, alter any source,
or infer equivalent recitation and approved print layout.

Both independently verifiable origin and the actual selected options,
including whether sequential tanween was enabled, remain required before
any official-source acceptance. Two qualified human reviews, proper
`me_quran` or alternative Arabic font rendering checks, and explicit
release approval still remain outside these diagnostic tests.
