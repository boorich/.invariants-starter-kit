#!/usr/bin/env bash
# Install GitHub CLI into vendor/bin from https://github.com/cli/cli releases.
# Submodule vendor/github-cli pins upstream; we do not build Go on every clone.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$ROOT/vendor/bin"
mkdir -p "$BIN_DIR"

# Pin (override: GH_VERSION=2.93.0 bash scripts/ensure-gh.sh)
GH_VERSION="${GH_VERSION:-2.93.0}"
GH_BIN="$BIN_DIR/gh"

if [[ -x "$GH_BIN" ]]; then
  echo "→ gh (vendored) $("$GH_BIN" --version 2>/dev/null | head -1)"
  exit 0
fi

if command -v gh &>/dev/null && [[ "${INVARIANTS_FORCE_VENDOR_GH:-}" != "1" ]]; then
  echo "→ gh (system) $(command -v gh) — set INVARIANTS_FORCE_VENDOR_GH=1 to vendor a copy"
  exit 0
fi

OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
  Darwin)
    PLATFORM=macOS
    case "$ARCH" in
      arm64) ARCHIVE="gh_${GH_VERSION}_macOS_arm64.zip" ;;
      x86_64) ARCHIVE="gh_${GH_VERSION}_macOS_amd64.zip" ;;
      *) echo "ERROR: unsupported macOS arch: $ARCH" >&2; exit 1 ;;
    esac
    ;;
  Linux)
    PLATFORM=linux
    case "$ARCH" in
      x86_64) ARCHIVE="gh_${GH_VERSION}_linux_amd64.tar.gz" ;;
      aarch64|arm64) ARCHIVE="gh_${GH_VERSION}_linux_arm64.tar.gz" ;;
      *) echo "ERROR: unsupported Linux arch: $ARCH" >&2; exit 1 ;;
    esac
    ;;
  *)
    echo "ERROR: install gh manually from https://github.com/cli/cli/releases" >&2
    exit 1
    ;;
esac

URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/${ARCHIVE}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ downloading gh v${GH_VERSION} (${ARCHIVE})"
curl -fsSL "$URL" -o "$TMP/archive"

mkdir -p "$TMP/extract"
if [[ "$ARCHIVE" == *.zip ]]; then
  unzip -q "$TMP/archive" -d "$TMP/extract"
else
  tar -xzf "$TMP/archive" -C "$TMP/extract"
fi
GH_EXTRACTED="$(find "$TMP/extract" -name gh -type f | head -1)"

if [[ -z "$GH_EXTRACTED" || ! -f "$GH_EXTRACTED" ]]; then
  echo "ERROR: gh binary not found in release archive" >&2
  exit 1
fi

cp "$GH_EXTRACTED" "$GH_BIN"
chmod +x "$GH_BIN"
echo "→ gh installed at $GH_BIN"

if ! "$GH_BIN" auth status &>/dev/null; then
  echo "  (run: gh auth login — required for issue fetch/post)"
fi
