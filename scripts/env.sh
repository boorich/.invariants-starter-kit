# Source from bash:  source scripts/env.sh
# Exposes vendored vecs + gh on PATH for this workspace.

if [[ -z "${INVARIANTS_WORKSPACE_ROOT:-}" ]]; then
  INVARIANTS_WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export INVARIANTS_WORKSPACE_ROOT

VECS_ROOT="${INVARIANTS_WORKSPACE_ROOT}/vendor/vecs"
export VECS_ROOT

_path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

# vendor/bin: vecs wrapper + optional gh release binary (prepended first)
if [[ -d "${INVARIANTS_WORKSPACE_ROOT}/vendor/bin" ]]; then
  _path_prepend "${INVARIANTS_WORKSPACE_ROOT}/vendor/bin"
fi

export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
