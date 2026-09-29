# Azure Local - Troubleshoot Outbound Network Connectivity

Use `Test-AzureLocalConnectivity` from the **AzStackHci.DiagnosticSettings** module to investigate outbound connectivity failures from Azure Local nodes. The report helps distinguish unreachable endpoints, missing test inputs, TLS inspection, and private-address resolution.

**Applies to:** Connected hyperconverged and disaggregated Azure Local deployments, with or without Azure Arc Gateway. Use this guide to troubleshoot and validate outbound connectivity from the tested nodes; it does not provide complete deployment validation. Pre-deployment tests on another Windows device assess that device's path only. This guide does not validate disconnected operations, multi-rack deployments, or connectivity from workload VMs and Azure Resource Bridge (ARB).

## Contents

- [Overview](#overview)
- [Symptoms](#symptoms)
- [Issue Validation](#issue-validation)
- [Prerequisites](#prerequisites)
- [Mitigation Details](#mitigation-details)
- [Output format](#output-format)
- [Interpret results and verify resolution](#interpret-results-and-verify-resolution)
- [Programmatic use with `-PassThru` (automation)](#programmatic-use-with--passthru-automation)
- [Share test results with Microsoft (Optional)](#share-test-results-with-microsoft-optional)
- [Demo and example output](#demo-and-example-output)
- [Parameter reference](#parameter-reference)
- [Appendix](#appendix)
- [How to get additional support](#how-to-get-additional-support)

## Overview

Connected Azure Local instances require outbound connectivity from their management network to Azure public endpoints for deployment, updates, workload provisioning, and ongoing management.

The required endpoints depend on the Azure region, hardware vendor, enabled services, and whether you use Azure Arc Gateway. Use the endpoint list for your deployment rather than treating every destination discovered by a probe as a required firewall exception.

For the authoritative requirements, see [Firewall requirements for Azure Local](https://learn.microsoft.com/azure/azure-local/concepts/firewall-requirements).

## Symptoms

Blocked endpoints, DNS failures, proxy configuration, or TLS inspection can contribute to these symptoms:

1. Azure Local instance cloud deployment and/or update operations fail with network failure or timeout.
2. Physical machines show an Azure Arc status of **Disconnected** in the Azure portal.
3. Azure Local VM deployment reports a remote procedure call (RPC) failure in the Azure portal.
4. An update fails at **update ARB and extensions** with `SSL: CERTIFICATE_VERIFY_FAILED`.

These symptoms are not unique to connectivity problems. Capture the exact error, affected machines, and time of failure before changing network configuration.

## Issue Validation

Start with the failed deployment or update readiness check. Azure Local Environment Checker and solution update readiness checks provide individual results, diagnostic details, and remediation guidance.

See the [Appendix](#appendix) for PowerShell examples. Record the failing endpoint and node, and compare the check timestamp with the incident. Use this module when you need additional endpoint, certificate, proxy, or DNS evidence.

## Prerequisites

- Open **Windows PowerShell 5.1 as Administrator** on the machine to test. PowerShell 7 is not supported by `Test-AzureLocalConnectivity`.
- Identify your deployment's Azure region, Key Vault URL, and Arc Gateway URL if applicable. Replace every `<placeholder>` before running an example. Use the Key Vault's actual URI, including the correct cloud suffix.
- **Environment Validator (`AzStackHci.EnvironmentChecker`) is required and checked automatically by the function.** A separate manual dependency check is not required for an interactive run. Azure Local supplies and manages this dependency through solution updates; do not manually install, update, or uninstall it on Azure Local nodes. If the function reports it missing or unable to load on a node, stop and contact Microsoft Support. On a non-Azure Local Windows device used for pre-deployment testing or network troubleshooting, the function prompts to install the dependency from PowerShell Gallery if it is missing. See [Environment Checker guidance](https://learn.microsoft.com/azure/azure-local/manage/use-environment-checker) for background; its standalone installation and cleanup procedures are not instructions to modify the managed dependency on Azure Local nodes.
- **Allow Environment Validator to retrieve current connectivity targets.** `Test-AzureLocalConnectivity` calls Environment Validator's `Get-AzStackHciConnectivityTarget` to retrieve the target endpoint list from `https://aka.ms/HciConnectivityTargets`. Allowing outbound access to this URL and its redirect destination is highly recommended to obtain current targets. The diagnostic module's update switches do not control this separate dependency download.
- For online installation of the diagnostic module, allow access to PowerShell Gallery or use your approved offline installation process. On non-Azure Local test devices, also provide Environment Validator through an approved process if Gallery access is unavailable. On Azure Local nodes, use the existing managed dependency. `-NoAutoUpdate` does not disable installation of a missing Environment Validator dependency.
- Use an Azure Local node for incident diagnosis. A staging device is useful before deployment only when it uses the intended DNS, routing, and firewall/proxy path. A successful staging-device test does not prove node or ARB connectivity.

> [!IMPORTANT]
> The connectivity test sends outbound requests, performs download measurements, and writes local diagnostic files. It does not remediate firewall, proxy, DNS, or certificate settings. Coordinate testing on bandwidth-constrained links, especially for cluster-wide runs. Installing or updating modules changes local software. In version 0.7.0, silent mode (`-NoOutput`) automatically accepts installation of a missing Environment Validator dependency. Before unattended runs, verify both modules are available on every target device. If Environment Validator is missing on an Azure Local node, stop rather than allowing automatic installation. Preinstall missing dependencies only on non-Azure Local test devices, with the required permissions and software-installation approval.

## Mitigation Details

The following tests collect evidence for your network administrator or Microsoft Support. Choose the options that match the affected deployment, then use [Interpret results and verify resolution](#interpret-results-and-verify-resolution) to decide the next action.

The module supplements built-in readiness checks with:

* **Per-endpoint results** - DNS and Layer-7 (HTTP/HTTPS) results help isolate unreachable endpoints. Direct TCP tests are optional: add `-IncludeTCPConnectivityTests` when you need direct-path evidence.
* **TLS inspection evidence** - captures certificate-chain details and flags suspected interception. Certificate verification errors can also have other causes; review the chain and response together.
* **Private-address detection** - identifies RFC1918 addresses and checks proxy-bypass evidence to help distinguish intentional private endpoints from incorrect DNS configuration.
* **Scenario-aware endpoint selection** - uses Azure region, Arc Gateway options, and hardware vendor detection to select endpoints.

> [!NOTE]
> This article documents **AzStackHci.DiagnosticSettings 0.7.0** and connectivity output schema **1.2**. See [Key parameter changes from previous versions](#key-parameter-changes-from-previous-versions) for changes affecting earlier examples.

**Validation evidence:** `Test-AzureLocalConnectivity` version 0.7.0 was exercised repeatedly on a Windows hardware test device across all supported Azure regions and produced schema 1.2 reports with real endpoint results. The result-handling examples were also exercised with synthetic data. The retained reports demonstrate node-scope safe-proxy validation; cluster fan-out remains outside this evidence. Validation fidelity is L2.

### Install and run connectivity tests

1. **[READ-ONLY] Check the PowerShell version and diagnostic module.** Expect PowerShell `5.1` with edition `Desktop`, and note whether the diagnostic module is installed. The function checks for Environment Validator automatically when it runs. Risk is not applicable to this inventory check.

```PowerShell
$PSVersionTable | Select-Object PSVersion, PSEdition
Get-Module -ListAvailable -Name AzStackHci.DiagnosticSettings |
    Select-Object Name, Version, Path
```

2. **Install the diagnostic module if it is not already installed.**

    **Action type:** State-changing

    **Risk label:** `[LOW RISK]` - installs the current PowerShell Gallery release for all users without expected workload impact.

    Skip installation if the inventory above lists the module. Administrator rights and software-installation approval are required. Stop on installation errors rather than bypassing security controls.

```PowerShell
Install-Module -Name AzStackHci.DiagnosticSettings `
    -Repository PSGallery -Scope AllUsers -ErrorAction Stop
```

In a fresh Windows PowerShell session, import the module and verify the loaded version:

```PowerShell
Import-Module -Name AzStackHci.DiagnosticSettings -ErrorAction Stop
Get-Module -Name AzStackHci.DiagnosticSettings | Select-Object Name, Version, Path
```

The test checks for newer releases by default and notifies you when one is available. To approve installation, rerun the command with `-AutoUpdate`. If an update is installed, the current run stops; open a fresh session, import and verify the new version, then rerun the test. There is no need to pin installation to 0.7.0, which is the version reviewed for this article. Retain previous approved versions if rollback is needed; select one explicitly in a fresh session and verify it with `Get-Module`.

3. **Run the test for the affected region.** Supply your actual Key Vault URI. Add `-ArcGatewayURL` if applicable, as shown in [Arc Gateway deployments](#arc-gateway-deployments).

```PowerShell
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" `
    -KeyVaultURL "https://<YourKeyVaultName>.vault.azure.net"
```

Expect endpoint results and report paths at completion. By default, results are written to a self-contained HTML report; JSON and transcript artifacts are also generated. Add `-Verbose` or `-Debug` when more request details are needed. If no results are returned, resolve the reported prerequisite or execution error before interpreting connectivity. Open the HTML report and retain the transcript for the failing run.

**Missing dependency installation (non-Azure Local test devices only)**

The function checks for the dependency automatically. The installation prompt is intended for non-Azure Local Windows devices used for pre-deployment testing or network troubleshooting. If it appears on an Azure Local node, decline it and stop testing; do not manually install, update, or uninstall Environment Validator on the node, as this component is managed through solution updates.

**Action type:** State-changing

**Risk label:** `[LOW RISK]` - accepting the prompt installs `AzStackHci.EnvironmentChecker` for all users without expected workload impact.

On a non-Azure Local test device, enter `Y` only with software-installation approval and PowerShell Gallery access. Administrator rights are required. Declining stops the test. If installation fails, stop and resolve the error; do not interpret the incomplete run as a connectivity result. Confirm the test proceeds past the dependency check and produces endpoint results. Any cleanup of a separately installed test-device copy must follow your approved software-removal process and must not be applied to Azure Local nodes.

### Run tests across all cluster nodes (`-Scope Cluster`)

By default the function tests connectivity from the **current node only** (`-Scope Node`). When you run the command from a node that is a member of an active Azure Local (failover) cluster, you can add `-Scope Cluster` to enumerate every cluster node and run the same connectivity test on each node, then aggregate the per-node results into a single tabbed HTML report.

Cluster mode requirements:

* The function automatically checks for **AzStackHci.EnvironmentChecker** on each node. If it reports the dependency missing or unable to load, stop and contact Microsoft Support; do not install, update, or uninstall it manually.
* The **AzStackHci.DiagnosticSettings** module must be installed (at the same version) on every cluster node. If a node is missing the module or has a different version, the run fails fast and lists the affected nodes — unless you add `-InstallMissingModuleOnNodes` (see below).
* Standard Kerberos / `Invoke-Command` remoting is used (no CredSSP or TrustedHosts changes are required).
* Start from an elevated Windows PowerShell 5.1 session directly on a cluster node (for example, through a remote desktop or console session), with remote access to every node. Starting cluster fan-out inside an existing PowerShell remoting session can encounter the Kerberos double-hop restriction. Do not enable CredSSP or modify TrustedHosts to work around it; use a direct session on the node or run node-scope tests separately.

```PowerShell
# Run the connectivity test on every node in the cluster and produce a
# single, tabbed cluster HTML report.
# /// ACTION: Update <AzureRegionName> to match your Azure Region.
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" `
    -KeyVaultURL "https://<YourKeyVaultName>.vault.azure.net" `
    -Scope Cluster
```

Each node runs its own Layer-7 sweep with a default of eight parallel workers. Cluster operations have a 30-minute deadline; timed-out or failed nodes must be treated as incomplete coverage, not as successful tests.

**Optional module side-loading:** After reviewing the pre-flight list of missing or mismatched modules and obtaining software-installation approval, add `-InstallMissingModuleOnNodes` to copy the orchestrator's exact module version to those nodes. The copy does not require PowerShell Gallery access on the nodes, but it does not provision the Environment Checker dependency. Stop if copying or importing fails. Verify that a subsequent run passes the version pre-flight; retain prior approved versions for rollback and use a fresh session to select one if needed.

```PowerShell
# Cluster test, automatically side-loading the orchestrator's module version
# to any node that is missing it or has a version mismatch (drift).
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" `
    -KeyVaultURL "https://<YourKeyVaultName>.vault.azure.net" `
    -Scope Cluster `
    -InstallMissingModuleOnNodes
```

### Arc Gateway deployments

If your Azure Local deployment uses Arc Gateway, supply `-ArcGatewayURL`. This automatically enables gateway mode, which skips direct tests for entries marked as supporting Arc Gateway and tests the gateway endpoint and remaining direct-access endpoints. You may also specify `-ArcGatewayDeployment` explicitly, but that switch requires `-ArcGatewayURL`.

```PowerShell
# Test connectivity for Arc Gateway deployment.
# -ArcGatewayURL automatically enables gateway mode.
# /// ACTION: Update parameters below to match your Azure Region, Key Vault, and Arc Gateway URL.
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" `
    -KeyVaultURL "https://<YourKeyVaultName>.vault.azure.net" `
    -ArcGatewayURL "https://<YourArcGatewayID>.gw.arc.azure.com"
```

### OEM hardware partner endpoints

The module detects the original equipment manufacturer (OEM) automatically. To select a different vendor, such as when testing from a staging VM, use `-IncludeOEMUrls`:

```PowerShell
# Include OEM-specific endpoints for your hardware vendor.
# Valid values: DataOn, Dell, HPE, Hitachi, Lenovo, TestAll
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" `
    -KeyVaultURL "https://<YourKeyVaultName>.vault.azure.net" `
    -IncludeOEMUrls "<YourOEMPartner>"
```

### Control module updates and GitHub endpoint refresh

By default the function checks PowerShell Gallery for a newer module version (notification only) and attempts to refresh endpoint lists from GitHub (`raw.githubusercontent.com`). It does not install an update unless you specify `-AutoUpdate`. These parameters control update and endpoint-list retrieval, not the connectivity probes:

* **`-NoAutoUpdate`** skips the PowerShell Gallery update check and GitHub endpoint-list download, using the bundled cache instead. Endpoint probes and download measurements still make outbound requests; this is not an offline test or a network-access control.
* **`-ForceGitHubEndpointsUpdate`** forces the endpoint-list refresh from GitHub **even when `-NoAutoUpdate` is specified**. This decouples the endpoint refresh from the module update check, so you can leave the installed module untouched while still pulling the freshest endpoint list. It only has an effect together with `-NoAutoUpdate` (without it, the GitHub refresh is already attempted by default). If the download is blocked or fails, the run gracefully falls back to the cached endpoint files.

If `-ForceGitHubEndpointsUpdate` is used alone, the module warns that it has no additional effect. For unattended runs, verify dependencies as described in [Prerequisites](#prerequisites) and also specify `-ExcludeUploadResults` to skip the upload prompt.

> [!IMPORTANT]
> These switches do not make the test offline. Environment Validator is required; the module prompts to install it if missing during an interactive run. Accept that prompt only on a non-Azure Local test device with installation approval; on an Azure Local node, decline and contact Microsoft Support. Its `Get-AzStackHciConnectivityTarget` function retrieves the endpoint list through `https://aka.ms/HciConnectivityTargets`, independently of this module's GitHub endpoint refresh. Allowing that download is highly recommended even when `-NoAutoUpdate` is used. Endpoint probes and download measurements also require outbound connectivity.

```PowerShell
# Leave the installed module untouched (no PSGallery check) but still refresh the
# endpoint list from GitHub. Useful when raw GitHub content is allowed through the
# firewall/proxy but the PowerShell Gallery is not.
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" `
    -NoAutoUpdate `
    -ForceGitHubEndpointsUpdate
```

### Faster testing: HEAD requests and parallel workers

Two parameters can reduce the wall-clock time of a full endpoint sweep:

* **`-RequestMethod`** controls the HTTP method used to test each endpoint:
  * `Auto` (**default**) — try an HTTP `HEAD` request first (status line and headers only, no body download) and automatically fall back to `GET` for any endpoint that rejects or under-answers `HEAD` (for example a `405 Method Not Allowed`, `400 Bad Request`, or an ambiguous `403`). This gives the speed of `HEAD` with `GET` as a safety net.
    * `Get` - always use `GET`. Use this to compare request-method behavior with versions before 0.6.7; it does not disable newer retry or classification logic.
  * `Head` — always use `HEAD` with no fallback. Fastest, but some endpoints (certain storage SAS URLs and CDN edge nodes) respond differently to `HEAD` than `GET`.
* **`-Parallelism`** (1–16, default `1`) fans the Layer-7 endpoint sweep out across that many process-isolated background workers. At `1` the test runs sequentially (identical to earlier behaviour). With `-Scope Cluster`, each node uses a per-node default of `8`.

```PowerShell
# Faster sweep: HEAD-first with GET fallback (default) and 8 parallel workers.
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" -Parallelism 8

# Use GET-only, sequential requests for comparison.
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" -RequestMethod Get -Parallelism 1
```

Output ordering is preserved regardless of `-Parallelism` (results are re-sorted before the report is written), so the report contents are comparable between sequential and parallel runs.

### Supported Azure regions

Version 0.7.0 accepts these exact `-AzureRegion` values (case-insensitive). These are module input names, not a guarantee that every Azure service is available in each region:

* `EastUS`, `WestEurope`, `AustraliaEast`, `CanadaCentral`, `CentralIndia`, `JapanEast`, `SouthCentral`, `SouthEastAsia`, `USGovVirginia`

Use `SouthCentral` for South Central US. Confirm current deployment availability in [Azure requirements](https://learn.microsoft.com/azure/azure-local/concepts/system-requirements-23h2#azure-requirements).

### Testing an individual endpoint

After completing the installation steps, use `Test-Layer7Connectivity` to investigate an individual endpoint. Match the URL and port to the failing report row:

```PowerShell
$url = 'https://graph.microsoft.com/v1.0/'
Test-Layer7Connectivity -url $url -port 443 -Verbose -Debug
```

## Output format

### HTML report (default)

The default HTML report includes:

* **Color-coded rows** - Connectivity failures are highlighted in red and successful endpoints in green. Configuration gaps and advisory redirect failures are warnings; a warning is not proof that an additional firewall rule is required.
* **Summary section** — Hostname, timestamp, Azure region, hardware OEM, and download speed are displayed at the top of the report.
* **Scrollable table** — A synchronized dual-scrollbar table allows horizontal scrolling of the wide results table from both the top and bottom.
* **Full endpoint details** — Each row includes the URL, port, Arc Gateway support status, source, IP address, Layer 7 status, response, response time, certificate chain details (leaf, intermediate, root), and notes.

Version 0.7.0 adds conditional **Direct TCP Diagnostics** and **DNS Diagnostics** columns when evidence is available. IP addresses are displayed as text, preferring IPv4 when both families are returned. This display preference does not change the tested TCP destination.

### JSON output (always generated)

A completed report includes a JSON file alongside HTML or CSV. Schema `1.2` includes the endpoint results, run metadata, redirect classification, and nested TCP/DNS evidence. Early prerequisite failures or file-write errors can prevent artifact creation; check reported paths rather than assuming a file exists.

### CSV format (optional)

Use `-OutputFormat CSV` for spreadsheet analysis. Diagnostic evidence is flattened into CSV columns; JSON retains the nested objects:

```PowerShell
Test-AzureLocalConnectivity -AzureRegion "EastUS" -OutputFormat CSV
```

### Output file location

Connectivity reports and transcripts are saved under `C:\ProgramData\AzStackHci.DiagnosticSettings\Reports\Connectivity\`.

Use `-ExportPath` to copy the run's artifacts to an additional **absolute local path**. UNC shares (such as `\\server\share`) and relative paths are not supported. The canonical reports remain in the folder above if the additional copy fails:

```PowerShell
Test-AzureLocalConnectivity -AzureRegion "EastUS" -ExportPath "C:\Temp\AzureLocalDiagnostics"
```

Node-scope filenames:

| File | Description |
|------|-------------|
| `AzureLocal_ConnectivityTest_<Region>_<Hostname>_<DateTime>.html` | HTML report (default) or `.csv` if `-OutputFormat CSV` is used |
| `AzureLocal_ConnectivityTest_<Region>_<Hostname>_<DateTime>.json` | JSON test results with summary metadata (always generated) |
| `Transcript_AzureLocal_ConnectivityTest_<Region>_<Hostname>_<DateTime>.log` | PowerShell transcript log |

In cluster scope, use the returned `ReportPath` and `JSONReportPath` for the merged report on the orchestrator. Per-node report paths refer to files on the corresponding remote node. Do not construct cluster filenames from the node-scope patterns above. The module warns about recognized canonical artifacts older than 180 days; it does not delete them automatically.

## Interpret results and verify resolution

### Decide which findings need action

Start with the summary, then inspect the affected endpoint's URL, port, response, certificate chain, and notes. A service can be reachable while returning an HTTP error to an unauthenticated probe; use the module's classification and supporting evidence, not the HTTP status alone.

| Finding | Next action |
| --- | --- |
| Connectivity failure, not an advisory redirect | Correlate the failure with DNS, proxy, routing, and firewall logs for the same node and time. Confirm the endpoint is required for your scenario before requesting a targeted change. |
| `ConfigGap` | Supply the missing test input, such as the actual Key Vault URL, and rerun. This is not evidence of a blocked endpoint. |
| `SSLInspected` | Review the certificate chain with the network team. Azure Local does not support HTTPS inspection; apply the documented exception through your approved change process. Do not bypass certificate validation. |
| `PrivateLink` | Check the resolved address and intended DNS/routing configuration. Arc endpoints must resolve publicly; a proxy bypass does not make Arc Private Link supported. Other private endpoints require scenario-appropriate routing and proxy bypass. |
| CRL/OCSP offline | Investigate reachability of certificate revocation endpoints. Unavailable revocation checks are distinct from an intercepted certificate. |
| `Skipped`, an untested placeholder, or a failed node collection | Treat as untested or incomplete, not as success. Confirm whether the exclusion is expected and obtain missing evidence where needed. |
| Download speed `Failed` | The measurement was unavailable or incomplete. Review endpoint results separately; this value does not mean every endpoint failed. |

Follow the [Azure Local firewall requirements](https://learn.microsoft.com/azure/azure-local/concepts/firewall-requirements) for HTTPS inspection and Private Link restrictions. Do not disable the firewall, change authentication policy, or open every discovered redirect destination to make the report green.

### Redirects and wildcard probes

In schema `1.2`, each row includes `RedirectDisposition`:

| Value | Meaning |
| --- | --- |
| `NotRedirect` | The row is not classified as a redirected destination. |
| `RequiredDependency` | The module classified the destination as part of a required redirect chain; connectivity failures remain failures. |
| `Advisory` | The probe discovered the destination, but its requirement is unverified. Connectivity failures are warnings, while raw status and `ResultCategory` are unchanged. |

Use `RedirectReason`, `RedirectOriginUrls`, and `RedirectTargetUrl` to trace the evidence. Wildcard **Test for** rows probe concrete hostnames using ports matched from the loaded endpoint inventory. Unmatched hosts are skipped; the module no longer assumes ports 80 and 443 for every wildcard probe.

### TCP and DNS evidence

With `-IncludeTCPConnectivityTests`, `TCPDiagnostics` captures direct TCP source-address, interface, route, and DNS-answer evidence where available. Direct TCP probes do not validate a proxy-mediated application path, so a failed direct connection alone does not prove that HTTPS through the proxy is blocked.

`DNSResolutionStatus` describes normal resolution. After normal DNS fails, `DNSDiagnostics` can contain bounded queries to configured resolvers. Namespace policies, ambiguous interfaces, route checks, or time limits can prevent these diagnostic queries; review `CollectionStatus` and `SkipReason`. Diagnostic-only answers, including private-address annotations, do not replace the original failed result or identify which server answered a normal DNS request.

### Verify after an approved change

1. Retain the original report and record the affected nodes, endpoints, and test time. Ask the network owner to preserve the previous settings and define rollback before applying any approved change.
2. Rerun the same test from each affected node with the same region and scenario options. Confirm that the targeted failures are resolved and no new required-endpoint failures appear. Compare endpoint inventories if the lists refreshed between runs.
3. Review configuration gaps, TLS/Private Link findings, advisories, and collection errors separately. Zero hard failures is not proof of complete coverage.
4. Rerun the original deployment or update readiness check using its supported workflow. Confirm a fresh successful result before retrying the affected operation. Reading an old `Get-SolutionUpdateEnvironment` result alone does not rerun a check.
5. If the original failure persists, stop broadening network exceptions. Escalate with both reports and the original operation error; have the network owner roll back any change that introduced a regression.

## Programmatic use with `-PassThru` (automation)

The `-PassThru` switch returns a **structured object** (`[pscustomobject]`) for automation without re-parsing the JSON report. In module version 0.7.0, the object and JSON use `SchemaVersion` `1.2`. Node-scope endpoint rows are under `.Results`; cluster-scope node objects are under `.Nodes`.

> **Caller contract:** assign the result directly (`$ConnectivityTests = Test-AzureLocalConnectivity ... -PassThru`). Filter `$ConnectivityTests.Results`, keeping `$ConnectivityTests` for run-level metadata. Verify both modules are available according to [Prerequisites](#prerequisites), supply the region and scenario inputs, and disable the upload prompt explicitly. On Azure Local nodes, a missing Environment Validator dependency is a stop condition, not an instruction to install it.

### Node scope (`-Scope Node`, default)

`-PassThru` returns the structured object described above. The per-endpoint rows are under `$ConnectivityTests.Results`, and each **row** includes a `ResultCategory` field that classifies the outcome, so you no longer need to parse free-text notes to tell a genuine connectivity failure apart from a configuration gap:

| `ResultCategory` | Meaning |
|------------------|---------|
| `Success` | Endpoint reachable. |
| `ConnectivityFailure` | Connectivity test failed. Check `RedirectDisposition` before treating the row as a hard failure. |
| `ConfigGap` | A required parameter was not supplied (for example `-KeyVaultURL` left unsubstituted) — a setup issue, not a blocked endpoint. |
| `SSLInspected` | SSL/TLS inspection was detected on the path to the endpoint. |
| `PrivateLink` | Endpoint resolved to a private (RFC1918) address — possible Private Link configuration. |
| `Skipped` | Endpoint was not tested (for example, skipped under Arc Gateway, or an untested wildcard placeholder). |

Run-level properties include report paths, hostname, region, download speed, request method, parallelism, timing, captured proxy settings, and SSL inspection, Private Link, and revocation-offline findings. Per-row `RedirectDisposition`, `RedirectReason`, `RedirectOriginUrls`, `RedirectTargetUrl`, `DNSResolutionStatus`, `TCPDiagnostics`, and `DNSDiagnostics` provide the schema 1.2 evidence described above.

The following example fails on non-advisory connectivity failures and critical Arc private-address resolution. It is not a complete readiness gate: also review `ConfigGap`, `SSLInspected`, other Private Link findings, skipped tests, and collection coverage according to your scenario. Add `-ArcGatewayURL` for gateway deployments.

```PowerShell
# Capture results without update checks or the upload prompt.
$ConnectivityTests = Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" `
    -KeyVaultURL "https://<YourKeyVaultName>.vault.azure.net" `
    -NoAutoUpdate -ExcludeUploadResults -NoOutput -PassThru -ErrorAction Stop
if ($null -eq $ConnectivityTests -or $null -eq $ConnectivityTests.Results -or @($ConnectivityTests.Results).Count -eq 0) {
    throw "No endpoint results were returned. Review the transcript and errors."
}

# Preserve advisory redirects as warnings, not hard failures.
$advisories = @($ConnectivityTests.Results | Where-Object {
    $_.ResultCategory -eq 'ConnectivityFailure' -and $_.RedirectDisposition -eq 'Advisory'
})
if ($advisories.Count -gt 0) {
    Write-Warning "$($advisories.Count) redirect advisory failure(s); review applicability before changing firewall rules."
}
$failures = @($ConnectivityTests.Results | Where-Object {
    $_.ResultCategory -eq 'ConnectivityFailure' -and $_.RedirectDisposition -ne 'Advisory'
})
$failures | Format-Table URL, Port, Layer7Status, ResultCategory -AutoSize
if ($failures.Count -gt 0) {
    throw "$($failures.Count) endpoint connectivity failure(s) detected."
}

# Run-level flags (real properties on the returned object)
if ($ConnectivityTests.PrivateLinkCriticalArray.Count -gt 0) {
    throw "Arc endpoint(s) resolved to a private IP: $($ConnectivityTests.PrivateLinkCriticalArray -join ', ')"
}
```

### Cluster scope (`-Scope Cluster`)

With `-Scope Cluster -PassThru`, the function returns the **same unified structured object** as node scope, except the per-endpoint rows are grouped per node under a `.Nodes` array (each entry is itself a node-shaped structured object with its own `.Results` and run-level/detection fields). This gives you one consistent contract regardless of scope. Key top-level properties:

| Property | Description |
|----------|-------------|
| `SchemaVersion` | Contract schema version (`1.2`), also used by nested node objects. |
| `Scope` | `Cluster`. |
| `ClusterName` | Cluster name from `Get-Cluster`. |
| `OrchestratorMachine` | Node that orchestrated the run. |
| `RunGuid` | Unique identifier for the cluster run. |
| `StartTime` / `EndTime` / `Duration` | Orchestration timing. |
| `ReportPath` / `JSONReportPath` | The **merged** cluster report and JSON on the orchestrator (local to the caller). |
| `ExportPath` | Folder containing the merged cluster artifacts on the orchestrator. Per-node files remain on their respective nodes. |
| `Nodes` | Array of per-node structured objects. Each entry carries `Hostname`, `Collected`, `Error`, `Results` (that node's per-endpoint rows), and the same run-level/detection fields as a node-scope run (per-node `ReportPath` / `JSONReportPath` point to files on the remote node). |
| `Errors` | Per-node error messages (empty when the node succeeded). |

```PowerShell
# Run a cluster test and inspect per-node results programmatically.
$cluster = Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" `
    -KeyVaultURL "https://<YourKeyVaultName>.vault.azure.net" `
    -Scope Cluster -NoAutoUpdate -ExcludeUploadResults -PassThru -ErrorAction Stop
if ($null -eq $cluster -or $null -eq $cluster.Nodes -or @($cluster.Nodes).Count -eq 0) {
    throw "No cluster results were returned. Review the pre-flight errors."
}

foreach ($node in $cluster.Nodes) {
    if (-not $node.Collected -or $node.Error -or $null -eq $node.Results -or @($node.Results).Count -eq 0) {
        Write-Warning "$($node.Hostname) collection failed or returned no endpoint results: $($node.Error -join '; ')"
        continue
    }

    $failures = @($node.Results | Where-Object {
        $_.ResultCategory -eq 'ConnectivityFailure' -and $_.RedirectDisposition -ne 'Advisory'
    })
    $advisories = @($node.Results | Where-Object {
        $_.ResultCategory -eq 'ConnectivityFailure' -and $_.RedirectDisposition -eq 'Advisory'
    })
    Write-Host "$($node.Hostname) : $($failures.Count) connectivity failure(s), $($advisories.Count) redirect advisory failure(s)"
}
```

## Share test results with Microsoft (Optional)

Where the Azure Local log-collection command is available, the function offers to upload diagnostic results to Microsoft. Upload occurs only after you accept the prompt. See [Collect diagnostic logs for Azure Local](https://learn.microsoft.com/azure/azure-local/manage/collect-logs?tabs=powershell#about-on-demand-log-collection) for the transfer process.

Use `-ExcludeUploadResults` to skip the prompt, including in automation. If upload is unavailable on a staging device, retain the local artifacts and use your support case's approved transfer method.

Review files under your organization's data-handling policy before sharing: reports can contain hostnames, IP addresses, resource identifiers, and proxy or certificate details. Do not post diagnostic files in a public GitHub issue. For an existing support request, share the upload's `CorrelationId` and other requested identifiers privately with the case owner.

## Demo and example output

The following recording illustrates the interactive workflow. It is not a version-specific reference for the 0.7.0 report layout; use the parameter and output guidance in this article for current behavior.

The primary source of information is **opening the HTML output file** in a web browser on your laptop or desktop PC. The HTML report provides an interactive, color-coded view of all test results. Alternatively, use the JSON output for programmatic analysis or the CSV format for spreadsheet workflows.

![Test-AzureLocalConnectivity Demo](./images/Test-AzureLocalConnectivity_Demo.gif)

## Parameter reference

The following reference summarizes the public parameters for version 0.7.0; it is not a script to run. Use `Get-Command Test-AzureLocalConnectivity -Syntax` for installed command syntax and `Get-Help Test-AzureLocalConnectivity -Full` for help.

<details>
<summary>Parameter summary (click to expand)</summary>

```PowerShell
[CmdletBinding(DefaultParameterSetName = 'Default')]
param (
    # Target Azure region for endpoint testing.
    [ValidateSet("EastUS", "WestEurope", "AustraliaEast", "CanadaCentral",
                 "CentralIndia", "JapanEast", "SouthCentral", "SouthEastAsia",
                 "USGovVirginia")]
    [string]$AzureRegion,

    # Custom KeyVault URL including https:// prefix.
    # Example: https://yourhcikeyvaultname.vault.azure.net
    [System.Uri]$KeyVaultURL,

    # Switch to ONLY test URLs that do NOT support Arc Gateway.
    # Requires -ArcGatewayURL; optional when the URL is supplied.
    [switch]$ArcGatewayDeployment,

    # Custom Arc Gateway URL including https:// prefix.
    # Automatically enables -ArcGatewayDeployment.
    # Example: https://1be59945-12c0-4cda-9580-84a66a1120a0.gw.arc.azure.com
    [System.Uri]$ArcGatewayURL,

    # Custom DNS Name for NTP Time Server (no http:// or https:// prefix).
    # Example: yourtimeserver.fqdn, this can be your on-premises AD domain FQDN, if using AD integrated NTP service (PDC).
    [string]$NTPTimeServer,

    # Include tests for TCP connectivity (for scenarios not using a Proxy).
    [switch]$IncludeTCPConnectivityTests,

    # Exclude testing of Redirected endpoints.
    [switch]$ExcludeRedirectedUrls,

    # Exclude testing manually defined subdomains for Wildcard endpoints.
    [switch]$ExcludeWildcardTests,

    # Exclude the prompt to upload test results to Microsoft.
    [switch]$ExcludeUploadResults,

    # Include OEM hardware partner specific endpoints.
    # Valid values: DataOn, Dell, HPE, Hitachi, Lenovo, TestAll
    [string]$IncludeOEMUrls,

    # Skip the PowerShell Gallery update check AND skip downloading endpoint
    # lists from GitHub (uses cached endpoint files bundled with the module).
    # Does not control Environment Validator's separate endpoint download.
    [switch]$NoAutoUpdate,

    # Opt in to installing a newer module version from PowerShell Gallery.
    # If installed, this run stops; import in a fresh session and rerun.
    # Default behaviour is notification only.
    [switch]$AutoUpdate,

    # Force downloading the latest endpoint lists from GitHub even when
    # -NoAutoUpdate is specified. Only has an effect together with -NoAutoUpdate
    # (the GitHub refresh is already attempted by default otherwise). Falls back
    # to the cached endpoint files if the download is blocked or fails.
    [switch]$ForceGitHubEndpointsUpdate,

    # Suppress normal console output, not every warning/error or upload prompt.
    # Silent mode automatically accepts installing missing Environment Validator.
    [switch]$NoOutput,

    # Return the structured results object (Node scope) or the unified cluster
    # structured object (Cluster scope) for further processing in PowerShell.
    # Node rows are under .Results; cluster nodes are under .Nodes (schema 1.2).
    [switch]$PassThru,

    # Output report format. Default is HTML. CSV is also available.
    # JSON is always generated in addition to the selected format.
    [ValidateSet('HTML', 'CSV')]
    [string]$OutputFormat = 'HTML',

    # HTTP request method for each endpoint test.
    #   'Auto' (default) - HEAD first, GET fallback on 405/400/ambiguous response.
    #   'Get'  - GET only; does not revert newer retry/classification logic.
    #   'Head' - HEAD only, no fallback (fastest; some endpoints reject HEAD).
    [ValidateSet('Get', 'Head', 'Auto')]
    [string]$RequestMethod = 'Auto',

    # Number of parallel workers for the Layer-7 endpoint sweep (1-16).
    # Default 1 (sequential). With -Scope Cluster the per-node default is 8.
    [ValidateRange(1, 16)]
    [int]$Parallelism = 1,

    # Test scope. 'Node' (default) tests the current node only. 'Cluster'
    # enumerates Get-ClusterNode and runs the test on every node, aggregating
    # the per-node results into a tabbed HTML report.
    [ValidateSet('Node', 'Cluster')]
    [string]$Scope = 'Node',

    # Only valid with -Scope Cluster. Side-load the orchestrator's exact module
    # version to nodes that are missing it or have a different version. Opt-in;
    # never mutates remote nodes silently. No PowerShell Gallery / internet
    # dependency (copies from the orchestrator's installed module folder).
    [switch]$InstallMissingModuleOnNodes,

    # Optional additional absolute local copy target; UNC/relative paths rejected.
    # Canonical connectivity artifacts are routed under Reports\Connectivity
    # beneath the default path. Use returned report paths to locate artifacts.
    [string]$ExportPath = 'C:\ProgramData\AzStackHci.DiagnosticSettings'
)
```

</details>

### Key parameter changes from previous versions

| Change | Details |
|--------|---------|
| `-Scope` | **New in 0.6.7.** `Node` (default) tests the current node only; `Cluster` enumerates `Get-ClusterNode` and runs the test on every node via `Invoke-Command`, aggregating per-node results into a tabbed HTML report. |
| `-InstallMissingModuleOnNodes` | **New in 0.6.7.** Only valid with `-Scope Cluster`. Side-loads the orchestrator's exact module version to nodes that are missing it or have a version mismatch (drift). Opt-in; no PowerShell Gallery / internet dependency. |
| `-ExportPath` | Copies artifacts to an additional absolute local path; UNC shares are not supported. Since 0.6.9, canonical connectivity artifacts are under `C:\ProgramData\AzStackHci.DiagnosticSettings\Reports\Connectivity`. |
| `-Parallelism` | **New in 0.6.7.** Fans the Layer-7 sweep out across 1–16 process-isolated workers. Default `1` (sequential). Per-node default is `8` under `-Scope Cluster`. |
| `-RequestMethod` | **New in 0.6.7.** `Auto` (default), `Get`, or `Head`. The default is HEAD-first with GET fallback. Use `-RequestMethod Get` for GET-only comparisons; this does not revert newer retry or classification logic. |
| `-PassThru` | Structured object since 0.6.8; **schema 1.2 in 0.7.0** adds redirect classification and TCP/DNS diagnostic evidence. Node rows remain under `.Results`; cluster node objects remain under `.Nodes`. See [Programmatic use with -PassThru](#programmatic-use-with--passthru-automation). |
| `-AutoUpdate` | **New in 0.6.7.** Opt in to installing a newer module version from PowerShell Gallery. An installation stops the current run; import in a fresh session and rerun. Default is notification only. |
| `-ForceGitHubEndpointsUpdate` | **New in 0.6.8.** Forces the endpoint-list refresh from GitHub even when `-NoAutoUpdate` is specified, leaving the installed module untouched. Only meaningful together with `-NoAutoUpdate`; falls back to cached endpoint files if the download is blocked. |
| `-ArcGatewayDeployment` and `-ArcGatewayURL` | In 0.7.0, supplying the URL automatically enables gateway mode. The switch remains supported and requires the URL if used. |
| `-OutputFormat` | Controls the report format: `HTML` (default) or `CSV`. JSON is always generated alongside. |
| `-IncludeOEMUrls` | Allows testing OEM hardware partner specific endpoints (DataOn, Dell, HPE, Hitachi, Lenovo, or TestAll). |
| `-NoAutoUpdate` | Skips this module's PowerShell Gallery update check and GitHub endpoint-list refresh. Does not suppress Environment Validator's endpoint download or connectivity probes. |
| `-NoOutput` | Suppresses normal console output, not every warning/error or upload prompt. In 0.7.0, silent mode automatically accepts installation of missing Environment Validator. Verify dependencies before unattended runs; stop if Environment Validator is missing on an Azure Local node. |
| `USGovVirginia` | Azure region included in the `-AzureRegion` validated set. |
| HTML output | Default output format is HTML with color-coded rows and summary section. |
| JSON output | **Always generated** alongside the primary report format. |
| Download speed test | In 0.7.0, bounded recovery handles eligible transport failures, and numeric throughput requires a complete transfer. A failed measurement does not prevent endpoint reporting. |
| Private Link detection | Detects and warns if endpoints resolve to RFC1918 private IP addresses (possible Private Link configuration). |

## Appendix

### Environment Checker Connectivity Tests

Run the Environment Checker connectivity validator and retain its full result set. These diagnostics send test traffic and write diagnostic logs; they do not change firewall settings. Review failure details and remediation rather than only endpoint names:

```PowerShell
$validation = @(Invoke-AzStackHciConnectivityValidation -PassThru -ErrorAction Stop)
if ($validation.Count -eq 0) {
    throw "Environment Checker returned no results. Review its logs."
}
$validation | Where-Object { $_.Status -in @('FAILURE', 'FAILED') } |
    Sort-Object TargetResourceName |
    Format-List TargetResourceName, Status, Description, Remediation, AdditionalData
```

For additional information for how to use Azure Local Environment Checker module, review the [Troubleshooting External Connectivity Failures in Environment Checker](../../EnvironmentValidator/Troubleshooting-External-Connectivity-Failures-in-Environment-Checker.md) article.

For prerequisites, result interpretation, and log locations, see [Run Environment Checker readiness checks](https://learn.microsoft.com/azure/azure-local/manage/use-environment-checker?tabs=connectivity#run-readiness-checks). An empty filtered view only means no matching failures were displayed; inspect the full `$validation` results for warnings and incomplete tests.

### Solution Update Environment Tests

**[READ-ONLY]** On a deployed Azure Local node, retrieve existing solution update health-check results. Risk is not applicable to this query. It does not initiate a fresh check; inspect `HealthCheckDate` before using the evidence:

```PowerShell
$result = Get-SolutionUpdateEnvironment -FullHealthCheckDetails -ErrorAction Stop
$result | Format-List HealthState, HealthCheckDate
if ($null -eq $result -or $null -eq $result.HealthCheckResult -or @($result.HealthCheckResult).Count -eq 0) {
    throw "No health-check details were returned. Use the supported workflow to refresh the checks."
}
$result.HealthCheckResult | Where-Object { $_.Status -ne 'SUCCESS' } |
    Format-List Title, Status, Severity, Description, AdditionalData, Remediation
```

Retain the displayed details with the incident evidence. For fresh-check and retry procedures, follow [Troubleshoot solution updates using PowerShell](https://learn.microsoft.com/azure/azure-local/update/update-troubleshooting-23h2#using-powershell). System health checks and checks for a specific pending update can use different validation logic; inspect the check associated with the failed operation.

## How to get additional support

If the failure persists, open a support request through the Azure portal. Provide the affected operation and exact error, node names, incident time and time zone, module version, Azure region, gateway/proxy scenario, and before-and-after HTML/JSON reports and transcripts. Include collection errors and recent network changes. Share these through the case's private upload channel, not this public repository.

<!-- tsg-metadata
{
    "schema": "azure-local-supportability/tsg-metadata/v1",
    "document_type": "troubleshoot",
    "products": ["Azure Local - connected hyperconverged deployments", "Azure Local - connected disaggregated deployments"],
    "detector": {
        "type": "command",
        "signal": "Test-AzureLocalConnectivity: ResultCategory and RedirectDisposition; cluster node Collected and Error"
    },
    "validation": {
        "fidelity_level": "L2",
        "technical_grade": null,
        "reproduction_substrate": "hardware",
        "automation_status": "not-assessed",
        "last_validated": "2026-09-28",
        "spec_ref": ""
    }
}
-->
