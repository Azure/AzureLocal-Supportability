# AzStackHci_Security_AsrRuleGPConflict

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_Security_AsrRuleGPConflict</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-AsrRuleGPConflict</code> (run with <code>Invoke-AzStackHciSecurityValidation</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Security (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Informational</strong>: the status is always SUCCESS. A Group Policy-managed ASR rule reports a <strong>WARNING</strong> (the actionable signal), not an outage.</td>
  </tr>
</table>

> **At a glance**
> - **What it is:** an Environment Validator (Environment Checker) security check that reports whether Windows Defender **Attack Surface Reduction (ASR)** rules are also managed by **Group Policy** on a node.
> - **Why it matters:** on Azure Local the Defender settings (including ASR) are meant to be governed by the platform's **OSConfig security baseline**. An ASR rule set through Group Policy **overrides** the OSConfig-managed Defender configuration, and that conflict can cause a **Solution Update to fail**.
> - **Owner:** operator configuration. This is not an Azure Local software defect; the fix is to remove the ASR settings from Group Policy so the OSConfig baseline applies.
> - **Lab versus production scope:** the validated lab evidence uses a reversible local GPO and reports `SOMID=Local`. That proves the RSoP detection and restore path, not production ownership. Production findings commonly report a domain or organizational-unit scope and require the Active Directory or Group Policy owner.
> - **Read the Detail and Severity, not the Status:** this validator is informational and always reports a SUCCESS status. The actionable state is a **WARNING** severity with a **Detail** that lists the Group Policy-managed ASR rules and their scopes. See the detection note below.

## Overview

Azure Local applies its Microsoft Defender Antivirus configuration (including Attack Surface Reduction rules) through the platform **OSConfig security baseline**. This check looks for ASR rules that are **also** configured by Group Policy. When both configure ASR, Group Policy wins, so the OSConfig-managed Defender document no longer reflects the effective state, and a Solution Update that expects the OSConfig baseline can fail.

The check inspects the node's **Resultant Set of Policy (RSoP)** for any of the known ASR rule GUIDs applied under the ASR policy registry key, and reports each rule it finds together with the **scope** that applied it (the Group Policy scope of management, such as an Active Directory organizational unit, or `Local` for a local group policy).

- **Severity:** Informational status. The check does not fail with an error status; it reports posture. A node needs attention when the severity is **WARNING**. See the detection note.
- **When it runs:** the Environment Checker runs this check as part of the **Security** readiness checks, during **pre-deployment readiness** and during the **pre-update health check**. Because the conflict specifically risks a Solution Update failure, you will most often see it surface in a pre-update readiness run.
- **RSoP and network dependency:** RSoP reflects Group Policy processing. For a domain scope, stale or empty RSoP can mean that the node cannot reach a domain controller or its secure channel is unhealthy. Do not treat missing rows as clean until that dependency is checked.
- **Read the Detail and Severity, not the Status (IMPORTANT).** This validator always reports a SUCCESS status, so a filter that looks for a non-success status finds nothing. A node needs attention when its **Detail** reads `Group Policy-managed ASR settings were found` (severity WARNING). The steps below read the Detail.
- **Who owns the fix.** Whoever manages the Group Policy that configures ASR (a domain administrator for a domain GPO, or the node's local administrator for a local group policy). The operator's role is to remove the ASR configuration from Group Policy so the OSConfig-managed Defender baseline applies, then re-run the readiness check.

## Requirements

- Administrative (local administrator) access to each Azure Local node.
- Access to view and edit the Group Policy that configures ASR: the Group Policy Management Console (GPMC) and rights on the reported scope for a **domain** GPO, or `gpedit.msc` on the node for a **local** group policy.
- Familiarity with your Azure Local security baseline (the OSConfig-managed Defender configuration). See the [manage the security baseline](https://learn.microsoft.com/azure/azure-local/manage/manage-secure-baseline) guidance.

### Safety and ownership gate

Complete the read-only evidence steps and identify the reported `SOMID` before changing any policy:

1. **Domain or organizational-unit scope:** stop at the node. The Active Directory or Group Policy owner must approve and make the change through the normal directory change process. Do not edit or unlink a shared domain GPO from the Azure Local node.
2. **Local scope (`SOMID=Local`):** a local administrator may use `gpedit.msc`, but first confirm that no domain GPO also configures the same ASR rule and that the local policy is the intended owner. This is the scope used by the reversible lab evidence, not a production recommendation to move policy into local GPO.
3. **RSoP error, stale output, or no domain-controller connectivity:** do not interpret zero rows as proof of a clean node. Preserve the error and evidence, then resolve the Group Policy or secure-channel issue or escalate it.
4. **Workload review:** clearing the conflicting setting does not drain the cluster, restart a node, or stop a running VM. It can change the effective Defender ASR action when the OSConfig baseline takes over, so notify affected application and workload owners before applying a shared policy change.

The normal effort is one local-policy refresh and recheck for a local scope, or a directory change request, rollout, and per-node verification for a shared domain GPO. A reader who does not own the reported policy should collect the evidence below and hand it to the directory owner rather than making an unapproved change.

## Troubleshooting Steps

### 1. Confirm the failure and see where it appears

Because this check always reports a SUCCESS status, confirm it by reading the result **Detail** and **Severity**, not the status. Read the newest health-check result file and flag any node whose Detail reports Group Policy-managed ASR settings:

```powershell
$base = 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System'
if (-not (Test-Path $base)) {
    $base = Get-ChildItem 'C:\ClusterStorage' -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'Shares\SU1_Infrastructure_1\Updates\HealthCheck\System' } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}
$latest = $null
if ($base) {
    $latest = Get-ChildItem $base -Filter 'HealthCheckResult.EnvironmentChecker.*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $latest) {
    Write-Warning "No HealthCheck result on this node; use the RSoP query below or read the AzStackHciEnvironmentChecker event log (Event ID 17205)."
}
else {
    Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object { $_.Name -like '*AsrRuleGPConflict*' } |
        ForEach-Object {
            $d = $_.AdditionalData.Detail
            [pscustomobject]@{
                NeedsAttention = ($d -match 'Group Policy-managed ASR settings were found')
                Detail = $d
            }
        }
}
```

The same record is on the Windows event log as Event ID 17205 in `AzStackHciEnvironmentChecker` (read `AdditionalData.Detail` the same way), and in the Azure portal on the cluster's **Updates** tab when a pre-update health check reports a warning.

**The Environment Checker also writes its own log and report on the node that ran the check.** By default these are under the running account's `%USERPROFILE%\.AzStackHci\` folder: the text log `AzStackHciEnvironmentChecker.log` and the machine-readable `AzStackHciEnvironmentReport.json` (and `.xml`). The actionable ASR entry keeps `AdditionalData.Status = SUCCESS`, has numeric top-level `Severity = WARNING`, and carries the specific scope and rule details in `AdditionalData.Detail`. These files are local to the node that executed the check; the cluster-wide result file and Event ID 17205 are the consolidated views.

The following surfaces do not independently emit this validator result:

- **Cluster logs:** not evident in the cluster logs; this is not a failover-cluster event.
- **Failover Cluster Manager:** not evident in Failover Cluster Manager; this is not a clustered role, resource, or node property.
- **Windows Admin Center (standalone host):** not evident in Windows Admin Center on a standalone host for this check.
- **Windows Admin Center in Azure:** not evident in Windows Admin Center in Azure for this check.

**Read the exact surface the check reads (immediate, on-node).** The check inspects the node's RSoP for ASR rules applied under the ASR policy key. Query it directly to see each Group Policy-managed ASR rule and the scope that applied it:

```powershell
$asrKey = 'Software\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules'
Get-CimInstance -Namespace 'root\rsop\computer' -ClassName 'RSOP_RegistryPolicySetting' -ErrorAction Stop |
    Where-Object { $_.RegistryKey -eq $asrKey } |
    Select-Object ValueName, SOMID
```

> **Why this query does not use `-Filter`.** A WQL filter treats the backslash as an escape character, so passing the registry path into `-Filter` is rejected by the CIM provider with `Invalid query`. Paired with `-ErrorAction SilentlyContinue`, that error is swallowed and the query returns no rows, which is indistinguishable from a clean node. Retrieving the class and matching `RegistryKey` in PowerShell avoids the escaping problem, and `-ErrorAction Stop` makes a genuine RSoP failure visible instead of silent.

Each `ValueName` is an ASR rule GUID and each `SOMID` is the Group Policy scope that applied it (an Active Directory distinguished name for a domain GPO, or `Local` for a local group policy). No rows means no Group Policy-managed ASR on that node.

### 2. What it looks like: example failure signatures

The Detail is a single composite line. A healthy node reads:

```
No Group Policy-managed ASR settings were found.
```

A node that needs attention reads (severity WARNING), listing each rule and its scope:

```
Group Policy-managed ASR settings were found. These settings can override OSConfig DefenderAV settings. Configured entries: ASRBlockOfficeApplicationsFromCreatingChildProcesses (d4f940ab-401b-4efc-aadc-ad5f3c50688a) Scope(s)=[OU=Hci001,DC=contoso,DC=com]
```

Multiple rules and scopes are separated by `;`, for example:

```
Group Policy-managed ASR settings were found. These settings can override OSConfig DefenderAV settings. Configured entries: ASRBlockOfficeApplicationsFromCreatingChildProcesses (d4f940ab-401b-4efc-aadc-ad5f3c50688a) Scope(s)=[OU=Hci001,DC=contoso,DC=com]; ASRBlockProcessCreationFromPSExecAndWMICommands (d1e49aac-8f56-4280-b9ba-993a6d77406c) Scope(s)=[Local]
```

What each part means:

- **`Configured entries`** lists each ASR rule GUID (with its friendly name) that Group Policy currently sets.
- **`Scope(s)=[...]`** is where each rule was applied from: an Active Directory distinguished name (a domain or organizational-unit GPO scope), or `Local` for a local group policy on the node. This is the scope you remediate in Step 5.
- If the Detail instead reports that the RSoP query did not complete, resolve the query error (RSoP availability, permissions) and re-evaluate.

**Scope decision example:** `SOMID=Local` follows the local-policy path in Step 5.2 and matches the scope used by the reversible lab evidence. A value such as `OU=Hci001,DC=contoso,DC=com` is a domain scope: stop and give the evidence to the directory owner rather than editing the node's local policy.

### 3. Identify the affected nodes and scopes

Run the RSoP query across every node so you know which nodes carry a Group Policy-managed ASR rule and from which scopes:

```powershell
$asrKey = 'Software\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules'
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    Get-CimInstance -Namespace 'root\rsop\computer' -ClassName 'RSOP_RegistryPolicySetting' -ErrorAction Stop |
        Where-Object { $_.RegistryKey -eq $using:asrKey } |
        Select-Object ValueName, SOMID
} | Sort-Object PSComputerName | Select-Object PSComputerName, ValueName, SOMID
```

Collect the distinct `SOMID` scopes: those are the Group Policy objects (or the local policy) you remove the ASR configuration from in Step 5.

**Resolve a domain scope to the owning Group Policy object.** The `SOMID` is the scope (an organizational-unit or domain distinguished name), not the GPO display name. To find the exact GPO that set the ASR rule at that scope, generate a Resultant Set of Policy report on an affected node and read the winning GPO for the ASR setting:

```powershell
gpresult /scope computer /h C:\rsop.html
```

Open `C:\rsop.html` and, under Computer Configuration, find the Attack Surface Reduction setting; the report lists the **winning GPO** name. Edit that GPO in Step 5. For a `Local` scope there is no domain GPO: the setting is the node's local group policy, edited with `gpedit.msc`.

### Evidence package and escalation

For a handoff to the directory owner or Azure Local support, preserve the following from every affected node:

```powershell
$asrKey = 'Software\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules'
$rsop = @(Get-CimInstance -Namespace 'root\rsop\computer' -ClassName 'RSOP_RegistryPolicySetting' -ErrorAction Stop |
    Where-Object { $_.RegistryKey -eq $asrKey } |
    Select-Object ValueName, SOMID)
$rsop | Export-Csv (Join-Path $env:TEMP 'AsrRuleGPConflict-RSoP.csv') -NoTypeInformation
gpresult /scope computer /h (Join-Path $env:TEMP 'AsrRuleGPConflict-gpresult.html')
Test-ComputerSecureChannel -Verbose
Get-WinEvent -FilterHashtable @{
    LogName = 'AzStackHciEnvironmentChecker'
    Id = 17205
    StartTime = (Get-Date).AddHours(-4)
} -ErrorAction Stop |
    Where-Object { $_.Message -like '*AsrRuleGPConflict*' } |
    Select-Object TimeCreated, ProviderName, Id, Message
```

Escalate to the **Active Directory or Group Policy owner** when the scope is a domain or organizational unit, the GPO is shared, or multiple clusters report the same scope. Resolve one directory-level GPO change through that owner, then verify every affected cluster and node instead of assuming that one change cleared the fleet. Escalate to **Azure Local support** when the corrected RSoP query returns an error despite healthy Group Policy and domain-controller connectivity, or when every node is clean but the validator still reports a WARNING after a fresh `Invoke-SolutionUpdatePrecheck -SystemHealth`. Include the RSoP CSV, `gpresult` report, Event ID 17205 output, the validator Detail and Severity, and the post-change health-check result.

### 4. Consequences if you do not fix this

There is no imminent impact: nodes keep booting and running, and Defender still enforces the effective ASR rules. But because Group Policy overrides the OSConfig-managed Defender configuration, the node is no longer on the Azure Local security baseline for ASR, and a **Solution Update can fail** when it validates or applies the OSConfig Defender document. The finding will keep surfacing in readiness and pre-update health checks until the ASR configuration is removed from Group Policy.

When the setting is removed, OSConfig becomes the managing layer again. If its effective ASR action differs from the previous Group Policy action, application behavior can change, for example a process that was audited can become blocked or a process that was blocked can become allowed. No node reboot, cluster drain, or VM stop is expected from `gpupdate`, but validate representative workloads and coordinate with their owners when the ASR policy is material to application behavior.

### 5. Remediation

Remove the Attack Surface Reduction configuration from **every Group Policy scope the check reported** so that the Azure Local OSConfig security baseline manages Defender ASR again. Use the scopes from Step 3.

**Most common production fix (start here):** in the great majority of cases the finding comes from a domain Group Policy object that a directory administrator applied to the nodes' organizational unit. Have that directory owner edit the GPO (Step 5.1), set only the ASR policy to **Not Configured**, then run `gpupdate /force /target:computer` on each node (Step 5.3). This is a configuration change only: it does **not** restart nodes or bounce running VMs, but it can change effective ASR behavior as described above.

1. **For a domain scope (a `SOMID` that is an Active Directory distinguished name, for example `OU=Hci001,DC=contoso,DC=com`):** in the Group Policy Management Console, edit the Group Policy object linked at that scope (the GPO name from the `gpresult` report in Step 3) and clear the ASR configuration at:

   `Computer Configuration > Policies > Administrative Templates > Windows Components > Microsoft Defender Antivirus > Microsoft Defender Exploit Guard > Attack Surface Reduction > Configure Attack Surface Reduction rules`

   Set it to **Not Configured** or remove only the specific ASR rule entries. Do not unlink a shared GPO as an operator shortcut: unlinking changes every setting in that GPO for every linked computer. If the GPO exists only to set ASR on these nodes, the directory owner may choose to unlink it through the normal change process after reviewing its full contents. Coordinate with the Active Directory or Group Policy owner before changing any domain GPO.

2. **For a local scope (`SOMID` is `Local`):** this is the scope used by the reversible lab evidence. After confirming that no domain GPO also owns the rule, a local administrator on the affected node can open `gpedit.msc` and set the same policy to **Not Configured**:

   `Computer Configuration > Administrative Templates > Windows Components > Microsoft Defender Antivirus > Microsoft Defender Exploit Guard > Attack Surface Reduction > Configure Attack Surface Reduction rules`

3. **Apply the change on each affected node and let it re-evaluate:**

   ```powershell
   gpupdate /force /target:computer
   ```

   Re-run the RSoP query from Step 1 and confirm it returns no rows under the ASR key.

Let the Azure Local security baseline (OSConfig) manage Defender ASR rather than configuring ASR through Group Policy on these nodes. See [Manage the Azure Local security baseline](https://learn.microsoft.com/azure/azure-local/manage/manage-secure-baseline) and the [Azure Local security features overview](https://learn.microsoft.com/azure/azure-local/concepts/security-features) for how the baseline governs Defender and Attack Surface Reduction.

> **Note:** the Remediation link that this check prints (`aka.ms/azurelocalsecuritydefenderpolicyTSG`) does not currently resolve to a document. Use the guidance in this TSG and the security-baseline links above.

The read-only evidence steps are [LOW RISK]. Removing an ASR rule from a shared Group Policy is a [MEDIUM RISK] configuration change because the effective Defender behavior may change, even though it does not restart nodes, drain the cluster, or stop running VMs. Coordinate with whoever owns the reported GPO, confirm the OSConfig security baseline is the intended source of the Defender configuration, and validate representative workloads after the change.

### 6. Verification: prove the failure cleared

On each remediated node, confirm the RSoP no longer carries a Group Policy-managed ASR rule:

```powershell
$asrKey = 'Software\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules'
$rows = @(Get-CimInstance -Namespace 'root\rsop\computer' -ClassName 'RSOP_RegistryPolicySetting' -ErrorAction Stop |
    Where-Object { $_.RegistryKey -eq $asrKey })
if (-not $rows) { 'Clean: no Group Policy-managed ASR rules' } else { $rows | Select-Object ValueName, SOMID }
```

Then re-run the pre-update health check so the validator re-evaluates cluster-wide, and confirm the health state:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

Confirm `HealthState` is `Success` with a current `HealthCheckDate`, then re-read the Detail (Step 1). A healthy node reports `No Group Policy-managed ASR settings were found.`

> **Note:** the Azure portal readiness view and the cluster-wide health-check result refresh only when a full health check or `Invoke-SolutionUpdatePrecheck -SystemHealth` runs, not on a targeted per-node re-test. If the corrected RSoP query is clean but the validator remains WARNING after that fresh precheck, do not close the issue; use the evidence package and escalation path above.

## Glossary

- **ASR (Attack Surface Reduction):** a set of Microsoft Defender rules (each identified by a GUID) that block or audit common attack behaviors, such as Office applications spawning child processes.
- **OSConfig security baseline:** the Azure Local platform's managed security configuration, including the Defender settings, applied and maintained by the platform. On Azure Local this is the intended source of the Defender/ASR configuration. See [Manage the Azure Local security baseline](https://learn.microsoft.com/azure/azure-local/manage/manage-secure-baseline).
- **Group Policy conflict:** when ASR is configured by both Group Policy and the OSConfig baseline, Group Policy wins, so the effective state no longer matches the OSConfig-managed configuration. That mismatch is what this check reports.
- **RSoP (Resultant Set of Policy):** the computed result of all Group Policy applied to a node. This check reads RSoP (WMI namespace `root\rsop\computer`) to see which ASR rules Group Policy set and from where.
- **Scope / SOM (scope of management):** where a Group Policy setting was applied from, reported as an Active Directory distinguished name (a domain or organizational-unit GPO) or `Local` for a local group policy on the node.
