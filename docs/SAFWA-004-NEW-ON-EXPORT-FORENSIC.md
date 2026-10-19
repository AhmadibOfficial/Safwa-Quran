# SAFWA-004 — read-only forensic comparison of the new single ON export

Developer reported two locally preserved **tanween-ON** Uthmani candidates.
The older file is only a *comparison reference*, not a second reader edition:

- Old: `~/Downloads/quran-uthmani.txt`, SHA-256
  `aa0bf9278a177a12e6d9bef621ce37a1d24fa35168b5ae9c13ebcbe01e3686cf`
- New (all four other export options user-declared OFF):
  `~/Downloads/quran-uthmani (1).txt`, SHA-256
  `f9a45b967b4b3407d0c7ca97ac122bbc8afb2d005b0af81e3a0a2c07d64fa94f`

The existing `official_unicode_diagnostics.py` comparison of the newer
candidate against the pinned older source returned 1,125 exact verses,
805 tatweel-only, 810 small-meem insertions only, 777 other mark/tatweel,
and **2,719 other differences**. This cannot be called a text approval;
the removed-character inventory included tatweel, spaces, Quranic pause/
sajdah/rub-el-Hizb signs.

For a more focused, nonmutating analysis, compare both ON downloads directly:

```bash
cd ~/Safwa-Quran
python3 -m unittest discover -s scripts/tests -v
python3 scripts/inspect_tanween_on_export.py \
  --old-on "$HOME/Downloads/quran-uthmani.txt" \
  --new-on "$HOME/Downloads/quran-uthmani (1).txt"
```

The script validates SHA-256 of both, original source integrity, 6,236
numbered ayat, and retains full original strings and a private report at
`.staging/2026-10-19-on-export-forensic.json`. It separates:

- Exact verses.
- Deletion of **only a limited, explicitly listed annotation set**
  (tatweel; known pause/sajdah/rub codepoints) with every other character
  still exactly preserved.
- Cases where eliminating literal U+0020 spaces *in the temporary
  comparison only* makes that restricted deletion relation hold. **These
  are still unresolved, including potential word-boundary changes.**
- Other Unicode differences not explained by these restrictions.
- Any differences involving the order/number of Unicode letter codepoints.

This comparison never converts, rewrites, accepts, or substitutes a Quran
asset. Removing or filtering marks **even for comparison** does not
constitute proof that those marks may be omitted in a correct Mushaf.

The same independent qualified scholar/official provenance/Arabic font
license and device typography gates remain. The selection manifest is not
updated automatically: a new file digest should be chosen only after its
exact source and edition are reviewed. No reader or public release.
