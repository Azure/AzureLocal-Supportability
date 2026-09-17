---
ArticleType: "TSG"
Article_ID: "20260917160004"
Title: "AzStackHci_SBEHealth_Test-Endpoint-Connectivity"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Hyperconverged", "Disaggregated", "Multi-Rack", "Disconnected", "Microsoft 365 Local"]
  OEM: ["All"]
  OS: ["23H2", "24H2"]
  SolutionMinorBuild: []
  ExtensionName: "Solution Builder Extension"
  ExtensionVersion: []
Component: "Environment Validator"
Engineering_ID:
  Source: "ADO Work Item"
  ID: 38356180
Tags: ["Validation", "Solution Update", "SBE", "Firewall", "Proxy"]
---

[[_TOC_]]

::: audience-css

# Revision History

| Date | Version | Summary |
| --- | --- | --- |
| 2026-09-17 | 2.0 | Added mandatory PickleFactory metadata, audience scoping, and current article layout without changing technical guidance. |

:::

# AzStackHci_SBEHealth_Test-Endpoint-Connectivity

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_SBEHealth_Test-Endpoint-Connectivity</strong></td>
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
    <td>Solution Builder Extension manifest endpoint connectivity ("Validate SBE manifest reachable")</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-SBEEndpointConnectivity</code> (the standalone probe invoked by <code>Test-AzStackHciSBEHealth</code>); the emitted result is <code>Test-Endpoint-Connectivity</code> during <code>PreUpdate</code> or <code>PreUpdateJIT</code>.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>SBEHealth (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Informational</strong>: this check reports whether the SBE manifest endpoint is reachable so you can fix connectivity, but it does <strong>not</strong> block the update. A failure still means the node cannot reach the endpoint and should be resolved.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Customer impact</th>
    <td>Read-only evidence collection and endpoint testing do not restart nodes or move running VMs. Until reachability is restored, the node cannot retrieve the partner SBE manifest, so an update that needs that manifest may fail or have reduced partner-content coverage. Starting the update is a separate change with its own workload and maintenance-window assessment.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>The network, firewall, or proxy owner handles transport and egress policy. The OEM or SBE publisher owns an incorrect, expired, or search-engine redirecting manifest URL. The Azure Local or LCM owner handles a missing endpoint from solution discovery.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical effort</th>
    <td>Allow 10-20 minutes for evidence and a layered probe, 15-30 minutes for a network or proxy allow-list change plus revalidation, and partner or product-support time when the endpoint or solution-discovery configuration is wrong.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Requirement</th>
    <td>The node can reach the hardware partner (OEM) <strong>Solution Builder Extension (SBE) manifest endpoint</strong> over HTTPS (443) and receives a normal <code>200</code> response (not a firewall block, a non-200 response, or a redirect to a search engine).</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>Pre-update SBE health validation (update readiness), on solutions that ship a Solution Builder Extension. Skipped when the cluster is configured for disconnected (ALDO) operations.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td>Azure Local, version 23H2 and later.</td>
  </tr>
</table>

## Quick fix

If you just want the short version: this check failed because the node could not reach the
**SBE manifest endpoint** (the URL your hardware partner's Solution Builder Extension content is
published at) over HTTPS, or because the endpoint returned a non-usable response. It is usually a
**firewall / proxy** problem on outbound HTTPS (443), but a missing endpoint or a broken redirect
needs a different owner. Read `AdditionalData.Detail`, identify the endpoint and failure mode, allow
only the required destinations on every node, then re-run the pre-update health check. Full detail
and the verification boundary are below.

## Overview

A **Solution Builder Extension (SBE)** is the hardware partner (OEM) content that ships
alongside the Azure Local solution: drivers, firmware, and a partner module. The SBE content is
published at a **manifest endpoint**, an HTTPS URL (often an `aka.ms` link that redirects to the
partner's download location). During **pre-update** validation, this check confirms the node can
actually reach that endpoint, because a later step needs to download the SBE manifest from it.

The check discovers the endpoint URL for the solution (from the cluster's solution-discovery
information) and then makes an HTTPS request to it. The outcome is one of:

- **SUCCESS.** The endpoint returned a normal `200` response. The node can reach the SBE
  manifest. The detail reads *"Validate SBE manifest reachable: `<endpoint>`"*.
- **FAILURE.** The node could **not** reach the endpoint. This happens when the request throws a
  connection error (blocked or unroutable), returns a non-`200` status code, returns no response,
  or is redirected to a search engine (a symptom of a broken `aka.ms` redirect). The detail names
  the endpoint and why it failed, and the remediation is *"Check firewall rules to ensure the SBE
  manifest endpoint `<endpoint>` is reachable."*

This check is **Informational**: a failure does **not** block the deployment or update. It is an
early warning that the node cannot reach the SBE content source, so it surfaces the problem before a
later SBE operation needs the manifest. If the cluster is configured for **disconnected (ALDO)
operations**, the endpoint check is skipped entirely.

## Boundary with general connectivity

This check answers one narrow question: can this node reach the configured SBE manifest URI from
`Get-SolutionDiscoveryDiagnosticInfo` and receive a usable HTTPS response? The product's real probe
is `Test-SBEEndpointConnectivity`; the emitted health-check name is `Test-Endpoint-Connectivity`.
The DNS, TCP, and HTTP commands in this guide are supporting evidence only. Do not replace the real
HTTPS probe with `Test-NetConnection`, a DNS lookup, or a test against a different Microsoft or
Azure endpoint.

A successful SBE probe does **not** prove general outbound connectivity, Azure control-plane access,
Arc registration, proxy access for every destination, or connectivity from every node. Conversely,
a general connectivity failure does not prove that this SBE endpoint is broken. For broad endpoint
coverage, use the [general Environment Checker connectivity guide](./Troubleshooting-External-Connectivity-Failures-in-Environment-Checker.md).

## Impact, ownership, and change boundary

| Situation | Owner | Typical effort | Impact and risk |
|---|---|---|---|
| Read the result, inspect logs, or run the layered probe | Cluster administrator or CSS engineer | 10-20 minutes | [LOW RISK] Read-only. No node restart, VM move, or update installation. |
| Allow the endpoint and its required redirect destinations | Network, firewall, or proxy owner | 15-30 minutes plus propagation and revalidation | [MEDIUM RISK] Changes outbound egress policy. Scope the rule to the required hosts and TCP 443; do not disable the node firewall. |
| Correct an expired, wrong, or search-engine redirecting URL | OEM or SBE publisher, with the update owner | 30 minutes to collect evidence, then partner-dependent | [LOW RISK] Investigation is read-only. The endpoint owner must publish or confirm the correct manifest location. |
| The endpoint is missing from solution discovery | Azure Local or LCM owner | 15-30 minutes for local evidence, then product support as needed | [LOW RISK] Stop before changing firewall rules. This is not a transport diagnosis. |
| Proceed while this informational check remains failed | Update owner and change approver | Follows the normal update process | [MEDIUM RISK] The check does not block the update, but SBE manifest retrieval remains unproven. Assess the specific update and partner-content dependency separately. |

## Before you start: who should do this, and is it safe?

- **Who owns this.** This is an outbound-connectivity problem, so it is usually a **network /
  firewall / proxy** task for whoever manages the node's internet egress, done together with the
  person running the update. The SBE endpoint URL itself comes from solution discovery and may be
  overridden, so involve the OEM or SBE publisher if the URL looks wrong or its redirect target is
  unknown.
- **This is safe to investigate read-only.** Reading the check result, the event log, and testing
  the endpoint with a web request changes nothing on the node.
- **The precheck is not the update.** `Invoke-SolutionUpdatePrecheck -SystemHealth` only reruns
  validation; it does not install the update, restart nodes, or move running VMs. Starting the
  update afterward follows the normal change process and may have separate workload impact.
- **Use an administrator session on the affected node.** Run the evidence commands in Windows
  PowerShell 5.1 or PowerShell 7 on the node that reported the result. The component logs are
  written under the profile that ran Environment Checker.
- **Stop before a firewall change when the endpoint is missing.** A blank
  `Configuration.ComponentUris["SBE"]`, the message *"Unable to determine SBE manifest endpoint"*,
  or `DISCONNECTED_OPS_SUPPORT=True` indicates solution-discovery or ALDO handling, not a missing
  firewall allow rule.
- **Do not paste placeholders literally.** Replace `<endpoint-from-step-1>` with the URI from
  `AdditionalData.Detail`. Do not disable the Windows firewall globally or create an unrestricted
  outbound allow rule.
- **Do not "fix" this by disabling the check or ignoring it.** Because it is Informational it will
  not block the update, but the underlying connectivity gap will cause a later SBE step to fail.
  Fix the reachability, do not suppress the warning.

## Where this failure appears, and where it does not

Use the following surfaces to decide where to collect evidence. Only the first three and the
component files carry a direct signal for this check.

| Admin surface | Expected signal |
|---|---|
| PowerShell on an Azure Local node | **Shown**: the Event ID 17205 result, `Get-SolutionDiscoveryDiagnosticInfo`, and the layered probe below. |
| Azure portal | **Shown**: the Azure Local cluster **Updates** view can show the SBE health result after validation. |
| Windows event logs | **Shown**: `AzStackHciEnvironmentChecker`, Event ID 17205. |
| Cluster logs from `Get-ClusterLog` | This check does **not** appear as an authoritative cluster-log event. Use cluster logs only if a separate cluster or node issue needs correlation. |
| Windows Failover Cluster Manager | This check does **not** appear as a dedicated cluster resource or node signal. |
| Windows Admin Center on a standalone host | This check does **not** appear as a dedicated WAC signal. Use the node result or portal Updates view. |
| Windows Admin Center in the Azure portal | This check does **not** appear as a separate WAC diagnostic. Use the Azure portal Updates view. |
| Component or tool log files on disk | **Shown**: the Environment Checker log and report files under `%USERPROFILE%\.AzStackHci` on the node and profile that ran the check. |

### In the Azure portal

When you run update readiness (or update validation) from the portal, the validation phase runs
the Environment Checker and surfaces SBE health results on the cluster's **Updates** view. A
failed `Test-Endpoint-Connectivity` appears there under the SBE health checks with the "Validate
SBE manifest reachable" title and the failure detail naming the endpoint.

### On the node

The Environment Checker writes each check result to the `AzStackHciEnvironmentChecker` event log
as the JSON body of an **Event ID 17205** entry, and to the cluster-wide `HealthCheckResult.*.json`
on the infrastructure share. Read this check's most recent result on a node with:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    ForEach-Object { $_.Message | ConvertFrom-Json } |
    Where-Object { $_.Name -like '*Test-Endpoint-Connectivity*' } |
    Select-Object -First 1 Name,
        @{n='Status';e={$_.AdditionalData.Status}},
        @{n='Detail';e={$_.AdditionalData.Detail}},
        Remediation
```

The `Name` on the node carries a domain prefix (`AzStackHci_SBEHealth_`) and can carry a node
suffix, so the query uses `-like '*Test-Endpoint-Connectivity*'` (leading and trailing wildcard) to
match it. In this JSON the human-readable status and message live under `AdditionalData` (the
top-level `Status` and `Severity` are numeric enums, and the top-level `Description` is a generic
check description), so the query projects `AdditionalData.Status` and `AdditionalData.Detail`; the
top-level `Remediation` is human-readable. When the endpoint is unreachable, `AdditionalData.Status`
is `FAILURE`, `AdditionalData.Detail` reads *"Failed to reach SBE manifest endpoint: `<endpoint>`
..."*, and `Remediation` reads *"Check firewall rules to ensure the SBE manifest endpoint
`<endpoint>` is reachable."*

### In component and tool logs

The Environment Checker also writes component evidence under the `.AzStackHci` directory in the
profile that ran the check. Use this read-only command to list the files, show their freshness, and
search the log and report files for this check:

```powershell
$componentLogRoot = Join-Path $env:USERPROFILE '.AzStackHci'
if (-not (Test-Path -LiteralPath $componentLogRoot)) {
    throw "Component log directory was not found: $componentLogRoot"
}

$componentFiles = Get-ChildItem -LiteralPath $componentLogRoot -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -in @(
            'AzStackHciEnvironmentChecker.log',
            'AzStackHciEnvironmentReport.json',
            'AzStackHciEnvironmentReport.xml'
        )
    } |
    Sort-Object LastWriteTime -Descending

$componentFiles | Select-Object FullName, LastWriteTime, Length
$componentFiles | ForEach-Object {
    Select-String -LiteralPath $_.FullName `
        -Pattern 'Test-Endpoint-Connectivity', 'SBE manifest endpoint',
                 'Failed to reach', 'Validate SBE manifest reachable' `
        -Context 2, 2 -ErrorAction SilentlyContinue
}
```

Attach the matching files with their `LastWriteTime`. If they predate the Event ID 17205 entry, they
are stale evidence and must be refreshed by rerunning the validation.

## Troubleshooting Steps

### 1. Read the failure detail and get the endpoint URL

Run the Event ID 17205 query above (or open the `HealthCheckResult.*.json`) and read the
`AdditionalData.Detail`, not the top-level `Description`. It names the exact **SBE manifest
endpoint** URL the check could not reach and the reason. Confirm the configured URI and discovery
status before changing a firewall:

```powershell
$discovery = Get-SolutionDiscoveryDiagnosticInfo
[pscustomobject]@{
    SbeEndpoint = $discovery.Configuration.ComponentUris['SBE']
    ManifestSource = $discovery.SbeManifestResult.ManifestSource
    ManifestStatus = $discovery.SbeManifestResult.Status
    ManifestDescription = $discovery.SbeManifestResult.Description
}
```

Classify the result using the exact evidence you collected:

| Evidence | Meaning | First owner |
|---|---|---|
| Blank `ComponentUris['SBE']` or *"Unable to determine SBE manifest endpoint"* | Solution discovery did not provide a URI. This is not a firewall diagnosis. | Azure Local / LCM owner |
| Connection exception or no response | DNS, route, TCP 443, TLS inspection, firewall, or proxy timeout prevented a usable response. | Network, firewall, or proxy owner |
| `407` | The proxy reached the request but requires proxy authentication or policy authorization. | Proxy owner |
| `401`, `403`, `404`, `410`, or another non-`200` response | A server, proxy, or endpoint policy refused the request, or the URI is wrong, expired, or no longer publishes the manifest. | Proxy owner, endpoint owner, or OEM |
| Redirect ends at Bing, Google, Yahoo, or another search page, even with HTTP `200` | The redirect URI is not a usable SBE manifest location. An unregistered or broken `aka.ms` link can look successful by status code alone. | Endpoint owner or OEM, then Microsoft link owner if appropriate |
| Final response is `200` from the expected manifest host and is not a search page | This probe is healthy. Continue with the specific Event ID 17205 verification in step 5. | No connectivity action |

On Windows PowerShell 5.1, a non-`200` response can enter the `catch` path before a response object
is available, so the check detail may show a blank response code. Treat a blank code with an
exception as a transport or proxy symptom, not as success.

### 2. Confirm the endpoint reachability from the node

Run the real HTTPS request from the affected node, then collect DNS and TCP evidence. This keeps the
product probe as the pass/fail authority while separating DNS, TCP, TLS, proxy, and HTTP symptoms.
Use the actual URI from `AdditionalData.Detail`; do not use the placeholder as written:

```powershell
# Replace this with the actual URI from AdditionalData.Detail.
$sbeEndpoint = 'https://endpoint-from-step-1'
$uri = [System.Uri]$sbeEndpoint
$dnsAddresses = @(
    try {
        [System.Net.Dns]::GetHostAddresses($uri.DnsSafeHost) |
            ForEach-Object { $_.IPAddressToString }
    } catch {
        "DNS error: $($_.Exception.Message)"
    }
)
$tcp = Test-NetConnection -ComputerName $uri.DnsSafeHost -Port 443 `
    -InformationLevel Detailed -WarningAction SilentlyContinue

try {
    $request = @{
        Uri = $sbeEndpoint
        TimeoutSec = 15
        MaximumRedirection = 10
        ErrorAction = 'Stop'
    }
    if ($PSVersionTable.PSVersion.Major -le 5) {
        $request.UseBasicParsing = $true
    } else {
        $request.SkipHttpErrorCheck = $true
    }
    $response = Invoke-WebRequest @request
    $finalUri = $null
    if ($null -ne $response.BaseResponse -and $null -ne $response.BaseResponse.ResponseUri) {
        $finalUri = $response.BaseResponse.ResponseUri.AbsoluteUri
    } elseif ($null -ne $response.ResponseUri) {
        $finalUri = $response.ResponseUri.AbsoluteUri
    }
    [pscustomobject]@{
        DnsAddresses = $dnsAddresses
        Tcp443 = $tcp.TcpTestSucceeded
        StatusCode = [int]$response.StatusCode
        FinalUri = $finalUri
        Error = $null
    }
} catch {
    $errorResponse = $_.Exception.Response
    $errorStatus = $null
    if ($null -ne $errorResponse -and $null -ne $errorResponse.StatusCode) {
        $errorStatus = [int]$errorResponse.StatusCode
    }
    [pscustomobject]@{
        DnsAddresses = $dnsAddresses
        Tcp443 = $tcp.TcpTestSucceeded
        StatusCode = $errorStatus
        FinalUri = $null
        Error = $_.Exception.Message
    }
}
```

The real probe uses an HTTPS request with a 15-second timeout and treats an exception, no response,
non-`200` response, or search-engine redirect as failure. `BaseResponse.ResponseUri` is a useful
Windows PowerShell 5.1 field, but it is not consistently populated in PowerShell 7. If PowerShell 7
does not return `FinalUri`, use the following optional header trace to identify each redirect target:

```powershell
if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    curl.exe -sSIL --max-redirs 10 --connect-timeout 15 --max-time 20 $sbeEndpoint
} else {
    Write-Warning 'curl.exe is not available; collect the redirect Location headers with an approved proxy or browser trace.'
}
```

An HTTP `200` is not sufficient when `FinalUri` lands on a search engine. The product's
`Test-SBEEndpointConnectivity` result remains the authoritative check result; these commands are
the evidence ladder that explains why it passed or failed.

### 3. Fix the reachability (firewall / proxy)

Do not edit the check. Make the endpoint reachable from the node. In plain terms, you are allowing
the node to make an outbound HTTPS request (TCP port **443**) to the SBE endpoint host:

- **Allow outbound HTTPS (443) to the endpoint host.** Add the SBE manifest endpoint host to your
  firewall / proxy allow list on port 443. If the endpoint is an `aka.ms` link, allow HTTPS to
  **all three redirect layers**: `aka.ms`, `redirectiontool.trafficmanager.net`, and the final OEM
  manifest host identified by the `FinalUri`, `Location` headers, or an approved browser trace. For
  a non-`aka.ms` endpoint, allow the configured host and any documented redirect target only.
- **If a proxy is in the path**, make sure the node's proxy configuration lets it reach the
  endpoint. A **`407` response means the proxy is refusing the request because it wants
  authentication** (the node is not sending proxy credentials). Configure the node's proxy settings
  so the SBE endpoint is reachable, or add it to the proxy bypass / allow list per your
  environment's proxy policy.
- **This runs per node, so fix egress on every node.** The check evaluates connectivity on each
  cluster node independently, and firewall / proxy egress policy is usually the same across the
  cluster, so a block that affects one node typically affects all of them. Apply the allow-list /
  proxy change to every node (not just the one that flagged) so you clear the whole cluster in one
  pass, then confirm with step 2 on each node.
- **If the endpoint URL itself looks wrong or expired** (a `403`/`404`, or a redirect to a search
  engine that never resolves), confirm the correct SBE manifest endpoint with your hardware partner
  (OEM), since the endpoint is published by them.

### 4. Re-run the pre-update check

Re-run the same pre-update / system health check that surfaced this warning so it re-tests the
endpoint. In the Azure portal, open the cluster's **Updates** page and run update readiness again;
or on a node, an administrator can trigger a fresh system health check with
`Invoke-SolutionUpdatePrecheck -SystemHealth`:

```powershell
# Trigger a fresh system health check (this re-runs the SBE health checks)
Invoke-SolutionUpdatePrecheck -SystemHealth

# Wait a few minutes, then check the health state
Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate
```

The `-SystemHealth` switch is what actually re-runs the health checks (a bare
`Invoke-SolutionUpdatePrecheck` does not re-run them).

### 5. Verify the fix

Re-read the Event ID 17205 result after the new validation run. The specific check is fixed only
when the result matched by `Name -like '*Test-Endpoint-Connectivity*'` has
`AdditionalData.Status = SUCCESS` and a detail such as *"Validate SBE manifest reachable:
`<endpoint>`"*. Confirm the component log or report has a newer `LastWriteTime` and the same
success result. The step 2 probe should also show `StatusCode = 200`, a usable final manifest host,
and no search-engine redirect.

`Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate` is an **aggregate**
readiness result. `HealthState = Success` alone does not prove this specific endpoint check passed,
and `HealthState = Failure` does not identify which check failed. Use the Event ID 17205
`AdditionalData` result or fresh component evidence for this check, then use the aggregate state as
supporting context. In the portal, the SBE health check clears on the next validation pass.

Because the check runs per node, repeat the specific result query on every cluster node. A single
healthy node does not clear a failure on another node.

## When to escalate

- The check reports **"Unable to determine SBE manifest endpoint to test connectivity against"**.
  That is not a firewall problem: the node could not even discover the endpoint URL from
  solution discovery. Confirm the **LCM extension** is installed and that
  `Get-SolutionDiscoveryDiagnosticInfo` returns an SBE endpoint. Stop changing firewall rules and
  escalate to the Azure Local or LCM owner with the discovery output and the fresh Event ID 17205
  record.
- The endpoint has a DNS result and TCP 443 succeeds, but HTTPS returns `407`, a TLS error, or a
  policy response after the allow-list is confirmed. Escalate to the network or proxy team with
  the endpoint URI, DNS addresses, TCP result, HTTP status or exception, redirect trace, proxy
  configuration, and the UTC timestamp.
- The endpoint URL itself is wrong, expired, returns `404`/`410`, or its `aka.ms` redirect ends at
  a search engine or an invalid partner location. Escalate to the OEM or SBE publisher with the
  `ComponentUris['SBE']` value, `AdditionalData.Detail`, and the redirect trace. Do not reset an
  intentional endpoint without its owner.
- The event result changes to SUCCESS but component files are missing or stale, or the event result
  does not refresh after `Invoke-SolutionUpdatePrecheck -SystemHealth`. Escalate to Environment
  Validator / LCM support with the Event ID 17205 record, file paths and timestamps, and the
  precheck output.
- This SBE check passes while a broader connectivity check fails. Do not route that discrepancy to
  the OEM by default; use the general connectivity guide to identify the other endpoint or service.
- The sibling SBE health checks also fail (see **Related**), which can indicate a broader SBE
  configuration problem rather than a connectivity one.

::: audience-css

# Source Articles

- **Firewall blocks SBE update discovery** (internal SBE connectivity guide with the per-vendor
  `aka.ms/AzureStackSBEUpdate/<vendor>` endpoints and how to discover the active endpoint with
  `Get-SolutionDiscoveryDiagnosticInfo`):
  [Firewall-blocks-update-discovery.md](../SolutionExtension/Firewall-blocks-update-discovery.md)
- **Firewall blocks SBE validation** (internal guide covering the SBE manifest endpoint, its
  `redirectiontool.trafficmanager.net` redirect target, and the firewall allow-list):
  [Firewall-blocks-SBE-validation.md](../SolutionExtension/Firewall-blocks-SBE-validation.md)
- **General Environment Checker connectivity** (broader DNS, proxy, and endpoint diagnostics):
  [Troubleshooting-External-Connectivity-Failures-in-Environment-Checker.md](./Troubleshooting-External-Connectivity-Failures-in-Environment-Checker.md)
- **Rerun a deployment / update after fixing prerequisites** (Azure Local deployment
  troubleshooting): https://learn.microsoft.com/azure/azure-local/manage/troubleshoot-deployment#restart-the-deployment-via-azure-portal
- **Solution Builder Extension** overview and partner content:
  https://learn.microsoft.com/azure/azure-local/update/solution-builder-extension
- Sibling SBE health checks that validate other parts of the same SBE:
  `Test-Endpoint-Matches-ModelSKU` (the SBE manifest at the endpoint matches this hardware model
  and SKU), `Test-Installed-SBE-Env-Vars` (the installed-SBE environment variables are consistent),
  and `Test-SolutionExtensionModule` (the staged SBE `SolutionExtension` module is present,
  integrity-intact, and signed).

:::
