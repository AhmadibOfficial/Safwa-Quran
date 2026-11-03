# SAFWA-017 — Data Security & Confidentiality for AI-Assisted Engineering

**Status: Source implementation pending independent Kali verification, scanner runs, human review and GitHub branch-protection configuration.** This is a security-hardening proposal, not an assertion that the project is already compliant with any contract, certification or formal standard.

The work is isolated on `feature/safwa-017-ai-confidentiality-hardening`, stacked on SAFWA-016 draft PR #21. It must remain **draft and unmerged** until the separate source-only and security gates are verified. Older feature branch HEAD `01c00f1424508ffa0f4c19639459527aa55859dd` passed owner Kali source-only validation with **131 Flutter**, **14 Python**, analyzer clear. Those results **do not validate SAFWA-017**.

## Threat model and controls

| Risk | Committed protection | Limits / owner responsibilities |
| --- | --- | --- |
| Secret / credential disclosure | Expanded `.gitignore`, sensitive tracked/staged path scanner, optional staged Gitleaks hook, Gitleaks Git-history CI | Ignore files do NOT prevent reading secrets; already-tracked secrets remain in Git history. **Rotate exposed credentials**, then plan history remediation only with authorization |
| Model indexing customer/owner files | `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json` deny patterns, `.cursorignore` | AI config applies only where supported; arbitrary shell, subprocesses, alternate clients or extra mounts may bypass rules. Use an OS-level sandbox/VM with secrets excluded |
| Provider data retention/training | Explicit workflow instruction prohibiting sensitive material unless terms reviewed | A repo configuration **cannot force zero training or zero retention** by an external model provider. Review the actual enterprise contract, data residency, subprocessors, logs and retention settings; otherwise use only synthetic data |
| Prompt/data overcollection | Minimal per-task context and redaction instructions | Human must remove real names, keys, email addresses, IPs, stack-trace payloads, local paths, personal recordings and confidential business logic from prompts |
| Typosquatting / dependency confusion | Exact direct-dependency inventory `config/dependency_review_baseline.json` + fail-closed drift guard | This is only a **baseline**, NOT an audit of publisher identity, CVEs, full transitive dependency graph or license. No trusted `pubspec.lock` is committed yet |
| Unsafe AI-generated application code | Local Flutter/Dart Semgrep rules for select TLS bypass, unsafe shell and raw SQL interpolation patterns; existing Dart analyzer/tests | Signature rules are intentionally limited; human security review and further SAST/DAST are still needed |
| CI / release overprivilege | GitHub Actions read-only permissions, pinned checkout/Gitleaks commits, no production deployment workflow or environment secrets | GitHub Actions must actually run successfully; branch protection, required checks and reviewer policies must be configured by repo administration |
| Unapproved Safwa branding | `brand_rights_confirmed=false` and corrected legal notice; release and reader remain blocked | Brand use needs written permission from appropriate rights holder, not a Boolean change or collaboration conversation |

## Confidential AI coding workflow

1. Work in a **disposable development environment** or clean worktree with no access to real users' data, device backups, secrets manager, SSH agent, private GitHub tokens, production service credentials or unrelated repositories. Never mount `$HOME` or all of `/mnt/data` in an agent sandbox.
2. Grant the AI only explicit, task-relevant **read paths**, not blanket access to the repository, logs or filesystem. Use synthetic JSON/SQLite records, placeholder organizations and public test fixtures. Preserve quarantined religious source content verbatim; do not generate or hallucinate Quran verses.
3. For Claude Code, review `.claude/settings.json`. It denies Read for known secret paths, and dangerous commands; shell tooling and third-party extensions can still bypass path patterns unless isolated at the OS layer. Do not use bypass mode.
4. For Codex and other coding agents, follow `AGENTS.md` and avoid running the agent with access to sensitive directories. For supported IDE agents, `.cursorignore` can reduce indexing, but is not an access-control mechanism.
5. Before pasting any logs or diagnostics into a model: **remove tokens, passwords, customer names and contact details, private IPs, file paths revealing people/clients, URLs containing credentials, full database records and stack traces with live data**. Use a redacted summary when possible.
6. Review all AI-authored diffs manually. Validate authorization and data provenance, input validation, cryptography, safe URLs, storage, privacy/erasure, resource consumption, caching, recovery and dependency licenses.
7. Run the privacy/security gates and source-only tests before proposing a draft PR. **Do not let an AI agent merge or deploy.**

### Model-provider contract policy

Do not describe a consumer account, editor plugin or API as offering zero-data-retention or no-training guarantees without verified, applicable written terms. If a provider contract is not acceptable, keep client/proprietary material out of prompts entirely. Limit remote tool permissions and provider retention, and avoid uploading complete repos or access logs as convenience context.

## Commit protection

The following hook is committed but **not automatically installed**. Git does not activate tracked `.githooks/pre-commit` by default, and the GitHub Contents API does not mark the file executable.

**Optional owner-approved installation**, only after reviewing what Git's hook path points to:

```bash
bash <<'BASH'
set -Eeuo pipefail
cd "$HOME/Safwa-Quran"
git rev-parse --show-toplevel
HOOK="$(git rev-parse --git-path hooks/pre-commit)"
if [ -e "$HOOK" ] || [ -L "$HOOK" ]; then
  echo "STOP: A hook already exists; do not overwrite it."
  exit 1
fi
command -v gitleaks >/dev/null || {
  echo "STOP: Install a verified Gitleaks v8 CLI first."
  exit 1
}
install -m 0755 .githooks/pre-commit "$HOOK"
echo "Installed in Git's resolved hooks path; it may affect linked worktrees."
BASH
```

The hook checks staged file **paths**, direct dependency drift and `gitleaks git --staged --redact --no-banner`. It refuses commits when Gitleaks is missing or detects findings. A local Git hook can be skipped with `--no-verify`; it is not equivalent to enforced CI. **Do not run the installer against the owner's primary checkout without reviewing its shared worktree hook path.** To verify it without installation, run:

```bash
python3 scripts/security/check_repo_security.py
python3 scripts/security/check_dependency_policy.py
gitleaks git --staged --redact --no-banner
```

Do not paste a Gitleaks match that contains a real secret into an issue or AI prompt; rotate affected credentials and coordinate responsible remediation.

## CI safeguards and AppSec limits

New `.github/workflows/ai-security.yml` is **read-only**. It has three independently named jobs:

- **Restricted files and release policy:** verifies tracked paths, brand/release gates, direct package inventory and Python policy tests.
- **Gitleaks Git-history scan:** scans commit history with `gitleaks/gitleaks-action@v3` pinned to a reviewed commit. PR comments and SARIF artifact upload are disabled to reduce disclosure risk.
- **Local Semgrep Flutter/Dart security rules:** runs Semgrep **1.183.0** from an isolated Python venv against `lib/`, using only `.semgrep/safwa-security.yml`; metrics and version checking disabled. Rules focus on a few known dangerous practices and do **not** constitute full Dart SAST coverage.

GitHub must successfully run these jobs before calling them passing gates. Check the account's Actions billing and permissions if they cannot start; an absent or billing-blocked check is **not PASS**. Repository admins must configure required status checks and a required **independent human approval** for protected branches. CODEOWNERS alone is not branch protection, and an author cannot approve their own changes to satisfy an independent review requirement.

## Third-party dependency review

The direct Flutter packages under `config/dependency_review_baseline.json` are listed with their current constraints. The gate deliberately blocks any new direct package, new source or changed version constraint without a matching reviewed baseline update. This is **not proof those existing packages are safe**.

For every proposed dependency review:

- Verify **official package name/publisher**, source repository, last release, maintenance and signing/trust path; check typosquatting, namespace similarity and dependency confusion.
- Read changelogs, licensing, requested permissions and the full transitive graph. Assess latest security advisories using an approved SCA tool with a committed, reviewed `pubspec.lock`.
- Require a human review for both `pubspec.yaml` and the baseline update. Do not silently accept AI-generated packages or run install scripts with elevated permissions.
- Preserve the owner's untracked `pubspec.lock` in existing worktrees; do not auto-delete or promote it into the repository without review.

## Pending acceptance and unmodified blockers

- **SAFWA-015D:** physical Android/iOS SQLite interruption, crash/disk-full and legacy retention tests are still pending. No production SQLite cutover.
- **SAFWA-016:** offline Al-Huzaifi recitation source named, but audio redistribution permission, scholarly recitation audit and physical offline playback remain pending. No audio bundled or enabled.
- **Quran reader:** original text corpus and required **two independent scholarly Hafs approvals** remain gated (currently 0/2). Public release remains blocked.
- **Safwa Institute branding:** collaboration with Safwa Studios is exploratory. The prior configuration claim of brand approval was not sufficient evidence; the branch now records **permission pending**.
- **Independent security, cryptography, privacy and accessibility signoff** have not been obtained.

## Non-destructive Kali source-only validation

After pulling the new draft branch into a **new** isolated review worktree (do not reuse or replace existing ones), perform:

```bash
python3 scripts/security/check_repo_security.py
python3 scripts/security/check_dependency_policy.py
python3 -m unittest discover -s scripts/tests -v
python3 scripts/quran_pipeline.py check
python3 scripts/check_offline_audio.py
flutter analyze
flutter test --concurrency=1
bash scripts/verify_source_only.sh --offline
git diff --check
git status --short --branch
git rev-parse HEAD
```

For the extra scanners, use a reviewed locally installed Gitleaks CLI and Semgrep 1.183.0; these need separate executable availability and evidence. Expected unit-test target before additional tests is **131 Flutter** and **25 Python** (14 previously passed plus 11 newly defined) — this is an **unexecuted target**, not a result. No Android/iOS builds, app deployment, secret read, data deletion or history rewrites are part of this milestone.
