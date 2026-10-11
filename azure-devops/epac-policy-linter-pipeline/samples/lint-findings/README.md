# Sample with intentional lint findings

`allowed-locations.before.json` is the first draft of the policy that now lives at
`Definitions/policyDefinitions/General/allowed-locations.json`. It deliberately keeps the mistakes
the linter is designed to catch, so you can see all three severities at once:

- a parameter reference with a typo, `allowedLocation` instead of `allowedLocations` (Error)
- a hard-coded `Deny` effect, and `notLike` on `type` with a value that has no wildcard (Warning)
- a missing `description` (Informational)

The file lives outside `Definitions/` on purpose: EPAC never deploys it, and the pipeline's Lint
stage never sees it. Run the linter against it by hand:

```powershell
./scripts/Invoke-PolicyLinter.ps1 -Path ./samples/lint-findings -FailOn None
```
