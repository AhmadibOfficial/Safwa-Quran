# SAFWA-004 — offline Quran review dossier

This addition does NOT promote source content to the application or complete the two independent scholarly reviews.

From the Safwa-Quran checkout:

```bash
python3 -m unittest discover -s scripts/tests -v
python3 scripts/build_review_pack.py --out .staging/review-pack
```

Open `.staging/review-pack/index.html` in a trusted browser, or examine
`.staging/review-pack/unresolved_verses.csv` and `manifest.json`.

The report contains exact side-by-side Arabic strings from two byte-pinned source
copies, Unicode edit operations, original source attribution and a list of unresolved
verse references. It is for private, qualified source review only.

The source strings are preserved without alteration. A visualization or edit comparison
is NEVER an approval of the text. Two distinct, qualified human reviewers must
independently review the exact source digest and verify official Tanzil export
settings. Record any approvals in separately authenticated, immutable evidence; do
not edit `content_activation.json` or modify Quran text in order to satisfy an
automated check.

The app's existing fail-closed Quran activation and public-release controls remain
unchanged. Source-only development is allowed while content release remains blocked.

## Human review evidence (never automatic approval)

The generated dossier now also includes `reviewer_1_worksheet.csv` and
`reviewer_2_worksheet.csv`, which contain the same 308 references and **blank**
review fields. The generated `manifest.json` records SHA-256 digests for
the original source copies, HTML/CSV report, and blank worksheets.

Each reviewer must independently examine the original authoritative source,
the selected Tanzil export options, Unicode differences and the Arabic display.
Use separate reviewer identities and authenticated documentation. Any completed
worksheet will have a **new SHA-256** and must be independently retained with
the reviewer identity and verification evidence. Generating or filling a
worksheet is not a scholarly ruling or a release authorization.

The source comparisons and worksheets remain private. No review signature is
inferred from a passing unit test. The activation manifest and public release
policy remain unchanged and locked.
