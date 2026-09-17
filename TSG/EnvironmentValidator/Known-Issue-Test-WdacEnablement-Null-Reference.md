---
ArticleType: "KI"
Article_ID: "20260917145002"
Title: "Known issue: Test-WdacEnablement null-reference error during upgrade validation"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
EngineeringStatus: "Fixed - External"
FixedInBuild:
  OS: ["24H2"]
  SolutionMinorBuild: ["2607"]
  ExtensionName: ""
  ExtensionVersion: []
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Hyperconverged", "Disaggregated", "Multi-Rack"]
  OEM: ["All"]
  OS: ["23H2", "24H2"]
  SolutionMinorBuild: ["2509", "2510", "2511", "2512", "2601", "2602", "2603", "2604", "2605", "2606"]
  ExtensionName: ""
  ExtensionVersion: []
Component: "Environment Validator"
Engineering_ID:
  Source: "ADO Bug"
  ID: 37710770
Tags: ["Solution Update", "Validation", "WDAC"]
---
[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
|---|---|---|
| 2026-09-17 | 1.2 | Added mandatory metadata and canonical KI layout, assigned the wave-four Article ID, and corrected audience-directive spacing after Grade A L2 validation. |

:::

# Known issue: Test-WdacEnablement null-reference error during upgrade validation

# Symptoms

The Environment Validator upgrade check `Test-WdacEnablement`, run by
`Invoke-AzStackHciUpgradeValidation`, can stop upgrade readiness validation with:

```text
[ERROR] [Invoke-AzStackHciUpgradeValidation] You cannot call a method on a null-valued expression.
[ERROR] [Invoke-AzStackHciUpgradeValidation] at <ScriptBlock>, AzStackHciUpgrade\AzStackHci.Upgrade.Helpers.psm1
```

The defining historical signature is a call to `ToXml()` on a missing Code
Integrity event while `Test-WdacEnablement` evaluates active policy files. A
different exception, a normal `FAILURE` result that says WDAC is enabled, or an
unrelated upgrade validator failure is a different scenario.

The defect affects Environment Checker implementations before the 2607 source
fix. The historical issue was first identified in `10.2509.0.2010` and later
2509 through 2606 builds. The product fix merged on April 30, 2026 for the 2607
train. The fixed implementation was also confirmed in installed
`AzStackHci.EnvironmentChecker 10.2610.0.2039` runtime on September 17, 2026.

**Severity:** Critical when reproduced because upgrade readiness validation
stops before the upgrade can proceed.

**Customer impact:** upgrade readiness validation stops before the upgrade can
proceed. Read-only diagnosis and rerunning the targeted validator do not drain
nodes, reboot nodes, or interrupt running virtual machines.

**Primary owner:** the Azure Local Environment Validator or solution-upgrade
owner handles the defect and package version. The security or
application-control owner must review any policy-state concern. No OEM,
firmware, switch, or physical-hardware action is required.

**Typical effort:** allow 15-30 minutes to inventory all nodes, verify the
installed implementation, rerun the targeted check, and collect evidence.
Updating to a fixed release requires the normal solution-update maintenance
planning.

# Issue Validation

## Errors or Failures

**Decision summary**

1. **[LOW RISK]** Inventory the Environment Checker version, installed source
   markers, and active Code Integrity policy relationships on every node.
2. If every node contains the fixed implementation, do not rename any policy
   file. Rerun only `Test-WdacEnablement`.
3. If the targeted check succeeds, the retired defect is not blocking the
   upgrade. Address any other validator result separately.
4. If an affected pre-2607 implementation is present, update to a fixed Azure
   Local release through the supported solution-update path.
5. If the exact null-reference occurs with the fixed implementation, preserve
   the evidence and escalate. Do not use the historical policy-file rename
   workaround.

**Terms and safety boundary**

- **Windows Defender Application Control (WDAC)**, also called App Control for
  Business, controls which code is authorized to run.
- A **base policy** defines the main trust policy.
- A **supplemental policy** extends a base policy. In `CiTool.exe -lp -json`
  output, it has a `PolicyID` that differs from its `BasePolicyID`.
- A GUID-named `.cip` file is not, by itself, proof that the policy is
  supplemental, unexpected, or safe to remove.

Active policy files are security configuration. Renaming or deleting one can
change enforcement and can leave the node in a state that differs from the
security owner's approved policy.

**[LOW RISK]** Run the read-only inventory and targeted validation.

**[HIGH RISK]** Do not rename, delete, replace, refresh manually, or otherwise
change active WDAC policy files without Microsoft Support and the
security-policy owner.

**Where this failure appears**

| Admin surface | What to expect |
|---|---|
| PowerShell on an Azure Local node | **Shown**: `Invoke-AzStackHciUpgradeValidation` reports the exception or the targeted `Test-WdacEnablement` result. The inventory below shows the installed implementation and policy relationships. |
| Azure portal | **Shown when persisted**: the upgrade-readiness operation can report the Environment Validator exception. The portal does not show the local policy relationship or installed helper source. |
| Windows event logs | **Shown for correlation**: `Microsoft-Windows-CodeIntegrity/Operational` contains policy events 3099 and 3096 when Windows emits them. Their absence was the trigger for the old null dereference, not proof that no policy exists. |
| Cluster logs from `Get-ClusterLog` | This Environment Validator code defect is **not evident in cluster logs** as a cluster membership, quorum, storage, or resource failure. |
| Windows Failover Cluster Manager | This defect is **not evident in Failover Cluster Manager** as a node, role, or resource state. |
| Windows Admin Center on a standalone host | The exact validator implementation and policy relationship are **not evident in Windows Admin Center on a standalone host**. Use node PowerShell. |
| Windows Admin Center in the Azure portal | The exact local exception and policy relationship are **not evident in Windows Admin Center in the Azure portal**. Use the Azure Local lifecycle result for correlation and node PowerShell for evidence. |
| Component or tool log files on disk | **Shown when written**: preserve `C:\CloudDeployment\Logs` and, for a user-profile Environment Checker run, `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` plus `AzStackHciEnvironmentReport.json` or `.xml`. A missing file is a data gap, not proof that the failure did not occur. |

## PowerShell Detection Script

**Inventory every node**

Run the following read-only block from an elevated Windows PowerShell session.
It checks every currently Up cluster node when `Get-ClusterNode` is available
and checks the local host otherwise. It does not import the module, invoke the
validator, refresh policies, or change Code Integrity state.

```powershell
$ErrorActionPreference = 'Stop'

$nodes = @(
    if (Get-Command Get-ClusterNode -ErrorAction SilentlyContinue) {
        Get-ClusterNode |
            Where-Object State -eq 'Up' |
            Select-Object -ExpandProperty Name
    }
    else {
        $env:COMPUTERNAME
    }
)

if ($nodes.Count -eq 0) {
    throw 'No target nodes were found.'
}

$inventory = foreach ($node in $nodes) {
    Invoke-Command -ComputerName $node -ScriptBlock {
        $module = Get-Module AzStackHci.EnvironmentChecker -ListAvailable |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if (-not $module) {
            throw 'AzStackHci.EnvironmentChecker is not installed.'
        }

        $helperPath = Get-ChildItem -LiteralPath $module.ModuleBase `
            -Recurse -File -Filter 'AzStackHci.Upgrade.Helpers.psm1' |
            Select-Object -First 1 -ExpandProperty FullName

        if (-not $helperPath) {
            throw 'AzStackHci.Upgrade.Helpers.psm1 was not found.'
        }

        $source = Get-Content -LiteralPath $helperPath -Raw
        $function = [regex]::Match(
            $source,
            '(?ms)^function\s+Test-WdacEnablement\b.*?(?=^function\s+\S+|\z)'
        ).Value

        $ciTool = Join-Path $env:SystemRoot 'System32\CiTool.exe'
        $policies = if (Test-Path -LiteralPath $ciTool) {
            $list = & $ciTool -lp -json | ConvertFrom-Json
            @(
                $list.Policies |
                    Select-Object PolicyID, BasePolicyID, FriendlyName,
                        IsSystemPolicy, IsEnforced, IsAuthorized, PolicyOptions
            )
        }
        else {
            @()
        }

        [pscustomobject]@{
            Node = $env:COMPUTERNAME
            ObservedAtUtc = [DateTime]::UtcNow.ToString('o')
            ModuleVersion = [string]$module.Version
            ModuleBase = $module.ModuleBase
            HelperPath = $helperPath
            HelperSha256 = (Get-FileHash -LiteralPath $helperPath -Algorithm SHA256).Hash
            FixedNullGuard = [bool](
                $function -match '\$null\s+-ne\s+\$targetEvent'
            )
            IteratesAllPolicies = [bool](
                $function -match 'foreach\s*\(\s*\$cipFile\s+in\s+\$cipFiles\s*\)'
            )
            CiToolPresent = Test-Path -LiteralPath $ciTool
            Policies = $policies
        }
    }
}

$inventory |
    Select-Object Node, ModuleVersion, FixedNullGuard,
        IteratesAllPolicies, CiToolPresent |
    Format-Table -AutoSize

$inventory | ConvertTo-Json -Depth 8
```

Expected fixed implementation:

- `FixedNullGuard` is `True`;
- `IteratesAllPolicies` is `True`; and
- the installed module version and helper SHA-256 are recorded for every node.

Interpret policy rows by relationship:

- `PolicyID -eq BasePolicyID` identifies a base policy.
- `PolicyID -ne BasePolicyID` identifies a supplemental policy.
- `IsEnforced` describes the current policy state. Do not infer policy intent
  or ownership from the file name.
- If `CiToolPresent` is `False`, preserve the remaining inventory and
  escalate. Do not substitute a file rename.

Stop and escalate if nodes have different Environment Checker versions or
different fixed-source markers. Do not copy module files between cluster nodes.

**Rerun only the WDAC check**

When the fixed implementation is present on every node, run the targeted
upgrade validator:

```powershell
$ErrorActionPreference = 'Stop'
$outputPath = Join-Path $env:TEMP 'WdacEnablement-validation'

$result = @(
    Invoke-AzStackHciUpgradeValidation `
        -Include 'Test-WdacEnablement' `
        -PassThru `
        -OutputPath $outputPath
)

$result |
    Select-Object Name, Status,
        @{Name = 'Detail'; Expression = { $_.AdditionalData.Detail } },
        Remediation |
    Format-List
```

Expected fixed result shape:

```text
Name   : AzStackHci_Upgrade_WdacEnablement
Status : SUCCESS
Detail : <node> - 1 of 1 checks SUCCESS
```

A normal `FAILURE` result that reports WDAC enforcement is not the retired
null-reference defect. Review the policy state with the security owner.

# Root Cause

The affected implementation selected one GUID-named `.cip` file, refreshed it,
searched the `Microsoft-Windows-CodeIntegrity/Operational` log for event 3099 or
3096, and called `$targetEvent.ToXml()` without first checking whether an event
was found.

A supplemental policy can be present without generating the base-policy event
the old code expected. In that state, `$targetEvent` is `$null`, and the
unconditional `ToXml()` call raises the null-reference error.

The 2607 fix:

- initializes the result to a safe default;
- refreshes the policy set once;
- evaluates every active `.cip` file instead of only the first file;
- limits the event query to the recent refresh window; and
- checks that `$targetEvent` is not null before calling `ToXml()`.

The fixed check returns its normal result when only a supplemental-policy event
is absent. It does not treat a missing event as an exception.

# Internal Root Cause

::: audience-engineering

ADO Bug 37710770 tracked the defect. ASZ-EnvironmentValidator PR 15541474,
merged April 30, 2026 for the 2607 train, changed
`AzStackHci.Upgrade.Helpers.psm1` to initialize `$policyResult = $false`, iterate
all `$cipFiles`, and guard `$targetEvent.ToXml()` with
`if ($null -ne $targetEvent)`.

The same markers and helper SHA-256
`55C2C9B22B1728C38B4FDA664485F02036C03D7D300DAEBA64C493AE5370C686`
were confirmed on all three nodes of the 2610 validation environment.

:::

# Mitigation Details

**Fixed implementation present**

No policy-file workaround is required. Keep the active policy set unchanged
and continue with the upgrade-readiness workflow after the targeted check
returns its normal result.

If the broader validation has other failures, address each result separately.
Do not interpret a successful WDAC check as an all-clear for the entire
upgrade.

**Affected pre-2607 implementation present**

Update Azure Local through the supported solution-update process to a release
that contains the 2607 or later Environment Checker implementation. Do not
manually replace the installed module or copy a fixed helper file from another
node.

If the upgrade cannot reach the fixed package because this validator blocks
the prerequisite workflow, open a Microsoft Support case. Include the evidence
listed in the Escalation section. Any temporary Code Integrity workaround
requires explicit review by Microsoft Support and the customer's
security-policy owner.

**Verify the fix**

1. Confirm every node reports `FixedNullGuard = True` and
   `IteratesAllPolicies = True`.
2. Confirm the targeted validator returns a normal result object instead of a
   null-reference exception.
3. Confirm active policy files and `CiTool.exe -lp -json` policy relationships
   are unchanged from the pre-validation inventory.
4. Rerun the original upgrade-readiness action and confirm it advances past
   `Test-WdacEnablement`.

The targeted validator refreshes the installed policy set as part of its
normal read path so Windows can emit current Code Integrity events. It does
not rename or delete policy files.

# Escalation

Escalate to Microsoft Support when:

- the exact null-reference occurs even though the fixed source markers are
  present;
- nodes have mixed Environment Checker versions or source markers;
- the check returns a normal `FAILURE` and policy ownership or intent is
  unclear; or
- an affected build cannot reach the fixed Azure Local release.

Collect:

- the complete inventory JSON from every node;
- the exact exception, UTC timestamp, and upgrade operation;
- the targeted validator result;
- relevant `Microsoft-Windows-CodeIntegrity/Operational` events 3099 and 3096
  from the same window;
- `C:\CloudDeployment\Logs`; and
- the Environment Checker log and JSON or XML report when present.

Do not remove or rename active policy files before collecting this evidence.

# Internal Escalation

::: audience-engineering

The September 17, 2026 validation used Azure Local solution
`12.2610.1004.30`, platform `12.2610.0.3059`, and
`AzStackHci.EnvironmentChecker 10.2610.0.2039`.

The exact multi-node read-only inventory returned the fixed source markers and
the same helper hash on `V-HOST1`, `V-HOST2`, and `V-HOST3`. The real
`Test-WdacEnablement` path returned `SUCCESS` on disposable nodelab node
`tsg-wdac-0917` with a real supplemental-policy fixture. The affected pre-2607
binary was not executed, and the retired exception was not forced.

No Code Integrity change was made on deployed members. The disposable node was
destroyed after the test, and independent host residue checks confirmed that
the VM and its differencing disk were absent.

:::

# Related Content

- [Validate solution upgrade readiness for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/upgrade/validate-solution-upgrade-readiness)
- [App Control for Business policy management](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/deployment/appcontrol-deployment-guide)
- [Troubleshooting updates for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/update/update-troubleshooting-23h2)

::: audience-css

# Source Articles

- Azure Local source fix: ASZ-EnvironmentValidator PR 15541474, merged April
  30, 2026.
- Azure DevOps Bug 37710770.
- [Validate solution upgrade readiness for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/upgrade/validate-solution-upgrade-readiness)
- [App Control for Business policy management](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/deployment/appcontrol-deployment-guide)

:::
