<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "envchecker",
    "signal": "Azure_Kubernetes_Service_Azure_Arc|Azure_Kubernetes_Service_Cluster_connect"
  },
  "validation": {
    "fidelity_level": "L2",
    "technical_grade": "A",
    "reproduction_substrate": "vm",
    "automation_status": "proven",
    "last_validated": "2026-09-18",
    "spec_ref": "Azure_Kubernetes_Service_Cluster_connect"
  }
}
-->

## Table of contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Troubleshooting steps](#troubleshooting-steps)
- [Glossary](#glossary)
- [Source articles](#source-articles)

# Revision History

| Date | Version | Summary |
| --- | --- | --- |
| 2026-09-24 | 2.1 | Added cloud-aware result names, current severity, WebSocket requirements, and GitHub-compatible metadata. |
| 2026-09-18 | 2.0 | Added the publication contract, source-exact cloud endpoint guidance, and refreshed live validation evidence. |

# Azure_Kubernetes_Service_Cluster_connect

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>Azure_Kubernetes_Service_Azure_Arc</strong> in public Azure; <strong>Azure_Kubernetes_Service_Cluster_connect</strong> in Azure Government (Fairfax)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Invoke-AzStackHciConnectivityValidation</code> (target "Azure Arc" in public Azure; "Cluster connect" in Fairfax)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Connectivity (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong> and mandatory on current public Azure and Azure Government target definitions.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable scenarios</th>
    <td>Deployment, Update, Add Node, and Upgrade readiness</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected versions</th>
    <td>Versions whose active connectivity target set includes this check</td>
  </tr>
</table>

> **At a glance**
> - **What it is:** an Environment Validator (Environment Checker) connectivity check that confirms each Azure Local node can reach the **Azure Arc cluster-connect endpoint** over outbound HTTPS. Public Azure reports it under `Azure_Kubernetes_Service_Azure_Arc`; Fairfax reports it under `Azure_Kubernetes_Service_Cluster_connect`.
> - **Why it matters:** cluster connect is the secure reverse tunnel that lets you reach Arc-enabled Kubernetes (AKS enabled by Azure Arc) on this cluster **without opening any inbound port**. If a node cannot reach the relay, `az connectedk8s proxy`, the Azure portal Kubernetes view, and cluster-connect-based `kubectl` access to the workload cluster stop working.
> - **Owner:** a **network / firewall / proxy / DNS** action. The fix is to allow the node's outbound connection to the relay endpoint; it is not an Azure Local configuration change.
> - **Read the Detail:** this check reports the outbound test result in a `Detail` string. The line `Test Analysis - Layer 3 (tnc): True/False` tells you whether the low-level TCP connection worked, which selects the right fix below.

## Overview

Azure Arc **cluster connect** provides a secure way to connect to Arc-enabled Kubernetes clusters (including AKS enabled by Azure Arc on Azure Local) from anywhere, without requiring any inbound port on the cluster's firewall. It works by having the node maintain an **outbound** connection to an Azure Relay (Service Bus relay) endpoint, and routing management traffic back down that connection. This guide covers the same relay requirement under both source-defined result names:

| Cloud | Result name | Display title | Relay family |
| --- | --- | --- | --- |
| Public Azure | `Azure_Kubernetes_Service_Azure_Arc` | Azure Arc | `servicebus.windows.net` |
| Azure Government (Fairfax) | `Azure_Kubernetes_Service_Cluster_connect` | Cluster connect | `servicebus.usgovcloudapi.net` |

- **What the check does:** on each node it issues an outbound HTTPS request to the cluster-connect relay endpoint for the cluster's region, `azgnrelay-<region>-l1.servicebus.windows.net` (for example `azgnrelay-eastus-l1.servicebus.windows.net`), on TCP port **443**. Reaching the endpoint is a success **even if the endpoint replies `403`** - the check is proving *reachability*, not authentication, so any HTTP response from the real endpoint (commonly `200` or `403`) passes.
- **Severity:** current target definitions mark the relay endpoint **Critical** and mandatory in both public Azure and Fairfax. Older builds can carry earlier target definitions, so use the severity in the fresh result when investigating an older release.

> [!IMPORTANT]
> **Azure Government uses a different endpoint family.** The public-cloud relay
> pattern is `azgnrelay-<region>-l1.servicebus.windows.net`. Do not derive a
> Government hostname by replacing only the suffix. The source-defined Fairfax
> target uses a different name, for example
> `azgns-usgovvirginia-fairfax-1p-public.servicebus.usgovcloudapi.net`.
> Confirm and use the exact host emitted in the failing result's
> `TargetResourceID` or `Detail`. Testing or allowing a constructed commercial-style
> name does not clear the check, and the Government-cloud failure is Critical.
- **When it runs:** the Connectivity validator runs during **Deployment**, **Update**, **Scale-out (Add Node)**, and **Upgrade** readiness, and can also be run standalone at any time (see step 1).
- **The failure is always the same class of problem:** the node's outbound connection to the relay endpoint did not complete. The `Detail` string tells you *where* it broke (DNS, TCP/firewall, proxy, or TLS inspection); step 2 maps each signature to its fix.

> **Most common in the field (start here).** The usual cause is a **firewall,
> proxy, or TLS-inspection appliance** that does not allow the node's outbound
> connection to the exact relay hostname emitted by the failed result. Read the
> `Detail` string first (step 1), match the signature in step 2, and apply the
> matching fix in step 5.

## Requirements

- Outbound connectivity from **every** node to the exact Azure Relay / Service Bus
  relay hostname emitted by the failed result on TCP 443, with outbound WebSockets
  enabled through the enforcing firewall and proxy. Public-cloud hosts
  normally end in `servicebus.windows.net`; Azure Government hosts end in
  `servicebus.usgovcloudapi.net`.
- If the cluster uses a **proxy**, the proxy must be configured on the nodes and must allow those endpoints.
- If the network uses **TLS inspection / deep packet inspection**, the Azure Relay endpoints must be **excluded** from interception (the relay uses a long-lived connection that inspection appliances frequently break).
- A cluster node from which to run the pre-update health check and read its refreshed
  health-check JSON or Event ID 17205 result. The standalone
  `Invoke-AzStackHciConnectivityValidation` command is optional because the active
  manifest may omit the **Cluster connect** target.

## Troubleshooting Steps

### 1. Confirm the failure and see where it appears

**Run the connectivity validator directly.** On a node (or a workstation with the Environment Checker module installed), run:

```powershell
Invoke-AzStackHciConnectivityValidation
```

Look for **Azure Kubernetes Service -> Azure Arc** in public Azure or **Azure Kubernetes Service -> Cluster connect** in Fairfax. A failing target is shown as **Needs Attention / Critical** with the relay URL and a help link. The run also writes its own log and report (see below), and the failing URL to `FailedUrls.txt`.

> **Note:** this target is validated as part of the cluster's **pre-update / deployment readiness** run, and on newer builds it may not appear in every ad-hoc standalone `Invoke-AzStackHciConnectivityValidation` run (the connectivity target set is versioned). So the **authoritative** confirmation for this specific check is the pre-update health-check result below (the `HealthCheckResult.EnvironmentChecker.*.json`, Event ID 17205, or the portal Updates tab), which is populated by the readiness run that actually evaluates it. After running the exact-host extraction block later in this step, use `Test-NetConnection -ComputerName $relayHost -Port 443` to test raw reachability, and use the health-check result to confirm the check's own pass/fail.

**Read the newest health-check result on a node** and flag this check:

```powershell
$base = 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System'
if (-not (Test-Path $base)) {
    $base = Get-ChildItem 'C:\ClusterStorage' -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'Shares\SU1_Infrastructure_1\Updates\HealthCheck\System' } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}
$latest = $null
if ($base) {
    # Use the Environment Checker result file specifically. The folder also holds
    # HealthCheckResult.CheckCloudHealth.*.json (other checks), so a broad filter could
    # pick a newer unrelated file and wrongly report no match for this validator.
    $latest = Get-ChildItem $base -Filter 'HealthCheckResult.EnvironmentChecker.*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $latest) {
    Write-Warning "No HealthCheck result on this node; use Invoke-AzStackHciConnectivityValidation above, or read the AzStackHciEnvironmentChecker event log (Event ID 17205)."
}
else {
    Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object {
            ($_.Name -like '*Azure_Kubernetes_Service_Azure_Arc*' -or
             $_.Name -like '*Azure_Kubernetes_Service_Cluster_connect*') -and
            ("$($_.TargetResourceID) $($_.AdditionalData.Detail)" -match
                '\.servicebus\.(windows\.net|usgovcloudapi\.net)') -and
            $_.Status -ne 0 -and $_.Status -ne 'SUCCESS'
        } |
        ForEach-Object {
            [pscustomobject]@{
                Status = if ($_.AdditionalData.Status) { $_.AdditionalData.Status } else { $_.Status }
                Source = $_.AdditionalData.Source
                Target = $_.TargetResourceID
                Detail = $_.AdditionalData.Detail
            }
        }
}
```

The same result is on the Windows event log as **Event ID 17205** in `AzStackHciEnvironmentChecker`, and in the Azure portal on the cluster's **Updates** tab when a pre-update health check fails. When the cluster share is unreadable, read the same result straight from the event log:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath "*[System[(EventID=17205)]]" |
  ForEach-Object { try { $_.Message | ConvertFrom-Json } catch { } } |
  Where-Object {
      ($_.Name -like '*Azure_Kubernetes_Service_Azure_Arc*' -or
       $_.Name -like '*Azure_Kubernetes_Service_Cluster_connect*') -and
      ("$($_.TargetResourceID) $($_.AdditionalData.Detail)" -match
          '\.servicebus\.(windows\.net|usgovcloudapi\.net)')
  } |
  Sort-Object { $_.Timestamp } -Descending |
  Select-Object -First 10 `
    @{n='Status';e={
        if ($_.AdditionalData.Status) { $_.AdditionalData.Status }
        else { $_.Status }
    }},
    @{n='Target';e={$_.TargetResourceID}},
    @{n='Detail';e={$_.AdditionalData.Detail}}
```

**The Environment Checker also writes its own log and report on the node that ran the check.** By default these are under the running account's `%USERPROFILE%\.AzStackHci\` folder: the text log `AzStackHciEnvironmentChecker.log`, the machine-readable `AzStackHciEnvironmentReport.json`, and, for connectivity failures, `FailedUrls.txt` (the list of endpoints that failed). These files are local to the node that executed the check; search the log for `FAILURE` or the endpoint host to find this failure and its debug detail:

```powershell
Get-ChildItem C:\Users\*\.AzStackHci\AzStackHciEnvironmentChecker.log -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1 |
    Select-String -Pattern 'azgnrelay', 'FAILURE' | Select-Object -Last 20
```

**Resolve the exact relay hostname before any network test.** Do not construct a
hostname from a region. The public and Fairfax targets use different naming
families. The following reads the newest local Event ID 17205 result and extracts
the source-emitted Service Bus hostname from `TargetResourceID` or `Detail`:

```powershell
$clusterConnectResult = Get-WinEvent -LogName AzStackHciEnvironmentChecker `
    -FilterXPath "*[System[(EventID=17205)]]" -MaxEvents 2000 |
    ForEach-Object {
        try { $_.Message | ConvertFrom-Json }
        catch { $null }
    } |
    Where-Object {
        ($_.Name -like '*Azure_Kubernetes_Service_Azure_Arc*' -or
         $_.Name -like '*Azure_Kubernetes_Service_Cluster_connect*') -and
        ("$($_.TargetResourceID) $($_.AdditionalData.Detail)" -match
            '\.servicebus\.(windows\.net|usgovcloudapi\.net)')
    } |
    Sort-Object { $_.Timestamp } -Descending |
    Select-Object -First 1

if (-not $clusterConnectResult) {
    throw 'No Azure Arc or Cluster connect Event ID 17205 result was found. Run the precheck, then retry.'
}

$targetText = @(
    [string]$clusterConnectResult.TargetResourceID
    [string]$clusterConnectResult.AdditionalData.Detail
) -join ' '
$hostMatch = [regex]::Match(
    $targetText,
    '(?i)(?<host>[a-z0-9][a-z0-9.-]*\.servicebus\.(?:windows\.net|usgovcloudapi\.net))'
)
if (-not $hostMatch.Success) {
    throw 'The emitted result did not contain a Service Bus hostname. Preserve the result and escalate.'
}
$relayHost = $hostMatch.Groups['host'].Value
"Exact emitted relay host: $relayHost"
```

If the customer noticed this because a pending update will not start, confirm whether this Critical result is the blocker:

```powershell
Get-SolutionUpdate | Select-Object DisplayName, Version, State, HealthCheckResult, HealthCheckDate | Format-Table -AutoSize
```

**Where this does NOT appear.** This is an outbound-connectivity signal from the Environment Checker, not a Windows failover-cluster state, so do not spend time looking for it in the cluster tooling:

- **Cluster logs:** not evident in `Get-ClusterLog` (a connectivity-validator result is not a failover-cluster event and is never written there).
- **Windows Failover Cluster Manager:** not evident in Failover Cluster Manager (endpoint reachability is not a clustered role, resource, or node property).
- **Windows Admin Center (standalone host):** not evident for this check (a standalone Windows Admin Center may show a general Azure-connection warning, but does not distinctly flag the `Azure_Kubernetes_Service_Azure_Arc` or `Azure_Kubernetes_Service_Cluster_connect` relay result; confirm with `Invoke-AzStackHciConnectivityValidation` above or the Azure portal).
- **Windows Admin Center in the Azure portal:** not evident for this check (use the cluster's **Updates** blade or run the validator on the node instead).

### 2. What it looks like: example failure signatures

A healthy node reports `Test Analysis - Overall Result: True` with an HTTP `StatusCode` of `200` (or `403` - both mean the endpoint was reached). A node that needs attention reports `Overall Result: False` with one of the following `Detail` signatures. The line `Test Analysis - Layer 3 (tnc): True/False` is the key discriminator: `tnc` is the result of `Test-NetConnection` to the endpoint on 443, so `True` means the TCP connection worked and the failure is higher up the stack (proxy or TLS inspection), while `False` means even the TCP/DNS layer failed (firewall or DNS).

**Sub-mode 1: DNS resolution failure** (`tnc: False`).

```
Test Analysis - Overall Result: False
Test Analysis - Exception Message: The remote name could not be resolved: 'azgnrelay-eastus-l1.servicebus.windows.net'
Test Analysis - Layer 3 (tnc): False
```

The node cannot resolve the relay hostname. This is a DNS problem (step 5, "DNS resolution").

**Sub-mode 2: TCP blocked by the firewall** (`tnc: False`).

```
Test Analysis - Overall Result: False
Test Analysis - Exception Message: Unable to connect to the remote server
Test Analysis - Layer 3 (tnc): False
```

or

```
Test Analysis - Exception Message: The operation has timed out.
Test Analysis - Layer 3 (tnc): False
```

DNS resolved, but the TCP connection to the endpoint on 443 never completed. A firewall or route is blocking the outbound connection (step 5, "Firewall / outbound 443 blocked").

**Sub-mode 3: proxy or application-layer block** (`tnc: True`).

```
Test Analysis - Overall Result: False
Test Analysis - Exception Message: Unable to connect to the remote server
Test Analysis - Layer 3 (tnc): True
```

The raw TCP connection worked (`tnc: True`), but the HTTPS request still failed. A proxy that the node is not configured to use, or that is refusing the request, is the usual cause (step 5, "Proxy").

**Sub-mode 4: TLS inspection breaking the connection** (`tnc: True`).

```
Test Analysis - Overall Result: False
Test Analysis - Exception Message: The underlying connection was closed: An unexpected error occurred on a send.
Test Analysis - Layer 3 (tnc): True
```

The TCP connection worked, then the TLS session was torn down mid-handshake. A TLS-inspection / deep-packet-inspection appliance is intercepting the connection to the Azure Relay endpoint, which the long-lived relay connection does not tolerate (step 5, "TLS inspection").

> A transient network blip can produce a one-off failure. If the `Detail` shows `Overall Result: True` on a later run, it has recovered. If it persists, match the signature above and apply the fix.

### 3. Identify the affected nodes

The check runs per node, so confirm which nodes fail and re-test the endpoint directly from each:

```powershell
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    param($ExactRelayHost)
    $tnc = Test-NetConnection -ComputerName $ExactRelayHost -Port 443 `
        -InformationLevel Quiet -WarningAction SilentlyContinue
    [pscustomobject]@{ TcpTo443 = $tnc }
} -ArgumentList $relayHost |
    Sort-Object PSComputerName |
    Select-Object PSComputerName, TcpTo443
```

Nodes returning `True` reach the exact emitted endpoint at the TCP layer (any
remaining failure is proxy or TLS inspection); nodes returning `False` are
blocked at the firewall or DNS layer. Run the relay-host extraction block above
in the same session before this test.

### 4. Consequences if you do not fix this

While this check fails, **Azure Arc cluster connect does not work** for this cluster: you cannot reach Arc-enabled Kubernetes (AKS enabled by Azure Arc) through the secure reverse tunnel. That breaks `az connectedk8s proxy`, the Azure portal's Kubernetes resource view, and cluster-connect-based `kubectl` access to the workload cluster. Current public Azure and Fairfax target definitions mark this relay endpoint Critical and mandatory, so it can block readiness until outbound connectivity is restored. The cluster's local VMs and workloads keep running.

### 5. Remediation

Match the `Detail` signature from step 2 to the sub-mode and apply **only** the matching fix. The canonical endpoint list is in [Azure Arc-enabled Kubernetes network requirements](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/network-requirements) and, for AKS on Azure Local, [AKS enabled by Azure Arc network requirements](https://learn.microsoft.com/en-us/azure/aks/aksarc/network-system-requirements#firewall-url-exceptions).

> [!IMPORTANT]
> **Apply one sub-mode fix at a time, and stop when the check passes.** Every fix below
> changes network configuration that other systems depend on. If you are unsure which
> sub-mode applies, re-read step 2 rather than applying several fixes at once.
>
> **These changes are owned by the customer's network or platform team**, not by this
> guide. DNS servers, firewall rules, proxy configuration, and TLS-inspection policy are
> all outside the Azure Local support boundary. Confirm the change with the owning team
> and follow the customer's change process before you make it. Record the current value
> first so every change can be reversed.

**Sub-mode: DNS resolution** (`The remote name could not be resolved`, `tnc: False`).

> [!WARNING]
> A cluster node's DNS configuration is also how it finds Active Directory, the cluster
> name, and its own management endpoints. Pointing a node at a public resolver such as
> `8.8.8.8` to make this one lookup succeed will break domain and cluster name
> resolution. **Never point a node at a public resolver, whether by replacing its DNS servers
> or by adding one to the list.** An added public resolver still gets used for lookups and
> still breaks Active Directory and cluster name resolution intermittently, which is harder to
> diagnose than an outright break. The correct fix is to make
> the customer's existing DNS servers resolve the public name, normally by fixing their
> forwarders.

1. Run the relay-host extraction block in step 1, then confirm the exact emitted
   hostname resolves: `Resolve-DnsName -Name $relayHost`.
2. Record the current setting before changing anything, so the change is reversible:

   ```powershell
   Get-DnsClientServerAddress -AddressFamily IPv4 |
       Select-Object InterfaceAlias, InterfaceIndex, ServerAddresses
   ```

3. If it does not resolve, the fix belongs on the DNS servers the node already uses: confirm `Get-DnsClientServerAddress` points at the customer's DNS servers, and have the DNS owner make those servers resolve public Azure names (normally by correcting their forwarders). Do not repoint the node. See [Troubleshooting Connectivity Test DNS](./Troubleshooting-Connectivity-Test-Dns.md) and [Troubleshooting DNS External DNS Resolution](./Troubleshooting-DNS-External-DNS-Resolution.md).
4. Re-test with step 1.

Risk: [MEDIUM RISK] if a node's DNS servers are changed, because a node's DNS configuration also serves Active Directory and cluster name resolution, and a wrong value can break domain join, cluster communication, and management. [LOW RISK] when the fix is made on the DNS servers themselves (correcting forwarders), which is the recommended path and does not disrupt running workloads.

**Sub-mode: firewall / outbound 443 blocked** (`Unable to connect to the remote server` or `timed out`, `tnc: False`).

1. Allow outbound **TCP 443** and WebSocket upgrade traffic from every node to the exact relay hostname
   extracted from the emitted result. Add the applicable endpoint to the firewall
   allow list per [Azure Arc-enabled Kubernetes network requirements](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/network-requirements)
   and [AKS enabled by Azure Arc network requirements](https://learn.microsoft.com/en-us/azure/aks/aksarc/network-system-requirements#firewall-url-exceptions).
   This is normally the **perimeter or edge firewall**, not the Windows firewall
   on the node. Confirm with the network owner which device enforces the block.
2. Confirm no route or Network Security Group (NSG) drops the outbound connection to the relay. Route and NSG changes are owned by the network team.
3. Re-test with `Test-NetConnection -ComputerName $relayHost -Port 443` from
   the node.

Risk: [LOW RISK] to the cluster. Allowing the documented outbound endpoint does not disrupt running workloads, but it is a change to customer network policy and needs the network owner's approval.

**Sub-mode: proxy** (`Unable to connect to the remote server`, `tnc: True`).

1. If the cluster uses a proxy, confirm the proxy is configured on the nodes and
   allows the exact `$relayHost` extracted from the emitted result in step 1. Do not
   substitute a commercial wildcard for a Government-cloud host. Public-cloud hosts
   normally end in `servicebus.windows.net`; Azure Government hosts end in
   `servicebus.usgovcloudapi.net`. The proxy must permit outbound WebSocket upgrades
   for the relay connection, not only ordinary HTTPS requests. See the proxy guidance in
   [Troubleshooting External Connectivity Failures in Environment Checker](./Troubleshooting-External-Connectivity-Failures-in-Environment-Checker.md).
2. Confirm the node's proxy configuration matches the cluster's documented proxy, and that the relay endpoints are not on a bypass list that routes them incorrectly. Read the current values before changing them:

   ```powershell
   netsh winhttp show proxy
   [Environment]::GetEnvironmentVariable('HTTPS_PROXY','Machine')
   [Environment]::GetEnvironmentVariable('HTTP_PROXY','Machine')
   [Environment]::GetEnvironmentVariable('NO_PROXY','Machine')
   ```

   Report a mismatch to the platform owner rather than editing it ad hoc: the proxy configuration is applied and maintained by the Azure Local deployment, and an out-of-band edit can be overwritten or can break other platform traffic.
3. Re-test with step 1.

Risk: [MEDIUM RISK] if node proxy settings are edited directly, because the proxy carries all node outbound traffic including Arc and update traffic. [LOW RISK] for a proxy allow-list change made on the proxy itself.

**Sub-mode: TLS inspection** (`The underlying connection was closed: An unexpected error occurred on a send`, `tnc: True`).

1. Exclude the exact `$relayHost` extracted from the emitted result in step 1 from
   any TLS-inspection, deep-packet-inspection, or SSL-interception appliance on the
   outbound path. This covers both `servicebus.windows.net` and
   `servicebus.usgovcloudapi.net` without constructing a cloud-specific hostname.
   These middleboxes terminate and re-sign TLS so they can inspect the traffic; the
   cluster-connect relay uses a long-lived connection that they break.
2. Confirm with the network team that the relay endpoints are on the inspection bypass list. This is a security-policy change and needs their approval and their change record.
3. Re-test with step 1.

Risk: [LOW RISK] to the cluster. Excluding the endpoint from interception does not disrupt running workloads, but it changes the customer's security enforcement and must be agreed with the security or network owner.

### 6. Verification: prove the failure cleared

**Re-run the actual check (authoritative for every sub-mode).** The validator makes the real HTTPS request to the endpoint, so it is the only reliable confirmation for the proxy and TLS-inspection sub-modes (where the TCP layer already succeeds while HTTPS still fails). Re-run the pre-update health check so the validator re-evaluates and refreshes the cluster-wide readiness record:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

Confirm `HealthState` is `Success` with a current `HealthCheckDate`.

> [!NOTE]
> `HealthState` is the **aggregate** result of the whole pre-update health check,
> not this one target. An unrelated failure can keep it non-`Success`. Confirm
> this target in the refreshed `HealthCheckResult.EnvironmentChecker.*.json` or
> the newest Event ID 17205 result and require readable `AdditionalData.Status =
> SUCCESS`. If the current standalone manifest emits the relevant **Azure Arc** or
> **Cluster connect** relay target,
> `Invoke-AzStackHciConnectivityValidation` is an additional confirmation. Do not
> require that standalone target when the active manifest omits it.

**Quick lower-layer check (DNS and firewall/TCP sub-modes only).** For sub-modes 1 and 2, `Test-NetConnection` confirms the DNS/TCP layer is now open:

```powershell
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    param($ExactRelayHost)
    Test-NetConnection -ComputerName $ExactRelayHost -Port 443 `
        -InformationLevel Quiet -WarningAction SilentlyContinue
} -ArgumentList $relayHost | Sort-Object PSComputerName
```

Every node should return `True` for the exact emitted host. Run the relay-host
extraction block from step 1 in the same session first. `True` only proves the TCP
connection succeeds; for the **proxy** and **TLS-inspection** sub-modes it does
**not** prove the fix, so confirm those with the refreshed per-target result above.

> **Note:** the Azure portal readiness view and the cluster-wide health-check result
> refresh only when a full health check or `Invoke-SolutionUpdatePrecheck` runs, not
> on a targeted per-node re-test. Confirm the fix with the refreshed per-target JSON
> or Event ID 17205 result from the precheck rather than waiting on the portal. Use
> `Invoke-AzStackHciConnectivityValidation` only as an additional confirmation when
> its active manifest includes the relevant **Azure Arc** or **Cluster connect** relay
> target.

## Glossary

- **Azure Arc cluster connect:** a feature that provides secure connectivity to Arc-enabled Kubernetes clusters from anywhere without opening any inbound port, by maintaining an outbound connection from the cluster to an Azure Relay endpoint. This check verifies that outbound path.
- **Result name:** public Azure emits `Azure_Kubernetes_Service_Azure_Arc` with title **Azure Arc**; Fairfax emits `Azure_Kubernetes_Service_Cluster_connect` with title **Cluster connect** for the relay endpoint.
- **Azure Relay / Service Bus relay:** the Azure service that hosts the cluster-connect
  reverse tunnel. Public-cloud hosts normally use `servicebus.windows.net`; Azure
  Government hosts use `servicebus.usgovcloudapi.net`. Always read the exact hostname
  from the failed result instead of constructing it.
- **`Invoke-AzStackHciConnectivityValidation`:** the standalone Environment Checker
  connectivity validator. Its target set is manifest-dependent and may omit
  **Cluster connect**. When the target is absent, confirm this check through the
  refreshed pre-update health-check JSON or Event ID 17205 result.
- **`Test Analysis - Layer 3 (tnc)`:** the `Test-NetConnection` (TCP 443) result recorded in the `Detail`. `True` = TCP reached the endpoint (a remaining failure is proxy or TLS inspection); `False` = TCP or DNS failed (firewall or DNS).
  > **Note on the label.** The validator prints "Layer 3", but `Test-NetConnection -Port 443`
  > completes a **TCP** handshake, which is layer 4. Read the field as "did name resolution
  > plus a direct TCP connection succeed", not as an IP-layer test. It is also **not**
  > proxy-aware: `Test-NetConnection` connects directly, while the validator's HTTPS request
  > honors the node's proxy. On a network where direct 443 is blocked and all traffic must go
  > through a proxy, `tnc` can therefore read `False` even though the proxy path is the only
  > supported route, so treat `tnc: False` plus a configured proxy as the proxy sub-mode, not
  > automatically as a firewall problem.
- **AKS enabled by Azure Arc:** Azure Kubernetes Service running on Azure Local, managed through Azure Arc. Cluster connect is one of the paths used to reach it.

# Source Articles

- [Azure Arc-enabled Kubernetes network requirements](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/network-requirements)
- [AKS enabled by Azure Arc network requirements](https://learn.microsoft.com/en-us/azure/aks/aksarc/network-system-requirements)
