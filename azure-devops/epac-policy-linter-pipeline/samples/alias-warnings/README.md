# Sample with field alias findings

`storage-https-only.json` is a well-formed policy: parameterized effect, explicit `type` condition,
description, the lot. The linter still reports two findings on every reference to the alias
`Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly`:

- `field-alias-unavailable-in-old-api-versions` (Warning). The property doesn't exist in the storage
  API versions from 2015-05-01-preview through 2016-05-01. A request that uses one of those versions
  resolves the alias to an empty value, so a `Deny` assignment behaves differently than you expect.
- `optional-field-alias` (Informational). The property isn't marked as required, so a request can omit
  it even on a current API version.

Neither finding is a typo you can edit away. The rule documentation asks you to decide what the policy
should do when the property is missing: either guard it with an `exists` condition and accept that such
requests aren't enforced, or audit first and check the activity log for requests on old API versions
before switching to `Deny`.

Once you have made that call, tell the gate so the pipeline stops failing on it:

```powershell
# Still reported, but no longer fails the run.
./scripts/Invoke-PolicyLinter.ps1 -Path ./samples/alias-warnings -ExcludeRule field-alias-unavailable-in-old-api-versions
```

In the pipeline, set the `lintExcludeRules` parameter to the same identifier.
