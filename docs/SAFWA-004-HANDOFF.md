# SAFWA-004 reviewer handoff — structural checks only

The complete 6,236-ayah Arabic Mushaf remains UNAPPROVED. This checker is neither
a fatwa nor independent source authentication. Reviewer identities and evidence
must be separately authenticated outside this tool.

Build the review pack and confirm the original data and report fingerprints:

    python3 scripts/build_review_pack.py --out .staging/review-pack
    python3 scripts/validate_review_handoff.py --pack .staging/review-pack

This checks original pinned source SHA-256, output hashes, the 308 exact
references and untouched blank worksheet templates. It always reports
scholarly_approval PENDING and public_release_permitted false.

After real human review, preserve the two original blank templates and store
completed copies OUTSIDE the .staging/review-pack directory. Check CSV
completeness only:

    python3 scripts/validate_review_handoff.py --pack .staging/review-pack --reviewer-one /private/first.csv --reviewer-two /private/second.csv

Required for each verse row: the exact primary SHA-256, consistent claimed
reviewer name, official export acknowledged yes, independent evidence reference,
written Unicode assessment, and timezone-aware completion timestamp.

Passing submission format validation is NOT verification of reviewer identity,
source correctness, full Mushaf accuracy, independent scholarly approval or
release permission. The remaining 5,928 verse records and official source
provenance still need the appropriate authoritative assessment.

The activation manifest, source files, app bundles and release flags are not
changed by these commands. Keep both pull requests private and unmerged.

## Protect completed reviewer work

Rebuilding a dossier in the same directory is allowed while worksheets remain
blank. If a reviewer has filled any non-reference cell in an existing worksheet,
the dossier builder now refuses to overwrite it and asks for a new output directory.
Preserve completed worksheets outside the generated report folder and use the
structural handoff command; authentication and scholarly approval remain separate.
