# EPAC with an Azure Policy Linter gate

Walkthrough: _link to the blog post_

A small, runnable Enterprise Policy as Code (EPAC) sample with the [Azure Policy Linter](https://github.com/Azure/azure-policy-linter) in front of it. The Azure Pipeline lints every custom policy definition, creates two management groups (one for dev, one for prod), and deploys the definitions and assignments to each with EPAC.

Everything below assumes your shell is in this folder:

```powershell
cd azure-devops/epac-policy-linter-pipeline
```

## Layout

The repository follows the EPAC convention of a `Definitions` root, with the pipeline and its scripts kept outside it so EPAC never mistakes them for policy files.

- `Definitions/` holds `global-settings.jsonc` (two EPAC environments, `epac-dev` and `epac-prod`), two custom policy definitions, and one assignment file that targets both environments.
- `scripts/Invoke-PolicyLinter.ps1` runs the linter, turns findings into Azure Pipelines annotations, and exits with 1 at a configurable severity. The linter itself always exits 0 when it ran, so this wrapper is what makes the Lint stage fail.
- `scripts/New-PolicyManagementGroups.ps1` creates `mg-epac-dev` and `mg-epac-prod` under a parent of your choice, and does nothing when they already exist.
- `pipelines/` contains the pipeline and one template per stage.
- `samples/lint-findings/` has a deliberately flawed first draft of one of the definitions, kept outside `Definitions/` so it is never deployed.
- `samples/alias-warnings/` has a well-formed storage policy that still gets alias warnings, to show when `-ExcludeRule` is the right answer.

## Try the linter without Azure

```powershell
dotnet tool install --global Microsoft.Azure.Policy.PolicyLinter.Cli

# See one Error, two Warnings and two Informational findings on the flawed sample.
./scripts/Invoke-PolicyLinter.ps1 -Path ./samples/lint-findings -FailOn None

# Lint the real definitions. Exit code 1 on any Warning or Error.
./scripts/Invoke-PolicyLinter.ps1

# A warning you have reviewed and accepted: still reported, no longer blocking.
./scripts/Invoke-PolicyLinter.ps1 -Path ./samples/alias-warnings -ExcludeRule field-alias-unavailable-in-old-api-versions
```
