<!-- ·NAV:S -->
# Shared interface contract

> **Descriptive only.** Machine-enforceable rules live in `/.invariants` and `{repo}/.invariants`.
> The conformance agent may update this file to match implementation reality; it must not contradict assertions.

## One-line contract

Replace with the single interface every implementation must honor — same meaning as `contract_one_liner` in `sentinel.config.yml`.

Example shape (delete this example when you write yours):

```
(identity, resource) → operation_is_allowed
```

## Consumers

List repositories or systems that must implement the contract identically:

- _(add after you clone repos into this workspace)_

## Non-goals

What this contract explicitly does **not** cover (keeps triage scope tight).
