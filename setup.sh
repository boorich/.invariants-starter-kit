#!/usr/bin/env bash
# One-shot: bootstrap vendored deps + full session (sync, issues, index).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
bash "$ROOT/scripts/bootstrap.sh"
# env.sh is sourced again inside session-setup via bootstrap path
source "$ROOT/scripts/env.sh"
bash "$ROOT/session-setup.sh"
