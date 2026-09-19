---
ArticleType: "TSG"
Article_ID: "20260917170003"
Title: "MSI does not have access to subscription"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-18"
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Hyperconverged", "Disaggregated", "Multi-Rack", "Disconnected", "Microsoft 365 Local"]
  OEM: ["All"]
  OS: ["23H2", "24H2"]
  SolutionMinorBuild: []
  ExtensionName: ""
  ExtensionVersion: []
Component: "Environment Validator"
Engineering_ID:
  Source: ""
  ID: 0
Tags: ["Solution Update", "Validation", "Diagnostics"]
---
[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
| --- | --- | --- |
| 2026-09-18 | 2.1 | Made RBAC remediation consume the per-role detection results and recheck each missing assignment before creation. |
| 2026-09-17 | 2.0 | Replaced the stale Az.Accounts pin and speculative role assignment with current-source branches, current-recipe remediation, scoped RBAC verification, and read-only validation evidence. |

:::

# MSI does not have access to subscription

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>MSI does not have access to subscription</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">ArticleType</th>
    <td><code>TSG</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Audience</th>
    <td><code>['Engineering', 'CSS', 'OEM Partners', 'External']</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">AppliesTo.Product</th>
    <td><code>Azure Local</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">AppliesTo.OEM</th>
    <td><code>['All']</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-AzStackHciArcIntegration</code>, which calls <code>Invoke-AzStackHciArcIntegrationValidation</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Environment Validator, ArcIntegration, Azure managed identity, and Azure RBAC</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>: the affected deployment, upgrade, or pre-update readiness operation is blocked.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>Azure Local deployment or update owner, with an Azure subscription Owner or User Access Administrator for an approved RBAC repair.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>The lifecycle operation cannot continue. Read-only diagnosis has no workload impact. Module reconciliation or RBAC changes require approval and must target only the affected node and registration resource group.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Allow 15 to 30 minutes for read-only classification. Add approval time for an Azure RBAC change or a maintenance window for product-owned module reconciliation.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validation boundary</th>
    <td>Validated at L1 with current source, installed module source, three-node module inventory, Arc identity reads, and Azure role-assignment reads. The token-authentication exception branch was also exercised at L2 with a process-local command shadow. No Azure, RBAC, MSI, registration, module, reservation, or deployed-member state was changed.</td>
  </tr>
</table>

> **Decision summary**
>
> 1. **[LOW RISK]** Confirm the exact exception and current operation.
> 2. **[LOW RISK]** Run the current Validated Recipe module check. If it fails, follow the module branch. If it succeeds, do not change Az.Accounts.
> 3. **[LOW RISK]** Resolve each Arc machine's system-assigned identity and list its role assignments at the registration resource-group scope.
> 4. **[HIGH RISK]** Change only the failed branch. Use `Remediate-PSModules` for confirmed current-recipe drift. Add only a confirmed missing RBAC role, through an authorized owner.
> 5. **[LOW RISK]** Re-run the same evidence and then refresh the lifecycle validation.

## Overview

The message `The provided account MSI@<port> does not have access to subscription`
is an authentication or authorization exception raised while ArcIntegration connects
to Azure. It is not a named validator result and it does not prove that Az.Accounts is
wrong.

Current ArcIntegration source has two credential branches:

- The `DefaultSet` branch gets an ARM access token from the registration token
  cache and passes the cache username as `AccountId`.
- The other branch signs in with the configured registration service principal,
  gets an ARM access token, and passes the service-principal application ID as
  `AccountId`.

`Invoke-AzStackHciArcIntegrationValidation` then calls `Connect-AzAccount` with
the supplied ARM token, account ID, tenant, environment, and subscription. The
`MSI@<port>` text is an account label from that authentication path. It is not an
Azure object ID and must not be pasted into an RBAC command.

Two conditions can produce a similar lifecycle exception:

1. The build's PowerShell module set is outside its current Validated Recipe, or a
   stale incompatible module is already loaded in the PowerShell process.
2. The system-assigned managed identity of one or more Arc machine resources lacks
   required access at the Azure Local registration resource-group scope.

Classify the branch before changing anything.

## Symptoms

During deployment, upgrade, or pre-update readiness, ArcIntegration raises an
exception similar to:

```text
The provided account MSI@<port> does not have access to subscription ID
"<subscription-id>". Please try logging in with different credentials or a
different subscription ID.
```

Pre-update can surface a generic result:

```text
Name        : Environment Validator Exception
DisplayName : Environment Validator Exception - Test-AzStackHciArcIntegration
Status      : ERROR
Severity    : CRITICAL
```

Deployment or upgrade can name the wrapper action:

```text
Type 'ValidateArcIntegration' of Role 'EnvironmentValidator' raised an exception
```

The generic exception is a container for the underlying error. Preserve its
timestamp, operation, complete error text, and stack before retrying.

## Before you start

- Run node commands from a new elevated Windows PowerShell session.
- Run Azure CLI commands from an authenticated administrator workstation that can
  read the affected subscription.
- Use the Arc machine resource ID reported by `azcmagent`. Do not guess a resource
  group or managed-identity object ID from a machine name.
- An Azure RBAC repair requires an authorized **Owner** or **User Access
  Administrator**. The operator running diagnostics might not have that permission.
- Do not run `Register-AzStackHCI`, `Unregister-AzStackHCI`, remove the Arc machine,
  disable its identity, or delete the Arc Resource Bridge.
- Do not install or downgrade Az.Accounts to `4.0.2`, `5.3.0`, or any other
  historical value copied from an incident. The supported recipe changes with the
  Azure Local build.

## Where this failure appears

| Administrator surface | What to expect |
| --- | --- |
| PowerShell on an Azure Local node | The lifecycle exception, current module inventory, `azcmagent show`, and the current Validated Recipe result provide the actionable evidence. |
| Azure portal | Deployment validation or the Azure Local cluster's Updates view can show `Environment Validator Exception - Test-AzStackHciArcIntegration`. Portal data can lag until the next full validation. |
| Windows event logs | Event ID `17205` in `AzStackHciEnvironmentChecker` can preserve a serialized Environment Validator result. The original exception can instead be present only in the action-plan progress or deployment logs. |
| Cluster logs (`Get-ClusterLog`) | This Azure authentication and authorization exception does not normally appear in cluster logs. It is not a quorum, storage, or failover-cluster event. |
| Failover Cluster Manager | The exception does not appear as a clustered role, resource, or node state. |
| Windows Admin Center, standalone | The exact ArcIntegration exception and RBAC scope are not normally evident here. |
| Windows Admin Center in Azure | The exact ArcIntegration exception and RBAC scope are not normally evident here. Use the Azure Local lifecycle result and Azure IAM evidence. |
| Component or tool log files | Preserve `C:\CloudDeployment\Logs`, `$env:LocalRootFolderPath\MASLogs\AzStackHciEnvironmentChecker*`, and the running account's `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` and `AzStackHciEnvironmentReport.json` or `.xml`, when present. |

## Diagnosis

### 1. Preserve the exception and operation

For pre-update, read the current failed health-check results:

```powershell
Get-SolutionUpdateEnvironment |
    Select-Object -ExpandProperty HealthCheckResult |
    Where-Object {
        $_.Status -ne 'Success' -or
        $_.DisplayName -like '*Test-AzStackHciArcIntegration*'
    } |
    Select-Object Name, DisplayName, Status, Severity, Remediation,
        @{n='Detail';e={$_.AdditionalData.Detail}},
        Timestamp
```

Also preserve ArcIntegration progress entries when they exist:

```powershell
Get-AzStackHciEnvironmentCheckerProgress |
    Where-Object {
        $_.Command -eq 'Test-AzStackHciArcIntegration' -or
        $_.ExecutionDetail -like '*MSI@*does not have access to subscription*'
    } |
    Select-Object Command, Result, StartTime, EndTime, ExecutionDetail
```

If these commands return no current record, treat that as a data gap. Use the
deployment or upgrade action-plan error and logs instead.

### 2. Rule out current-recipe module drift

Run the current Validated Recipe check on every affected node:

```powershell
$moduleResult = @(
    Invoke-AzStackHciValidatedRecipeValidation `
        -Include Test-PSModules `
        -PassThru
)

$moduleResult |
    Where-Object {
        $_.Name -eq 'AzStackHci_ValidatedRecipe_PowerShellModule_Version'
    } |
    Select-Object Name, Status, Severity,
        @{n='Detail';e={$_.AdditionalData.Detail}}
```

Interpret the result:

- `SUCCESS`: do not install, uninstall, or downgrade Az.Accounts. Continue to the
  RBAC branch.
- `FAILURE` with module-specific detail: follow
  [AzStackHci_ValidatedRecipe_PowerShellModule_Version](Troubleshooting-Test-PowerShell-Module-Version.md).
- `FAILURE` without actionable detail: preserve the full object and escalate. Do
  not select a version manually.

For secondary inventory only:

```powershell
Get-Module -Name Az.Accounts -ListAvailable |
    Sort-Object Version, ModuleBase |
    Select-Object Name, Version, ModuleBase, Path

Get-InstalledModule -Name Az.Accounts -AllVersions -ErrorAction SilentlyContinue |
    Select-Object Name, Version, Repository, InstalledLocation
```

`Get-Module -ListAvailable` and `Get-InstalledModule` answer different questions.
Neither overrides a current passing recipe result.

### 3. Resolve each node identity and required scope

Run this read-only command on every affected node:

```powershell
$arc = azcmagent show -j | ConvertFrom-Json

[pscustomobject]@{
    Node           = $env:COMPUTERNAME
    ArcStatus      = $arc.status
    ResourceId     = $arc.resourceId
    SubscriptionId = $arc.subscriptionId
    ResourceGroup  = $arc.resourceGroup
    TenantId       = $arc.tenantId
}
```

Require `ArcStatus` to be `Connected`. If the node is disconnected or
`azcmagent` cannot return a resource ID, stop and investigate Arc connectivity or
registration. Do not repair RBAC against a guessed identity.

The required scope for this issue is the registration resource group in the
returned resource ID:

```text
/subscriptions/<subscription-id>/resourceGroups/<registration-resource-group>
```

### 4. List the current RBAC assignments

Run the following from an Azure-authenticated administrator workstation. It uses
ARM directly so it does not need Microsoft Graph to resolve the service principal:

```powershell
$ErrorActionPreference = 'Stop'

function Invoke-AzJsonOrThrow {
    param(
        [Parameter(Mandatory)]
        [string[]] $Arguments,

        [Parameter(Mandatory)]
        [string] $Operation
    )

    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $stdout = @(& az @Arguments --only-show-errors 2> $stderrPath)
        $exitCode = $LASTEXITCODE
        $stderr = Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
        if ($exitCode -ne 0) {
            throw "$Operation failed with exit code $exitCode. Azure CLI error: $stderr"
        }
        if (-not ($stdout -join '').Trim()) {
            throw "$Operation returned no JSON output."
        }
        return (($stdout -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop)
    }
    finally {
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

$machineResourceId = '<resource-id-from-azcmagent>'
$machine = Invoke-AzJsonOrThrow `
    -Arguments @('resource', 'show', '--ids', $machineResourceId, '--output', 'json') `
    -Operation 'Arc machine lookup'

$principalId = $machine.identity.principalId
$subscriptionId = ($machine.id -split '/')[2]
$resourceGroup = $machine.resourceGroup
$scope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"

$url = "https://management.azure.com/subscriptions/$subscriptionId/providers/" +
    "Microsoft.Authorization/roleAssignments" +
    "?api-version=2022-04-01&`$filter=principalId%20eq%20'$principalId'"

$assignments = (
    Invoke-AzJsonOrThrow `
        -Arguments @('rest', '--method', 'get', '--url', $url, '--output', 'json') `
        -Operation 'Role-assignment lookup'
).value

if (-not $principalId -or -not $machine.id -or -not $machine.resourceGroup) {
    throw 'The Arc machine response did not include the required identity and scope fields.'
}

$requiredRoles = [ordered]@{
    '865ae368-6a45-4bd1-8fbf-0d5151f56fc1' =
        'Azure Stack HCI Device Management Role'
    'c99c945f-8bd1-4fb1-a903-01460aae6068' =
        'Azure Stack HCI Connected InfraVMs'
}

$roleResults = @(
    $requiredRoles.GetEnumerator() | ForEach-Object {
        $roleId = $_.Key
        $roleName = $_.Value
        $match = @(
            $assignments |
                Where-Object {
                    $_.properties.scope -ieq $scope -and
                    $_.properties.roleDefinitionId -like "*/$roleId"
                }
        )

        [pscustomobject]@{
            Node = $machine.name
            PrincipalId = $principalId
            Scope = $scope
            Role = $roleName
            RoleDefinitionId = $roleId
            Present = $match.Count -gt 0
            AssignmentId = @($match.id)
        }
    }
)

$roleResults
```

Run it for every Arc machine resource in the cluster. A role present on one node
does not prove it is present for the other node identities.

## Mitigation

### Branch A: current Validated Recipe reports module drift

**[HIGH RISK]** Coordinate the lifecycle owner and confirm that no deployment,
solution update, CAU run, Environment Validator run, or unrelated PowerShell
session is using the affected modules.

Use the product-owned reconciliation path:

```powershell
$ErrorActionPreference = 'Stop'
Get-Command Remediate-PSModules -ErrorAction Stop | Out-Null
Remediate-PSModules
```

Do not replace this command with a blanket `Uninstall-Module` loop or a historical
`Install-Module -RequiredVersion` value. If `Remediate-PSModules` is unavailable
or fails, preserve the complete output and escalate.

### Branch B: a required role is missing

**[HIGH RISK]** Adding an Azure role assignment changes authorization. An
authorized subscription Owner or User Access Administrator must approve and
perform the change. Add only the role shown as missing, to the exact Arc machine
principal, at the exact registration resource-group scope.

Portal path:

1. Open the registration resource group returned by `azcmagent show`.
2. Select **Access control (IAM)**, then **Add role assignment**.
3. Select the missing role:
   - **Azure Stack HCI Device Management Role**
   - **Azure Stack HCI Connected InfraVMs**
4. Select **Managed identity**.
5. Select the **Azure Arc machine** resource for the affected node.
6. Review the principal and resource-group scope, then assign.
7. Repeat only for another node whose read-only check reports the same role missing.

Azure CLI equivalent:

```powershell
# Reuse $principalId, $scope, $url, $requiredRoles, and $roleResults from
# the read-only check for one affected Arc machine.
$ErrorActionPreference = 'Stop'

$detectedRoleIds = @(
    $roleResults.RoleDefinitionId |
        Sort-Object -Unique
)

if (
    @($roleResults).Count -ne $requiredRoles.Count -or
    $detectedRoleIds.Count -ne $requiredRoles.Count
) {
    throw 'Role detection is incomplete. Re-run the read-only RBAC check.'
}

$invalidResults = @(
    $roleResults |
        Where-Object {
            -not $requiredRoles.Contains($_.RoleDefinitionId) -or
            $_.PrincipalId -ne $principalId -or
            $_.Scope -ine $scope
        }
)

if ($invalidResults.Count -gt 0) {
    throw 'Role detection does not match the approved principal and scope.'
}

$missingRoles = @($roleResults | Where-Object { $_.Present -eq $false })

if ($missingRoles.Count -eq 0) {
    Write-Host 'Both required roles are already present. No RBAC change was made.'
}
else {
    foreach ($missingRole in $missingRoles) {
        $roleId = $missingRole.RoleDefinitionId
        $roleName = $requiredRoles[$roleId]

        # Recheck immediately before changing authorization so reruns are safe.
        $currentAssignments = (
            Invoke-AzJsonOrThrow `
                -Arguments @(
                    'rest', '--method', 'get', '--url', $url, '--output', 'json'
                ) `
                -Operation "Recheck $roleName"
        ).value

        $alreadyPresent = @(
            $currentAssignments |
                Where-Object {
                    $_.properties.scope -ieq $scope -and
                    $_.properties.roleDefinitionId -like "*/$roleId"
                }
        ).Count -gt 0

        if ($alreadyPresent) {
            Write-Host "$roleName is already present. No change was made."
            continue
        }

        $createdAssignment = Invoke-AzJsonOrThrow `
            -Arguments @(
                'role', 'assignment', 'create',
                '--assignee-object-id', $principalId,
                '--assignee-principal-type', 'ServicePrincipal',
                '--role', $roleId,
                '--scope', $scope,
                '--output', 'json'
            ) `
            -Operation "Create $roleName"
        [pscustomobject]@{
            Role = $roleName
            PrincipalId = $createdAssignment.principalId
            Scope = $createdAssignment.scope
            AssignmentId = $createdAssignment.id
        }
    }
}
```

The script creates only roles whose matching detection result is
`Present = False`. It also repeats the read-only ARM check immediately before
each create, so a role added after diagnosis is skipped rather than duplicated.

Do not assign these roles at subscription scope merely to avoid finding the
registration resource group. Do not assign them to the deployment user in place
of the node's Arc machine identity.

## Verify the fix

1. Re-run the current-recipe module check on every affected node. Require
   `AzStackHci_ValidatedRecipe_PowerShellModule_Version` to return `SUCCESS`.
2. Re-run the ARM role-assignment query. Require both roles to be present for each
   affected Arc machine principal at the registration resource-group scope.
3. Confirm `azcmagent show -j` still reports `Connected`.
4. Refresh the applicable lifecycle validation.

For pre-update:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment |
    Format-List HealthState, HealthCheckDate, HealthCheckResult
```

Require `HealthState` to be `Success`, a current `HealthCheckDate`, and no new
`Test-AzStackHciArcIntegration` exception.

For deployment or upgrade, retry the failed operation through the same supported
deployment or upgrade workflow. Do not call the internal wrapper with invented
parameters.

## Rollback and failed remediation

- A module reconciliation failure has no generic manual rollback. Preserve the
  product command's output and stop. Do not delete module directories or force a
  downgrade.
- If this procedure created a role assignment for the wrong principal or scope,
  remove only the exact new assignment ID after approval:

```powershell
az role assignment delete --ids '<new-assignment-resource-id>'
```

- Do not remove a pre-existing role assignment as a troubleshooting experiment.
- If both roles are already present and the current recipe passes, the article's
  two repair branches do not apply. Preserve the authentication exception and
  escalate without repeating either change.

## Validation evidence and limits

This revision was validated on September 17, 2026 against Azure Local 2610 with
Environment Checker `10.2610.0.2039`.

- **L1:** current `ASZ-EnvironmentValidator` main source and the installed module
  both showed the token-cache and registration-service-principal branches. All
  three lab nodes were Up, Arc Connected, and exposed only Az.Accounts `5.5.1`.
  Direct ARM reads showed both required roles on each node identity at the
  registration resource-group scope.
- **L2:** a process-local `Connect-AzAccount` shadow drove the installed
  `Invoke-AzStackHciArcIntegrationValidation` token branch to the documented
  subscription-access exception. The shadow was removed in `finally`, and a fresh
  process confirmed the real `Az.Accounts` cmdlet was restored.
- **Command validation:** every PowerShell block in this article parsed
  successfully. The live diagnostic commands used only read operations.
- **Not performed:** no role was added or removed, no managed identity or
  registration was changed, no module was installed or removed, and no cluster
  member was modified. Therefore this is not an L4 remediation proof.

## Escalation

Escalate to the Environment Validator or ArcIntegration owner when:

- the module check passes and both required roles are present at the correct scope;
- `MSI@<port>` persists after a fresh lifecycle run;
- the Arc machine identity or registration resource group cannot be resolved;
- the tenant or subscription in the exception differs from `azcmagent show`;
- `Remediate-PSModules` is unavailable or fails;
- the role assignment exists but ARM still denies the same action; or
- different nodes use different authentication branches or report different results.

Include:

- operation type and UTC timestamp;
- complete exception and stack;
- Environment Checker and solution versions;
- per-node Az.Accounts inventory and current recipe result;
- per-node `azcmagent` resource ID and connection status;
- managed-identity principal IDs;
- role names, assignment IDs, and scopes;
- current lifecycle result after revalidation.

Do not include ARM access tokens, registration credentials, passwords, or unrelated
customer data.

::: audience-css

# Source Articles

- [Assign required permissions for Azure Local deployment](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-arc-register-server-permissions)
- [Azure built-in roles for Hybrid and multicloud](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/hybrid-multicloud)
- [PowerShell Module Version troubleshooting](Troubleshooting-Test-PowerShell-Module-Version.md)

:::
