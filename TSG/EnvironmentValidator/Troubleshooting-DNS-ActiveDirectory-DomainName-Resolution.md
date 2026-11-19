# AzStackHci_DNS_ActiveDirectoryDomainName

> **At a glance**
> - **Owner:** the customer's Active Directory or DNS administrator. This is not a Microsoft software defect and not an OEM hardware or firmware issue.
> - **Impact:** Critical. It blocks Azure Local deployment, add-node, and updates until every node can resolve the cluster's Active Directory domain name.
> - **Effort and downtime:** small. A per-node DNS change applies immediately, with no reboot, no cluster drain, and no impact to running VMs or live migration.
> - **Typical time to resolve:** about 15 to 30 minutes per affected node for a DNS-client fix once you have the correct DNS server addresses. Allow longer if the fix is an upstream DNS server change (a conditional forwarder or a domain-controller DNS fix) that must be coordinated with whoever owns that server.
> - **Before you change anything:** do not guess DNS server IP addresses. Get the cluster's intended DNS servers (the ones that resolve your Active Directory domain, normally your domain controllers) from your Active Directory or network administrator first.

## Overview

This Environment Validator check confirms that each Azure Local node can resolve the
cluster's Active Directory (AD) domain name. On every node, for each DNS server
configured on every network adapter that is up, the check resolves the AD domain
FQDN (for example `contoso.local`) and expects at least one A record back. If any
configured DNS server returns no records (or no DNS server is configured at all), the
check fails for that node.

- **Severity:** Critical. It blocks the pre-update health check and the deployment or
  add-node readiness check until the AD domain resolves on every node.
- **When it runs:** pre-deployment readiness, deployment, add-node, the pre-update
  health check, and site-assessment or update validation. In practice you will most
  often see it block a pending Azure Local update or an add-node operation.
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

**Who owns this fix.** This is a customer Active Directory and DNS configuration check.
The owner is the customer's Active Directory or DNS administrator. It is not a Microsoft
software defect, and it is not an OEM hardware or firmware issue, so it does not require
a hardware vendor or a Microsoft product fix. A Microsoft support engineer can guide the
customer through it, but the change itself is made in the customer's DNS infrastructure
or in a node's network configuration. The DNS servers that resolve an AD domain are
normally the domain controllers for that domain. If the DNS or Active Directory owner is
unresponsive, escalate within the customer's IT organization or open a Microsoft support
case for guidance; the change itself must still be made by whoever administers that DNS
or AD infrastructure.

**Where a node's DNS comes from.** A node's DNS servers are set at deployment time from
the deployment configuration's management network settings and applied to the management
network adapter; they are not baked into the OEM factory image. If you are an OEM or
field engineer checking your own imaging process, confirm the image does not pin DNS
servers and leaves them to be set by deployment, so each cluster picks up the customer's
intended DNS (the servers that resolve its AD domain) rather than a stale value carried
over from imaging.

## Requirements

- Administrative (local administrator) access to each Azure Local node, or a remote
  PowerShell session to the nodes.
- The cluster's Active Directory domain FQDN, and the DNS servers that resolve it
  (normally the domain controllers), from the deployment's network configuration.
- Access to, or coordination with, whoever administers those DNS servers, in case an
  upstream server needs a conditional forwarder or a domain-controller DNS fix.
- No maintenance window is required. A node DNS-client change applies immediately and
  does not need a reboot or a cluster drain.

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
        Where-Object { $_.Name -in $names -and $_.Status -ne 0 -and $_.Status -ne 'SUCCESS' } |
        Select-Object Severity,
            @{ n = 'Source';      e = { $_.AdditionalData.Source } },
            @{ n = 'Detail';      e = { $_.AdditionalData.Detail } },
            Remediation
}
```

Each row is one currently-failing DNS server on one node. The `Detail` column is the
precise error string; the `Remediation` column points at the public
[Azure Local network requirements](https://learn.microsoft.com/azure/azure-local/concepts/firewall-requirements)
documentation.

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
        if ($r.Name -in $names -and $r.Status -ne 0 -and $r.Status -ne 'SUCCESS') {
            [pscustomobject]@{
                TimeCreated = $_.TimeCreated
                Source      = $r.AdditionalData.Source
                Detail      = $r.AdditionalData.Detail
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

The first signature means the node reached the DNS server at that IP, but the server
returned no A records for the AD domain name `contoso.local` after three attempts. The
second means the node's up adapters have no DNS server configured at all.

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
    $base = 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System'
    if (-not (Test-Path $base)) {
        # Same fallback as Step 1 Option A: walk all ClusterStorage volumes.
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
        # Emit an explicit NO DATA row so this node is never silently treated as passing.
        return [pscustomobject]@{ Detail = 'NO DATA: no HealthCheck result file on this node (use Option C, the event log)' }
    }
    $failing = Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object { $_.Name -in $names -and $_.Status -ne 0 -and $_.Status -ne 'SUCCESS' } |
        Select-Object @{ n = 'Detail'; e = { $_.AdditionalData.Detail } }
    if ($failing) { $failing }
    else { [pscustomobject]@{ Detail = 'PASS: no failing AD domain DNS result in the latest health check' } }
} | Sort-Object PSComputerName | Select-Object PSComputerName, Detail
```

Every node now reports one of three things: a failing `Detail` (the node is failing,
fix it), `PASS` (the check passed on that node), or `NO DATA` (the result could not be
read on that node, so confirm it with Option C rather than assuming it passed).

### 4. Consequences if you do not fix this

This check is Critical. It fails the pre-update health check overall, and:

- A pending Azure Local update, an add-node operation, or a deployment that runs this
  readiness check will not proceed until the AD domain name resolves on every node.
- Resolving the Active Directory domain name is required for nodes to locate domain
  controllers for authentication, cluster identity, and AD-integrated operations. While
  the cluster keeps running local workloads, AD-dependent operations and its
  cloud-managed lifecycle are impaired until AD DNS resolution works.

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
   your domain controllers). If the node has no DNS server on its management adapter (the
   `No DNS server configured` signature), or the configured servers are wrong, set the
   correct ones (per node, applies immediately, no reboot).

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
   Record the original values first so the change can be rolled back, then set them on
   the management adapter:

   ```powershell
   Set-DnsClientServerAddress -InterfaceAlias '<ManagementAdapter>' -ServerAddresses '<dns1>','<dns2>'
   ```

3. Test each configured DNS server the same way the validator does, resolving the AD
   domain name directly against that server:

   ```powershell
   $adDomain = (Get-CimInstance Win32_ComputerSystem).Domain
   foreach ($dns in ((Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses | Sort-Object -Unique)) {
       $count = (Resolve-DnsName -Name $adDomain -Server $dns -Type A -DnsOnly -QuickTimeout -ErrorAction SilentlyContinue).Count
       '{0}: {1} A record(s)' -f $dns, ([int]$count)
   }
   ```

   A server reporting `0 A record(s)` is the failing one: the node reaches it, but it
   cannot resolve the AD domain name.

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
reversible by restoring the previous servers. Changing an upstream DNS server or domain
controller is a [MEDIUM RISK] change, because it can affect other systems that use it, so
coordinate with its owner. No node drain or reboot is required for DNS-client changes.

### 6. Verification: prove the failure cleared

Re-run the pre-update health check. This writes a fresh result file to the cluster
shared volume and fresh event-log entries on every node:

```powershell
Invoke-SolutionUpdatePrecheck
```

This typically takes several minutes depending on cluster size. When it finishes,
re-run any option from Step 1. The check should return no failing rows. You can also
confirm the underlying resolution directly on each node:

```powershell
Resolve-DnsName -Name (Get-CimInstance Win32_ComputerSystem).Domain -Type A
```

A result containing one or more A records means the node can resolve the Active
Directory domain name. If Step 1 still shows failures, re-read the new `Detail` text:
the failure may have moved to a different DNS server or a different node that needs the
same fix.

> **Note:** the Azure portal readiness view and the cluster-wide `HealthCheckResult`
> file refresh only when a full health check or `Invoke-SolutionUpdatePrecheck` runs, not
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
