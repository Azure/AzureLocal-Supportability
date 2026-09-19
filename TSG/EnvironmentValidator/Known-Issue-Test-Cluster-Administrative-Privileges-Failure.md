---
Article_ID: "20260917141833"
ArticleType: "KI"
Title: "Test-Cluster reports missing administrative privileges during deployment"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
EngineeringStatus: "Fixed"
FixedInBuild:
  OS: ["24H2"]
  SolutionMinorBuild: ["2610"]
  ExtensionName: ""
  ExtensionVersion: []
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Hyperconverged", "Disaggregated", "Multi-Rack"]
  OEM: ["All"]
  OS: ["24H2"]
  SolutionMinorBuild: ["2604"]
  ExtensionName: ""
  ExtensionVersion: []
Component: "Deployment"
Engineering_ID:
  Source: "ONE"
  ID: 37471190
Tags: ["Cloud Deployment", "Seed Node", "Validation"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
|---|---|---|
| 2026-09-17 | 2.0 | Added the confirmed 2610 boundary, fail-closed diagnosis, live command validation, and authoritative article metadata. |

:::

---

# Test-Cluster reports missing administrative privileges during deployment

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width:180px;">ArticleType</th>
    <td><code>KI</code></td>
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
    <th style="text-align:left;">Component</th>
    <td>Environment Validator, <code>Invoke-AzStackHciClusterValidation</code>, <code>Test-ClusterPreReq</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical when reproduced</strong>: deployment validation cannot continue.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable scenarios</th>
    <td>Deployment validation on hosts that are not yet deployed cluster members.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected versions</th>
    <td>Legacy Environment Checker versions that return the first FQDN-based <code>Test-Cluster</code> access error without a successful short-name retry. The earliest fixed release is not established by this article.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Confirmed current boundary</th>
    <td>On September 17, 2026, Azure Local solution <code>12.2610.1004.30</code>, platform <code>12.2610.0.3059</code>, and AzStackHci.EnvironmentChecker <code>10.2610.0.2039</code> did not reproduce the historical top-level failure before the disposable host's first post-join restart. The FQDN-based System Configuration test completed before and after restart. The installed module also contains the retry for all three signatures in this article.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>Deployment is blocked. This article does not authorize rebooting a deployed cluster member or interrupting running workloads.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Allow 10-20 minutes for evidence collection and version classification. A confirmed legacy pre-deployment host reboot usually adds 5-10 minutes per host.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The Azure Local deployment administrator owns diagnosis and the pre-deployment reboot. Route persistent 2610-or-later failures to Microsoft Support. This is not a switch, firmware, or hardware-replacement procedure.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Risk summary</th>
    <td><strong>[LOW RISK]</strong> collect evidence and run validation probes. <strong>[MEDIUM RISK]</strong> reboot only a confirmed pre-deployment host with no workloads. <strong>[HIGH RISK]</strong> stop if the target is already a deployed cluster member.</td>
  </tr>
</table>

**Decision summary**

Do not reboot a node solely because the error contains `Access is denied` or
`administrative privileges`.

1. **[LOW RISK]** Capture the solution, platform, and Environment Checker
   versions before changing anything.
2. **[LOW RISK]** Confirm the exact Environment Checker result and test both the
   fully qualified and short node names.
3. On the confirmed 2610 boundary above, the historical top-level error did not
   reproduce before restart. The validator also retries the three historical
   errors with short names when they occur. If the current result succeeds, or
   reports specific validation subtests instead of `Failed to execute
   Test-Cluster`, stop using this article and follow the reported subtest.
4. Use the legacy reboot path only when all of these are true:
   - the target is a pre-deployment host, not a deployed cluster member;
   - it has no running workloads;
   - the failure occurred after domain join and before that host's first reboot;
   - the short-name retry is absent or still fails for the same authentication
     reason;
   - DNS, WinRM, and the domain secure channel do not identify another cause.
5. If the same error persists on 2610 or later, preserve the evidence and
   escalate. Do not assume the old reboot defect.

# Symptoms

The deployment validation result
`AzStackHci_Cluster_Test-Cluster_Results` contains one of these messages:

```text
Failed to execute Test-Cluster: You do not have administrative privileges on the server <NodeName>
```

```text
Failed to execute Test-Cluster: Access is denied
```

```text
Failed to execute Test-Cluster: An error occurred opening cluster <NodeName>
```

These strings are not diagnostic by themselves. DNS registration, WinRM,
TrustedHosts, firewall rules, an unavailable node, or credentials can produce
overlapping symptoms. Use the checks below before choosing a remediation.

**Current product behavior**

On an affected legacy deployment path, a host could reach cluster validation
after joining Active Directory but before completing its required restart. The
first `Test-Cluster` call used fully qualified node names and could fail during
authentication.

Current product code treats all three messages above as a retryable name or
authentication path during deployment. It retries `Test-Cluster` with each
node's short name. On the confirmed 2610 build, the direct FQDN System
Configuration test completed even before the disposable node's first
post-domain-join restart, so the retry was not needed for that probe.

The current full validator can still report individual failed subtests for a
different reason. That is not the same as the historical top-level
`Failed to execute Test-Cluster` exception. Follow the named subtest and its
detail instead of applying this reboot procedure.

**Terms**

- **FQDN** is a fully qualified domain name, such as
  `node01.contoso.com`.
- **Short name** or **NetBIOS name** is the host name without its DNS suffix,
  such as `node01`.
- **Domain secure channel** is the authenticated relationship between a
  domain-joined computer and Active Directory.
- **Pre-deployment host** is a server being prepared for Azure Local that is not
  yet a member of a deployed failover cluster and carries no customer workload.

**Before you start**

1. Open an elevated Windows PowerShell session on the deployment management
   system or another host that can reach every candidate node.
2. Confirm the target is still a pre-deployment host:

   ```powershell
   Get-ClusterNode -Name '<FailingNodeName>' -ErrorAction SilentlyContinue
   ```

   Continue only when this returns no deployed cluster-node object and the
   deployment owner confirms the server carries no virtual machines or
   workloads.
3. If the command returns a cluster node, stop. This article does not authorize
   a drain or reboot of a deployed member. Use the cluster's approved
   maintenance procedure or contact Microsoft Support.
4. Record the UTC failure time and preserve the evidence before any restart.
   A restart removes the pre-restart authentication state.

**Where this failure appears**

| Admin surface | What to expect |
|---|---|
| PowerShell on an Azure Local host | **Shown**: the Environment Checker result, direct `Test-Cluster` comparison, DNS, WinRM, and secure-channel probes below identify the active branch. |
| Azure portal | **Shown** when the deployment validation operation reports the `Test-Cluster` result. The portal error alone does not prove the legacy reboot scenario. |
| Windows event logs | **Shown when persisted**: the `AzStackHciEnvironmentChecker` log can contain Event ID 17205 with the serialized result. |
| Cluster logs from `Get-ClusterLog` | This pre-deployment validator exception is **not evident in cluster logs** as a cluster membership, quorum, storage, or resource failure. |
| Windows Failover Cluster Manager | A host that is not yet deployed is **not evident in Failover Cluster Manager** as a cluster node or failed resource. |
| Windows Admin Center on a standalone host | The exact Environment Checker retry is **not evident in Windows Admin Center on a standalone host**. Use the PowerShell evidence. |
| Windows Admin Center in the Azure portal | The exact retry branch is **not evident in Windows Admin Center in the Azure portal**. Use the deployment operation for correlation and PowerShell for diagnosis. |
| Component or tool log files on disk | **Shown when written**: preserve `C:\CloudDeployment\Logs`, `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log`, `AzStackHciEnvironmentReport.json` or `.xml`, and the named `Test-Cluster` report under `C:\Windows\Cluster\Reports`. |

# Issue Validation

To confirm that the deployment is encountering this known issue, first verify
the exact failure family, then run the version and node-state probes below.

## Errors or Failures

The exact historical blocker is a top-level `Failed to execute Test-Cluster`
exception containing one of the three strings in [Symptoms](#symptoms). A
result that instead lists named `[!!Failed!!]` validation subtests is a
different failure shape and must be diagnosed from those subtests.

## PowerShell Detection Script

**Step 1: Capture the version boundary**

Run on a deployed node that carries the Environment Checker module. This is
read-only.

```powershell
$stamp = Get-StampInformation
$module = Get-Module -ListAvailable AzStackHci.EnvironmentChecker |
    Sort-Object Version -Descending |
    Select-Object -First 1

[pscustomobject]@{
    StampVersion = [string]$stamp.StampVersion
    PlatformVersion = [string]$stamp.PlatformVersion
    ServicesVersion = [string]$stamp.ServicesVersion
    EnvironmentCheckerVersion = [string]$module.Version
    EnvironmentCheckerModuleBase = [string]$module.ModuleBase
} | Format-List
```

If the Environment Checker version is `10.2610.0.2039` or later, do not assume
the historical defect. Continue through the current validator check.

**Step 2: Read the newest Environment Checker result**

```powershell
$name = 'AzStackHci_Cluster_Test-Cluster_Results'

$eventResult = Get-WinEvent -LogName AzStackHciEnvironmentChecker `
    -FilterXPath '*[System[(EventID=17205)]]' `
    -MaxEvents 2000 `
    -ErrorAction SilentlyContinue |
    ForEach-Object {
        try {
            $result = $_.Message | ConvertFrom-Json -ErrorAction Stop
            if ($result.Name -eq $name) {
                [pscustomobject]@{
                    TimeCreated = $_.TimeCreated
                    Name = [string]$result.Name
                    Status = [string]$result.AdditionalData.Status
                    Detail = [string]$result.AdditionalData.Detail
                    Remediation = [string]$result.Remediation
                }
            }
        }
        catch {
        }
    } |
    Sort-Object TimeCreated -Descending |
    Select-Object -First 1

if ($eventResult) {
    $eventResult | Format-List
}
else {
    Write-Warning 'No matching Event ID 17205 result was found. Use the deployment operation and component logs.'
}
```

Read `AdditionalData.Status` and `AdditionalData.Detail`. The top-level serialized
status is numeric and is not the human-readable result.

**Step 3: Compare the FQDN and short-name paths**

Replace the node list and domain. This command writes `Test-Cluster` diagnostic
reports but does not change node or cluster configuration.

```powershell
$nodes = @('<Node1>', '<Node2>')
$domainFqdn = '<domain.fqdn>'
$include = 'System Configuration'
$evidence = foreach ($node in $nodes) {
    $fqdn = "$node.$domainFqdn"
    foreach ($target in @($fqdn, $node)) {
        $started = Get-Date
        try {
            Test-Cluster -Node $target `
                -Include $include `
                -ReportName "AdminPrivilege-$node-$($target -eq $node)-$($started.ToString('yyyyMMddHHmmss'))" `
                -ErrorAction Stop | Out-Null
            $status = 'SUCCESS'
            $errorText = $null
        }
        catch {
            $status = 'FAILURE'
            $errorText = $_.Exception.Message
        }

        [pscustomobject]@{
            Node = $node
            Target = $target
            NameForm = if ($target -eq $node) { 'Short' } else { 'FQDN' }
            Status = $status
            Error = $errorText
            ObservedAtUtc = [DateTime]::UtcNow.ToString('o')
        }
    }
}

$evidence | Format-Table Node, NameForm, Status, Error -AutoSize
```

Interpret the comparison:

- **FQDN fails with one of the three known strings and short name succeeds:**
  the current product retry should handle this. Run Step 4. Do not reboot.
- **Both name forms fail:** continue to Step 5. The historical retry does not
  resolve the active problem.
- **Both name forms succeed:** the reported state is not currently present.
  Rerun deployment validation and correlate by UTC time. If the current
  validator reports named subtests, troubleshoot those subtests instead.

**Step 4: Run the current product validator**

```powershell
$fqdnNodes = $nodes | ForEach-Object { "$_.$domainFqdn" }
$outputPath = Join-Path $env:SystemDrive 'AdminPrivilegeValidation'
$null = New-Item -ItemType Directory `
    -Path (Join-Path $outputPath 'MASLogs') `
    -Force
$env:LocalRootFolderPath = $outputPath

$result = Invoke-AzStackHciClusterValidation `
    -Node $fqdnNodes `
    -Include 'Test-ClusterPreReq' `
    -OperationType Deployment `
    -PassThru `
    -OutputPath $outputPath

$result |
    Where-Object Name -eq 'AzStackHci_Cluster_Test-Cluster_Results' |
    Select-Object Name, Status,
        @{n='Detail';e={$_.AdditionalData.Detail}},
        Remediation |
    Format-List
```

- **Status is `SUCCESS`:** stop. The current product handled the validation.
  Do not reboot.
- **Status is `FAILURE` and `Detail` begins with `Failed to execute
  Test-Cluster` plus one of the three exact signatures:** preserve `Detail`,
  including the recorded `Test-Cluster Command`, and continue to Step 5.
- **Status is `FAILURE` and `Detail` contains named `[!!Failed!!]` validation
  subtests:** `Test-Cluster` executed. The historical top-level issue is not the
  active blocker. Follow the named subtests and do not use the legacy reboot as
  a generic fix.
- **No result is returned:** preserve the module version, command output, and
  component logs. Treat the state as unverified, not healthy.

**Step 5: Exclude overlapping causes**

```powershell
$checks = foreach ($node in $nodes) {
    $fqdn = "$node.$domainFqdn"
    $dns = Resolve-DnsName -Name $fqdn -Type A -ErrorAction SilentlyContinue
    $wsman = Test-WSMan -ComputerName $fqdn -ErrorAction SilentlyContinue
    $channel = Invoke-Command -ComputerName $node -ScriptBlock {
        [pscustomobject]@{
            ComputerName = $env:COMPUTERNAME
            PartOfDomain = [bool](
                Get-CimInstance Win32_ComputerSystem
            ).PartOfDomain
            SecureChannel = [bool](
                Test-ComputerSecureChannel -ErrorAction SilentlyContinue
            )
            LastBootUpTime = (
                Get-CimInstance Win32_OperatingSystem
            ).LastBootUpTime
        }
    } -ErrorAction SilentlyContinue

    [pscustomobject]@{
        Node = $node
        Fqdn = $fqdn
        DnsAddresses = @($dns | Where-Object IPAddress |
            Select-Object -ExpandProperty IPAddress) -join ','
        WinRM = if ($wsman) { 'Reachable' } else { 'Not reachable' }
        PartOfDomain = $channel.PartOfDomain
        SecureChannel = $channel.SecureChannel
        LastBootUpTime = $channel.LastBootUpTime
    }
}

$checks | Format-Table -AutoSize
```

Stop and use the corresponding TSG when:

- the FQDN has no DNS address;
- WinRM is not reachable;
- the host is not domain joined;
- the secure channel is false;
- the node is already a deployed cluster member.

There is no single supported read-only flag that proves a host is waiting for
its first post-domain-join restart. The legacy branch requires deployment
chronology showing that the host was joined and validation ran before its first
restart. If that chronology is unavailable, preserve evidence and escalate
rather than using a reboot as a diagnostic guess.

# Root Cause

The confirmed engineering cause was a DHCP-mode seed-node detection defect in
the deployment domain-join workflow. A seed node could restart while another
node was still joining the domain, terminating the workflow before the
non-seed node received its required restart. Netlogon then did not update that
node's supported Kerberos encryption types in Active Directory, which could
cause WinRM authentication and `Test-Cluster` to fail with the misleading
administrative-privileges message.

The failure was fixed in the deployment workflow. The confirmed 2610 boundary
also contains Environment Checker handling that retries the documented
top-level access errors with short names. A named validation-subtest failure is
not evidence that this legacy deployment defect is active.

::: audience-css

# Internal Root Cause

- Engineering cause and fix: One bug `37471190`,
  `Add-NodeToDomainAndReboot: DHCP seed detection fails causing non-seed nodes
  to skip reboot, breaking Kerberos auth`.
- The bug was resolved as Fixed and linked to the deployment-orchestration
  correction.
- Environment Checker commit
  `e90690975fe2f9846cd612ab87d477b7cb32f0cb` recognizes all three documented
  access-error strings and retries deployment validation with short names.
- A September 17, 2026 disposable-node validation on solution
  `12.2610.1004.30` and Environment Checker `10.2610.0.2039` did not reproduce
  the historical top-level exception before the first post-join restart.

:::

# Mitigation Details

**Legacy mitigation**

**Restart only a confirmed pre-deployment host**

**[MEDIUM RISK]** This step interrupts the target operating system. Run it only
after all decision-summary gates pass and the deployment owner confirms there
are no workloads.

```powershell
$failingNode = '<FailingNodeName>'

if (Get-ClusterNode -Name $failingNode -ErrorAction SilentlyContinue) {
    throw "$failingNode is a deployed cluster member. This article does not authorize its reboot."
}

Restart-Computer -ComputerName $failingNode -Force
```

If remoting is unavailable, use the server console or the OEM management
interface to request a graceful restart. Do not power-cycle the host unless the
approved hardware procedure explicitly requires it.

Wait for the host to return, then repeat Steps 3 through 5. A successful short
and FQDN comparison plus a `SUCCESS` product result is the recovery proof.

**Verify the fix and resume deployment**

Rerun the deployment validation from the Azure portal. Confirm that the new
result has a later UTC timestamp and no longer contains the exact historical
top-level exception. A fully healthy deployment should report
`AzStackHci_Cluster_Test-Cluster_Results` as `SUCCESS`; if it instead lists
specific failed subtests, troubleshoot those results separately.

Do not treat successful `Invoke-Command` or `Test-WSMan` output alone as proof.
The same current product validator that failed must pass.

**Evidence to preserve**

Before a restart, capture:

- solution, platform, services, and Environment Checker versions;
- the deployment operation name, correlation ID, and UTC failure time;
- the newest matching Event ID 17205 JSON;
- the FQDN versus short-name comparison;
- the current validator result and recorded `Test-Cluster Command`;
- DNS, WinRM, domain membership, secure channel, and boot-time output;
- `C:\CloudDeployment\Logs`;
- `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log`;
- `AzStackHciEnvironmentReport.json` or `.xml`;
- the named reports under `C:\Windows\Cluster\Reports`.

# Escalation

Escalate to Microsoft Support when:

- the error persists with AzStackHci.EnvironmentChecker `10.2610.0.2039` or
  later;
- both FQDN and short-name calls fail after DNS, WinRM, and secure-channel checks
  pass;
- the current validator returns no result;
- the target is already a deployed cluster member;
- the issue remains after one confirmed legacy pre-deployment restart.

Include the evidence list above. Do not repeat restarts as a troubleshooting
loop.

**Prevention**

For legacy deployment media, confirm each pre-deployment host completes its
required post-domain-join restart before cluster validation begins. For current
releases, keep the Environment Checker payload current and let the product's
short-name retry run before considering a host restart.

::: audience-css

# Internal Escalation

When escalation is required, include the full evidence set, the exact
Environment Checker version, the recorded `Test-Cluster Command`, and whether
the result was a top-level execution exception or named validation subtests.
Reference One bug `37471190` only when the domain-join chronology and
pre-restart state match the documented failure chain.

:::

# Related Content

- [Test-Cluster access denied caused by a missing DNS A record](Known-Issue-Test-Cluster-Access-Denied-WMI-Error.md)
- [WinRM cannot process the TrustedHosts configuration request](Known-Issue-WinRM-cannot-process-the-configuration-request.md)
- [Azure Local deployment prerequisites](https://learn.microsoft.com/azure/azure-local/deploy/deployment-prerequisites)
- [Validate hardware for a cluster](https://learn.microsoft.com/windows-server/failover-clustering/validate-hardware)

::: audience-css

# Source Articles

- **External source article:** [Test-Cluster reports missing administrative privileges during deployment](https://github.com/Azure/AzureLocal-Supportability/blob/main/TSG/EnvironmentValidator/Known-Issue-Test-Cluster-Administrative-Privileges-Failure.md)
- **Internal source article:** None
- **Public documentation article:** [Azure Local deployment prerequisites](https://learn.microsoft.com/azure/azure-local/deploy/deployment-prerequisites)
- **Porting work item:** None

:::
