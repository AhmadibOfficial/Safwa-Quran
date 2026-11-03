# Safwa Quran — AI-assisted engineering boundaries

These rules apply to Codex, Claude Code, IDE AI agents, and human-assisted code generation in this repository. They are instructions, **not** an operating-system security boundary. Work only inside an isolated, non-production worktree or sandbox with no secrets mounted.

## Non-negotiable access limits

- Do **not** read, display, quote, summarize, search, or send `.env`, `.env.*` (except safe checked-in examples), keys, certificates, service-account JSON, Google/Firebase credentials, keystores, tokens, native signing folders, private backups, SQLite databases, incident logs, customer information, or proprietary client data to any model or agent.
- Do **not** read files outside the expressly provided Safwa project workspace. Do not mount home directories, personal SSH material, credential helpers, browser profiles, device backups, or production volumes into AI tool sandboxes.
- Do not run blanket repository indexing, indiscriminate `grep -R` searches, or `cat`/file-dump commands against sensitive directories. Request only the minimal source files and functions for the current task.
- Do not copy unredacted environment output, stack traces, client records, IP addresses, personally identifiable information, private repository URLs with access tokens, or unverified Quran source archives into prompts. Replace them with synthetic fixtures and redact error logs **before** sharing.
- Never assert that a hosted model provider offers zero data retention or zero model training without reviewing the actual contractual terms for the relevant account/plan. If guarantees cannot be established, keep private material outside the AI workflow entirely.

## Source, rights, and release safety

- This codebase is **source-review only**. Live SQLite cutover, Quran text activation, Quran audio playback, public release, and native device deployment remain **blocked** by independent acceptance gates.
- The repository's `main` branch is not the shipping app; newer feature code is stacked in draft PRs. Do not merge/force-push/update release policy or publish without explicit owner approval and independently verified evidence.
- Safwa Institute / Safwa Studios collaboration and name/logo authorization are **proposed, not granted**. Do not claim brand permission; resolve the outstanding brand-rights policy only after verified written authorization. Do not modify unreviewed Quran text, generate substitute verses, or include unlicensed recordings.
- Protect existing worktrees, user-modified native platform folders, temporary SQL test data and untracked `pubspec.lock`. Never run `git clean`, `git reset --hard`, `flutter clean`, destructive cache purges, or broad removal of data.

## AI code change process

1. Use a new feature branch/worktree; inspect only task-relevant files. Separate proprietary business details from the prompt.
2. Work with **synthetic**, non-identifying examples. Keep secrets in secret managers or local environment variables on the operator's own system, never in committed files or LLM prompts.
3. Vet packages before adding them: official publisher, exact package name, maintained releases, licenses, security advisories, transitive packages and version compatibility. Treat suggestions and installation scripts as untrusted.
4. Perform manual review of **every AI-authored change** for authorization and disclosure issues, input handling, SQL injection, unsafe HTML/WebViews, TLS bypasses, insecure file paths, symlink races, backup/erasure behavior and failure handling.
5. Run `python3 scripts/security/check_repo_security.py`, `gitleaks git --staged --redact` for staged changes, and the normal source-only tests. The local Git hook is opt-in and requires explicit installation by the owner; if the scanner is missing it **must fail**, not silently pass.
6. Require passing CI, independent human review, release-policy approval and documented device evidence before merging or deploying. Do not grant AI runners production keys or deployment access.

## Working on this repository

- Baseline SAFWA-016 verified on Kali at `01c00f1424508ffa0f4c19639459527aa55859dd`: 131 Flutter tests, 14 Python tests, analyzer clean. These results do **not** prove new security changes pass.
- No source or prompt policy proves secret isolation: OS-level sandboxing, file permissions, tool approvals and constrained provider data handling remain the owner's responsibility.
- Security guidance: [docs/AI-CONFIDENTIALITY-AND-SECURE-DEVELOPMENT.md](docs/AI-CONFIDENTIALITY-AND-SECURE-DEVELOPMENT.md).
