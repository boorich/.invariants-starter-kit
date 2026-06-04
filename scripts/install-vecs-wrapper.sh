#!/usr/bin/env bash
# Place vendor/bin/vecs → node vendor/vecs/cli/index.js (npm does not always link local bin).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$ROOT/vendor/bin"
mkdir -p "$BIN_DIR"
WRAPPER="$BIN_DIR/vecs"
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
exec node "\$(cd "\$(dirname "\$0")/../vecs" && pwd)/cli/index.js" "\$@"
EOF
chmod +x "$WRAPPER"
echo "→ vecs wrapper at $WRAPPER"
