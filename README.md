# `.invariants`

**A dotfile convention for any repository** — one structured file that states what must always remain true, at what severity, in plain language.

Not a framework install. Not a SaaS product. A file you commit next to your code, in **one repo** or **many**, for backend services, SDKs, contracts, data pipelines, or any system where silent drift is expensive.

This repository is a **reference workspace**: examples, an optional multi-repo layout, session tooling, and an agent playbook that show how far the convention can go. **The convention is the dotfile.** Everything else is adapt optional.

---

## The dotfile (what actually ships)

Add **`.invariants`** at the root of a repository (like `.gitignore` or `LICENSE` — a convention, not a dependency).

```yaml
version: "1.0"
scope: "What this file governs"
authority: "Maintainers only — not agent-writable"

asserts:
  - id: identity_derivation_consistency
    claim: "All consumers derive identity the same way from the same inputs"
    severity: FROZEN
    verify:
      search: "identity derivation keccak256"
    why: "Cross-consumer mismatch fails silently at runtime."
```

**One repo** — a single `.invariants` is enough. Your team and any agent read the same constitution.

**Many repos** — one **apex** `.invariants` (cross-repo guarantees) and a `.invariants` per product repo with `inherits: "../.invariants"` (or the correct relative path). Sub-repos add scoped claims; apex links down with `cascades_to`. Both levels apply when evaluating a change.

**Any domain** — the examples use “interface” language because that is the sharpest failure mode (SDK vs contract vs indexer). The format is generic: *claims that must hold*, with `FROZEN`, `VERSIONED`, or `ADDITIVE` severity. Use it for protocol rules, security boundaries, data semantics, release policy, or architectural non-negotiables.

**Agents optional, agents powerful** — humans can review `.invariants` in PRs without automation. With an LLM agent and codebase access, each assertion becomes **checkable against real proposals and real code**. The dotfile is the law; the agent is the clerk.

---

## Naming assertions

Each assertion has a stable **`id`** (snake_case, unique in that file) — see [`.invariants.example`](.invariants.example). The `id` is how reports, `cascades_to`, and sub-repo files reference the same claim.

- One `id` = one claim; do not reuse an `id` for a different meaning.
- Prefer descriptive handles (`subscriber_derivation_cross_sdk_consistency`) over ticket numbers or dates.
- Sub-repo assertions may mirror an apex `id` when scoping the same guarantee locally.

---

## Lifecycle of assertions

**Who may edit:** only maintainers named in `authority` (typically via CODEOWNERS on `/.invariants`). Agents and other contributors must not edit dotfiles — they evaluate proposals against the cascade and write **reports**, not constitutional changes. Chat rules are not the lock: after you finish editing, **OS-seal** the file (below) so a rogue agent cannot write it.

| Phase | What happens |
|-------|----------------|
| **Propose** | Issues, ADRs, or designs may *threaten* claims; that does not edit `.invariants`. |
| **Approve** | A maintainer merges a PR that changes the dotfile. |
| **Enforce** | Later changes are checked against the cascade (human review and/or conformance agent). |
| **Retire** | A maintainer removes or rewrites an assertion in a PR — never silent drift in the file. |

---

## OS seal (maintainer only — not an agent script)

A writable `.invariants` is unprotected. Chat rules (“never edit”) do not stop a non-compliant agent with shell. The real lock is **owner-read-only + immutable** on disk.

**No `seal` / `unseal` scripts in this repository.** Named scripts are a one-liner an agent with shell could run. You apply `chmod` and the immutable flag in your own terminal. The only in-repo helper is a **read-only check**.

| Command | Risk | When |
|---------|------|------|
| **SEAL** (below) | Safe — locks the constitution | Always run after you finish editing `.invariants` |
| **UNLOCK** (below) | **Dangerous** — same-UID agents can write until you re-seal | Only when you deliberately intend to edit |
| `npm run check:sealed` | Safe — read-only verify | Anytime; does not change permissions |

Seal every live file in the cascade (apex and each `{repo}/.invariants`). Check a path with `bash scripts/check-invariants-sealed.sh path/to/.invariants`.

**SEAL — run after every edit** (macOS):

```bash
# SAFE: owner read-only + immutable. Cursor cannot save without your password.
chflags nouchg .invariants 2>/dev/null
chmod 400 .invariants
chflags uchg .invariants
```

**UNLOCK — only when you intend to edit** (macOS):

```bash
# DANGEROUS: opens writes. Re-run SEAL before you return to an agent.
chflags nouchg .invariants
chmod 600 .invariants
```

Linux:

```bash
# SEAL
chmod 400 .invariants
sudo chattr +i .invariants

# UNLOCK (DANGEROUS)
sudo chattr -i .invariants
chmod 600 .invariants
```

Agents must never run `chmod` / `chflags` / `chattr` on `.invariants`.

---

## Versioning and migration

Changing `.invariants` has **high blast radius** for the repo (and cascaded repos). The default traceability model is **auditable git history**: each change lands in a maintainer PR that CODEOWNERS review, so commits pin who changed which claim and when.

**Severity** is how you express migration cost on the claims themselves — see [What happens when a change is proposed](#what-happens-when-a-change-is-proposed): FROZEN, VERSIONED, ADDITIVE drive BLOCKED / PROCEED TO TRIAGE / PROCEED. A VERSIONED assertion implies the team owes a documented migration path when that claim is threatened.

The top-level `version:` field in the YAML is a **file-format** label (e.g. `"1.0"`), not a mandate to semver your product. Teams with very high stakes may adopt stricter release rules for the dotfile itself; that is optional policy, not part of the convention.

---

## What happens when a change is proposed

Whoever evaluates (human or agent) loads the **cascade** — apex plus every relevant repo file — and asks per assertion: **does this threaten the claim?**

| Threatened severity | Outcome |
|---------------------|---------|
| *(none)* | **CLOSE** — out of scope for these claims |
| **FROZEN** | **BLOCKED** — needs coordinated / major migration |
| **VERSIONED** | **PROCEED TO TRIAGE** — allowed with a documented migration path |
| **ADDITIVE** | **PROCEED** — new surface; existing consumers unaffected |

Severity was chosen when the assertion was written. Evaluation **pattern-matches**; it does not renegotiate policy in chat.

A separate **PASS / FAIL / UNKNOWN** on current code is audit output for that run — never written back into `.invariants`.

---

## Four principles

**01 — Descriptive, not prescriptive**  
Claims in plain language — not a rules engine, not ArchUnit, not a linter config.

**02 — Hierarchical by design**  
Apex constitution plus per-repo files that `inherits` upward. One repo is the degenerate case (apex only).

**03 — Precise, not vague**  
**CLOSE**, **BLOCKED**, **PROCEED TO TRIAGE**, **PROCEED** — from severity, not mood.

**04 — Forks are valid (say it in the report, not in the file)**  
Incompatible sub-repo claims may mean an **intentional fork**. Articulate that in review; do not store fork status or issue trackers in `.invariants`.

---

## Why not only ADRs or only fitness functions?

**ADRs** record *why* past decisions were made. They do not instruct an agent when a proposal threatens them.

**Fitness functions** enforce structure in CI. They cannot express many semantic rules (“every SDK hashes identity identically”).

**`.invariants`** holds enforceable *intent* in natural language. With an agent (and optionally a code index), that intent is **executable** without maintaining a second rules codebase.

---

## Philosophy — constitution, not linter

Tools describe *what was built*. **`.invariants`** defines *what the system is allowed to remain*.

Other docs (README, ADRs, specs) may drift and be repaired. The dotfile is the governance layer — edited only by maintainers, never by agents.

### Never put in `.invariants`

- “Currently failing”, issue numbers, temporary waivers  
- Fork labels or status fields  
- TODOs or scratch notes  

Fix the code or change the claim in a maintainer PR.

---

## Adoption (pick your depth)

### Level 1 — Dotfile only (minutes)

```bash
cp .invariants.example .invariants   # in YOUR repo root
# edit asserts; commit; PR review like any policy file
```

No vecs, no workspace, no agent required. You already have a portable convention.

### Level 2 — Multi-repo cascade

- Apex `.invariants` in the meta-repo or integration workspace root  
- `sub-repo.invariants.example` → `{each-product-repo}/.invariants` with `inherits`  
- Wire your own agent rule or review checklist to load the cascade on PRs

### Level 3 — Reference workspace (this repository)

Full loop: code index ([vecs](https://github.com/boorich/vecs)), GitHub triage (`gh`), conformance agent. **Copy-paste:**

```bash
# prerequisites: Node 18+, Docker Desktop running, git
git clone --recurse-submodules <repo-url>
cd <repo-dir>

cp sentinel.config.yml.example sentinel.config.yml
cp .invariants.example .invariants
# edit sentinel.config.yml, .invariants, CONTRACT.md when ready
# then OS-seal .invariants (see OS seal). Do not leave it writable around agents.

bash setup.sh
gh auth login    # once — only if you fetch/post GitHub issues
npm run check:sealed                 # read-only verify
```

`setup.sh` pulls submodules (`vendor/vecs`), installs npm deps, starts Qdrant, puts `vecs` on PATH, syncs repos from config, fetches `needs_triage` issues, rebuilds the code index.

**Already cloned without submodules?**

```bash
git submodule update --init --recursive
bash setup.sh
```

**Just deps, no index yet:** `bash scripts/bootstrap.sh` then `bash session-setup.sh` (same as `setup.sh` in two steps).

#### Qdrant without Docker (macOS, power users)

Same Level 3 workspace — you only change **how Qdrant runs**. Skip Docker entirely and use [vecs](https://github.com/boorich/vecs)’s native install: a **launchd daemon** plus `vecs` on your PATH for every terminal session.

```bash
git submodule update --init --recursive
cd vendor/vecs && npm install && npm run install:system
cd ../..

cp sentinel.config.yml.example sentinel.config.yml
cp .invariants.example .invariants
bash setup.sh
npm run check:sealed
```

`install:system` downloads Qdrant, registers `dev.vecs.qdrant` (starts on login), stores data in `~/.vecs/data/`, and **`npm link`s the `vecs` CLI globally**. After that:

- **`vecs list` / `vecs query …` work from any directory** — not only this workspace.
- Collections persist on your machine; other projects can reuse the same Qdrant without another stack.
- `setup.sh` sees Qdrant on `localhost:6333` and **does not start Docker**.

Remove later: `cd vendor/vecs && npm run uninstall:system`.

Open `.cursor/rules/conformance-agent.mdc` in Cursor and run it on `issues/` or an ad-hoc change.

```text
your-workspace/
  .invariants              # apex
  service-a/               # clones from sentinel.config.yml
    .invariants
```

---

## Two layers: code in vecs, markdown on disk

| Layer | What | How the agent uses it |
|-------|------|------------------------|
| **Materializes** | Source code in product repos | **`vecs query`** — semantic search across the stack; then **read those files** for PASS/FAIL |
| **Navigates** | Markdown in the workspace | **Plain file read/write** — never in the vector corpus |

**Markdown is special.** It does not implement behavior — it **points at** behavior, orients triage, and **accumulates curation** (`IMPLEMENTATION_MAP.md` is **meant to be edited** by the agent after it finds code). Putting `.md` in vecs blurs “what we said” with “what runs” and retrieval lies politely.

| In `vecs` (code corpus) | On disk only (navigation / IO) |
|-------------------------|--------------------------------|
| `.ts`, `.js`, `.sol`, `.cs` (default) | `CONTRACT.md`, `GLOSSARY.md`, `IMPLEMENTATION_MAP.md` |
| Chunked by declaration boundaries | `issues/`, `reports/`, repo `README`, `docs/` |
| Skips `node_modules`, `dist`, `build`, … | `/.invariants` (governance — agent **must not** edit) |

The agent rule requires: **`vecs` = find code → read source → optionally update the map on disk → rummage other `.md` when it needs human context.**

**`·NAV` sentinels** — line 1 of governed markdown, hidden in HTML comments (`<!-- ·NAV:M -->`). Humans learn to ignore; agents grep them for edit control:

```bash
rg '<!-- ·NAV:' --glob '*.md' --glob '!node_modules/**'
```

Codes: **`M`** map paths, **`S`** sync facts. **Untagged** `.md` (`issues/`, `reports/`, README, …) is a **wildcard** — use or ignore. **Ground truth:** code in `vecs` + triage **labels** on GitHub (`skip if exists` on `reports/`). See `GLOSSARY.md`.

---

## What `setup.sh` wires up (optional detail)

| Piece | What happens |
|-------|----------------|
| `vendor/vecs` | Submodule — Qdrant via **Docker** (default) or **macOS daemon** (`install:system`) |
| `vecs` CLI | `vendor/bin/vecs` in this repo; global `vecs` after `install:system` |
| `gh` | Uses yours if installed; otherwise downloads to `vendor/bin/gh` |
| Index | Code only (no `.md` in Qdrant) — see **Two layers** below |

| File | Part of the **convention**? | Role |
|------|---------------------------|------|
| `/.invariants`, `{repo}/.invariants` | **Yes** | Governance (OS-seal after edit) |
| `CONTRACT.md`, `GLOSSARY.md`, `IMPLEMENTATION_MAP.md` | No | Agent helpers (`·NAV` on line 1) |
| `setup.sh`, `sentinel.config.yml` | No | This workspace only |
| `scripts/check-invariants-sealed.sh` | No | Read-only verify that `.invariants` is sealed |

---

## Customising the template

1. Copy examples into **your** repos — that is the real deliverable.  
2. Adjust `sentinel.config.yml` only if you use this workspace.  
3. Fork `conformance-agent.mdc` for your editor or CI — the verdict table is the contract.

---

## Static site (GitHub Pages)

Landing page for social sharing: [`docs/index.html`](docs/index.html) — same visual language as the handbook’s `invariance.html`, updated for `.invariants` (plural) and this starter kit.

Enable Pages: repo **Settings → Pages → Build from branch `main` / folder `/docs`**.

---

## License

Apache-2.0. Take the dotfile format, adapt asserts, ignore the workspace if you do not need it.
