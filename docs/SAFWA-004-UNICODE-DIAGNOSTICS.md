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
