#!/usr/bin/env node
/**
 * Verifies Qdrant is reachable before session-setup indexes.
 * Install vecs first: https://github.com/boorich/vecs
 */
const QDRANT = process.env.QDRANT_URL || 'http://localhost:6333'

async function main() {
  try {
    const res = await fetch(`${QDRANT}/collections`, { signal: AbortSignal.timeout(5000) })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    console.log(`→ Qdrant OK at ${QDRANT}`)
  } catch (err) {
    console.error(`
ERROR: Cannot reach Qdrant at ${QDRANT}

vecs is required for Interface Sentinel sessions.
  https://github.com/boorich/vecs

macOS:  cd vecs && npm run install:system
Docker: cd vecs && docker compose up -d

Then verify:  vecs list
`)
    console.error(err.message || err)
    process.exit(1)
  }
}

main()
