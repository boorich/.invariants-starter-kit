#!/usr/bin/env bash
# Batteries-included deps: git submodules (vecs, github-cli pin), npm, Qdrant, gh binary.
# Usage:  bash scripts/bootstrap.sh
# Then:   bash session-setup.sh   — or  bash setup.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "── Bootstrap (.invariants reference workspace) ───────────────────────"

# ── Submodules ───────────────────────────────────────────────────────────────

if [[ ! -f .gitmodules ]]; then
  echo "ERROR: .gitmodules missing" >&2
  exit 1
fi

echo "→ git submodule update --init --recursive"
git submodule update --init --recursive

if [[ ! -f vendor/vecs/package.json ]]; then
  echo "ERROR: vendor/vecs not checked out — run: git submodule update --init" >&2
  exit 1
fi

# ── Node (workspace + vecs CLI) ────────────────────────────────────────────────

if [[ ! -d node_modules ]]; then
  echo "→ npm install (workspace)"
  npm install --silent
fi

if [[ ! -d vendor/vecs/node_modules ]]; then
  echo "→ npm install (vendor/vecs)"
  npm install --prefix vendor/vecs --silent
fi

bash "$ROOT/scripts/install-vecs-wrapper.sh"

# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh"

if command -v vecs &>/dev/null; then
  echo "→ vecs at $(command -v vecs)"
else
  echo "→ vecs CLI: $VECS_ROOT/node_modules/.bin/vecs (after npm install)"
fi

# ── Qdrant ───────────────────────────────────────────────────────────────────

_qdrant_up() {
  if curl -sf "${QDRANT_URL}/collections" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

if _qdrant_up; then
  echo "→ Qdrant already running at $QDRANT_URL"
else
  echo "→ starting Qdrant (docker compose in vendor/vecs)"
  if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker required for one-shot Qdrant, or start Qdrant yourself." >&2
    echo "  macOS alternative: cd vendor/vecs && npm run install:system" >&2
    echo "  https://github.com/boorich/vecs" >&2
    exit 1
  fi
  docker compose -f "$VECS_ROOT/docker-compose.yml" up -d
  echo "→ waiting for Qdrant health"
  for _ in $(seq 1 30); do
    if _qdrant_up; then
      echo "→ Qdrant OK at $QDRANT_URL"
      break
    fi
    sleep 1
  done
  if ! _qdrant_up; then
    echo "ERROR: Qdrant did not become ready at $QDRANT_URL" >&2
    exit 1
  fi
fi

# ── GitHub CLI ─────────────────────────────────────────────────────────────────

bash "$ROOT/scripts/ensure-gh.sh"
source "$ROOT/scripts/env.sh"

echo ""
echo "── Bootstrap complete ────────────────────────────────────────────────"
echo "   vecs:   $(command -v vecs 2>/dev/null || echo "$VECS_ROOT/cli/index.js")"
echo "   gh:     $(command -v gh 2>/dev/null || echo 'not found')"
echo "   qdrant: $QDRANT_URL"
echo "   next:   bash session-setup.sh"
