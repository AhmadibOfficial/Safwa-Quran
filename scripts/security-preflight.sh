#!/usr/bin/env bash
# SAFWA-017 fail-closed developer commit gate; never installs dependencies.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
command -v python3 >/dev/null || { echo "STOP: python3 required" >&2; exit 1; }
command -v gitleaks >/dev/null || {
  echo "STOP: Gitleaks v8 is required; obtain a reviewed binary before committing." >&2
  exit 1
}
python3 scripts/ai_security_preflight.py
# Redact any potential credential values from tool output.
gitleaks git --staged --redact --no-banner --exit-code 1
echo "PASS: Safwa local AI security preflight"
