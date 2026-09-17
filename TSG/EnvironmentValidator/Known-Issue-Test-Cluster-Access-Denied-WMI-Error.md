---
ArticleType: "KI"
Article_ID: "20260917143325"
Title: "Known issue: Test-Cluster cannot reach a node through WMI because its DNS A record is missing"
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
  DeploymentType: ["Hyperconverged", "Disaggregated", "Multi-Rack", "Disconnected", "Microsoft 365 Local"]
  OEM: ["All"]
  OS: ["23H2", "24H2"]
  SolutionMinorBuild: []
  ExtensionName: ""
  ExtensionVersion: []
Component: "Deployment"
Engineering_ID:
  Source: ""
  ID: 0
Tags: ["Cloud Deployment", "Validation", "DNS"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
|------|---------|---------|
| 2026-09-17 | 1.0 | Initial TSG Forge revision |

:::

# Known issue: Test-Cluster cannot reach a node through WMI because its DNS A record is missing

This known issue affects the Environment Validator cluster-validation path,
`Invoke-AzStackHciClusterValidation` with `Test-ClusterPreReq`, which emits
`AzStackHci_Cluster_Test-Cluster_Results`.

- **Severity:** Critical when reproduced. Deployment or Add Node cannot continue.
- **Primary owner:** The Azure Local deployment engineer runs node checks and
  requests registration. The customer's Active Directory or DNS administrator
  owns a persistent secure-update or zone problem.
- **Typical effort:** Allow 10 to 20 minutes to identify the affected node,
  request DNS registration, wait for propagation, and rerun validation.
- **Customer impact:** The lifecycle operation is blocked. Existing virtual
  machines and cluster storage are not changed by this procedure.
- **Hardware boundary:** No OEM, firmware, storage, or switch action is required.
- **Risk:** **[LOW RISK]** for read-only diagnosis and
  `ipconfig /registerdns`. This procedure does not require a node drain, reboot,
  service restart, DNS-server configuration change, or manual record creation.

On September 17, 2026, Azure Local solution `12.2610.1004.30`, platform
`12.2610.0.3059`, and AzStackHci.EnvironmentChecker `10.2610.0.2039` contained a
product retry that changes access-denied, cluster-open, and
administrative-privilege failures from fully qualified names to short node
names. In a disposable-node validation, removing the node's A record did not
create a persistent failure because secure dynamic registration restored the
record before the next Test Cluster probe. Treat the historical condition as a
legacy path on this confirmed build.

# Symptoms

The deployment or Add Node validation includes this result:

```text
AzStackHci_Cluster_Test-Cluster_Results
```

The detail can include:

```text
Failed to execute Test-Cluster: Unable to connect to <NodeName>.<DomainFQDN> via WMI
```

The same validation path can also emit these messages:

```text
Failed to execute Test-Cluster: Access is denied
```

```text
Failed to execute Test-Cluster: You do not have administrative privileges on the server <NodeName>
```

Those last two messages are not sufficient to select this article. Confirm the
missing A record first.

**Where this failure appears**

| Admin surface | What to expect |
|---|---|
| PowerShell on an Azure Local node | **Shown**: the direct DNS and WMI checks below identify the missing record and affected FQDN. |
| Azure portal | **Shown**: the deployment or Add Node validation displays the failed Test Cluster result. The portal does not prove why name resolution failed. |
| Windows event logs | **Shown when persisted**: Environment Checker Event ID 17205 can contain `AzStackHci_Cluster_Test-Cluster_Results`. DNS Client operational events can provide registration context. |
| Cluster logs from `Get-ClusterLog` | This pre-deployment name-registration condition is **not evident in cluster logs** as a quorum, storage, or clustered-resource failure. |
| Windows Failover Cluster Manager | The missing pre-deployment DNS record is **not evident in Failover Cluster Manager** as a node, role, or resource state. |
| Windows Admin Center on a standalone host | The exact Environment Validator result is **not evident in Windows Admin Center on a standalone host**. Use node PowerShell and the lifecycle result. |
| Windows Admin Center in the Azure portal | The exact DNS record and WMI probe are **not evident in Windows Admin Center in the Azure portal**. Use the Azure Local lifecycle view for correlation and PowerShell for proof. |
| Component or tool log files on disk | **Shown when written**: preserve `C:\CloudDeployment\Logs`, `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log`, and `AzStackHciEnvironmentReport.json` or `.xml`. Test Cluster reports are under `C:\Windows\Cluster\Reports` and can be copied into `C:\CloudDeployment\MASLogs`. |

# Issue Validation

## Errors or Failures

Use this article only when the node's fully qualified domain name (FQDN) has no
usable A record and `Test-Cluster` cannot reach that node through WMI.

1. **[LOW RISK]** Test the node's FQDN against the intended DNS server without
   suppressing query errors.
1. If the FQDN resolves, stop. Use the
   [administrative privileges guide](Known-Issue-Test-Cluster-Administrative-Privileges-Failure.md)
   or investigate the exact `Test-Cluster` error instead.
1. If the DNS server is unreachable, stop. Restore the DNS path before attempting
   registration.
1. If the server answers but the node's A record is missing, run
   `ipconfig /registerdns` on only that node.
1. Wait for the record, verify WMI reachability, and rerun the original validation.
   Do not resume while any required node remains unresolved.

Current 2610 Environment Checker code retries certain access-denied and
administrative-privilege failures with short node names. That retry prevents
those messages from proving a DNS-record problem. On the confirmed 2610 build, a
disposable node also re-registered its deliberately removed record before the
next Test Cluster probe. Do not attempt to suppress current automatic
registration merely to recreate the legacy issue.

**Before you start**

- Run the commands from an elevated Windows PowerShell session.
- Get the intended node names, Active Directory domain FQDN, and DNS server
  addresses from the deployment configuration or the directory owner. Do not
  guess them.
- For a deployment, operate only on the host being prepared.
- For Add Node, operate only on the new node. Do not drain, reboot, or change
  running cluster members or workloads.
- Do not change DNS zone settings, scavenging, access control lists, forwarders,
  or the node's DNS-client addresses as part of this quick fix.
- Do not manually create an A record to hide a failed secure-update path. A
  manually created record can have the wrong owner or become stale.

## PowerShell Detection Script

**Test every intended node against the intended DNS server**

Populate the three variables from the deployment configuration. This script
distinguishes an unreachable DNS server from an authoritative answer with no A
record. It also produces one overall verdict.

```powershell
$ErrorActionPreference = 'Stop'
$nodes = @('<Node1>', '<Node2>', '<Node3>')
$domainFqdn = '<domain.fqdn>'
$dnsServer = '<dns-server-ip>'

if ($nodes.Count -eq 0 -or $nodes -contains '<Node1>') {
    throw 'Replace the node placeholders with every intended deployment or Add Node host.'
}
if ($domainFqdn -eq '<domain.fqdn>' -or $dnsServer -eq '<dns-server-ip>') {
    throw 'Replace the domain and DNS-server placeholders.'
}

$dnsPort = Test-NetConnection -ComputerName $dnsServer -Port 53 -WarningAction SilentlyContinue
if (-not $dnsPort.TcpTestSucceeded) {
    throw "DNS server $dnsServer is not reachable on TCP 53. Restore the DNS path before continuing."
}

$results = foreach ($node in $nodes) {
    $fqdn = "$node.$domainFqdn"
    try {
        $records = @(
            Resolve-DnsName -Name $fqdn -Type A -Server $dnsServer `
                -DnsOnly -ErrorAction Stop
        )
        [pscustomobject]@{
            Node = $node
            Fqdn = $fqdn
            Status = if ($records.Count) { 'PRESENT' } else { 'MISSING' }
            Addresses = ($records | ForEach-Object IPAddress) -join ', '
            Error = $null
        }
    }
    catch {
        $rcode = if ($_.Exception.Message -match 'does not exist|NXDOMAIN') {
            'MISSING'
        }
        else {
            'QUERY-FAILED'
        }
        [pscustomobject]@{
            Node = $node
            Fqdn = $fqdn
            Status = $rcode
            Addresses = $null
            Error = $_.Exception.Message
        }
    }
}

$results | Format-Table -AutoSize
$missing = @($results | Where-Object Status -eq 'MISSING')
$queryFailed = @($results | Where-Object Status -eq 'QUERY-FAILED')

if ($queryFailed.Count) {
    throw 'At least one DNS query failed for a reason other than a missing record. Resolve that DNS-server or network error first.'
}
if ($missing.Count) {
    Write-Warning "$($missing.Count) node DNS A record(s) are missing. Continue with only those nodes."
}
else {
    Write-Host 'All node A records are present. Stop: this article does not apply.'
}
```

Interpret the result:

| Result | Meaning | Next step |
|---|---|---|
| `PRESENT` for every node | DNS registration is not the cause | Stop. Use the sibling administrative-privileges guide or investigate the exact Test Cluster report. |
| `MISSING` for one or more nodes | The DNS-registration condition is present | Continue for only the missing nodes. |
| `QUERY-FAILED` | The DNS server, DNS service, or network path failed | Stop and route to the DNS or network owner. |

**Confirm the affected node's local identity and DNS-client state**

Run locally on each node reported as `MISSING`, or through an already working
management path:

```powershell
$computer = Get-CimInstance Win32_ComputerSystem
$upAdapters = @(
    Get-NetAdapter |
        Where-Object Status -eq 'Up' |
        Select-Object -ExpandProperty Name
)
$dns = @(
    Get-DnsClientServerAddress -AddressFamily IPv4 |
        Where-Object {
            $_.InterfaceAlias -in $upAdapters -and
            $_.ServerAddresses
        }
)

[pscustomobject]@{
    Node = $env:COMPUTERNAME
    PartOfDomain = $computer.PartOfDomain
    Domain = $computer.Domain
    UpAdapters = $upAdapters -join ', '
    DnsServers = (
        $dns.ServerAddresses |
            Sort-Object -Unique
    ) -join ', '
}
```

Continue only when `PartOfDomain` is `True`, `Domain` is the expected domain, and
the intended DNS server is listed. If the node is not domain joined or points at
the wrong DNS servers, this article does not authorize changing that state.

**Distinguish DNS registration from the post-domain-join authentication issue**

From another host that should manage the affected node, compare its FQDN and
short name:

```powershell
$node = '<AffectedNode>'
$domainFqdn = '<domain.fqdn>'
$fqdn = "$node.$domainFqdn"

[pscustomobject]@{
    FqdnDns = [bool](
        Resolve-DnsName -Name $fqdn -Type A -DnsOnly `
            -ErrorAction SilentlyContinue
    )
    FqdnWinRM = [bool](
        Test-WSMan -ComputerName $fqdn -ErrorAction SilentlyContinue
    )
    ShortNameWinRM = [bool](
        Test-WSMan -ComputerName $node -ErrorAction SilentlyContinue
    )
}
```

- `FqdnDns = False` selects this DNS-registration article.
- `FqdnDns = True` but both WinRM probes fail after a recent domain join points
  away from this article. Use the
  [administrative privileges guide](Known-Issue-Test-Cluster-Administrative-Privileges-Failure.md).
- `FqdnDns = True`, `FqdnWinRM = False`, and `ShortNameWinRM = True` is consistent
  with a qualified-name path problem. Current 2610 Environment Checker code
  retries the applicable `Test-Cluster` access-denied signatures with short
  names. Preserve the module version and lifecycle detail if the current
  product still blocks.

# Root Cause

An **A record** maps a host name to an IPv4 address. After a Windows node joins
Active Directory, the DNS client normally registers the node's FQDN in the
Active Directory-integrated DNS zone. A zone configured for **secure dynamic
updates** accepts registrations only from authenticated domain identities.

If the target node's A record is absent, `Test-Cluster` can fail while opening a
WMI connection to that FQDN. Requesting registration with
`ipconfig /registerdns` asks the Windows DNS client to publish the node's current
addresses again. It does not restart the node, change its DNS-server list, or
modify other cluster members.

This article covers a narrow DNS-registration failure. It does not assert that
every `Access is denied` or administrative-privilege message is caused by DNS.

::: audience-css

# Internal Root Cause

The current `Invoke-TestCluster` implementation catches messages matching
`Access is denied`, `An error occurred opening cluster`, or
`do not have administrative privileges` during non-PreUpdate operations. It
retries `Test-Cluster` after reducing each supplied FQDN to its short node name.
The shipped 2610 module used in validation contained this branch.

PR 14044194 introduced the short-name retry and completed on November 20, 2025.
PR 16312579 later changed the AD-less TrustedHosts entries to per-node wildcard
suffixes and completed on July 9, 2026. These engineering references establish
current behavior but do not establish the first customer-serviced build, so the
external text names only the live-confirmed 2610 boundary.

:::

# Mitigation Details

**Request DNS registration on only the affected node**

**[LOW RISK]** Run locally on the affected node, or through an already working
management path:

```powershell
$before = Get-Date
$output = ipconfig /registerdns | Out-String

[pscustomobject]@{
    Node = $env:COMPUTERNAME
    RequestedAtUtc = $before.ToUniversalTime().ToString('o')
    Command = 'ipconfig /registerdns'
    Output = $output.Trim()
}
```

The command asks the DNS client to register all configured adapter addresses.
It is asynchronous, so a successful command return does not prove that the DNS
server accepted the update.

**Wait for the exact A record**

From the same vantage point used in Issue Validation:

```powershell
$fqdn = '<AffectedNode>.<domain.fqdn>'
$dnsServer = '<dns-server-ip>'
$record = $null

for ($attempt = 1; $attempt -le 12 -and -not $record; $attempt++) {
    Clear-DnsClientCache
    $record = @(
        Resolve-DnsName -Name $fqdn -Type A -Server $dnsServer `
            -DnsOnly -ErrorAction SilentlyContinue
    )
    if (-not $record) {
        Start-Sleep -Seconds 5
    }
}

if (-not $record) {
    throw "The A record for $fqdn is still missing. Do not resume deployment."
}

$record |
    Select-Object Name, Type, IPAddress |
    Format-Table -AutoSize
```

If the record remains missing, stop. The Active Directory or DNS owner should
check these items read-only on the DNS server:

```powershell
$zone = '<domain.fqdn>'
$node = '<AffectedNode>'

Get-DnsServerZone -Name $zone |
    Select-Object ZoneName, IsDsIntegrated, DynamicUpdate

Get-DnsServerResourceRecord -ZoneName $zone -Name $node `
    -RRType A -ErrorAction SilentlyContinue
```

For an Active Directory-integrated production zone, the owner should confirm
that the zone's intended dynamic-update policy is in effect and that the node's
computer account can securely update its own record. Scavenging is not a fix for
a registration that never succeeds. Do not disable secure updates, broaden zone
permissions, or create a permanent manual record without the directory owner's
change and rollback plan.

**Verify WMI and rerun the original validation**

```powershell
$node = '<AffectedNode>'
$domainFqdn = '<domain.fqdn>'
$fqdn = "$node.$domainFqdn"

$dns = Resolve-DnsName -Name $fqdn -Type A -DnsOnly -ErrorAction Stop
$os = Get-CimInstance -ClassName Win32_OperatingSystem `
    -ComputerName $fqdn -ErrorAction Stop

[pscustomobject]@{
    Fqdn = $fqdn
    Address = ($dns | ForEach-Object IPAddress) -join ', '
    WmiComputerName = $os.CSName
    DnsPresent = [bool]$dns
    WmiReachable = [bool]$os
}
```

Expected result: `DnsPresent` and `WmiReachable` are both `True`, and
`WmiComputerName` identifies the affected node.

Return to the same Azure portal deployment or Add Node operation and select
**Retry** or **Resume**. Success requires a fresh
`AzStackHci_Cluster_Test-Cluster_Results` result without the WMI reachability
error. Do not substitute an unrelated connectivity test.

**Rollback**

`ipconfig /registerdns` does not change persistent node configuration, so there
is normally nothing to roll back.

If a DNS administrator made a separate server-side change after this article
stopped and handed off the case, that owner must use the change-specific backup
and rollback plan. Do not delete the newly registered node record as a routine
rollback; doing so recreates the failure.

# Escalation

Escalate to Microsoft support when the exact A record exists and direct WMI
access succeeds, but a fresh lifecycle validation still reports the same error.
Collect:

```powershell
Get-Module -ListAvailable AzStackHci.EnvironmentChecker |
    Sort-Object Version -Descending |
    Select-Object -First 1 Name, Version, ModuleBase

Get-StampInformation |
    Format-List StampVersion, PlatformVersion, InitialDeployedVersion

Get-ChildItem 'C:\Windows\Cluster\Reports' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 10 Name, LastWriteTime, Length

Get-WinEvent -LogName AzStackHciEnvironmentChecker `
    -FilterXPath "*[System[(EventID=17205)]]" `
    -MaxEvents 200 |
    Where-Object Message -like '*AzStackHci_Cluster_Test-Cluster_Results*' |
    Select-Object -First 5 TimeCreated, Id, Message
```

Also preserve:

- the Issue Validation output from every intended node;
- the exact DNS server queried and the returned A record;
- the direct WMI verification output;
- the deployment or Add Node correlation ID and UTC failure time;
- `C:\CloudDeployment\Logs`, the newest Test Cluster report, and the Environment
  Checker log and report files.

On a current 2610 or later build, call out whether the lifecycle detail shows the
short-name retry. If access-denied signatures remain after that retry, this DNS
registration article is not sufficient by itself.

::: audience-css

# Internal Escalation

Route a current-build failure to the Environment Validator product group with:

- the Azure Local solution, platform, and Environment Checker module versions;
- the exact first and retry `Test-Cluster` command strings from the validator log;
- the DNS, WinRM, and CIM evidence from both FQDN and short-name paths;
- the lifecycle correlation ID and UTC timestamps;
- the generated Test Cluster HTML and XML reports.

Reference PR 14044194 for the short-name retry and PR 16312579 for the 2610
AD-less TrustedHosts suffix correction. These are source-history references,
not customer-visible fixed-release declarations.

:::

# Related Content

- [Known issue: Test-Cluster administrative privileges failure during deployment](Known-Issue-Test-Cluster-Administrative-Privileges-Failure.md)
- [Azure Local deployment prerequisites](https://learn.microsoft.com/azure/azure-local/deploy/deployment-prerequisites)
- [Azure Local host network requirements](https://learn.microsoft.com/azure/azure-local/concepts/host-network-requirements)
- [Validate hardware for a failover cluster](https://learn.microsoft.com/windows-server/failover-clustering/create-failover-cluster)

::: audience-css

# Source Articles

- **Internal source article:** None. No internal wiki page was verified as the same article.
- **External source article:** [AzureLocal-Supportability source](https://github.com/Azure/AzureLocal-Supportability/blob/main/TSG/EnvironmentValidator/Known-Issue-Test-Cluster-Access-Denied-WMI-Error.md)
- **Public documentation article:** None. The related Microsoft Learn pages do not contain this same known issue.
- **Porting work item:** None. No EdgeSRE-Wiki porting work item was supplied for this lane.

:::
