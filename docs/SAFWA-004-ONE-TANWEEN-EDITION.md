# SAFWA-004 — Safwa Quran uses ONE intended Quran-text copy with tanween enabled

## User-selected intended edition
One intended reading edition only: **Tanzil Uthmani v1.1**, numbered UTF-8
Quran text, **sequential tanweens ON**. The only selected original candidate
file is `quran-uthmani.txt` with original SHA-256:

`aa0bf9278a177a12e6d9bef621ce37a1d24fa35168b5ae9c13ebcbe01e3686cf`

The previously downloaded tanween-OFF copy is **comparison evidence only**.
It must not be bundled as a second reader edition. Do not delete or change
the original files while preserving evidence. Nothing is activated yet.

The selected edition and its exact original-file SHA are pinned in
`config/quran_text_selection.json` with explicit unapproved status. The
selected text is not checked into app assets. Existing quarantined sources
remain immutable research evidence, not alternative production editions.

## Single-file ON proof

After pulling the Safwa feature branch on Kali, run:

    python3 -m unittest discover -s scripts/tests -v
    python3 scripts/prove_selected_tanween.py --source "$HOME/Downloads/quran-uthmani.txt"

The verifier needs ONLY the selected ON file. It verifies the original
download SHA-256, exact 6,236 ordered verse references, copyright notice,
and matches the entire chosen text against the unchanged pinned primary.
Every difference must be an insertion of U+06ED or U+06E2 only. The
previously observed 2,718 verbatim matches, 3,518 marker-only verses and
4,708/1,935 small-meem additions are checked again.

The output is a private, reproducible **ordered selected-text SHA-256**
in `.staging/selected_tanween_content_proof.json`. This selected digest
differs from the earlier OFF edition content digest; reviewers must sign
off against the **new ON content digest**, never the old OFF digest. All
script checks remain technical diagnostics, not a scholar's attestation.

## Font and license are release blockers

Tanzil explicitly describes sequential tanweens as special extra small
meems that only render properly in the me_quran font:
https://tanzil.net/docs/me_quran_font

That document describes the font download as intended for personal or
non-commercial use. **Do not automatically bundle it** in Safwa Quran:
obtain appropriate permission/licenses for intended distribution first,
or establish alternative compatible rendering with permitted fonts and
have qualified Quran reviewers approve all visible marks. Do not strip
tanween small meems or convert the Arabic source text to hide defects.

Tanzil permits use of verbatim original text with attribution, link and
copyright notice: https://tanzil.net/download/ .

## Approval boundaries remain closed

Source download provenance and the four other export options still need
authentication; two independent qualified Quran scholars need to review
the full selected ON text and compare it against the intended Hafs
Mushaf. Real-device typography and font rights must be confirmed.

No generated report, hash match or test run authorizes content activation,
production app bundling, merge or public release. The original
`assets/data/content_activation.json` and `config/release_policy.json`
stay unchanged and false. This selected candidate is NOT approved.
