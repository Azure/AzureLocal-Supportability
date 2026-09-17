# AzStackHci_DNS_ActiveDirectoryDomainName

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_DNS_ActiveDirectoryDomainName</strong></td>
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
    <th style="text-align:left;">Display name</th>
    <td>Active Directory Domain Name Resolution</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Invoke-AzStackHciDNSValidation</code> with <code>Test-ActiveDirectoryDomainName</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>DNS and Active Directory integration (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>: failed AD-domain name resolution blocks applicable deployment, add-node, and update readiness checks.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The customer's Active Directory or DNS owner applies the node-side or upstream correction. Microsoft support can guide evidence collection and verification.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Plan 10-20 minutes per node for read-only evidence and configuration capture. A supported deployment-time node correction and revalidation usually takes 15-30 minutes per node. An upstream DNS or domain-controller change follows the owning team's change process and has no reliable fixed duration.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>Local workloads continue to run, but the affected Azure Local lifecycle operation remains blocked. Guest workloads that separately depend on Active Directory can also be affected by the same DNS outage.</td>
  </tr>
</table>

> **At a glance**
> - **Owner and support role:** the customer's Active Directory or DNS administrator owns the correction. Microsoft support can help identify the failing node and DNS server, interpret the evidence, and verify a fresh result.
> - **Impact:** Critical. It blocks Azure Local deployment, add-node, and updates until every node can resolve the cluster's Active Directory domain name.
> - **Effort and downtime:** read-only evidence and configuration capture usually take 10 to 20 minutes per node. A supported deployment-time node correction and revalidation usually take 15 to 30 minutes per node, with no reboot or cluster drain. An upstream DNS or domain-controller change follows the owning team's change process.
> - **Before you change anything:** do not guess DNS server IP addresses. Get the cluster's intended DNS servers (the ones that resolve your Active Directory domain, normally your domain controllers) from your Active Directory or network administrator first.

> **Customer-facing framing:** This is an AD-domain DNS path issue that blocks readiness, not a request to rebuild the cluster. Microsoft support can help isolate the failing path and verify the result. The customer's DNS or Active Directory owner applies any shared DNS-server or domain-controller change.

## Overview

This Environment Validator check confirms that each Azure Local node can resolve the
cluster's Active Directory (AD) domain name. On every node, for each DNS server
configured on every network adapter that is up, the check resolves the AD domain
FQDN (for example `contoso.local`) and expects at least one A record back. If any
configured DNS server returns no records (or no DNS server is configured at all), the
check fails for that node.

This check proves a narrow prerequisite: an A-record query for the AD domain FQDN
returns at least one IPv4 address through every tested DNS server. It does **not** prove
that domain-controller location, Kerberos, LDAP, replication, or all AD-integrated DNS
records are healthy. Domain-controller discovery uses SRV records such as
`_ldap._tcp.dc._msdcs.<domain>`. If users or workloads cannot locate a domain controller
even after this validator passes, run the SRV check in
[Verification](#6-verification-prove-the-failure-cleared).

- **Severity:** Critical. It blocks the pre-update health check and the deployment or
  add-node readiness check until the AD domain resolves on every node.
- **When it runs:** deployment, add-node, and pre-update readiness paths. In practice
  you will most often see it block a pending Azure Local update or an add-node
  operation.
- **Only on AD-based clusters:** this check applies only when the cluster uses Active
  Directory. It is skipped when the cluster uses a local or Azure-based identity
  instead of AD, because there is no AD domain to resolve. To tell which mode a cluster
  is in, check a node with `(Get-CimInstance Win32_ComputerSystem).PartOfDomain`: it
  returns `True` (and `.Domain` shows your AD domain) on an AD-based cluster, and
  `False` on a local or Azure-identity cluster where this check does not apply.
- **Reported names:** this check is reported under one of two names,
  `AzStackHci_DNS_ActiveDirectoryDomainName` (the rolled-up, per-cluster result) or
  `AzStackHci_DNS_Test_ActiveDirectory_DomainName_Resolution` (the per-node, per-DNS-server
  detail result). Both are in use across current builds, so search the health-check
  results for either. They are the same check at two levels of detail: the cause and
  the fix in this guide apply to both.

**Ownership and escalation.** The customer's Active Directory or DNS administrator
applies the correction. Microsoft support can guide evidence collection and fresh-result
verification. If every DNS server on every up adapter returns one or more A records for
the AD domain, but a newly generated validator result still reports zero records, collect
the direct query output, fresh Event ID 17205 payload, Environment Checker logs, module
version, and health-check timestamp, then escalate to Microsoft support for product-group
review. That evidence distinguishes a validator problem from a customer DNS problem.

**Where a node's DNS comes from.** A node's DNS servers are set at deployment time from
the deployment configuration's management network settings and applied to the management
network adapter; they are not baked into the OEM factory image. If you are an OEM or
field engineer checking your own imaging process, confirm the image does not pin DNS
servers and leaves them to be set by deployment, so each cluster picks up the customer's
intended DNS (the servers that resolve its AD domain) rather than a stale value carried
over from imaging.

For an imaging validation pass, inspect the image before deployment:

```powershell
Get-DnsClientServerAddress -AddressFamily IPv4 |
    Where-Object ServerAddresses |
    Select-Object InterfaceAlias, AddressFamily,
        @{ n = 'DnsServers'; e = { $_.ServerAddresses -join ', ' } }
```

Review any returned static addresses against the imaging standard. Do not clear a DNS
setting merely because this command returns one; boot, provisioning, or the lab network
may have supplied it legitimately.

## Quick fix (start here)

First decide whether the machine is being deployed or added, or is already a deployed
cluster member:

- **Deploying or adding a node:** after you confirm the intended DNS addresses, you may
  correct the management-adapter DNS client and re-run readiness.
- **Already-deployed cluster:** do **not** re-point the node's DNS client as a routine
  repair. Azure Local does not support changing DNS server settings post-deployment.
  Fix the currently configured DNS server upstream, usually by correcting the AD zone,
  adding the required conditional forwarder, or restoring the DNS/firewall path.

> **Remote-access warning:** changing the management adapter can interrupt the current
> remote session. For a deployment-time node correction, use local console or out-of-band
> access, or confirm an alternate management path, before applying the change.

Run this read-only fast path first. It reads the AD domain, limits DNS inventory to
adapters that are currently up, and distinguishes a failed query from a zero-record
response:

```powershell
$computer = Get-CimInstance Win32_ComputerSystem
if (-not $computer.PartOfDomain) {
    throw 'This node is not AD-domain joined; this check does not apply.'
}
$adDomain = $computer.Domain
$upAliases = @(Get-NetAdapter -ErrorAction SilentlyContinue |
    Where-Object Status -eq 'Up' |
    Select-Object -ExpandProperty Name)
$dnsServers = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
    ForEach-Object { $_.ServerAddresses } |
    Sort-Object -Unique)

"AD domain: $adDomain"
"DNS servers on up adapters: $($dnsServers -join ', ')"
foreach ($dns in $dnsServers) {
    try {
        $records = @(Resolve-DnsName -Name $adDomain -Server $dns -Type A -DnsOnly -ErrorAction Stop)
        [pscustomobject]@{
            DnsServer = $dns
            Status    = if ($records.Count -gt 0) { 'PASS: A records returned' } else { 'FAILURE: no A records' }
            Records   = ($records | ForEach-Object IPAddress) -join ', '
        }
    }
    catch {
        [pscustomobject]@{
            DnsServer = $dns
            Status    = 'FAILURE: query failed'
            Records   = $_.Exception.Message
        }
    }
}
```

A correct result has at least one row with `Status = PASS: A records returned` for
every listed DNS server. `FAILURE: query failed` indicates a reachability, service, or
protocol problem. `FAILURE: no A records` indicates that the server answered but did
not return the required record.

An upstream DNS-server or domain-controller change is a **[MEDIUM RISK]** shared
infrastructure change, not a beginner action. Hand it to the Active Directory or DNS
owner, who must capture the prior server configuration and define rollback.

## Requirements

- Administrative (local administrator) access to each Azure Local node, or a remote
  PowerShell session to the nodes.
- The cluster's Active Directory domain FQDN, and the DNS servers that resolve it
  (normally the domain controllers), from the deployment's network configuration.
- Access to, or coordination with, whoever administers those DNS servers, in case an
  upstream server needs a conditional forwarder or a domain-controller DNS fix.
- Console or out-of-band access, or a confirmed alternate management path, before a
  supported deployment-time management-adapter DNS change.
- No maintenance window is required for a deployment-time node DNS-client correction.
  It applies immediately and does not need a reboot or a cluster drain. Upstream DNS
  changes follow the owning team's change process.

## Troubleshooting Steps

### 1. Confirm the failure and see where it appears

The same failure surfaces in several places depending on how it was noticed. Pick the
entry point that matches; they all converge on the same `Detail` string.

#### Option A: Health-check result files on the cluster shared volume (recommended)

Every pre-update health check writes one JSON result file to the cluster's
infrastructure share. Read the newest one and filter to this check (both reported
names):

```powershell
$base = 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System'
if (-not (Test-Path $base)) {
    # Fallback: walk all ClusterStorage volumes for the HealthCheck folder.
    $base = Get-ChildItem 'C:\ClusterStorage' -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'Shares\SU1_Infrastructure_1\Updates\HealthCheck\System' } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}

$names = 'AzStackHci_DNS_ActiveDirectoryDomainName','AzStackHci_DNS_Test_ActiveDirectory_DomainName_Resolution'

$latest = $null
if ($base) {
    $latest = Get-ChildItem $base -Filter 'HealthCheckResult.EnvironmentChecker.*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

if (-not $latest) {
    Write-Warning "No HealthCheck result file found on this node (the folder is missing or no health check has run yet). Use Option B, C, or D, or run this on a different node."
}
else {
    Write-Host "Reading: $($latest.FullName)"
    Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object { $_.Name -in $names -and $_.AdditionalData.Status -eq 'FAILURE' } |
        Select-Object Name, Severity,
            @{ n = 'Status';      e = { $_.AdditionalData.Status } },
            @{ n = 'Source';      e = { $_.AdditionalData.Source } },
            @{ n = 'Detail';      e = { $_.AdditionalData.Detail } },
            Remediation
}
```

Each row is one currently-failing DNS server on one node. The `Detail` column is the
precise error string; the `Remediation` column points at the public
[Azure Local network requirements](https://learn.microsoft.com/azure/azure-local/concepts/firewall-requirements)
documentation. The human-readable status and message are under
`AdditionalData.Status` and `AdditionalData.Detail`; the top-level `Status` is a
numeric enum and the top-level `Description` is generic.

#### Option B: `Get-SolutionUpdate` (is an update being blocked?)

If the failure was noticed because a pending update will not start, this is the
fastest confirmation:

```powershell
Get-SolutionUpdate |
    Select-Object DisplayName, Version, State, HealthCheckResult, HealthCheckDate |
    Format-Table -AutoSize
```

`HealthCheckResult = Failure` with a recent `HealthCheckDate` means the pre-update
validators failed. Use Option A to see which validator caused it.

#### Option C: Windows event log (when the result files are missing)

The same data is written to the Windows event log on each node. In Event Viewer, open
`Applications and Services Logs` then `AzStackHciEnvironmentChecker` and filter for
Event ID 17205, or from PowerShell:

```powershell
$names = 'AzStackHci_DNS_ActiveDirectoryDomainName','AzStackHci_DNS_Test_ActiveDirectory_DomainName_Resolution'
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath "*[System[(EventID=17205)]]" -MaxEvents 2000 |
    ForEach-Object {
        try { $r = $_.Message | ConvertFrom-Json } catch { return }
        if ($r.Name -in $names -and $r.AdditionalData.Status -eq 'FAILURE') {
            [pscustomobject]@{
                TimeCreated = $_.TimeCreated
                Name        = $r.Name
                Status      = $r.AdditionalData.Status
                Source      = $r.AdditionalData.Source
                Detail      = $r.AdditionalData.Detail
                Remediation = $r.Remediation
            }
        }
    } | Sort-Object TimeCreated -Descending | Select-Object -First 20
```

#### Option D: Azure portal

In the Azure portal, open the Azure Local cluster, then the **Updates** tab. When a
pre-update health check fails, the portal shows a banner naming the failing
validators. `Active Directory Domain Name Resolution` (the display name of this check)
appearing there is the same failure.

### 2. What it looks like: example failure signatures

The check emits one of these `Detail` strings per failing DNS server (the IP address,
the AD domain name, the node name, and the record count vary):

```
Queried dns server 10.0.0.10 for contoso.local on AzL-Node-01 (Attempt: 3/3). Result returned 0 A records. Expected at least 1. Error:
```

```
No DNS server configured
```

The first signature means the validator received no A records for the AD domain name
`contoso.local` after three attempts. The error suffix and the direct query in
[Quick fix](#quick-fix-start-here) distinguish an unreachable or failing DNS service
from a server that answered successfully with no matching record. The second signature
means the node's up adapters have no DNS server configured at all.

A passing node, for contrast, reports a count of one or more and lists the resolved
addresses, for example `Result returned 2 A records: 10.0.0.5, 10.0.0.6, expected at
least 1.`

On the rolled-up result (`AzStackHci_DNS_ActiveDirectoryDomainName`), the same failures
are listed one bullet per node, for example:

```
- AzL-Node-01
  - Queried dns server 10.0.0.10 for contoso.local on AzL-Node-01 (Attempt: 3/3). Result returned 0 A records. Expected at least 1. Error:
- AzL-Node-02
  - Queried dns server 10.0.0.10 for contoso.local on AzL-Node-02 (Attempt: 3/3). Result returned 0 A records. Expected at least 1. Error:
```

The meaning is the same as the per-node signature above; only the per-node bullet
layout differs.

### 3. Identify the affected nodes

Run across all nodes to see exactly which ones are failing and against which DNS
server:

```powershell
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    $node = $env:COMPUTERNAME
    $names = 'AzStackHci_DNS_ActiveDirectoryDomainName','AzStackHci_DNS_Test_ActiveDirectory_DomainName_Resolution'
    $escapedNode = [regex]::Escape($node)
    $localResults = @(
        Get-WinEvent -LogName AzStackHciEnvironmentChecker `
            -FilterXPath "*[System[(EventID=17205)]]" `
            -MaxEvents 2000 `
            -ErrorAction SilentlyContinue |
            ForEach-Object {
                $event = $_
                try { $result = $event.Message | ConvertFrom-Json } catch { return }
                if ($result.Name -notin $names) { return }

                $source = [string]$result.AdditionalData.Source
                $target = [string]$result.TargetResourceName
                $detail = [string]$result.AdditionalData.Detail
                $belongsToNode = (
                    $source -eq $node -or
                    $target -eq $node -or
                    $detail -match "(?i)\b$escapedNode\b"
                )
                if (-not $belongsToNode) { return }

                [pscustomobject]@{
                    Node       = $node
                    TimeCreated = $event.TimeCreated
                    ResultName = $result.Name
                    Status     = [string]$result.AdditionalData.Status
                    Source     = $source
                    Detail     = $detail
                }
            }
    )
    $latest = @($localResults | Sort-Object TimeCreated -Descending | Select-Object -First 1)
    if ($latest) {
        $latest
    } else {
        [pscustomobject]@{
            Node       = $node
            TimeCreated = $null
            ResultName = ''
            Status     = 'NO DATA'
            Source     = ''
            Detail     = 'No node-attributed Event ID 17205 DNS result was found. Run the direct DNS probe; do not assume PASS.'
        }
    }
} | Sort-Object Node | Format-Table -AutoSize
```

The query uses each node's local event channel and requires the payload's source,
target, or detail to identify that node. It never assigns a cluster-wide shared-file
result to the remoting target. `FAILURE` identifies a failing node; `SUCCESS`
identifies a passing result; `NO DATA` means to run the direct DNS probe rather than
assuming the node passed.

### Admin-surface map

The eight administrator surfaces are covered explicitly below. "Shown" means the
surface carries evidence for this check. "Not evident" means it is not an authoritative
place to look for this validator.

- **PowerShell on an Azure Local node:** **Shown.** Use the direct A-record probe,
  health-check result, Event ID 17205 query, and cross-node fan-out in this guide.
- **Azure portal:** **Shown.** Open the Azure Local cluster's **Updates** view. A failed
  pre-update health check names this validator there.
- **Windows event logs:** **Shown.** The `AzStackHciEnvironmentChecker` log carries
  Event ID 17205 with `AdditionalData.Status` and `AdditionalData.Detail`.
- **Cluster logs (`Get-ClusterLog`):** not evident in the cluster logs for this
  validator; use them only to correlate a separate cluster-network or membership event.
- **Windows Failover Cluster Manager (`cluadmin.msc`):** not evident in Failover
  Cluster Manager for this validator; it is not a clustered role, resource, or node
  property.
- **Windows Admin Center on a standalone host:** not evident in Windows Admin Center on
  a standalone host for this validator; use the node PowerShell and event-log paths.
- **Windows Admin Center in the Azure portal:** not evident in Windows Admin Center in
  the Azure portal for this validator; use the Azure portal **Updates** view instead.
- **Component and tool log files on disk:** **Shown.** The Environment Checker writes
  supporting files under `%USERPROFILE%\.AzStackHci` on the node and profile that ran
  the check:

  ```powershell
  $componentLogRoot = Join-Path $env:USERPROFILE '.AzStackHci'
  $componentFiles = @(Get-ChildItem $componentLogRoot -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match 'AzStackHciEnvironmentChecker|AzStackHciEnvironmentReport' } |
      Select-Object FullName, LastWriteTime, Length)
  $componentFiles
  $componentFiles | Select-String -Pattern 'ActiveDirectoryDomainName|Test_ActiveDirectory_DomainName_Resolution'
  ```

For the four not-evident surfaces, absence of a matching entry is not proof of health.
Use the shown PowerShell, event-log, portal, or component-log evidence instead.

### 4. Consequences if you do not fix this

This check is Critical. It fails the pre-update health check overall, and:

- A pending Azure Local update, an add-node operation, or a deployment that runs this
  readiness check will not proceed until the AD domain name resolves on every node.
- The cluster can keep running local workloads, but the affected lifecycle operation
  remains blocked. Guest workloads that independently use the same AD DNS path for user,
  service, or computer authentication can also be affected. This validator does not
  test those guest workloads or prove domain-controller location.

### 5. Remediation

The check fails when a DNS server configured on a node cannot resolve the cluster's
Active Directory domain name. The fix is a customer-side DNS change, either on the
node's DNS-client configuration or on the upstream DNS server. Work through this on
each node identified in Step 3.

**Most common fix (start here).** The usual cause is a node pointed at a DNS server that
does not host or forward the Active Directory domain zone (for example a node left on an
external-only resolver, or on the wrong server). Re-point that node's management adapter
at a DNS server that resolves the AD domain, normally a domain controller (step 2
below), or add a conditional forwarder for the AD domain on the current server (step 4
below). The numbered steps confirm which of these applies; most failures are resolved by
one of the two.

_New to any DNS term used below (A record, forwarder, conditional forwarder,
split-horizon)? See the [Glossary](#glossary) at the end of this guide._

1. Determine the AD domain name to resolve, and list the DNS servers currently
   configured on the node:

   ```powershell
   "AD domain: " + (Get-CimInstance Win32_ComputerSystem).Domain
   Get-DnsClientServerAddress -AddressFamily IPv4 |
       Where-Object ServerAddresses |
       Select-Object InterfaceAlias, @{ n = 'DnsServers'; e = { $_.ServerAddresses -join ', ' } }
   ```

2. Confirm these are the DNS servers the cluster is supposed to use, comparing against
   your documented management DNS servers (the ones that resolve the AD domain, normally
   your domain controllers). If this is a machine being deployed or added and it has no
   DNS server on its management adapter (the `No DNS server configured` signature), or
   the configured servers are wrong, set the correct values. If this is already a
   deployed cluster member, leave the node configuration unchanged and fix the
   configured DNS server upstream.

   First identify which adapter is the management adapter, so the placeholders below are
   concrete. It is the up adapter whose IPv4 address is the node's management IP; match
   that IP to an `InterfaceAlias` here, then reuse the same `InterfaceAlias` from Step 1
   to see the DNS servers currently on it:

   ```powershell
   Get-NetIPConfiguration | Where-Object { $_.IPv4Address } |
       Select-Object InterfaceAlias, @{ n = 'IPv4'; e = { $_.IPv4Address.IPAddress -join ', ' } }
   ```

   The correct `<dns1>`,`<dns2>` are your deployment's documented management DNS servers
   (the same ones the healthy nodes resolve against, normally your domain controllers).
   On a deployment-time node, capture the exact original values before the change:

   ```powershell
   $dnsSnapshot = @(Get-DnsClientServerAddress -InterfaceAlias '<ManagementAdapter>' -AddressFamily IPv4 |
       Select-Object InterfaceAlias, @{ n = 'ServerAddresses'; e = { @($_.ServerAddresses) } })
   $dnsSnapshot | ConvertTo-Json -Depth 3
   ```

   Keep this output in the change record. Then apply the documented addresses:

   ```powershell
   Set-DnsClientServerAddress -InterfaceAlias '<ManagementAdapter>' -ServerAddresses '<dns1>','<dns2>'
   ```

   If verification fails or remote connectivity degrades, restore the captured values
   from the same PowerShell session:

   ```powershell
   foreach ($entry in $dnsSnapshot) {
       Set-DnsClientServerAddress -InterfaceAlias $entry.InterfaceAlias -ServerAddresses @($entry.ServerAddresses)
   }
   ```

3. Test each configured DNS server the same way the validator does, resolving the AD
   domain name directly against that server. Limit the list to up adapters and preserve
   query errors:

   ```powershell
   $adDomain = (Get-CimInstance Win32_ComputerSystem).Domain
   $upAliases = @(Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -ExpandProperty Name)
   $dnsServers = @(Get-DnsClientServerAddress -AddressFamily IPv4 |
       Where-Object { $_.InterfaceAlias -in $upAliases -and $_.ServerAddresses } |
       ForEach-Object { $_.ServerAddresses } |
       Sort-Object -Unique)
   foreach ($dns in $dnsServers) {
       try {
           $records = @(Resolve-DnsName -Name $adDomain -Server $dns -Type A -DnsOnly -ErrorAction Stop)
           '{0}: PASS, {1} A record(s): {2}' -f $dns, $records.Count,
               (($records | ForEach-Object IPAddress) -join ', ')
       }
       catch {
           '{0}: FAILURE, query failed: {1}' -f $dns, $_.Exception.Message
       }
   }
   ```

   A correct result reports `PASS` and at least one A record for every configured DNS
   server. A query exception usually indicates DNS reachability, service, or protocol
   failure. A successful response with zero records indicates a zone, forwarding, or
   record problem.

4. Fix the failing DNS server, choosing the option that matches the environment:

   - If the configured server is wrong or stale, re-point the node at a DNS server that
     resolves the AD domain, normally a domain controller (Step 2).
   - If the configured server is correct but does not host the AD domain zone, add a
     conditional forwarder for the AD domain on that server, pointing at a domain
     controller (or otherwise enable AD domain resolution on it). This change is made on
     the DNS server, not on the Azure Local node, so coordinate with whoever owns that
     server.
   - If the configured server is a domain controller but still returns nothing, confirm
     the DC's DNS service is healthy and that the AD domain zone is present and loaded on
     it. A split-horizon or stale zone can shadow the expected records.
   - Confirm that DNS traffic on port 53 from the nodes to the DNS servers is not blocked
     by a firewall.

Re-pointing a node's DNS client is a [LOW RISK] change: it is per-node, immediate, and
reversible by restoring the captured previous servers, but it is supported here only
for a machine being deployed or added. Changing an upstream DNS server or domain
controller is a [MEDIUM RISK] change, because it can affect other systems that use it.
Coordinate with its owner. No node drain or reboot is required.

### Prevent recurrence before the next site

Before deploying another site or adding another node, run the [Quick fix](#quick-fix-start-here)
read-only probe from the candidate node or an equivalent host on the same management
network. Require every intended DNS server to return at least one A record for the AD
domain, and record the result with the deployment evidence. If the DNS server depends on
a conditional forwarder, validate that forwarder once for the customer environment
before repeating the deployment at additional sites.

### 6. Verification: prove the failure cleared

Re-run the pre-update health check. This writes a fresh result file to the cluster
shared volume and fresh event-log entries on every node:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

This typically takes several minutes depending on cluster size. When it finishes,
require `HealthState : Success` with a new `HealthCheckDate`, then re-run any option
from Step 1. The check should return no failing rows. Also confirm the exact A-record
prerequisite directly on each node:

```powershell
Resolve-DnsName -Name (Get-CimInstance Win32_ComputerSystem).Domain -Type A
```

A result containing one or more A records means the node can resolve the Active
Directory domain name. If Step 1 still shows failures, re-read the new `Detail` text:
the failure may have moved to a different DNS server or a different node that needs the
same fix.

If users, nodes, or workloads still cannot locate a domain controller after the A-record
check passes, test the separate SRV-record dependency:

```powershell
$adDomain = (Get-CimInstance Win32_ComputerSystem).Domain
Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$adDomain" -Type SRV -DnsOnly
```

One or more SRV answers identify domain-controller locator records. An A-record PASS
with an SRV failure is a separate AD DNS problem; this validator does not detect it.

> **Note:** the Azure portal readiness view and the cluster-wide `HealthCheckResult`
> file refresh only when a full health check or `Invoke-SolutionUpdatePrecheck -SystemHealth`
> runs, not
> on a targeted per-node re-test. The portal can therefore lag a just-applied fix until
> the next precheck or the periodic (roughly daily) health check, so confirm the fix
> on-node with `Resolve-DnsName` rather than waiting on the portal.

## Glossary

Plain-language definitions of the DNS terms used in this guide. Experienced readers can
skip this section; it is here so the steps above stay short.

- **A record:** the basic DNS record that maps a name (such as `contoso.local`) to an
  IPv4 address. This check passes only when a configured DNS server returns at least one
  A record for the Active Directory domain name.
- **DNS server / resolver:** the server a node asks to turn a name into an address. Each
  node lists one or more on its network adapters; this check tests each one.
- **Active Directory DNS zone / domain controller:** the DNS zone that holds the records
  for an AD domain (such as `contoso.local`). It is normally hosted on the domain
  controllers, which is why the DNS servers that resolve an AD domain are usually the
  domain controllers.
- **Forwarder:** a setting on a DNS server that hands off queries it cannot answer itself
  to another resolver that can.
- **Conditional forwarder:** a forwarder that applies only to a specific domain, so a
  server can send just the queries for the AD domain to a domain controller that hosts
  that zone. This is the usual way to make a non-AD DNS server resolve the AD domain.
- **Split-horizon (split-brain) DNS:** a setup where the same DNS name resolves
  differently for internal versus external clients. A stale or shadowing zone can cause a
  server to return nothing for the AD domain name this check asks for.
