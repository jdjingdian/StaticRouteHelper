#!/usr/bin/env bash

set -euo pipefail

SERVICE_LABEL="${1:-cn.magicdian.staticrouter.service}"
OUTPUT="$(launchctl print "system/${SERVICE_LABEL}" 2>&1 || true)"

printf '%s\n' "$OUTPUT"

if printf '%s' "$OUTPUT" | grep -Eiq 'OS_REASON_CODESIGNING|Launch Constraint Violation|spawn failed'; then
  printf '\n[error] SMAppService health check failed for %s\n' "$SERVICE_LABEL" >&2
  exit 1
fi

printf '\n[ok] SMAppService health check passed for %s\n' "$SERVICE_LABEL"
