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

Use this repo when you want the **full loop** used in production Interface Sentinel setups:

- Clone sibling product repos over time (`sentinel.config.yml`)  
- Rebuild a semantic code index each session ([vecs](https://github.com/boorich/vecs))  
- Triage GitHub issues via **`gh`** + `.cursor/rules/conformance-agent.mdc`  
- Self-healing `IMPLEMENTATION_MAP.md` (optional; not part of the dotfile spec)

```text
your-workspace/              # this boilerplate repo, renamed as you like
  .invariants                # apex — copy from .invariants.example
  service-a/                 # your git clone
    .invariants              # inherits: "../.invariants"
  service-b/
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

Default extensions: OCR’s set **minus `.md`**. OCR may still index markdown; this boilerplate does not.

---

## Running the reference workspace

**Prerequisites:** [vecs](https://github.com/boorich/vecs) (Qdrant + `vecs query`), Node 18+ for indexing, optional **`gh`** for issue fetch/post.

```bash
cp sentinel.config.yml.example sentinel.config.yml
cp .invariants.example .invariants
# edit config + dotfile + CONTRACT.md
npm install
bash session-setup.sh          # pull repos, fetch issues, rebuild index
# run conformance-agent on issues/ or ad-hoc
```

| File | Part of the **convention**? | Role |
|------|---------------------------|------|
| `/.invariants`, `{repo}/.invariants` | **Yes** — ship these everywhere | Governance |
| `CONTRACT.md`, `GLOSSARY.md` | No — workspace helpers | Descriptive context for agents/humans |
| `IMPLEMENTATION_MAP.md` | No — workspace helper | Agent-updated code index; git-audited |
| `sentinel.config.yml`, `session-setup.sh` | No — this repo only | Orchestration |
| `conformance-agent.mdc` | No — template | One agent implementation |

---

## Customising the template

1. Copy examples into **your** repos — that is the real deliverable.  
2. Adjust `sentinel.config.yml` only if you use this workspace.  
3. Fork `conformance-agent.mdc` for your editor or CI — the verdict table is the contract.

---

## License

Apache-2.0. Take the dotfile format, adapt asserts, ignore the workspace if you do not need it.
