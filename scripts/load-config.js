import { readFileSync, existsSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'
import yaml from 'js-yaml'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

const DEFAULTS = {
  collection: 'stack',
  contract_one_liner: '',
  repos: [],
  github: {
    issue_label: 'needs_triage',
    triage_label: 'in_triage',
    repos: [],
  },
  index: {
    // Code only — same default as OCR minus .md (prose is not the corpus)
    extensions: ['.ts', '.js', '.sol', '.cs'],
    skip_dirs: [
      'node_modules', '.git', 'out', 'build', 'dist', 'artifacts', 'cache',
      'coverage', '.next', 'vendor', 'lib',
      'Library', 'Temp', 'Logs', 'obj', 'Obj',
    ],
  },
}

export function workspaceRoot() {
  return ROOT
}

export function loadConfig() {
  const path = join(ROOT, 'sentinel.config.yml')
  if (!existsSync(path)) {
    throw new Error(
      'sentinel.config.yml not found. Copy sentinel.config.yml.example and configure repos.',
    )
  }
  const raw = yaml.load(readFileSync(path, 'utf8')) || {}
  return {
    ...DEFAULTS,
    ...raw,
    github: { ...DEFAULTS.github, ...(raw.github || {}) },
    index: { ...DEFAULTS.index, ...(raw.index || {}) },
  }
}

export function githubRepos(cfg) {
  if (cfg.github.repos?.length) return cfg.github.repos
  return (cfg.repos || [])
    .map((r) => r.github)
    .filter(Boolean)
}
