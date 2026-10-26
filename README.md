# Safwa Quran | صفوة القرآن

**An offline Quran and daily worship companion — under active development.**

Safwa Quran is an independent software initiative initiated by **Ahmad Ibrahim** to explore a dependable, accessible, source-conscious Islamic mobile experience. It aims to bring Quran reading, offline recitation, prayer planning, and useful worship tools together in one thoughtfully engineered application.

> **Institutional status:** Collaboration with **Safwa Institute / Safwa Studios** has been **proposed for discussion only**. The project is **not an officially endorsed Safwa Institute product**, and permission to use the Institute's name, logo, or brand identity has **not yet been granted in writing**. “Safwa Quran” is a provisional project name, not a declaration of trademark ownership or institutional affiliation.

**Development status:** Source-only prototype · **No public app release** · Quran text and audio activation **blocked**.

## Project at a glance

| Area | Current position |
| --- | --- |
| Product | Offline Quran and Islamic companion application |
| Project initiator | Ahmad Ibrahim |
| Potential institutional collaboration | Safwa Studios — exploratory discussion, **no agreement signed** |
| Technology | Flutter / Dart; local preferences; experimental SQLite review adapter |
| Intended platforms | Android and iOS; native release/device acceptance pending |
| Public availability | **Not released** |
| Quran Arabic text | Full source candidate under review; **reader not activated** |
| Offline audio | Local-file review foundation only; **no approved recordings bundled** |
| Branding | Safwa name/logo authorization and collaboration terms **pending** |
| Latest owner-verified source-only gate | **131 Flutter tests, 14 Python checks, zero analyzer issues** at the SAFWA-016 commit below |

## Vision

Build a calm, reliable application that supports beneficial Quran study and daily worship without making internet connectivity a requirement for essential local features.

The development approach prioritizes **authenticity before publication, privacy before convenience, and verification before release**. Technical tests and automated content checks do not replace qualified scholarly, legal, security, accessibility, or physical-device reviews.

## Product scope

The following table distinguishes code in the development branches from features available to end users. **Implemented in source does not mean released or independently approved.**

| Capability | Development status |
| --- | --- |
| 114-Surah directory, search, saved Surahs and Ayahs | Source implementation; Quran text access remains locked |
| Quran reader and adjustable Arabic typography | Reader UI implemented; authentic Arabic corpus **not activated** |
| Last-read position and reading preferences | Local prototype |
| Prayer times and weekly planner | Offline calculations; real-world timetable comparison pending |
| Qibla guidance | Estimate based on a selected location; not a calibrated device compass |
| Tasbih, Salah tracking and companion utilities | Local prototype; device validation pending |
| Local backup, encrypted import and recovery | Source-only validation passed; platform and privacy reviews pending |
| Transactional SQLite cutover and concurrency checks | **Isolated review/test code only**; production remains on the legacy preferences backend |
| Offline Quran recitation | File-only player and integrity validator for review; **public playback disabled** |
| Adhkar, verified lessons, translations and other content | Source/rights/scholarly gates still apply |

### Offline recitation direction

The project's **proposed** reciter is **Sheikh Ali ibn Abdul Rahman Al-Hudhaifi**. A candidate recording collection was identified at [Internet Archive](https://archive.org/details/AliAl-Huzaifi-QuranCompleteRecitation), including a file listed for Surah Ya-Sin.

This is **not** an approved audio source for app distribution. The item's inspected metadata did not establish a written license for reproduction, offline storage, or redistribution in Safwa Quran. No recordings have been acquired, bundled, enabled, or approved for the shipping application. The exact recording provenance, riwayah, licensing, and recitation quality require independent confirmation.

The source implementation currently uses an **empty, locked audio manifest**; its isolated player adapter does not provide remote streaming.

## Engineering architecture

The current feature branches contain a Flutter application, offline Quran source verification, local-first preference and recovery tools, and focused test suites.

```text
lib/                    Flutter screens, companion tools, storage and review adapters
assets/data/            Surah catalog, content-activation controls, locked audio manifest
sources/review_only/     Quarantined source material; not approved for app publication
config/                 Feature status, source metadata and release-policy controls
scripts/                Quran integrity, audio-policy and source-only validation tools
test/                   Unit, widget, migration and adversarial tests
integration_test/       Operator-controlled synthetic device test harness
docs/                   Technical acceptance and recovery procedures
.github/workflows/      Source-only quality workflows
```

**Storage boundary:** The live prototype continues to use its existing preferences path. SQLite migration, cross-isolate consistency, legacy data retention/erasure, WAL recovery and real process-kill durability are subject to separate gates. The tests do not establish that a production cutover is safe.

**Content boundary:** A 114-Surah/6,236-Ayah chapter catalog and quarantined Quran source candidates do not constitute approval to display or distribute Quran text. The reader remains fail-closed pending **two independent qualified Hafs reviews** and the remaining release approvals (**0/2 recorded**).

## Verified engineering progress

Testing evidence below comes from **owner-provided Kali Linux terminal logs**, not a published app, physical-device test report, independent security audit, or assertion that GitHub Actions completed successfully.

| Milestone | Exact locally tested commit | Source-only result |
| --- | --- | --- |
| [SAFWA-015C — controlled SQLite cutover rehearsal](https://github.com/AhmadibOfficial/Safwa-Quran/pull/19) | `ddbae89a2fe5b43e64c298313891b7d69a30ab76` | 106 Flutter / 11 Python; analyzer clean |
| [SAFWA-015D — concurrency and recovery harness](https://github.com/AhmadibOfficial/Safwa-Quran/pull/20) | `13196ae5502a448f3fc5bdad9d22e7eb7f16455e` | 117 Flutter / 11 Python; analyzer clean |
| [SAFWA-016 — offline recitation foundation](https://github.com/AhmadibOfficial/Safwa-Quran/pull/21) | `01c00f1424508ffa0f4c19639459527aa55859dd` | **131 Flutter / 14 Python; analyzer clean** |

All three pull requests are **draft and unmerged**. The quoted results apply to their **exact source commits** and do not validate hardware or subsequent edits.

### Outstanding acceptance gates

- Independent qualified Quran textual reviews and approval of exact source bytes.
- Written permission for intended use of the Safwa Institute name, logo and other protected branding.
- Separately verified audio provenance, copyright/redistribution rights and qualified recitation reviews.
- Real Android/iOS device builds and tests, including offline audio, interruptions, accessibility and privacy behavior.
- Disposable-device crash/restart and storage-failure evidence for the experimental SQLite cutover.
- Cross-isolate/native-writer coordination, retention of plaintext legacy preferences, backup policy and effective erasure safeguards.
- Independent AppSec, cryptography, privacy and accessibility review.
- Defined institutional governance, IP responsibilities, operational ownership and release approval before any collaboration or publication.

**No production SQLite migration, public Quran reader, audio playback release or app-store deployment is authorized.**

## Repository navigation

**The default `main` branch currently hosts this project overview.** The application and engineering work are in staged, unmerged branches; reviewers should not assume the default branch contains the latest Flutter source.

- **[Latest development branch — SAFWA-016](https://github.com/AhmadibOfficial/Safwa-Quran/tree/feature/safwa-016-offline-recitation-foundation)** — source-only app and offline audio foundation.
- **[SAFWA-016 draft PR #21](https://github.com/AhmadibOfficial/Safwa-Quran/pull/21)** — code changes, test scope and latest owner verification evidence.
- **[SAFWA-015D draft PR #20](https://github.com/AhmadibOfficial/Safwa-Quran/pull/20)** — transactional storage and synthetic device recovery work.
- **[Offline audio rights and review tracker #22](https://github.com/AhmadibOfficial/Safwa-Quran/issues/22)** — selected reciter and outstanding licensing/content decisions.
- **[SAFWA-016 technical documentation](https://github.com/AhmadibOfficial/Safwa-Quran/blob/feature/safwa-016-offline-recitation-foundation/docs/SAFWA-016-OFFLINE-RECITATION.md)** — implemented boundaries, safe tests and audio release gates.

## Developer setup (source-only)

These commands assume a **new checkout**, with no existing local changes to preserve. Flutter with a compatible Dart SDK, Git and Python 3 are required. This setup does **not** create Android/iOS platform folders, perform a native build or authorize device installation.

```bash
git clone https://github.com/AhmadibOfficial/Safwa-Quran.git
cd Safwa-Quran
git fetch origin
git switch --track origin/feature/safwa-016-offline-recitation-foundation

flutter pub get
flutter analyze
flutter test --concurrency=1
python3 -m unittest discover -s scripts/tests -v
python3 scripts/quran_pipeline.py check
python3 scripts/check_offline_audio.py
```

For the documented full source-only gate:

```bash
bash scripts/verify_source_only.sh --offline
```

**Expected behavior:** The script intentionally tests that public release is **rejected** while mandatory approvals are incomplete. Its source-only PASS does not mean the Quran reader, audio or app release is authorized.

**Existing developer checkouts:** Do not run destructive cleanup (`git clean`, `git reset --hard`, `flutter clean`) or overwrite uncommitted source files, platform projects, local databases or worktrees. Review branch changes in a separate worktree instead.

## Proposed collaboration with Safwa Studios

Safwa Institute has expressed interest in **exploring** development through Safwa Studios rather than considering only a standalone brand-use authorization. Discussions are preliminary, and no binding relationship or brand license should be inferred from this README.

A prospective agreement would need to establish:

1. The developer's **pre-existing contributions and intellectual-property interests**, including source written before any agreement.
2. The Institute/Studios' respective contributions, design approval, scholarly oversight and permission to use institutional branding.
3. Ownership or licensing of **future contributions**, technical decision-making, maintenance, confidentiality and governance.
4. Release, revenue or funding terms (if any), attribution, security responsibilities and an agreed process for ending or changing the collaboration.

**This repository is shared for project evaluation; access to the code or this README does not transfer intellectual property, grant a trademark license or constitute a partnership.**

## Intellectual property, attribution and responsible use

- **Safwa Institute branding:** Use of the institution's name and logo is subject to written permission from the appropriate rights holder. Do not treat any development-only flag, placeholder text or repository label as an authorization.
- **Quran sources and recitations:** Third-party rights, attribution requirements and scholarly verification are separate from repository/code permissions. Unverified material must remain quarantined.
- **Software license:** No repository-wide open-source license is being granted by this README. Public visibility does **not** mean unrestricted copying, redistribution, commercial use or sublicensing.
- **Security:** Do not post exploitable vulnerabilities, real personal data, private backups or access credentials in public issues. Contact the project maintainer privately to coordinate disclosure.

## Project contact

**Ahmad Ibrahim** — Project initiator and software developer  
**GitHub:** [@AhmadibOfficial](https://github.com/AhmadibOfficial)  
**Repository:** [AhmadibOfficial/Safwa-Quran](https://github.com/AhmadibOfficial/Safwa-Quran)

*Project working name and scope are subject to verification, institutional discussions, technical review and formal authorization. Last documented source-only acceptance: 25 October 2026.*
