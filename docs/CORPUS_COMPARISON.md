# SAFWA-003 — corpus comparison evidence (2026-10-18)

## Primary locked source
Tanzil Uthmani version 1.1 via a verbatim GitHub mirror:
- https://github.com/acfatah/tanzil/blob/main/data/quran-uthmani.txt
- Git object SHA-1: `f2f03c415ea50f8493d2058ec67a90257333abe3`
- 114 Surahs, 6,236 ayahs; Surah counts, sequential verse numbering and Arabic text presence validated.
- Original Git object SHA equals uploaded Safwa original-source Git object SHA: byte-for-byte match.
- Copyright and license text are preserved in the raw source and candidate.

## Secondary comparison (not independent scholarly approval)
- Source: https://github.com/gptforjoomla/Tanzil/blob/master/Packages/com_tanzil/site/resources/quran/quran-uthmani.txt
- Git object SHA-1: `87cdfd0096fa3057dbf7904f925608cd2e1d100e`
- Source rows: 6,236; primary rows: 6,236.
- Byte/character-exact verse matches in order: **2,662**.
- Different verse strings: **3,574**.
- NFC normalization alone did not close any of the 3,574 differences.

These are different Uthmani Unicode representations or export variants; this automated check does **not** determine which differences, if any, are substantive. **Do not rewrite either text to make them match.** Only compare editions with their specified options and authoritative provenance.

## Remaining gates
1. Verify official Tanzil downloadable output and its exact export options against the pinned copy.
2. Independently authenticate and review the text and displayed diacritics against authoritative Mushaf references; retain two distinct reviewer approvals tied to a single immutable digest.
3. Confirm reader display quality for Arabic shaping, RTL, diacritics, long pages, accessibility and offline behavior on actual Android/iOS devices.
4. Only then promote the exact reviewed candidate to the application asset, set its SHA-256 activation manifest, and run release preflight.
5. Public release remains disabled.

This evidence establishes *integrity of acquired copies*, not scholarly correctness or release readiness.
