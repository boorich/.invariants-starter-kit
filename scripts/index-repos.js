#!/usr/bin/env node
// Code-only stack index — same 3-phase pipeline as OCR (proven).
// Phase 1: collect all chunks. Phase 2: embed (single ONNX pass). Phase 3: upsert.
// Do not interleave Qdrant HTTP with ONNX (macOS crash).
//
// Requires: Qdrant at localhost:6333 (vecs), npm install in this workspace.
// Query: vecs query <collection> "…" --top 8 --json
//
// Markdown is NOT indexed — agent reads prose via plain file access
// (CONTRACT.md, issues/, reports/, repo docs/). See sentinel.config.yml.

import { readdir, readFile, stat } from 'fs/promises'
import { join, extname, relative } from 'path'
import { randomUUID } from 'crypto'
import { FlagEmbedding, EmbeddingModel } from 'fastembed'
import { loadConfig, workspaceRoot } from './load-config.js'

const QDRANT = process.env.QDRANT_URL || 'http://localhost:6333'
const VECTOR_SIZE = 384
const BATCH_SIZE = 64
const EMBED_PROGRESS_EVERY = 200
const MIN_CHUNK = 50
const WINDOW_LINES = 60
const OVERLAP_LINES = 10

// OCR boundary set — TS / JS / Solidity / C# / Python (not markdown, not prose)
const CODE_BOUNDARY =
  /^(export\s+)?(async\s+)?function\b|^(export\s+)?const\s+\w+\s*=\s*(async\s*)?\(|^(export\s+)?(abstract\s+)?class\b|^(export\s+)?interface\b|^(export\s+)?enum\b|^(export\s+)?type\s+\w+\s*=|^def\s+\w+|^async\s+def\s+\w+|^(public\s+|private\s+|protected\s+|internal\s+|static\s+|override\s+)*(class|interface|enum|struct|void|async)\b|^contract\s+\w+|^library\s+\w+|^interface\s+\w+|^function\s+\w+\s*\(/

function chunkCode(text) {
  const lines = text.split('\n')
  const chunks = []
  let current = []
  let lineStart = 1

  const flush = (endLine) => {
    const content = current.join('\n').trim()
    if (content.length >= MIN_CHUNK) {
      chunks.push({ text: content, line_start: lineStart, line_end: endLine })
    }
  }

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim()
    if (CODE_BOUNDARY.test(trimmed) && current.length > 0) {
      flush(i)
      current = [lines[i]]
      lineStart = i + 1
    } else {
      current.push(lines[i])
    }
  }
  if (current.length > 0) flush(lines.length)

  if (chunks.length <= 1) {
    const fallback = []
    for (let i = 0; i < lines.length; i += WINDOW_LINES - OVERLAP_LINES) {
      const slice = lines.slice(i, i + WINDOW_LINES)
      const content = slice.join('\n').trim()
      if (content.length >= MIN_CHUNK) {
        fallback.push({
          text: content,
          line_start: i + 1,
          line_end: Math.min(i + WINDOW_LINES, lines.length),
        })
      }
    }
    return fallback
  }

  return chunks
}

async function collectFiles(dir, supportedExt, skipDirs) {
  const skip = new Set(skipDirs)
  const files = []
  async function walk(current) {
    let entries
    try {
      entries = await readdir(current, { withFileTypes: true })
    } catch {
      return
    }
    for (const entry of entries) {
      if (entry.name.startsWith('.') || skip.has(entry.name)) continue
      const fullPath = join(current, entry.name)
      if (entry.isDirectory()) {
        await walk(fullPath)
      } else if (supportedExt.has(extname(entry.name))) {
        files.push(fullPath)
      }
    }
  }
  await walk(dir)
  return files
}

async function qdrant(method, path, body) {
  const res = await fetch(`${QDRANT}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  })
  if (!res.ok) {
    const text = await res.text()
    throw new Error(`Qdrant ${method} ${path} → ${res.status}: ${text}`)
  }
  return res.json()
}

async function main() {
  const cfg = loadConfig()
  const WORKSPACE = workspaceRoot()
  const COLLECTION = cfg.collection
  const supportedExt = new Set(cfg.index.extensions)
  const skipDirs = cfg.index.skip_dirs

  const now = new Date().toISOString()
  const allChunks = []

  try {
    await qdrant('DELETE', `/collections/${COLLECTION}`)
    console.error(`→ dropped '${COLLECTION}'`)
  } catch {
    /* first run */
  }

  await qdrant('PUT', `/collections/${COLLECTION}`, {
    vectors: { size: VECTOR_SIZE, distance: 'Cosine' },
  })
  console.error(`→ created '${COLLECTION}' (code-only — no markdown in corpus)`)

  if (!cfg.repos?.length) {
    console.error('→ no repos in sentinel.config.yml')
    return
  }

  for (const { dir } of cfg.repos) {
    const repoPath = join(WORKSPACE, dir)
    try {
      await stat(repoPath)
    } catch {
      console.error(`→ ${dir}: not found — clone into workspace root`)
      continue
    }

    const files = await collectFiles(repoPath, supportedExt, skipDirs)
    if (files.length === 0) {
      console.error(`→ ${dir}: no source files matching index.extensions`)
      continue
    }

    let repoChunks = 0
    for (const file of files) {
      let text
      try {
        text = await readFile(file, 'utf8')
      } catch {
        continue
      }
      const source = relative(WORKSPACE, file)
      for (const chunk of chunkCode(text)) {
        allChunks.push({
          text: chunk.text,
          payload: {
            text: chunk.text,
            source,
            repo: dir,
            line_start: chunk.line_start,
            line_end: chunk.line_end,
            strategy: 'code',
            ingested_at: now,
          },
        })
        repoChunks++
      }
    }
    console.error(`→ ${dir}: ${files.length} files → ${repoChunks} chunks`)
  }

  console.error(`→ collected ${allChunks.length} chunks total`)
  if (allChunks.length === 0) {
    console.error('→ index empty')
    return
  }

  process.stderr.write('→ loading embedding model (cached after first run)...\n')
  const model = await FlagEmbedding.init({
    model: EmbeddingModel.BGESmallENV15,
    cacheDir: `${process.env.HOME}/.cache/fastembed`,
  })

  const allVectors = []
  const texts = allChunks.map((c) => c.text)
  for await (const batch of model.embed(texts)) {
    allVectors.push(...batch)
    if (
      allVectors.length % EMBED_PROGRESS_EVERY === 0 ||
      allVectors.length === texts.length
    ) {
      console.error(`→ embedding progress: ${allVectors.length}/${texts.length}`)
    }
  }
  console.error(`→ embedded ${allVectors.length} vectors`)

  let totalPoints = 0
  for (let i = 0; i < allChunks.length; i += BATCH_SIZE) {
    const slice = allChunks.slice(i, i + BATCH_SIZE)
    const points = slice.map((c, j) => ({
      id: randomUUID(),
      vector: Array.from(allVectors[i + j]),
      payload: c.payload,
    }))
    await qdrant('PUT', `/collections/${COLLECTION}/points`, { points })
    totalPoints += points.length
    if (totalPoints % 500 === 0 || totalPoints === allChunks.length) {
      console.error(`→ upsert progress: ${totalPoints}/${allChunks.length}`)
    }
  }

  console.error(`\n── Index complete: ${totalPoints} code chunks in '${COLLECTION}' ──`)
  console.error(`   Query: vecs query ${COLLECTION} \"…\" --top 8 --json`)
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
