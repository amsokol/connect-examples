# Quarantine (this product)

Approach: [`library/policy/quarantine.md`](library/policy/quarantine.md).

| Setting             | Value                                                                    |
| ------------------- | ------------------------------------------------------------------------ |
| Quarantine          | **2 days** (48 hours)                                                    |
| Renovate enforcement | `minimumReleaseAge: "2 days"` in `renovate.json` (same window)          |

Do not lower or disable Renovate `minimumReleaseAge` unless updated here and in
`renovate.json` together.

Apply to every ecosystem listed in [`POLICY.md`](POLICY.md).
