#!/usr/bin/env bash
# Read-only: verify .invariants is not writable. No unlock path in this repo.
#
# Usage: bash scripts/check-invariants-sealed.sh [path/.invariants]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="${1:-$ROOT/.invariants}"

if [[ ! -f "$FILE" ]]; then
  echo "→ .invariants not found (copy from .invariants.example first)" >&2
  exit 1
fi

if [[ -w "$FILE" ]]; then
  echo "WARNING: $FILE is writable" >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    if ls -laO "$FILE" 2>/dev/null | grep -q uchg; then
      echo "→ $FILE sealed (read-only + uchg)"
      exit 0
    fi
    echo "WARNING: $FILE read-only but missing uchg" >&2
    exit 1
    ;;
  Linux)
    if command -v lsattr &>/dev/null && lsattr "$FILE" 2>/dev/null | grep -q '\-i\-'; then
      echo "→ $FILE sealed (read-only + chattr +i)"
      exit 0
    fi
    if [[ ! -w "$FILE" ]]; then
      echo "→ $FILE read-only (chmod only)" >&2
      exit 0
    fi
    ;;
  *)
    if [[ ! -w "$FILE" ]]; then
      echo "→ $FILE read-only"
      exit 0
    fi
    ;;
esac

echo "WARNING: $FILE may not be fully sealed" >&2
exit 1
