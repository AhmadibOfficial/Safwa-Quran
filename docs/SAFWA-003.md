# Safwa Quran SAFWA-003 engineering gate

Safwa Institute logo usage was confirmed by the user. Brand implementation uses the reference navy, warm white, teal and gold colors; actual licensed high-resolution vector logo source is needed to replace the temporary wordmark.

### Authentic Quran text
Primary: https://tanzil.net/pub/download/index.php (Uthmani 1.1). Attribution and license: https://tanzil.net/docs/text_license .

The pinned public GitHub Tanzil mirror is **not independent** of the original source. Candidate acquisition verifies Git blob bytes, then all 114 chapters and 6236 verse numbering and Arabic text presence. **These automated checks cannot prove textual correctness**. Candidate remains quarantined. Independently compare every verse against approved authoritative source(s), record differences, rights and reviewers. Two distinct reviewers must approve the exact content hash.

Thereafter place exact approved JSON at assets/data/quran_verified.json, its byte-SHA256 in assets/data/content_activation.json, set review_status approved and quran_reader_enabled true with evidence IDs. The app verifies SHA256 at runtime. Never manually copy a candidate directly to packaged assets or set flags without independent approval.

No public release, subscription, server or permissions are activated. Platform identifiers, privacy and accessibility checks remain pending. Github Actions can build preview debug APKs for QA, not publish.
