<!-- ·NAV:S -->
# Glossary

Descriptive vocabulary for this sentinel. The conformance agent may update entries to match code. If a term conflicts with an assertion `claim`, **the assertion wins**.

| Term | Definition |
|------|------------|
| **`.invariants`** | The dotfile convention — claims + severity; belongs in each governed repo |
| **Reference workspace** | This repo: optional orchestration (vecs, `session-setup.sh`, agent rule) around the convention |
| **Contract** | Shared interface in `CONTRACT.md` — what consumers must agree on |
| **Assertion** | One YAML entry in `.invariants` (`id`, `claim`, `severity`, …) |
| **Cascade** | Apex `/.invariants` plus sub-repo files linked by `inherits` and `cascades_to` |
| **Constitution** | Apex `/.invariants` — cross-repo guarantees |
| **Collection** | Qdrant index name in `sentinel.config.yml`; query via `vecs query <collection>` |
| **Threatened** | A proposal would falsify a `claim` or touches `verify` scope |
| **FROZEN** | Must not change without coordinated migration; threatened → **BLOCKED** |
| **VERSIONED** | May change with migration path; threatened → **PROCEED TO TRIAGE** |
| **ADDITIVE** | New surface, consumers unaffected; threatened → **PROCEED** |
| **CLOSE** | No assertion threatened — out of scope for this contract |
| **Intentional fork** | Sub-repo incompatible with apex by design — stated in **reports**, never in `.invariants` |
| **Code corpus** | Qdrant collection — **source files only**; queried via `vecs query` |
| **Navigational markdown** | `.md` on disk — orients and points at code; **not** embedded in vecs |
| **Implementation map** | Navigational — agent-writable index of **code paths**; git-audited |
| **Materializes** | What the running system actually does — proven by reading source, not by reading prose |
| **`·NAV` sentinel** | Line 1 HTML comment — **how** to edit long-lived navigational `.md`; grep `<!-- ·NAV:` |
| **Ground truth** | **Code** in `vecs` (what runs) + **GitHub labels** (what still needs triage) — not unflagged markdown |

### `·NAV` codes (line 1 only)

**How** to edit when the agent curates — not whether a file may be touched (`/.invariants` owns hard rules).

| Code | How to edit |
|------|-------------|
| **M** | **Map** — add/fix code paths; commit `map: … [triggered by …]`; no MUST/SHALL |
| **S** | **Sync** — align stated facts with code/repos; no new requirements |

Inventory: `rg '<!-- ·NAV:' --glob '*.md' --glob '!node_modules/**'`.

**Untagged `.md`** (`README.md`, `issues/`, `reports/`, repo docs) — **wildcard**: use or ignore as the agent workflow needs. Triage idempotency: `reports/` **skip if exists**, then flip `needs_triage` → `in_triage` on GitHub (see agent rule). Before committing edits to a navigational file you intend to maintain, add `M` or `S` on line 1.

Add project-specific terms below.
