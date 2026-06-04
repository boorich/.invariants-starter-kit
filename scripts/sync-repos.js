#!/usr/bin/env node
import { existsSync } from 'fs'
import { join } from 'path'
import { execSync } from 'child_process'
import { loadConfig, workspaceRoot } from './load-config.js'

const root = workspaceRoot()
const cfg = loadConfig()
const repos = cfg.repos || []

for (const entry of repos) {
  const { dir, clone, invariants_branch: invBranch } = entry
  if (!dir || !clone) {
    console.error(`→ skip invalid repo entry (need dir + clone)`)
    continue
  }
  const target = join(root, dir)

  if (!existsSync(join(target, '.git'))) {
    console.error(`→ cloning ${dir}`)
    execSync(`git clone ${JSON.stringify(clone)} ${JSON.stringify(target)}`, {
      stdio: 'inherit',
    })
    continue
  }

  let defaultBranch = 'main'
  try {
    defaultBranch = execSync(
      `git -C ${JSON.stringify(target)} remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}'`,
      { encoding: 'utf8' },
    ).trim() || 'main'
  } catch {
    /* keep main */
  }

  execSync(`git -C ${JSON.stringify(target)} fetch origin --quiet`, { stdio: 'ignore' })

  if (invBranch) {
    let hasRemote = false
    try {
      execSync(
        `git -C ${JSON.stringify(target)} ls-remote --exit-code --heads origin ${invBranch}`,
        { stdio: 'ignore' },
      )
      hasRemote = true
    } catch {
      hasRemote = false
    }

    if (hasRemote) {
      try {
        execSync(
          `git -C ${JSON.stringify(target)} show-ref --quiet refs/heads/${invBranch}`,
          { stdio: 'ignore' },
        )
      } catch {
        execSync(
          `git -C ${JSON.stringify(target)} checkout -b ${invBranch} origin/${invBranch} --quiet`,
        )
      }
      execSync(`git -C ${JSON.stringify(target)} checkout ${invBranch} --quiet`)
      console.error(`→ ${dir} @ ${invBranch} — merging origin/${defaultBranch}`)
      try {
        execSync(
          `git -C ${JSON.stringify(target)} merge origin/${defaultBranch} --no-edit --ff-only`,
          { stdio: 'ignore' },
        )
      } catch {
        execSync(
          `git -C ${JSON.stringify(target)} merge origin/${defaultBranch} --no-edit -m "merge: sync ${defaultBranch} into ${invBranch}"`,
          { stdio: 'inherit' },
        )
      }
    } else {
      console.error(`→ ${dir} @ ${defaultBranch} (no remote ${invBranch})`)
      execSync(`git -C ${JSON.stringify(target)} checkout ${defaultBranch} --quiet`)
      execSync(`git -C ${JSON.stringify(target)} pull --ff-only`, { stdio: 'inherit' })
    }
  } else {
    console.error(`→ pulling ${dir} @ ${defaultBranch}`)
    execSync(`git -C ${JSON.stringify(target)} checkout ${defaultBranch} --quiet`)
    execSync(`git -C ${JSON.stringify(target)} pull --ff-only`, { stdio: 'inherit' })
  }
}

if (repos.length === 0) {
  console.error('→ no repos in sentinel.config.yml — add repos[] when ready')
}
