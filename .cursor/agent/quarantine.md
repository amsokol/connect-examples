# Quarantine (this product)

Approach: [`library/policy/quarantine.md`](library/policy/quarantine.md).

| Setting    | Value                 |
| ---------- | --------------------- |
| Quarantine | **2 days** (48 hours) |

Apply to every ecosystem listed in [`POLICY.md`](POLICY.md).

## Temporary exclusions (dogfood)

Skip the N-day window for these **only** (see library
[`quarantine.md`](library/policy/quarantine.md) — Product exclusions). Still
list under Pending quarantine as `excluded — dogfood`.

| Package / repo | Surfaces | Reason |
| -------------- | -------- | ------ |
| `amsokol/ai-devsecops-cursor` | runner git tags (`AGENT_RUNNER_REF` / clone), `uses: amsokol/ai-devsecops-cursor/…@v*` | dogfood runner |
| `amsokol/ai-devsecops-skills` | `.cursor/agent/library` submodule tags | dogfood skills |

**Temporary** — remove this section when dogfooding stops. Do not invent other
exclusions.
