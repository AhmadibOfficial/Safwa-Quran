# SAFWA-017 — Data security and confidentiality for AI-assisted engineering

**State: proposed source-only security policy. Tests and GitHub CI are not yet verified at this branch head. Draft PR only; no production deployment or Quran/audio activation.**

## Threat model and operational controls

| Concern | Repository guard | Required external control / residual risk |
| --- | --- | --- |
| API keys, tokens, credentials | Expanded `.gitignore`, safe `.env.example`, index inspection and `gitleaks git --staged --redact` in pre-commit; CI scans Git history | Git ignore does **not** restrict an AI tool's file reads. Rotate any credential already exposed; audit history, forks, logs and caches separately |
| Proprietary code and sensitive personal data | `AGENTS.md`, Claude deny patterns, workspace/file minimization, synthetic test policies, track-file preflight | Run AI in a separately provisioned container/worktree with no secret mounts or broad host access. Review each vendor's real contract; never assume zero retention or no training |
| Prompt injection and hidden context | Untrusted comments, repos and retrieved content cannot override owner/security instructions | Human reviews tool inputs/outputs, sanitizes paths/IPs, usernames, tokens and user data before prompts; read limits are not complete exfiltration protection |
| AI-generated code vulnerabilities | Semgrep custom Python/Dart rules in CI, Flutter analyzer, Python unit tests, existing Quran integrity checks | Human AppSec review; Semgrep rules have limited coverage and cannot establish application security or all Dart vulnerabilities |
| Dependency confusion, malicious package updates | Package-name review, pinned Semgrep and Gitleaks installer versions in CI, exact tested commits | Review `pubspec.yaml` **and** any generated `pubspec.lock` before merging, use official registries and verified maintainers, monitor advisories; transitive Go/Python/Flutter dependencies and CI actions are not all digest-pinned |
| Unsafe merges and deployment | Git branch isolation, draft PR, no repo write token in new CI job, no production access | GitHub **branch protection/rulesets** must be enabled in repository Settings; require ≥1 independent reviewer, mandatory passing checks and no direct pushes/auto-merge. These settings are not applied by this patch |
| App release, branding and Islamic content | Existing public release lock and separate Quran/audio policy checks remain in place | Brand-rights flag in legacy `config/release_policy.json` reads `true` despite no signed authorization: **OPEN BLOCKER**. Reconcile through a separately reviewed backwards-compatible policy migration; never treat this flag as legal evidence |

## Safe Kali installation — optional, local only

A pre-commit hook is **not active** just because the tracked file exists. On an **owner-approved isolated worktree** and only after confirming there is no pre-existing `core.hooksPath` value that must be preserved:

```bash
git config --local --get core.hooksPath || true
# Only if no existing hooks path and a reviewed Gitleaks v8 binary is already installed:
command -v gitleaks
git config --local core.hooksPath .githooks
```

The hook intentionally fails if Gitleaks is unavailable. It runs `python3 scripts/ai_security_preflight.py` and `gitleaks git --staged --redact --no-banner --exit-code 1`. Gitleaks pre-commit examines staged modifications; the CI workflow examines Git history. The source-only script deliberately runs only Python confidentiality guard; it does **not** silently pretend Gitleaks ran.

For a trusted local inspection, from an isolated worktree run:

```bash
python3 -m unittest discover -s scripts/tests -v
python3 scripts/ai_security_preflight.py
python3 scripts/check_offline_audio.py
python3 -m json.tool .claude/settings.json >/dev/null
bash -n scripts/security-preflight.sh .githooks/pre-commit
bash scripts/verify_source_only.sh --offline
```

The final source-only verifier still requires the existing Flutter SDK/cache. Never install unreviewed dependencies, run CI actions or change the user's global Git configuration without approval. A failing scan stops progression; do not disable scanner rules or suppress findings just to get a PASS.

## CI security contract

`.github/workflows/ai-security.yml` provides two independent read-only jobs:

- **Secrets and policy:** synthetic-only Python tests, tracked-source guard, Quran audio gate; Gitleaks v8.24.3 scan of checked-out Git history. Checkout is configured with `persist-credentials: false` and full history.
- **SAST:** Semgrep 1.183.0 with repository-owned **offline** Python/Dart rules and diagnostics. `SEMGREP_SEND_METRICS=off`; this does not upload project source to a third-party dashboard. This ruleset is a **baseline**, not comprehensive SAST.
- Existing `quality.yml` remains separate and unchanged. Flutter source-only acceptance, Quran 0/2 scholar approvals, and blocked release remain independent.

**CI execution is not proven merely because the YAML exists.** Verify installation, all job logs, exit statuses and corresponding branch protection. All third-party actions must later be reviewed and pinned to full immutable SHAs with controlled update policy.

## AI service contracts, logging, boundaries

1. Use synthetic Surah bookmarks, prayer times, fake user IDs, fake API responses and temporary test databases only. Do not load customer submissions or the real local legacy preferences store.
2. Before adopting Claude Code, Codex or another hosted provider for restricted data, document the exact enterprise contract, retention/training defaults, geography, access controls and delete/incident policy. If no verified eligible contract is available, feed only public/redacted/synthetic input.
3. Keep any actual secrets in a local managed secret store or purpose-scoped environment variables **outside** AI mounts. Flutter mobile applications must **not embed long-lived provider/admin secrets** in Dart/Android/iOS assets or config.
4. Share sanitized stack traces with secrets, user names, telephone/email addresses, local home paths, internal IPs, customer content and backup payloads removed.
5. Use narrow network egress, non-root execution, filesystem allowlist and explicit operator review before external shell commands. `.claude/settings.json` is one tool-specific mitigation; Codex must also be restricted at the OS/workspace level.
6. Require a different reviewer for AI-authored source changes. Reviewer should inspect design, data flow, misuse cases, storage lifecycle, intellectual-property use, dependencies, SAST findings, tests and fail-closed Quran/audio behavior.

## Safwa-specific release gates kept unchanged

- SAFWA-016 owner source-only verified at SHA `01c00f1424508ffa0f4c19639459527aa55859dd`: 131 Flutter tests, 14 Python, analyzer clean. Not a native audio/device success.
- SAFWA-015D synthetic crash harness not proven on Android/iOS; live SQLite migration off. Legacy plaintext retention/privacy and multi-isolate coordination not accepted.
- Al-Huzaifi Internet Archive recordings are selected **candidate sources only**. No redistribution license confirmed; no audio bundled or played.
- Quran text remains gated by 2 independent qualified Hafs reviewers (**0/2**). Public release blocked.
- **Brand-rights conflict:** source policy's historical `brand_rights_confirmed: true` is inconsistent with Safwa Studios' proposal, which is not a license. It was intentionally **not** changed here to avoid changing inherited Quran verification behavior without a separate reviewed migration. Owner must resolve before any release, and should not rely on this flag for permission.

## Owner Kali first-run finding and remediation

The original SAFWA-017 commit `1c31e51f537079f926cf450685e52fc89088cb63` **failed** immediately at `python3 scripts/ai_security_preflight.py`, which flagged a long `testPassword` value in `test/encrypted_backup_test.dart`. The command exited before Python test discovery, Flutter dependency resolution, analysis, and source-only verification. **No test pass is claimed for that run.**

The next draft revision replaces only that reused test passphrase with a visibly synthetic fixture; it does not modify the encryption/restore implementation. It also changes the preflight to require synthetic-value **prefixes**, rather than permitting a dangerous string merely because it contains the word `synthetic`. Two new Python regression tests cover these cases.

**Acceptance target after remediation, not a tested result:** 131 Flutter tests, 20 Python tests (14 inherited + 6 new security checks), clean Dart analysis and tracked-source preflight. Actual Gitleaks/CI SAST status must be reviewed separately. Preserve the original review worktree and run the revised SHA in a **new** isolated worktree; do not overwrite, clean or reset any previous directory.

## Acceptance before merge

- [ ] Owner runs Python tests, tracked-file preflight, Flutter source-only gate and Bash syntax on Kali.
- [ ] Gitleaks installed from a verified binary, staged hook tested on an isolated worktree, and full-history scan reviewed without publishing secrets.
- [ ] Semgrep pinned version and custom rules verified in CI; findings reviewed by an independent developer.
- [ ] GitHub branch rulesets enabled; human reviewer required and mandatory status checks verified.
- [ ] Developer confirms provider data policy, secure sandbox design and dependency origin/review.
- [ ] Written brand license still absent, Quran content 0/2 and separate device acceptance blocked — no release.
