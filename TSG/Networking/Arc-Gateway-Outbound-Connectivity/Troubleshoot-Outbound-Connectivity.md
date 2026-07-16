# Azure Local - Troubleshoot Outbound Network Connectivity

> **TL;DR:** You can use the `Test-AzureLocalConnectivity` function from the **AzStackHci.DiagnosticSettings** module, to validate / troubleshoot outbound connectivity issues from Azure Local nodes (_or any device or VM, such as pre-physical cluster deployment_) to the required Azure endpoints.

## Contents

- [Overview](#overview)
- [Symptoms](#symptoms)
- [Issue Validation](#issue-validation)
- [Mitigation Details](#mitigation-details)
- [Output format](#output-format)
- [Programmatic use with `-PassThru` (automation)](#programmatic-use-with--passthru-automation)
- [Share test results with Microsoft (Optional)](#share-test-results-with-microsoft-optional)
- [Demo and example output](#demo-and-example-output)
- [Parameter reference](#parameter-reference)
- [Appendix](#appendix)
- [How to get additional support](#how-to-get-additional-support)

## Overview

Connected instances of Azure Local require outbound / egress network connectivity from the management network of each Azure Local instance to a list of public endpoints. This connectivity lets Azure Local use Azure as its management and control plane. In short:

* **Required for day-one and day-two operations** — initial instance deployment, applying updates, and workload provisioning all depend on it.
* **Ongoing connectivity is not optional** — it is vital for support, manageability, and licensing compliance, not just for the initial deployment.
* **The endpoint list is scenario-specific** — it is reduced when using an Azure Arc Gateway, and varies (slightly) based on which Azure region is selected.

For additional information on Azure Local Firewall requirements, please review - [Azure Local Firewall documentation](https://learn.microsoft.com/azure/azure-local/concepts/firewall-requirements).

## Symptoms

Integrating Azure Local into your existing Firewall and/or Proxy Server infrastructure can be challenging depending on your organization's network security policies, such as requirements to define a strict access control list of the URL endpoints that are allowed to communicate from your Azure Local instance(s) "management network" to the required public endpoints.

There are several symptoms or issues that will occur if the required endpoints are not accessible from the Azure Local instance(s), below are just a few examples:

1. Azure Local instance cloud deployment and/or update operations fail with network failure or timeout.
1. Physical machines show their "Azure Arc" status as "Disconnected" in Azure portal experience (_Arc agent not connected_).
1. Deployment of new Azure Local VMs fails with RPC failure in Azure portal as the ARM deployment status.
1. Updates fail at "update ARB and extensions" step with "SSL: CERTIFICATE_VERIFY_FAILED" shown in Azure portal update blade.

Many other network related issues can also occur when the required endpoints are not accessible from the management (_physical machines and ARB_) network address space.

## Issue Validation

Azure Local includes built-in automation modules that are executed as part of Solution Update Readiness and Environment Checker modules, both of these modules include connectivity tests that validate network connectivity status to critical endpoints. The output of these can be viewed locally using PowerShell, or using Azure portal during updates.

> Note: For examples of how to use and view the output of Azure Local "Solution Update Environment" and "Environment Checker" built-in modules, see the [Appendix section](#appendix) at the bottom of this article.

If you are finding it difficult to isolate the cause of the network related issue(s) or failure(s), and are experiencing issues as described in 'Symptoms' section, you can follow the steps in the 'Mitigation Details' below to gain further insights and diagnostic data to validate the required endpoints are accessible from your on-premises network.

## Mitigation Details

To help with troubleshooting or root causing network connectivity issues, you can use the **Test-AzureLocalConnectivity** function which is included in the **AzStackHci.DiagnosticSettings** module. This function is intended for operators and Customer Service and Support (CSS) engineers, either to validate connectivity before deployment or to isolate a blocked firewall/proxy endpoint during active troubleshooting. It automates testing that connectivity is working correctly from Azure Local physical machines to the required public endpoints. The function supports Arc Gateway scenarios and has an `-AzureRegion` parameter to allow testing against a specific Azure region that matches your Azure Local instance deployment.

Unlike the built-in readiness checks, which report an overall pass/fail, this function gives deeper per-endpoint diagnostics that are useful when isolating a blocked or intercepted endpoint:

* **Per-endpoint results** — every required URL is tested individually for DNS, TCP, and Layer-7 (HTTP/HTTPS) reachability, so you can pinpoint exactly which endpoint is blocked.
* **SSL inspection detection** — flags endpoints where the certificate was substituted by a proxy, the typical cause of `SSL: CERTIFICATE_VERIFY_FAILED`, and captures the leaf/intermediate/root certificate chain.
* **Private Link / RFC1918 detection** — warns when an endpoint resolves to a private IP, helping distinguish intentional Private Link from a misconfiguration.
* **Scenario-aware endpoint list** — automatically adjusts for Arc Gateway, Azure region, and your hardware OEM partner endpoints.

> Note: This article documents version **0.6.8** of the module. For the parameters added or changed in recent versions (including the 0.6.7 cluster / performance features and the 0.6.8 additions), see [Key parameter changes from previous versions](#key-parameter-changes-from-previous-versions).

The 'Test-AzureLocalConnectivity' function has a dependency on the Azure Local Environment Checker module being installed, which is installed by default on all Azure Local physical machines. If Environment Checker module (_AzStackHci.EnvironmentChecker_) is not installed on the device running the connectivity test, you will be prompted to install the module first. The device used to install the AzStackHci.DiagnosticSettings module and test connectivity must have access to the PowerShell Gallery, in order to download the module (_nuget package_) to install it.

### Install and run connectivity tests

To install the AzStackHci.DiagnosticSettings module and perform connectivity tests for a support or troubleshooting scenario, use the commands below:

```PowerShell
# Install the AzStackHci.DiagnosticSettings module, this can be on an Azure Local
# physical machine (recommended), or any device inside your network (if it is using
# the same firewall / proxy configuration as your Azure Local instance). 
# Answer "Y", to proceed with install.
Install-Module -Name "AzStackHci.DiagnosticSettings" -Repository PSGallery

# Test Azure Local Connectivity for a specific target Azure region.
# /// ACTION: Update <AzureRegionName> and <YourKeyVaultName> to match the values
# of your Azure Region and Key Vault.
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" -KeyVaultURL "https://<YourKeyVaultName>.vault.azure.net"

# Optional parameters for more detailed output, add: "-Verbose" and "-Debug" to the
# function above, which will output full diagnostic level responses from the remote
# endpoint web server.
# The output from the function is automatically saved in the PowerShell transcript.
```

### Run tests across all cluster nodes (`-Scope Cluster`)

By default the function tests connectivity from the **current node only** (`-Scope Node`). When you run the command from a node that is a member of an active Azure Local (failover) cluster, you can add `-Scope Cluster` to enumerate every cluster node and run the same connectivity test on each node, then aggregate the per-node results into a single tabbed HTML report.

Cluster mode requirements:

* The **AzStackHci.DiagnosticSettings** module must be installed (at the same version) on every cluster node. If a node is missing the module or has a different version, the run fails fast and lists the affected nodes — unless you add `-InstallMissingModuleOnNodes` (see below).
* Standard Kerberos / `Invoke-Command` remoting is used (no CredSSP or TrustedHosts changes are required).
* The orchestrating session must be elevated (Administrator) and have remote access to every node.

```PowerShell
# Run the connectivity test on every node in the cluster and produce a
# single, tabbed cluster HTML report.
# /// ACTION: Update <AzureRegionName> to match your Azure Region.
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" -Scope Cluster
```

Each node runs its own Layer-7 sweep in parallel (per-node default `-Parallelism 8`), so the orchestrator only holds one lightweight remoting job per node. To automatically copy (side-load) the orchestrator's exact module version to any node that is missing it or has a different version, add `-InstallMissingModuleOnNodes`. This is opt-in by design (it never modifies remote nodes silently) and copies from the orchestrator's installed module folder, so it does **not** require PowerShell Gallery or internet access on the nodes:

```PowerShell
# Cluster test, automatically side-loading the orchestrator's module version
# to any node that is missing it or has a version mismatch (drift).
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" `
    -Scope Cluster `
    -InstallMissingModuleOnNodes
```

### Arc Gateway deployments

If your Azure Local deployment uses Arc Gateway, use the `-ArcGatewayDeployment` and `-ArcGatewayURL` parameters together. When `-ArcGatewayDeployment` is specified, the function only tests URLs that do **not** support Arc Gateway (i.e., the endpoints that must remain directly accessible even with Arc Gateway enabled).

```PowerShell
# Test connectivity for Arc Gateway deployment.
# Both -ArcGatewayDeployment and -ArcGatewayURL are required together.
# /// ACTION: Update parameters below to match your Azure Region, Key Vault, and Arc Gateway URL.
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" `
    -KeyVaultURL "https://<YourKeyVaultName>.vault.azure.net" `
    -ArcGatewayDeployment `
    -ArcGatewayURL "https://<YourArcGatewayID>.gw.arc.azure.com"
```

### OEM hardware partner endpoints

Hardware detection based on your hardware OEM vendor is built into the module automatically, however if you want to override this or target a specific OEM's endpoints you can use the `-IncludeOEMUrls` parameter:

```PowerShell
# Include OEM-specific endpoints for your hardware vendor.
# Valid values: DataOn, Dell, HPE, Hitachi, Lenovo, TestAll
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" `
    -KeyVaultURL "https://<YourKeyVaultName>.vault.azure.net" `
    -IncludeOEMUrls "<YourOEMPartner>"
```

### Air-gapped and offline environments (`-NoAutoUpdate` and `-ForceGitHubEndpointsUpdate`)

By default the function checks the PowerShell Gallery for a newer module version and downloads the latest endpoint lists from GitHub (`raw.githubusercontent.com`) before it runs. Two parameters control this behaviour for restricted or air-gapped environments:

* **`-NoAutoUpdate`** skips the PowerShell Gallery update check **and** skips the GitHub endpoint download, using the cached endpoint files bundled with the module instead. Use this when no outbound calls to PSGallery or GitHub are permitted.
* **`-ForceGitHubEndpointsUpdate`** forces the endpoint-list refresh from GitHub **even when `-NoAutoUpdate` is specified**. This decouples the endpoint refresh from the module update check, so you can leave the installed module untouched while still pulling the freshest endpoint list. It only has an effect together with `-NoAutoUpdate` (without it, the GitHub refresh is already attempted by default). If the download is blocked or fails, the run gracefully falls back to the cached endpoint files.

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
  * `Get` — always use `GET` (full body download). This preserves the behaviour of versions prior to 0.6.7 and is useful for baseline comparisons.
  * `Head` — always use `HEAD` with no fallback. Fastest, but some endpoints (certain storage SAS URLs and CDN edge nodes) respond differently to `HEAD` than `GET`.
* **`-Parallelism`** (1–16, default `1`) fans the Layer-7 endpoint sweep out across that many process-isolated background workers. At `1` the test runs sequentially (identical to earlier behaviour). With `-Scope Cluster`, each node uses a per-node default of `8`.

```PowerShell
# Faster sweep: HEAD-first with GET fallback (default) and 8 parallel workers.
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" -Parallelism 8

# Preserve pre-0.6.7 behaviour (GET only, sequential).
Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" -RequestMethod Get -Parallelism 1
```

Output ordering is preserved regardless of `-Parallelism` (results are re-sorted before the report is written), so the report contents are comparable between sequential and parallel runs.

### Supported Azure regions

For the most recent / up to date list of supported Azure regions review the ["Azure requirements" - System requirements for Azure Local](https://learn.microsoft.com/azure/azure-local/concepts/system-requirements-23h2#azure-requirements) article. At the time of publishing this article, the list of valid Azure Region names for Azure Local include:

* `EastUS`, `WestEurope`, `AustraliaEast`, `CanadaCentral`, `CentralIndia`, `JapanEast`, `SouthCentral`, `SouthEastAsia`, `USGovVirginia`

### Testing an individual endpoint

If you would like to test an individual public endpoint using PowerShell for troubleshooting or support purposes, you can use the **Test-Layer7Connectivity** function with the `-Debug` switch. Example syntax is shown below:

```PowerShell
# Install the "AzStackHci.DiagnosticSettings" module
Install-Module -Name "AzStackHci.DiagnosticSettings" -Repository PSGallery

# To test an individual endpoint (after installing the module), with
# Verbose and Debug output, use the "Test-Layer7Connectivity" function, as shown below:
$url = 'https://graph.microsoft.com/v1.0/'
Test-Layer7Connectivity -url $url -port 443 -Verbose -Debug
```

## Output format

### HTML report (default)

The function now generates an **HTML report** by default (replacing the previous CSV format). The HTML report includes:

* **Color-coded rows** — Failed endpoints are highlighted in red, successful in green, and skipped in yellow for quick visual identification.
* **Summary section** — Hostname, timestamp, Azure region, hardware OEM, and download speed are displayed at the top of the report.
* **Scrollable table** — A synchronized dual-scrollbar table allows horizontal scrolling of the wide results table from both the top and bottom.
* **Full endpoint details** — Each row includes the URL, port, Arc Gateway support status, source, IP address, Layer 7 status, response, response time, certificate chain details (leaf, intermediate, root), and notes.

### JSON output (always generated)

A JSON output file is **always generated** in addition to the primary report format. The JSON file includes all test results plus summary metadata (hostname, timestamp, Azure region, hardware OEM, download speed). This is useful for programmatic analysis or integration with monitoring tools.

### CSV format (optional)

To generate a CSV file instead of HTML, use the `-OutputFormat` parameter:

```PowerShell
Test-AzureLocalConnectivity -AzureRegion "EastUS" -OutputFormat CSV
```

### Output file location

All output files are saved to: `C:\ProgramData\AzStackHci.DiagnosticSettings\`

To copy the run's output files to an additional location (for example a network share), use the `-ExportPath` parameter. Files are still always saved to `C:\ProgramData\AzStackHci.DiagnosticSettings\` and copied to the specified path in addition:

```PowerShell
Test-AzureLocalConnectivity -AzureRegion "EastUS" -ExportPath "\\fileshare\AzureLocalDiagnostics"
```

Output files generated:

| File | Description |
|------|-------------|
| `AzureLocal_ConnectivityTest_<Region>_<Hostname>_<DateTime>.html` | HTML report (default) or `.csv` if `-OutputFormat CSV` is used |
| `AzureLocal_ConnectivityTest_<Region>_<Hostname>_<DateTime>.json` | JSON test results with summary metadata (always generated) |
| `Transcript_AzureLocal_ConnectivityTest_<Region>_<Hostname>_<DateTime>.log` | PowerShell transcript log |

## Programmatic use with `-PassThru` (automation)

The `-PassThru` switch returns the test results to the PowerShell pipeline so you can act on them programmatically (for example, to fail a CI pipeline) without re-parsing the JSON report file. In v0.6.8 the returned value is a single **structured object** (`[pscustomobject]`) that matches the on-disk JSON summary (`SchemaVersion` `1.1`): all run-level fields are real properties on the object, and the per-endpoint rows are nested under a `.Results` property.

> **Caller contract:** assign the result directly (`$results = Test-AzureLocalConnectivity ... -PassThru`). Access the per-endpoint rows through `$results.Results`. Because a single object is now returned, run-level properties survive `Where-Object` / `Select-Object` / `Sort-Object` on `.Results` (they no longer depend on note-properties bolted onto the results collection, as in 0.6.7).

### Node scope (`-Scope Node`, default)

`-PassThru` returns the structured object described above. The per-endpoint rows are under `$results.Results`, and each **row** includes a `ResultCategory` field that classifies the outcome, so you no longer need to parse free-text notes to tell a genuine connectivity failure apart from a configuration gap:

| `ResultCategory` | Meaning |
|------------------|---------|
| `Success` | Endpoint reachable. |
| `ConnectivityFailure` | Endpoint could not be reached (DNS / TCP / Layer-7 failure). |
| `ConfigGap` | A required parameter was not supplied (for example `-KeyVaultURL` left unsubstituted) — a setup issue, not a blocked endpoint. |
| `SSLInspected` | SSL/TLS inspection was detected on the path to the endpoint. |
| `PrivateLink` | Endpoint resolved to a private (RFC1918) address — possible Private Link configuration. |
| `Skipped` | Endpoint was not tested (for example, skipped under Arc Gateway, or an untested wildcard placeholder). |

The object also carries run-level summary values as real properties, including `SchemaVersion`, `Hostname`, `Timestamp`, `AzureRegion`, `HardwareOEM`, `DownloadSpeed`, `ReportPath` / `JSONReportPath` (on-disk report locations), `RequestMethod`, `Parallelism`, `TotalDurationSeconds`, `Layer7WallClockSeconds`, `Layer7TotalDurationSeconds`, `Layer7TestedEndpoints`, the proxy fields (`ProxyEnabled`, `ProxyServer`, `ProxyHttp`, `ProxyHttps`, `ProxyBypassList`, `NoProxyList`), and the diagnostic state flags `SSLInspectionDetected` / `SSLInspectedURLs`, `PrivateLinkDetected` / `PrivateLinkCriticalArray` / `PrivateLinkProxyBypassArray` / `PrivateLinkDetectedArray` / `OtherRfc1918Count` / `PrivateLinkBypassConfirmedArray` / `PrivateLinkBypassMissingArray`, and `CRLOfflineDetected` / `CRLOfflineURLs`.

```PowerShell
# Capture results and fail an automation run on any connectivity failure.
$results = Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" -NoOutput -PassThru

# Per-row classification (rows are under .Results)
$results.Results | Where-Object ResultCategory -eq 'ConnectivityFailure' |
    Format-Table URL, Port, Layer7Status, ResultCategory -AutoSize

# Run-level flags (real properties on the returned object)
if ($results.PrivateLinkCriticalArray.Count -gt 0) {
    throw "Arc endpoint(s) resolved to a private IP: $($results.PrivateLinkCriticalArray -join ', ')"
}
```

### Cluster scope (`-Scope Cluster`)

With `-Scope Cluster -PassThru`, the function returns the **same unified structured object** as node scope, except the per-endpoint rows are grouped per node under a `.Nodes` array (each entry is itself a node-shaped structured object with its own `.Results` and run-level/detection fields). This gives you one consistent contract regardless of scope. Key top-level properties:

| Property | Description |
|----------|-------------|
| `SchemaVersion` | Contract schema version (`1.1`). |
| `Scope` | `Cluster`. |
| `ClusterName` | Cluster name from `Get-Cluster`. |
| `OrchestratorMachine` | Node that orchestrated the run. |
| `RunGuid` | Unique identifier for the cluster run. |
| `StartTime` / `EndTime` / `Duration` | Orchestration timing. |
| `ReportPath` / `JSONReportPath` | The **merged** cluster report and JSON on the orchestrator (local to the caller). |
| `ExportPath` | Folder containing the cluster report and per-node output. |
| `Nodes` | Array of per-node structured objects. Each entry carries `Hostname`, `Collected`, `Error`, `Results` (that node's per-endpoint rows), and the same run-level/detection fields as a node-scope run (per-node `ReportPath` / `JSONReportPath` point to files on the remote node). |
| `Errors` | Per-node error messages (empty when the node succeeded). |

```PowerShell
# Run a cluster test and inspect per-node results programmatically.
$cluster = Test-AzureLocalConnectivity -AzureRegion "<AzureRegionName>" -Scope Cluster -PassThru

foreach ($node in $cluster.Nodes) {
    $failures = $node.Results | Where-Object ResultCategory -eq 'ConnectivityFailure'
    Write-Host "$($node.Hostname) : $($failures.Count) connectivity failure(s)"
}
```

## Share test results with Microsoft (Optional)

The 'Test-AzureLocalConnectivity' function includes an option to upload the test results to Microsoft, this is controlled by a User Prompt that asks if you would like to **Upload the Transcript file and report file to Microsoft**. If you **answer "Y"** to the prompt, the function will automatically upload the output files to Microsoft, the transfer uses the built-in log transfer method that uses secure protocols, more information on the upload process is available [here](https://learn.microsoft.com/azure/azure-local/manage/collect-logs?view=azloc-24113&tabs=powershell#about-on-demand-log-collection).

To skip the upload prompt, use the `-ExcludeUploadResults` switch.

If you are working with Microsoft customer service and support (CSS), and have a support request (SR) case open, you could share some of the "Share Test Results" log upload text output that shows your cluster's "AEORegion", "ARODeviceARMResourceUri" and "CorrelationId" with the SR case owner.

## Demo and example output

Example output is shown in the animated GIF image below, which shows an interactive console demo.

The primary source of information is **opening the HTML output file** in a web browser on your laptop or desktop PC. The HTML report provides an interactive, color-coded view of all test results. Alternatively, use the JSON output for programmatic analysis or the CSV format for spreadsheet workflows.

![Test-AzureLocalConnectivity Demo](./images/Test-AzureLocalConnectivity_Demo.gif)

## Parameter reference

The full parameter block is shown below for reference. You can also discover the same information at any time with `Get-Help Test-AzureLocalConnectivity -Full`.

<details>
<summary>Full parameter block (click to expand)</summary>

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
    # Must be used together with -ArcGatewayURL (mandatory parameter set).
    [switch]$ArcGatewayDeployment,

    # Custom Arc Gateway URL including https:// prefix.
    # Must be used together with -ArcGatewayDeployment (mandatory parameter set).
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
    # Use in air-gapped environments or CI pipelines.
    [switch]$NoAutoUpdate,

    # Opt in to auto-installing a newer module version from PowerShell Gallery
    # before running. Default behaviour is notify-only (non-destructive).
    [switch]$AutoUpdate,

    # Force downloading the latest endpoint lists from GitHub even when
    # -NoAutoUpdate is specified. Only has an effect together with -NoAutoUpdate
    # (the GitHub refresh is already attempted by default otherwise). Falls back
    # to the cached endpoint files if the download is blocked or fails.
    [switch]$ForceGitHubEndpointsUpdate,

    # Suppress all console output from the function.
    [switch]$NoOutput,

    # Return the structured results object (Node scope) or the unified cluster
    # structured object (Cluster scope) for further processing in PowerShell.
    # Per-endpoint rows are under the .Results property (SchemaVersion 1.1).
    [switch]$PassThru,

    # Output report format. Default is HTML. CSV is also available.
    # JSON is always generated in addition to the selected format.
    [ValidateSet('HTML', 'CSV')]
    [string]$OutputFormat = 'HTML',

    # HTTP request method for each endpoint test.
    #   'Auto' (default) - HEAD first, GET fallback on 405/400/ambiguous response.
    #   'Get'  - GET only (pre-0.6.7 byte-identical behaviour).
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

    # Optional additional path to copy the report/transcript/JSON to. Results
    # are ALWAYS saved to C:\ProgramData\AzStackHci.DiagnosticSettings; when a
    # different path is specified the run folder is additionally copied there
    # (never instead of ProgramData).
    [string]$ExportPath = 'C:\ProgramData\AzStackHci.DiagnosticSettings'
)
```

</details>

### Key parameter changes from previous versions

| Change | Details |
|--------|---------|
| `-Scope` | **New in 0.6.7.** `Node` (default) tests the current node only; `Cluster` enumerates `Get-ClusterNode` and runs the test on every node via `Invoke-Command`, aggregating per-node results into a tabbed HTML report. |
| `-InstallMissingModuleOnNodes` | **New in 0.6.7.** Only valid with `-Scope Cluster`. Side-loads the orchestrator's exact module version to nodes that are missing it or have a version mismatch (drift). Opt-in; no PowerShell Gallery / internet dependency. |
| `-ExportPath` | **New in 0.6.7.** Optional additional folder to copy the report, transcript, and JSON to. Results are **always** saved to `C:\ProgramData\AzStackHci.DiagnosticSettings`; a different path is copied there *in addition*, never instead. |
| `-Parallelism` | **New in 0.6.7.** Fans the Layer-7 sweep out across 1–16 process-isolated workers. Default `1` (sequential). Per-node default is `8` under `-Scope Cluster`. |
| `-RequestMethod` | **New in 0.6.7.** `Auto` (default), `Get`, or `Head`. **Behaviour change:** the default is now `Auto` (HEAD-first with GET fallback). Use `-RequestMethod Get` to preserve pre-0.6.7 behaviour. |
| `-PassThru` | **Restructured in 0.6.8.** Now returns a single structured object (`SchemaVersion` `1.1`) with run-level fields as real properties and per-endpoint rows under `.Results`. Node scope and Cluster scope share one contract; in Cluster scope the per-node objects are nested under a `.Nodes` array. See [Programmatic use with -PassThru](#programmatic-use-with--passthru-automation). |
| `-AutoUpdate` | **New in 0.6.7.** Opt in to auto-installing a newer module version from PowerShell Gallery. Default is notify-only (non-destructive). |
| `-ForceGitHubEndpointsUpdate` | **New in 0.6.8.** Forces the endpoint-list refresh from GitHub even when `-NoAutoUpdate` is specified, leaving the installed module untouched. Only meaningful together with `-NoAutoUpdate`; falls back to cached endpoint files if the download is blocked. |
| `-ArcGatewayDeployment` and `-ArcGatewayURL` | Now a **mandatory parameter set** — both must be specified together. Previously they were independent optional parameters. |
| `-OutputFormat` | Controls the report format: `HTML` (default) or `CSV`. JSON is always generated alongside. |
| `-IncludeOEMUrls` | Allows testing OEM hardware partner specific endpoints (DataOn, Dell, HPE, Hitachi, Lenovo, or TestAll). |
| `-NoAutoUpdate` | Skips the PowerShell Gallery update check **and** skips downloading endpoint lists from GitHub (uses cached endpoint files). Use in air-gapped environments. |
| `-NoOutput` | Suppresses all console output for automation/scripting scenarios. |
| `USGovVirginia` | Azure region included in the `-AzureRegion` validated set. |
| HTML output | Default output format is HTML with color-coded rows and summary section. |
| JSON output | **Always generated** alongside the primary report format. |
| Download speed test | Uses **parallel multi-session downloads** for more accurate bandwidth measurement. |
| Private Link detection | Detects and warns if endpoints resolve to RFC1918 private IP addresses (possible Private Link configuration). |

## Appendix

### Environment Checker Connectivity Tests

To view the output from Azure Local **Environment Checker** Connectivity Validation tests, use the PowerShell command below:

```PowerShell
Invoke-AzStackHciConnectivityValidation -PassThru | Where-Object -Property Status -eq FAILURE | Sort-Object TargetResourceName | Format-Table TargetResourceName -Autosize
```

For additional information for how to use Azure Local Environment Checker module, review the [Troubleshooting External Connectivity Failures in Environment Checker](../../EnvironmentValidator/Troubleshooting-External-Connectivity-Failures-in-Environment-Checker.md) article.

And the Microsoft Learn article is here: [Readiness of your environment for Azure Local - "Run readiness checks" section](https://learn.microsoft.com/azure/azure-local/manage/use-environment-checker?view=azloc-24113&tabs=connectivity#run-readiness-checks).

### Solution Update Environment Tests

To view the output from **all tests** included Azure Local **Solution Update Readiness**, which includes connectivity validation and tests for critical public endpoints, use the PowerShell command below:

```PowerShell
# Check Solution Update Environment
$Result = Get-SolutionUpdateEnvironment -FullHealthCheckDetails

# View "not equal to SUCCESS" alerts
$Result.HealthCheckResult | Where-Object {$_.Status -ne "SUCCESS"} | Format-List Title, Status, Severity, Description, AdditionalData, Remediation

# Create "C:\Temp" folder, if it does not exist
if(-not(Test-Path "C:\Temp\")) { New-Item -Path "C:\Temp\" -Type Directory | Out-Null }

# Output to Text format
$Result.HealthCheckResult | Out-File "C:\Temp\HealthResult-$((Get-Cluster).Name).txt"

# Output to JSON format
$Result.HealthCheckResult | ConvertTo-Json -Depth 10 | Out-File "C:\Temp\HealthResult-$((Get-Cluster).Name).json"
```

For additional information for how to analyze and understand the **$Results.HealthCheckResult** array, refer to this article: [Solution Update Readiness Checker - "using PowerShell" section](https://learn.microsoft.com/azure/azure-local/update/update-troubleshooting-23h2?view=azloc-24113#using-powershell).

## How to get additional support

If you need assistance with connectivity, please open a Support Request (SR) case with Microsoft CSS support using Azure portal.
