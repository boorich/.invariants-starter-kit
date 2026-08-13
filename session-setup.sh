#!/usr/bin/env bash
# Reference workspace session — optional tooling around the .invariants convention.
#
# First run:  bash setup.sh   (bootstrap submodules + Qdrant + gh, then this script)
# Or:         bash scripts/bootstrap.sh && bash session-setup.sh

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$WORKSPACE_DIR"

if [[ ! -f vendor/vecs/package.json ]]; then
  echo "→ vendor/vecs missing — running bootstrap"
  bash "$WORKSPACE_DIR/scripts/bootstrap.sh"
fi

# shellcheck source=scripts/env.sh
source "$WORKSPACE_DIR/scripts/env.sh"

if [[ ! -f sentinel.config.yml ]]; then
  echo "ERROR: sentinel.config.yml missing. Copy sentinel.config.yml.example and edit." >&2
  exit 1
fi

if [[ ! -d node_modules ]]; then
  echo "→ npm install (first run)"
  npm install --silent
fi

echo "── Checking .invariants seal ─────────────────────────────────────────"
if [[ -f "$WORKSPACE_DIR/scripts/check-invariants-sealed.sh" && -f "$WORKSPACE_DIR/.invariants" ]]; then
  if bash "$WORKSPACE_DIR/scripts/check-invariants-sealed.sh"; then
    true
  else
    echo "WARNING: .invariants is not OS-sealed. Maintainer: README OS seal. Agents must not chmod/chflags/chattr." >&2
  fi
else
  echo "→ no live .invariants (or no check script) — skip seal check"
fi

echo "── Checking Qdrant (vecs) ────────────────────────────────────────────"
node scripts/check-qdrant.js || {
  echo "→ Qdrant not up — running bootstrap"
  bash "$WORKSPACE_DIR/scripts/bootstrap.sh"
  source "$WORKSPACE_DIR/scripts/env.sh"
  node scripts/check-qdrant.js
}

if ! command -v vecs &>/dev/null; then
  echo "WARNING: 'vecs' not on PATH — run: bash scripts/bootstrap.sh" >&2
fi

if ! command -v gh &>/dev/null; then
  echo "WARNING: 'gh' not on PATH — issue fetch/post skipped unless installed" >&2
fi

# ── 1. Sync repositories ─────────────────────────────────────────────────────

echo ""
echo "── Syncing repositories (from sentinel.config.yml) ───────────────────"

node scripts/sync-repos.js

# ── 2. Fetch GitHub issues (optional) ────────────────────────────────────────

echo ""
echo "── Fetching triage issues ────────────────────────────────────────────"

ISSUE_LABEL=""
GH_REPOS_JSON=""
COLLECTION_NAME=""

while IFS= read -r line; do
  case "$line" in
    LABEL:*) ISSUE_LABEL="${line#LABEL:}" ;;
    REPOS:*) GH_REPOS_JSON="${line#REPOS:}" ;;
    COL:*) COLLECTION_NAME="${line#COL:}" ;;
  esac
done < <(node scripts/print-github-config.js)

ISSUES_DIR="$WORKSPACE_DIR/issues"
rm -rf "$ISSUES_DIR"
mkdir -p "$ISSUES_DIR"

if ! command -v gh &>/dev/null; then
  echo "→ gh not installed — skipping issue fetch"
elif [[ "$GH_REPOS_JSON" == "[]" ]]; then
  echo "→ no github repos in config — skipping issue fetch"
else
  TOTAL=0
  while IFS= read -r REPO; do
    [[ -z "$REPO" ]] && continue
    SHORT="${REPO##*/}"
    COUNT=$(gh issue list --repo "$REPO" --state open --label "$ISSUE_LABEL" --json number --jq 'length' 2>/dev/null || echo 0)
    if [[ "$COUNT" -eq 0 ]]; then
      echo "→ $REPO — no open issues with label $ISSUE_LABEL"
      continue
    fi
    NUMBERS=$(gh issue list --repo "$REPO" --state open --label "$ISSUE_LABEL" --json number --jq '.[].number' 2>/dev/null || true)
    for NUMBER in $NUMBERS; do
      FILE="$ISSUES_DIR/${SHORT}-${NUMBER}.md"
      gh issue view "$NUMBER" --repo "$REPO" \
        --json number,title,body,labels,url,createdAt,author,comments \
        --jq '"# \(.title)\n\n**Repo:** '"$REPO"'\n**Issue:** #\(.number)\n**URL:** \(.url)\n**Opened:** \(.createdAt[:10]) by \(.author.login)\n**Labels:** \(if (.labels | length) > 0 then (.labels | map(.name) | join(", ")) else "none" end)\n\n---\n\n## Body\n\n\(.body)\n\n\(if (.comments | length) > 0 then "---\n\n## Comments (" + (.comments | length | tostring) + ")\n\n" + (.comments | map("**" + .author.login + "** (" + .createdAt[:10] + "):\n\n" + .body) | join("\n\n---\n\n")) else "" end)"' \
        > "$FILE" 2>/dev/null || { echo "→ could not fetch ${SHORT}-${NUMBER}"; rm -f "$FILE"; continue; }
      echo "→ wrote ${SHORT}-${NUMBER}.md"
      TOTAL=$((TOTAL + 1))
    done
  done < <(echo "$GH_REPOS_JSON" | node -e "JSON.parse(require('fs').readFileSync(0,'utf8')).forEach(r=>console.log(r))")
  echo "→ ${TOTAL} issue file(s) in issues/"
fi

# ── 3. Rebuild vector index ──────────────────────────────────────────────────

echo ""
echo "── Rebuilding vector index (${COLLECTION_NAME:-stack}) ─────────────────"
node scripts/index-repos.js 1>&2

echo ""
echo "── Session ready ─────────────────────────────────────────────────────"
echo "   Collection: ${COLLECTION_NAME:-stack}"
echo "   Query:      vecs query ${COLLECTION_NAME:-stack} \"…\" --top 8"
echo "   Agent:      .cursor/rules/conformance-agent.mdc"
