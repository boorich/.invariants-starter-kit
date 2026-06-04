#!/usr/bin/env node
import { githubRepos, loadConfig } from './load-config.js'

const cfg = loadConfig()
console.log('LABEL:' + (cfg.github.issue_label || 'needs_triage'))
console.log('NEEDS:' + (cfg.github.issue_label || 'needs_triage'))
console.log('IN:' + (cfg.github.triage_label || 'in_triage'))
console.log('REPOS:' + JSON.stringify(githubRepos(cfg)))
console.log('COL:' + cfg.collection)
for (const r of githubRepos(cfg)) {
  console.log('REPO:' + r)
}
