#!/usr/bin/env bash
# Run a command under a wall-clock cap: CAP_SECONDS (default 120).
set -euo pipefail
exec timeout "${CAP_SECONDS:-120}" "$@"
