#!/usr/bin/env bash
# Create triage labels on GitHub repos listed in sentinel.config.yml.
# Safe to re-run.

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f sentinel.config.yml ]]; then
  echo "ERROR: sentinel.config.yml missing." >&2
  exit 1
fi

if ! command -v gh &>/dev/null; then
  echo "ERROR: gh CLI required." >&2
  exit 1
fi

REPOS=()
NEEDS_LABEL=""
IN_LABEL=""
while IFS= read -r line; do
  case "$line" in
    NEEDS:*) NEEDS_LABEL="${line#NEEDS:}" ;;
    IN:*) IN_LABEL="${line#IN:}" ;;
    REPO:*) REPOS+=("${line#REPO:}") ;;
  esac
done < <(node scripts/print-github-config.js)

create_label() {
  local REPO="$1"
  local NAME="$2"
  local COLOR="$3"
  local DESC="$4"

  if gh label list --repo "$REPO" --json name --jq '.[].name' 2>/dev/null | grep -qx "$NAME"; then
    echo "  ↳ '$NAME' exists"
  else
    gh label create "$NAME" --repo "$REPO" --color "$COLOR" --description "$DESC" || true
    echo "  ↳ '$NAME' created"
  fi
}

for REPO in "${REPOS[@]}"; do
  [[ -z "$REPO" ]] && continue
  echo "── $REPO"
  create_label "$REPO" "$NEEDS_LABEL" "E4E669" "Awaiting conformance evaluation"
  create_label "$REPO" "$IN_LABEL" "0075CA" "Conformance report posted — under review"
done

echo ""
echo "Done."
