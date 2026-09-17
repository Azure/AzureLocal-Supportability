<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "envchecker",
    "signal": "Invoke-AzStackHciConnectivityValidation"
  },
  "validation": {
    "fidelity_level": "L2",
    "technical_grade": "A",
    "reproduction_substrate": "vm",
    "automation_status": "one-off-live-driver",
    "last_validated": "2026-09-17",
    "spec_ref": ""
  }
}
-->

# Troubleshooting external connectivity failures in Environment Checker

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>External connectivity failures in Environment Checker</strong></td>
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
    <td><code>Invoke-AzStackHciConnectivityValidation</code>, including the <code>ValidateConnectivity</code> fabric action</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Environment Validator / Environment Checker connectivity</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable scenarios</th>
    <td>Deployment, update, scale out, upgrade, and standalone readiness validation</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical when a mandatory target fails</strong>. The affected deployment, update, scale-out, or upgrade readiness action remains blocked.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The customer's network, firewall, proxy, or security administrator owns access-control changes. Microsoft support can interpret evidence and identify product-target drift. This is not normally an OEM hardware or firmware issue.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Allow 15 to 30 minutes to collect evidence from all nodes. Network remediation time depends on the customer's change process.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>Existing local VMs normally continue running, but deployment, updates, Arc services, billing, telemetry, remote support, or workload provisioning can remain blocked or degraded.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Risk summary</th>
    <td>All node commands in this guide are read-only. Firewall, proxy, TLS-inspection, DNS, or routing changes are shared-infrastructure changes and require the owning team's review and rollback plan.</td>
  </tr>
</table>

> **At a glance**
> - **Fastest safe action:** run the validator on every node, collect the failed target, exception, TCP result, proxy response, and redirect destination, then give that evidence to the network owner.
> - **Workload impact:** the commands in this guide do not drain nodes, restart services, reboot hosts, or interrupt running VMs. The blocked fabric operation remains unavailable until every mandatory target passes.
> - **Ownership boundary:** this is usually a customer network-control issue. Engage the OEM only if an OEM image or appliance configured the proxy, certificate trust, or network policy. Engage Microsoft support or the Environment Validator product group when the target definition appears stale, moved, or inconsistent with the current manifest.
> - **Do not hardcode an old redirect path:** `https://aka.ms/hciconnectivitytargets` is a short link. Its destination and versioned path can change between releases.

> **Customer-facing status:** Azure Local can reach the network but one or more required service endpoints are not completing the expected web request. Existing local workloads normally continue, but the pending deployment or lifecycle action remains blocked. The next step is for the network or proxy owner to allow the exact failed destination, including any redirect target, and then for the cluster administrator to run a fresh validation on every node.

## Quick fix

1. Run the [cluster-wide evidence command](#collect-results-from-every-node).
2. Identify the failed hostname, the node or nodes affected, and the diagnostic branch in the [decision table](#classify-the-failure).
3. Have the network owner apply the narrowest change that permits the required traffic.
4. Run [Verify the fix](#verify-the-fix) in a fresh PowerShell process on every node.

Do not add a broad internet allow rule, disable TLS inspection globally, or bypass the
customer's proxy. The required change should be limited to the exact service endpoint,
protocol, port, source nodes, and current redirect destination.

## What the validator checks

Environment Checker tests Azure Local nodes against a connectivity-target manifest. The
manifest identifies service endpoints, protocols, severity, applicable operations, and
remediation references. A standalone run and a fabric operation use the same underlying
connectivity logic, but the visible result can differ by release and operation.

The validator can run during:

- standalone environment readiness validation;
- deployment;
- update health checks;
- scale out or add-node workflows;
- upgrade.

A target can also be conditional. For example, a target can apply only to a particular
operation, Azure service, Arc Gateway state, or optional workload. Therefore, a target
that exists in the manifest might not appear in every validator run.

### The target list moves with the product

The online manifest is reached through:

```text
https://aka.ms/hciconnectivitytargets
```

As of September 17, 2026, that short link redirects to a versioned file under:

```text
https://azurestackreleases.download.prss.microsoft.com/dbazure/AzureLocal/ConnectivityTargets/10.2607.0.2005/AzStackHciConnectivityTargets-Global.xml
```

Older logs and older versions of this article can show an
`AzureStackHCI/OnRamp/<version>` path instead. That older path is historical evidence,
not a current allow-list value. Always resolve the short link again at the time of the
incident.

Use this read-only command to record the current final URL:

```powershell
$manifestUri = 'https://aka.ms/hciconnectivitytargets'
$response = Invoke-WebRequest -Uri $manifestUri -UseBasicParsing -MaximumRedirection 10
[pscustomobject]@{
    RequestedUri = $manifestUri
    FinalUri     = $response.BaseResponse.ResponseUri.AbsoluteUri
    StatusCode   = [int]$response.StatusCode
    RetrievedUtc = [DateTime]::UtcNow
}
```

To enumerate the effective target IDs from the current manifest:

```powershell
$manifestUri = 'https://aka.ms/hciconnectivitytargets'
$response = Invoke-WebRequest -Uri $manifestUri -UseBasicParsing -MaximumRedirection 10
[xml]$manifest = $response.Content

$manifest.SelectNodes("//Property[@Name='TargetResourceID']") |
    ForEach-Object { $_.InnerText.Trim() } |
    Where-Object { $_ } |
    Sort-Object -Unique
```

If the first command reaches `aka.ms` but the redirect destination fails, the short-link
host is already allowed and the current destination is not. The network owner must review
both hosts. Do not assume that allowing only `aka.ms` is sufficient.

## Symptoms

You can encounter the failure in one of these forms:

- `Invoke-AzStackHciConnectivityValidation` reports **Needs Attention** or a failed
  external endpoint.
- A deployment, scale-out, or upgrade action fails in the `ValidateConnectivity`
  Environment Validator role with `Connectivity requirements not met`.
- A pre-update health check reports one or more connectivity results whose
  `AdditionalData.Status` is `FAILURE`.
- `%USERPROFILE%\.AzStackHci\FailedUrls.txt` contains one or more destinations.
- The Environment Checker log records `FAILURE` and a diagnostic object for the URL.

The failure can affect one node, a subset of nodes, or every node. Do not treat a passing
result from one node as cluster-wide success.

## Terms

| Term | Plain-language definition |
| --- | --- |
| Endpoint or target | The hostname or URL that Azure Local must reach for a service operation. |
| Manifest | The current list of connectivity targets and the conditions under which each target is tested. |
| Redirect | A web response that tells the client to make a second request to a different URL. Both destinations can require access. |
| Proxy | An intermediary that makes web requests for the node. A proxy can return its own HTTP status instead of the service's response. |
| TLS inspection | A security device decrypts and re-encrypts HTTPS traffic. Trust or protocol incompatibility can close the connection after TCP succeeds. |
| Transport or TCP result | Whether the node can establish the lower-level network connection, usually TCP 443. This does not prove that the HTTPS request succeeded. |
| HTTP response | A web-layer status such as 200, 301, 403, 407, or 503. The responding server and final URL determine whether the response came from the required service or an intermediary. |
| IPS or application firewall | A security control that can block or reset traffic after the network connection is established. |

## Where this failure appears

### PowerShell on an Azure Local node: shown

Run the validator from an elevated PowerShell session:

```powershell
Import-Module AzStackHci.EnvironmentChecker -Force
$results = @(Invoke-AzStackHciConnectivityValidation -PassThru)

$results |
    Where-Object {
        $_.AdditionalData.Status -eq 'FAILURE' -or
        "$($_.Status)" -eq 'FAILURE' -or
        "$($_.Status)" -eq '1'
    } |
    Select-Object TargetResourceName, TargetResourceID, Severity, Remediation,
        @{ n = 'Status'; e = { $_.AdditionalData.Status } },
        @{ n = 'Detail'; e = { $_.AdditionalData.Detail } }
```

Expected healthy result: no mandatory target is returned by the failure filter.

Expected affected result: one or more rows identify the failed target and the failure
detail. If the command emits no result at all, do not call the node healthy. Confirm that
the module is installed, the validator ran, and a fresh log or Event ID 17205 record was
created.

### Azure portal: shown

For an update, open the Azure Local resource, select **Updates**, and review the current
environment or system health check. For deployment, add node, or upgrade, review the
failed validation step in the deployment or operation details.

The portal can show a persisted health result rather than the result of a targeted command
that ran seconds ago. Record the health-check timestamp. Use the fresh on-node command,
event, and component log as the authority while validating a just-applied fix.

### Windows event logs: shown

Environment Checker writes serialized results to the
`AzStackHciEnvironmentChecker` log as Event ID `17205`. Parse the JSON message and read
the human-readable fields from `AdditionalData`:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker `
    -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    ForEach-Object {
        try {
            $result = $_.Message | ConvertFrom-Json
        }
        catch {
            return
        }

        if ($result.TargetResourceType -eq 'External Endpoint') {
            [pscustomobject]@{
                TimeCreated = $_.TimeCreated
                Name        = $result.Name
                Target      = $result.TargetResourceName
                Status      = $result.AdditionalData.Status
                Detail      = $result.AdditionalData.Detail
                Remediation = $result.Remediation
            }
        }
    } |
    Sort-Object TimeCreated -Descending
```

The top-level `Status` is commonly a numeric enum in serialized results. Use
`AdditionalData.Status` and `AdditionalData.Detail` for the readable result.

### Component and tool log files: shown

Review these files on the node where the validator ran:

```text
%USERPROFILE%\.AzStackHci\FailedUrls.txt
%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log
%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentReport.json
```

Search the log for the exact failed hostname, `FAILURE`, and the diagnostic object written
after the failure. Preserve the UTC time, node name, requested URI, response URI, server
header, exception, status code, retry count, latency, and TCP result.

### Surfaces where this validator result is not evident

- **Cluster logs (`Get-ClusterLog`)**: the external web probe is an Environment Checker
  result and does not appear as a failover-cluster resource or membership event.
- **Failover Cluster Manager**: this check does not create a failed clustered role,
  resource, network, storage object, or node state.
- **Windows Admin Center on a standalone host**: the specific validator result does not
  appear there. Use the on-node validator, Event ID 17205, and component logs.
- **Windows Admin Center in the Azure portal**: the specific validator result does not
  appear in that experience. Use the Azure Local resource's **Updates** or operation
  details blade instead.

## Collect results from every node

Run this from an Azure Local node in an elevated domain session that can connect to the
other nodes. It runs a fresh validator process on each up node and returns structured
results. The command does not change node or cluster state.

```powershell
$nodes = @(Get-ClusterNode |
    Where-Object State -eq 'Up' |
    Select-Object -ExpandProperty Name)

$clusterResults = Invoke-Command -ComputerName $nodes -ScriptBlock {
    Import-Module AzStackHci.EnvironmentChecker -Force
    $started = [DateTime]::UtcNow

    try {
        $results = @(Invoke-AzStackHciConnectivityValidation -PassThru -ErrorAction Stop)
        $failed = @($results | Where-Object {
            $_.AdditionalData.Status -eq 'FAILURE' -or
            "$($_.Status)" -eq 'FAILURE' -or
            "$($_.Status)" -eq '1'
        })

        [pscustomobject]@{
            Node       = $env:COMPUTERNAME
            StartedUtc = $started
            Status     = if ($failed.Count) { 'FAILURE' } else { 'SUCCESS' }
            Failed     = $failed.Count
            Targets    = @($failed | ForEach-Object {
                [pscustomobject]@{
                    Target      = "$($_.TargetResourceName)"
                    TargetId    = "$($_.TargetResourceID)"
                    Severity    = "$($_.Severity)"
                    Status      = "$($_.AdditionalData.Status)"
                    Detail      = "$($_.AdditionalData.Detail)"
                    Remediation = "$($_.Remediation)"
                }
            })
        }
    }
    catch {
        [pscustomobject]@{
            Node       = $env:COMPUTERNAME
            StartedUtc = $started
            Status     = 'NO DATA'
            Failed     = $null
            Targets    = @()
            Error      = $_.Exception.Message
        }
    }
}

$clusterResults | ConvertTo-Json -Depth 8
```

Expected output:

- `SUCCESS`: the validator ran and returned no failed targets on that node.
- `FAILURE`: inspect every object in `Targets`.
- `NO DATA`: the validation result is not established. Fix the execution, module, or
  remoting problem before declaring success.

## Classify the failure

Use more than one field. A single status code or successful TCP test is not enough to
identify the failing layer.

| Evidence | Most likely lane | What to confirm next |
| --- | --- | --- |
| The validator reports `Overall Result: True`, even when the HTTP status is 404 | Connectivity succeeded for this target | Do not override the validator with a blanket "only HTTP 200 passes" rule. Some host-root connectivity targets prove the expected server and request path are reachable even though the root resource is not a content page. |
| The remote name cannot be resolved; TCP test is false or absent | DNS or hostname resolution | Resolve the exact hostname from the affected node and through the configured DNS servers. Use the DNS-specific TSG if resolution fails. |
| `Unable to connect`, timeout, or connection refused; TCP 443 is false | Firewall, route, network access control, or service unavailable | Test the exact hostname and port from the same node. Confirm the destination resolves to current addresses and that the source node is included in the rule. |
| HTTP 403 or 407; server header or response URI identifies a proxy | Proxy access or authentication | Record `netsh winhttp show proxy`, the responding server, method, status, and response URI. Confirm the service, not the proxy, generated the response. |
| TCP 443 is true, but HTTPS closes during send or TLS negotiation | TLS inspection, application firewall, IPS, certificate trust, or protocol policy | Compare direct and inspected paths, collect the certificate chain, and have the security owner review resets or inspection logs. |
| The requested host succeeds, then a redirected host fails | Missing redirect destination in the allow list | Record every `Location` and final URL. Allow the required redirected host, not only the short link. |
| The destination is reachable with `curl`, but the validator still fails or tests an unexpected retired target | Product target or validator drift | Record the module version, manifest final URL, target definition, validator result, and raw log. Escalate to Microsoft support or the Environment Validator product group. |

### Check hostname and TCP reachability

```powershell
$targetHost = '<failed-hostname>'
Resolve-DnsName -Name $targetHost -Type A -ErrorAction Continue
Test-NetConnection -ComputerName $targetHost -Port 443 -InformationLevel Detailed
```

Use the hostname reported by the current failed result. Do not copy an address from an
old log or hardcode a resolved CDN IP in a firewall rule. Service addresses can rotate.

Read the validator's `Overall Result`, response-host match, method match, and failure
detail together. Do not classify every non-200 response as a failed connectivity target.
For example, a host-root probe can return HTTP 404 while the validator reports success
because the expected server answered the expected request and no network control blocked
the path.

### Check the node proxy

```powershell
netsh winhttp show proxy
```

If the result shows a proxy, give the proxy owner the target hostname, node, UTC
timestamp, HTTP method, status code, server header, and response URI. A proxy-generated
403 or 407 does not prove that the required Azure service rejected the node.

### Trace redirects

```powershell
$uri = 'https://aka.ms/hciconnectivitytargets'
curl.exe $uri --verbose --location --include --no-progress-meter --connect-timeout 10
```

Review each `Location:` header and each subsequent connection. The original request can
succeed while a later redirect destination fails.

## Mitigation

All node-side commands in this guide are **[READ-ONLY]**. The actual mitigation belongs
to the customer team that owns the network control.

| Failure lane | State-changing action | Risk and rollback |
| --- | --- | --- |
| DNS | Correct the DNS record, forwarder, conditional forwarder, or DNS egress path for the exact hostname. | **[MEDIUM RISK]** when changing a shared DNS service. Record the prior configuration and restore it if unrelated clients regress. |
| Firewall, route, or network access control | Permit the required protocol and port from every Azure Local node to the exact current hostname or supported service tag. | **[MEDIUM RISK]** shared network change. Use the narrowest rule and retain the prior rule set for rollback. |
| Proxy | Allow the destination and method, configure required authentication, and ensure the proxy returns the service response rather than its own block page. | **[MEDIUM RISK]** shared proxy policy change. Roll back only the new scoped exception if verification or security review fails. |
| TLS inspection or IPS | Add a narrowly scoped inspection bypass or correct the trust and protocol policy for the required service. | **[MEDIUM RISK]** security-control change. Require security-owner approval and a documented rollback. Do not disable inspection globally. |
| Redirect | Allow the current redirected destination as well as the original short-link host. | **[MEDIUM RISK]** network allow-list change. Re-resolve the redirect during verification and remove only the newly added destination if rollback is required. |
| Product-target drift | Do not add speculative network rules. Escalate with the evidence package below. | No customer network change is authorized until Microsoft confirms the current target definition. |

The network owner should record:

- change identifier and owner;
- exact source nodes or subnet;
- destination hostname or supported service tag;
- protocol and port;
- proxy or inspection exception, if any;
- prior policy and exact rollback;
- UTC time the change became active.

## Verify the fix

Run verification from a **new PowerShell process**. A fresh process avoids reusing cached
DNS or connections from before the network change.

### 1. Re-run the standalone validator on every node

Repeat the [cluster-wide evidence command](#collect-results-from-every-node). Success
requires:

- every node returns `SUCCESS`;
- no node returns `NO DATA`;
- no mandatory target remains in `Targets`;
- `FailedUrls.txt` contains no current failure for the target;
- a fresh Event ID 17205 or component-log entry records the successful run.

### 2. Re-run the blocked fabric health check

For a pending update:

```powershell
Invoke-SolutionUpdatePrecheck -SystemHealth
Get-SolutionUpdateEnvironment |
    Format-List HealthState, HealthCheckDate
```

Expected result: `HealthState` is `Success` and `HealthCheckDate` reflects the fresh
precheck.

For deployment, scale out, or upgrade, rerun the operation's documented validation step.
Do not retry the full state-changing operation until the connectivity validation is clean.

### 3. Confirm workload and cluster stability

The guide does not require a node drain or reboot. Confirm that no unrelated cluster or
workload issue appeared during the network-policy change:

```powershell
Get-ClusterNode | Format-Table Name, State
Get-ClusterGroup | Format-Table Name, State, OwnerNode
```

If a cluster node or workload is unhealthy, stop and investigate that condition separately.
Do not attribute it to the connectivity validator without evidence.

## Escalation and handoff

### Handoff to the network, proxy, or security team

Use this copy-ready summary:

```text
Azure Local external-connectivity readiness is blocked.

Affected nodes:
Failed requested URL or hostname:
Redirect destination, if any:
UTC failure time:
Exception message:
HTTP status, method, server header, and response URI:
Test-NetConnection TCP 443 result:
WinHTTP proxy result:
Current manifest final URL:
Business impact:

Please review the outbound DNS, TCP 443, proxy, TLS-inspection, IPS, and access-control path for the exact destination. Apply the narrowest approved change, record rollback, and tell us when to run a fresh validator process on every node.
```

### Escalate to Microsoft support or the Environment Validator product group when

- the current manifest and the validator test different target definitions;
- a target was renamed, removed, or gated on the current release but the operation still
  requires it;
- the exact request succeeds outside the validator from the same node and process context,
  but the validator still reports failure;
- the validator returns no result, writes no fresh event, or reports stale data after a
  confirmed run;
- the remediation link points to a retired product path or does not describe the emitted
  target;
- the issue persists after the network owner confirms the current destination is allowed.

Include:

- Azure Local solution, platform, and Environment Checker module versions;
- operation type and exact UTC failure time;
- affected and unaffected nodes;
- full failed result from `AdditionalData`;
- Event ID 17205 record;
- `FailedUrls.txt`, `AzStackHciEnvironmentChecker.log`, and
  `AzStackHciEnvironmentReport.json`;
- current manifest requested URL, final URL, and retrieved target definition;
- DNS, TCP, proxy, redirect, HTTP, and TLS evidence;
- network change identifier and verification result.

Remove secrets, tokens, private keys, proxy credentials, and unnecessary personal data
before sharing the package.

## Prevention

- Resolve and archive the current manifest destination before each deployment or major
  update window.
- Validate required destinations from every planned Azure Local node, not only from an
  administrator workstation.
- Review short-link redirects and CDN-backed hostnames without pinning resolved IP
  addresses.
- Keep firewall, proxy, and TLS-inspection exceptions scoped and owned.
- Run a fresh `Invoke-AzStackHciConnectivityValidation` before the maintenance window.
- Treat `NO DATA` as an unresolved validation gap, never as a pass.

## Related documentation

- [Evaluate the deployment readiness of your environment for Azure Local](https://learn.microsoft.com/azure/azure-local/manage/use-environment-checker)
- [Azure Local firewall requirements](https://learn.microsoft.com/azure/azure-local/concepts/firewall-requirements)
- [Troubleshoot Azure Local updates](https://learn.microsoft.com/azure/azure-local/update/update-troubleshooting-23h2)
- [Azure Arc-enabled servers network requirements](https://learn.microsoft.com/azure/azure-arc/servers/network-requirements)
