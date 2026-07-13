# Azure_Kubernetes_Service_Cluster_connect

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>Azure_Kubernetes_Service_Cluster_connect</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Invoke-AzStackHciConnectivityValidation</code> (connectivity target "Cluster connect")</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Connectivity (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Warning</strong> in the Azure public cloud (non-blocking, but the Arc cluster-connect feature will not work until it is fixed); <strong>Critical</strong> in Azure Government (Fairfax). See the detection note.</td>
  </tr>
</table>

> **At a glance**
> - **What it is:** an Environment Validator (Environment Checker) connectivity check that confirms each Azure Local node can reach the **Azure Arc "cluster connect" endpoint** over outbound HTTPS. On each node it makes an outbound request to the Azure Relay (Service Bus relay) endpoint `azgnrelay-<region>-l1.servicebus.windows.net` on TCP 443 and passes when the endpoint answers.
> - **Why it matters:** cluster connect is the secure reverse tunnel that lets you reach Arc-enabled Kubernetes (AKS enabled by Azure Arc) on this cluster **without opening any inbound port**. If a node cannot reach the relay, `az connectedk8s proxy`, the Azure portal Kubernetes view, and cluster-connect-based `kubectl` access to the workload cluster stop working.
> - **Owner:** a **network / firewall / proxy / DNS** action. The fix is to allow the node's outbound connection to the relay endpoint; it is not an Azure Local configuration change.
> - **Read the Detail:** this check reports the outbound test result in a `Detail` string. The line `Test Analysis - Layer 3 (tnc): True/False` tells you whether the low-level TCP connection worked, which selects the right fix below.

## Overview

Azure Arc **cluster connect** provides a secure way to connect to Arc-enabled Kubernetes clusters (including AKS enabled by Azure Arc on Azure Local) from anywhere, without requiring any inbound port on the cluster's firewall. It works by having the node maintain an **outbound** connection to an Azure Relay (Service Bus relay) endpoint, and routing management traffic back down that connection. This check verifies that outbound path.

- **What the check does:** on each node it issues an outbound HTTPS request to the cluster-connect relay endpoint for the cluster's region, `azgnrelay-<region>-l1.servicebus.windows.net` (for example `azgnrelay-eastus-l1.servicebus.windows.net`), on TCP port **443**. Reaching the endpoint is a success **even if the endpoint replies `403`** - the check is proving *reachability*, not authentication, so any HTTP response from the real endpoint (commonly `200` or `403`) passes.
- **Severity:** the check is defined at **Warning** severity in the Azure public cloud, so a failure does **not** block a solution update, but the Arc cluster-connect feature is broken until it is fixed. In Azure Government (Fairfax) the same check is **Critical**.
- **When it runs:** the Connectivity validator runs during **Deployment**, **Update**, **Scale-out (Add Node)**, and **Upgrade** readiness, and can also be run standalone at any time (see step 1).
- **The failure is always the same class of problem:** the node's outbound connection to the relay endpoint did not complete. The `Detail` string tells you *where* it broke (DNS, TCP/firewall, proxy, or TLS inspection); step 2 maps each signature to its fix.

> **Most common in the field (start here).** The usual cause is a **firewall, proxy, or TLS-inspection appliance** that does not allow the node's outbound connection to `*.servicebus.windows.net` (the Azure Relay endpoints). Read the `Detail` string first (step 1), match the signature in step 2, and apply the matching fix in step 5.

## Requirements

- Outbound connectivity from **every** node to the Azure Local required endpoints, including the Azure Relay / Service Bus relay endpoints used by Arc cluster connect (`*.servicebus.windows.net`, specifically `azgnrelay-<region>-l1.servicebus.windows.net`) on TCP 443.
- If the cluster uses a **proxy**, the proxy must be configured on the nodes and must allow those endpoints.
- If the network uses **TLS inspection / deep packet inspection**, the Azure Relay endpoints must be **excluded** from interception (the relay uses a long-lived connection that inspection appliances frequently break).
- A cluster node (or a workstation with the `AzStackHci.EnvironmentChecker` module) to run `Invoke-AzStackHciConnectivityValidation` for authoritative confirmation.

## Troubleshooting Steps

### 1. Confirm the failure and see where it appears

**Run the connectivity validator directly (authoritative).** On a node (or a workstation with the Environment Checker module installed), run:

```powershell
Invoke-AzStackHciConnectivityValidation
```

Look for the **Azure Kubernetes Service -> Cluster connect** target in the output. A failing target is shown as **Needs Attention / Critical** with the relay URL and a help link. The run also writes its own log and report (see below), and the failing URL to `FailedUrls.txt`.

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
    $latest = Get-ChildItem $base -Filter 'HealthCheckResult.*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $latest) {
    Write-Warning "No HealthCheck result on this node; use Invoke-AzStackHciConnectivityValidation above, or read the AzStackHciEnvironmentChecker event log (Event ID 17205)."
}
else {
    Get-Content $latest.FullName -Raw | ConvertFrom-Json |
        Where-Object { $_.Name -eq 'Azure_Kubernetes_Service_Cluster_connect' -and $_.Status -ne 0 -and $_.Status -ne 'SUCCESS' } |
        ForEach-Object {
            [pscustomobject]@{
                Status = $_.Status
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
  Where-Object { $_.Name -like '*Azure_Kubernetes_Service_Cluster_connect*' } |
  Sort-Object { $_.Timestamp } -Descending |
  Select-Object -First 10 Status, @{n='Target';e={$_.TargetResourceID}}, @{n='Detail';e={$_.AdditionalData.Detail}}
```

**The Environment Checker also writes its own log and report on the node that ran the check.** By default these are under the running account's `%USERPROFILE%\.AzStackHci\` folder: the text log `AzStackHciEnvironmentChecker.log`, the machine-readable `AzStackHciEnvironmentReport.json`, and, for connectivity failures, `FailedUrls.txt` (the list of endpoints that failed). These files are local to the node that executed the check; search the log for `FAILURE` or the endpoint host to find this failure and its debug detail:

```powershell
Get-ChildItem C:\Users\*\.AzStackHci\AzStackHciEnvironmentChecker.log -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1 |
    Select-String -Pattern 'azgnrelay', 'FAILURE' | Select-Object -Last 20
```

If the customer noticed this because a pending update will not start, confirm whether it is blocking (this check is a Warning in the public cloud, so it usually is not the blocker there):

```powershell
Get-SolutionUpdate | Select-Object DisplayName, Version, State, HealthCheckResult, HealthCheckDate | Format-Table -AutoSize
```

**Where this does NOT appear.** This is an outbound-connectivity signal from the Environment Checker, not a Windows failover-cluster state, so do not spend time looking for it in the cluster tooling:

- **Cluster logs:** not evident in `Get-ClusterLog` (a connectivity-validator result is not a failover-cluster event and is never written there).
- **Windows Failover Cluster Manager:** not evident in Failover Cluster Manager (endpoint reachability is not a clustered role, resource, or node property).
- **Windows Admin Center (standalone host):** not evident for this check (a standalone Windows Admin Center may show a general Azure-connection warning, but does not distinctly flag the `Azure_Kubernetes_Service_Cluster_connect` result; confirm with `Invoke-AzStackHciConnectivityValidation` above or the Azure portal).
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
    $uri = 'azgnrelay-eastus-l1.servicebus.windows.net'   # replace <region> with the cluster's region
    $tnc = Test-NetConnection -ComputerName $uri -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    [pscustomobject]@{ TcpTo443 = $tnc }
} | Sort-Object PSComputerName | Select-Object PSComputerName, TcpTo443
```

Nodes returning `True` reach the endpoint at the TCP layer (any remaining failure is proxy or TLS inspection); nodes returning `False` are blocked at the firewall or DNS layer. Substitute the cluster's real region for `<region>` (read it from the `TargetResourceID` / `Detail` of the failing result in step 1).

### 4. Consequences if you do not fix this

While this check fails, **Azure Arc cluster connect does not work** for this cluster: you cannot reach Arc-enabled Kubernetes (AKS enabled by Azure Arc) through the secure reverse tunnel. That breaks `az connectedk8s proxy`, the Azure portal's Kubernetes resource view, and cluster-connect-based `kubectl` access to the workload cluster. In the Azure public cloud the check is a **Warning**, so it does not block a solution update, but the feature stays broken until outbound connectivity is restored. The cluster's local VMs and workloads keep running. In Azure Government (Fairfax) the check is **Critical** and blocks the update until it passes.

### 5. Remediation

Match the `Detail` signature from step 2 to the sub-mode and apply the matching fix. All of these are network-side changes; none of them drain nodes or disrupt running VMs. The canonical endpoint list is in [Azure Arc-enabled Kubernetes network requirements](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/network-requirements) and, for AKS on Azure Local, [AKS network requirements - firewall URL exceptions](https://learn.microsoft.com/en-us/azure/aks/hybrid/aks-hci-network-system-requirements#firewall-url-exceptions).

**Sub-mode: DNS resolution** (`The remote name could not be resolved`, `tnc: False`).

1. On an affected node, confirm the relay hostname resolves: `Resolve-DnsName azgnrelay-<region>-l1.servicebus.windows.net`.
2. If it does not resolve, fix the node's DNS: confirm `Get-DnsClientServerAddress` points at DNS servers that can resolve public Azure names (or the customer's forwarders that do). See [Troubleshooting Connectivity Test DNS](./Troubleshooting-Connectivity-Test-Dns.md) and [Troubleshooting DNS External DNS Resolution](./Troubleshooting-DNS-External-DNS-Resolution.md).
3. Re-test with step 1.

Risk: [LOW RISK]. Correcting DNS resolution does not disrupt running workloads.

**Sub-mode: firewall / outbound 443 blocked** (`Unable to connect to the remote server` or `timed out`, `tnc: False`).

1. Allow outbound **TCP 443** from every node to the Azure Relay endpoints used by cluster connect: `*.servicebus.windows.net` (specifically `azgnrelay-<region>-l1.servicebus.windows.net`). Add these to the firewall allow list per [Azure Arc-enabled Kubernetes network requirements](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/network-requirements) and the [AKS on Azure Local firewall URL exceptions](https://learn.microsoft.com/en-us/azure/aks/hybrid/aks-hci-network-system-requirements#firewall-url-exceptions).
2. Confirm no route or NSG drops the outbound connection to the relay.
3. Re-test with `Test-NetConnection azgnrelay-<region>-l1.servicebus.windows.net -Port 443` from the node.

Risk: [LOW RISK]. Allowing the documented outbound endpoint does not disrupt running workloads.

**Sub-mode: proxy** (`Unable to connect to the remote server`, `tnc: True`).

1. If the cluster uses a proxy, confirm the proxy is configured on the nodes and allows `*.servicebus.windows.net`. See the proxy guidance in [Troubleshooting External Connectivity Failures in Environment Checker](./Troubleshooting-External-Connectivity-Failures-in-Environment-Checker.md).
2. Confirm the node's proxy configuration (WinHTTP / environment) matches the cluster's documented proxy, and that the relay endpoints are not on a bypass list that routes them incorrectly.
3. Re-test with step 1.

Risk: [LOW RISK]. A proxy allow-list change does not disrupt running workloads.

**Sub-mode: TLS inspection** (`The underlying connection was closed: An unexpected error occurred on a send`, `tnc: True`).

1. Exclude the Azure Relay endpoints (`*.servicebus.windows.net`) from any TLS-inspection / deep-packet-inspection / SSL-interception appliance on the outbound path. The cluster-connect relay uses a long-lived connection that inspection appliances break.
2. Confirm with the network team that the relay endpoints are on the inspection bypass list.
3. Re-test with step 1.

Risk: [LOW RISK]. Excluding the endpoint from interception does not disrupt running workloads.

### 6. Verification: prove the failure cleared

Re-run the connectivity validator on the affected nodes and confirm the target is healthy:

```powershell
Invoke-Command -ComputerName (Get-ClusterNode).Name -ScriptBlock {
    Test-NetConnection azgnrelay-eastus-l1.servicebus.windows.net -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
} | Sort-Object PSComputerName
```

Every node should return `True` (substitute the cluster's region). Then re-run the pre-update health check so the validator re-evaluates and refreshes the cluster-wide readiness record:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

Confirm `HealthState` is `Success` with a current `HealthCheckDate`.

> **Note:** the Azure portal readiness view and the cluster-wide health-check result refresh only when a full health check or `Invoke-SolutionUpdatePrecheck` runs, not on a targeted per-node re-test, so confirm the fix with `Invoke-AzStackHciConnectivityValidation` or `Test-NetConnection` on the nodes rather than waiting on the portal.

## Glossary

- **Azure Arc cluster connect:** a feature that provides secure connectivity to Arc-enabled Kubernetes clusters from anywhere without opening any inbound port, by maintaining an outbound connection from the cluster to an Azure Relay endpoint. This check verifies that outbound path.
- **Azure Relay / Service Bus relay (`*.servicebus.windows.net`):** the Azure service that hosts the cluster-connect reverse tunnel. The per-region endpoint is `azgnrelay-<region>-l1.servicebus.windows.net`.
- **`Invoke-AzStackHciConnectivityValidation`:** the Environment Checker connectivity validator. It probes each required endpoint and reports the result, including this "Cluster connect" target. Run it standalone on a node or workstation to reproduce and verify.
- **`Test Analysis - Layer 3 (tnc)`:** the `Test-NetConnection` (TCP 443) result recorded in the `Detail`. `True` = TCP reached the endpoint (a remaining failure is proxy or TLS inspection); `False` = TCP or DNS failed (firewall or DNS).
- **AKS enabled by Azure Arc:** Azure Kubernetes Service running on Azure Local, managed through Azure Arc. Cluster connect is one of the paths used to reach it.
