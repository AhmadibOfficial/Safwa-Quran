# SAFWA-004 — private reviewer handoff for one selected tanween-ON candidate

The new user-declared marks/sajdah/rub/tatweel=OFF, sequential tanween=ON
download differs from the older tanween-ON comparison file.
The user-supplied Kali result at commit `ecb5d76` **passed 68/68 tests**.

**New candidate bytes SHA-256:**
`f9a45b967b4b3407d0c7ca97ac122bbc8afb2d005b0af81e3a0a2c07d64fa94f`

**New candidate ordered 6,236 indexed-verse content SHA-256:**
`8257fca6ce59f1efcb4fbe514c9552f19666396a593d9e41e92fbea6dc9ef70f`

The reference ON export is retained only for **comparison**, not as a
second app reading edition. The new candidate is NOT yet promoted to
`config/quran_text_selection.json`.

## Full local diagnostic result at ecb5d76

- 1,935 exact between old and new ON exports
- 1,582 deletions limited to explicitly listed annotations
- 2,714 spacing cases needing qualified manual inspection
- 0 remaining Unicode-letter-order alarms, after correcting tatweel handling
- **5 other Unicode differences**: deleted U+06DC ARABIC SMALL HIGH SEEN
  at **18:1, 36:52, 69:28, 75:27, 83:14**

U+06DC can represent a recitation saktah mark. **Do not silently waive its
removal or assume an OFF pause-marks setting renders it dispensable.**
A qualified Hafs scholar must assess all five, including variant-specific
details, and decide which recitation cues must be present.

The 2,714 spacing cases are unapproved even if a stripped-space comparison
preserves every other character. Some may reflect the spaces surrounding
omitted standalone symbols, but this does NOT prove every word boundary
and intended Quran display are preserved.

## Generate a full reviewer handoff on Kali

```bash
cd ~/Safwa-Quran
git pull --ff-only
python3 -m unittest discover -s scripts/tests -v
python3 scripts/prepare_tanween_review_handoff.py \
  --old-on "$HOME/Downloads/quran-uthmani.txt" \
  --new-on "$HOME/Downloads/quran-uthmani (1).txt" \
  --out-dir .staging/selected-on-scholarly-review-2026-10-19
```

All artifacts are private `.staging/` outputs and must NOT be committed
to GitHub or included in public app assets. The generator refuses to
overwrite an existing nonempty handoff folder. It produces:

- `selected_complete_corpus.csv` — all **6,236 exact, unmodified selected
  candidate verse strings**, to enable actual full-corpus scholarly review.
- `all_flagged_cases.csv` — all flagged cases with verbatim older and new
  strings (not replacements, never auto-approved).
- `spacing_cases.csv` — every flagged space/word-boundary case.
- `small_seen_cases.csv` — the priority five removed saktah-related signs.
- `other_unresolved_cases.csv` — any other unresolved cases.
- `reviewer_1_blank_worksheet.csv`, `reviewer_2_blank_worksheet.csv`
  — 6,236 rows each, blank, to be completed independently by two genuine
  qualified scholars. **A generated worksheet is NOT a review**.
- `tanzil_copyright_notice.txt` (verbatim from the selected file).
- `manifest.json` binding every artifact SHA-256 to the exact new
  candidate whole-file and ordered-content fingerprints.

Do not treat the legacy 308-reference secondary-mirror review worksheet
as scholarly certification for this **new** ON candidate. Both independent
scholars must validate the exact new selected ordered-text SHA above,
and official Tanzil provenance and font rights/rendering remain OPEN.

**Current decision: NOT APPROVED.** No Quran asset mutation, promotion,
release, merge, or activation is authorized by these tools.
