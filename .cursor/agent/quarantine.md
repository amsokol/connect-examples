# Quarantine (this product)

Approach: [`library/policy/quarantine.md`](library/policy/quarantine.md).

| Setting    | Value                 |
| ---------- | --------------------- |
| Quarantine | **2 days** (48 hours) |

Apply to every ecosystem listed in [`POLICY.md`](POLICY.md).

## Temporary exclusions (dogfood) — MANDATORY

**These pins are exempt from the 2-day quarantine window.** Gate and maintain
**must not** REQUEST_CHANGES / `policy-violation` / FORBIDDEN for quarantine age
on them. Holds, bundles, verify, and human-OK rules still apply.

| Package / repo | Surfaces |
| -------------- | -------- |
| `amsokol/ai-devsecops-cursor` | `AGENT_RUNNER_REF` / `git clone` runner tags; any `uses: amsokol/ai-devsecops-cursor/…@v*` |
| `amsokol/ai-devsecops-skills` | `.cursor/agent/library` submodule pin / tags |

Under **Pending quarantine**, list as `excluded — dogfood` (do not claim they
cleared N). Do **not** invent other exclusions.

**Temporary** — delete this entire section when dogfooding stops.
