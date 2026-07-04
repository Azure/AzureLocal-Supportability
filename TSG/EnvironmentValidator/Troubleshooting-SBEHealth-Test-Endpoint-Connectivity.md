# AzStackHci_SBEHealth_Test-Endpoint-Connectivity

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_SBEHealth_Test-Endpoint-Connectivity</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>Solution Builder Extension manifest endpoint connectivity ("Validate SBE manifest reachable")</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-Endpoint-Connectivity</code> (an SBE health check emitted during pre-update validation)</td>
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
published at) over HTTPS. It is almost always a **firewall / proxy** block on outbound HTTPS
(443) to that endpoint. Find the endpoint URL from the failure detail, make sure the node can
reach it (allow HTTPS to that host, and to its redirect target if it is an `aka.ms` link), then
re-run the pre-update health check. Full detail and how to verify the fix are below.

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
early warning that the node cannot reach the SBE content source, which would cause a later step to
fail, so it surfaces the connectivity problem now while it is easy to fix. If the cluster is
configured for **disconnected (ALDO) operations**, the endpoint check is skipped entirely.

## Before you start: who should do this, and is it safe?

- **Who owns this.** This is an outbound-connectivity problem, so it is usually a **network /
  firewall / proxy** task for whoever manages the node's internet egress, done together with the
  person running the update. The SBE endpoint URL itself comes from the hardware partner (OEM), so
  involve them if the URL looks wrong or its redirect target is unknown.
- **This is safe to investigate read-only.** Reading the check result, the event log, and testing
  the endpoint with a web request changes nothing on the node.
- **It does not restart nodes or bounce running workloads.** This is a pre-update validation
  signal, not a runtime operation. Reading the check and adjusting firewall / proxy rules do not
  restart cluster nodes or move running VMs.
- **Do not "fix" this by disabling the check or ignoring it.** Because it is Informational it will
  not block the update, but the underlying connectivity gap will cause a later SBE step to fail.
  Fix the reachability, do not suppress the warning.

## Where this failure appears

You can see this failure in two places, the Azure portal and the node itself.

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
    Select-Object -First 1 Name, Status, Severity, Description, @{n='Detail';e={$_.AdditionalData.Detail}}
```

The `Name` on the node carries a domain prefix (`AzStackHci_SBEHealth_`) and can carry a node
suffix, so the query uses `-like '*Test-Endpoint-Connectivity*'` (leading and trailing wildcard) to
match it. When the endpoint is unreachable, `Status` is `FAILURE`, `Description` reads *"Failed to
reach SBE manifest endpoint: `<endpoint>` ..."*, and `Remediation` reads *"Check firewall rules to
ensure the SBE manifest endpoint `<endpoint>` is reachable."*

## Troubleshooting Steps

### 1. Read the failure detail and get the endpoint URL

Run the Event ID 17205 query above (or open the `HealthCheckResult.*.json`) and read the
`Description`. It names the exact **SBE manifest endpoint** URL the check could not reach, and the
reason. Classify the reason:

- **A connection error / no response** (for example *"Failed to reach ... Error: ..."*): the node
  cannot open an HTTPS connection to the endpoint. This is a firewall, proxy, or routing block.
- **A non-`200` response code** (for example *"Response code: 403"* or *"407"*): the request
  reached something, but it was refused. A `407` points at a proxy that needs authentication; a
  `403`/`404` can point at a wrong or expired endpoint.
- **Redirected to a search engine**: the endpoint is an `aka.ms` link whose redirect did not
  resolve, so the request landed on a search engine. Treat this as the endpoint being unreachable
  from this node.
- **"Unable to determine SBE manifest endpoint"**: the check could not even discover the endpoint
  URL (a solution-discovery / LCM extension problem, not a firewall one). See **When to escalate**.

### 2. Confirm the endpoint reachability from the node

Test the endpoint the same way the check does, from the affected node, so you can see the exact
failure and confirm the fix. This also surfaces the **final redirected URL** (the check inspects
the redirect target, and treats a redirect that lands on a search engine as a failure):

```powershell
# Use the endpoint URL from the failure Description in step 1.
$sbeEndpoint = '<endpoint-from-step-1>'
try {
    $r = Invoke-WebRequest -Uri $sbeEndpoint -UseBasicParsing -TimeoutSec 15 -PassThru -OutFile ([System.IO.Path]::GetTempFileName())
    [pscustomobject]@{ StatusCode = $r.StatusCode; FinalUri = $r.BaseResponse.ResponseUri.AbsoluteUri }
} catch {
    "Failed: $($_.Exception.Message)"
}
```

A reachable endpoint returns `StatusCode = 200`, and `FinalUri` shows the real host the `aka.ms`
link redirects to (the host you must also allow in step 3). A failure here reproduces exactly what
the check saw: the same connection error, non-`200` code, **no response at all**, or a `FinalUri`
that points at a search engine.

### 3. Fix the reachability (firewall / proxy)

Do not edit the check. Make the endpoint reachable from the node. In plain terms, you are allowing
the node to make an outbound HTTPS request (TCP port **443**) to the SBE endpoint host:

- **Allow outbound HTTPS (443) to the endpoint host.** Add the SBE manifest endpoint host to your
  firewall / proxy allow list on port 443. If the endpoint is an `aka.ms` link, it **redirects**,
  so you must allow HTTPS to **both** `aka.ms` **and** the redirect target host. Enumerate the
  redirect target with the `FinalUri` from step 2 (or `nslookup` / a browser: browse to the endpoint
  and note the host in the address bar it lands on), then allow that host on 443 too.
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

Re-read the Event ID 17205 result (step 1). A fixed check reports `Test-Endpoint-Connectivity` with
`Status = SUCCESS` and the detail *"Validate SBE manifest reachable: `<endpoint>`"*. The step 2
`Invoke-WebRequest` returns `StatusCode = 200`. If you re-ran with `-SystemHealth`, confirm the
overall result with `Get-SolutionUpdateEnvironment | Format-List HealthState, HealthCheckDate` and
check that `HealthState` is `Success` (not `Failure`). In the portal, the SBE health check clears on
the next validation pass.

## When to escalate

- The check reports **"Unable to determine SBE manifest endpoint to test connectivity against"**.
  That is not a firewall problem: the node could not even discover the endpoint URL from
  solution discovery. Confirm the **LCM extension** is installed and that
  `Get-SolutionDiscoveryDiagnosticInfo` returns an SBE endpoint, and escalate with that command's
  output if it does not.
- The endpoint is reachable from other machines but not from the node even after the firewall /
  proxy is opened. Escalate to the network team with the endpoint URL, the step 2 output, and the
  proxy configuration.
- The endpoint URL itself is wrong or its `aka.ms` redirect does not resolve to a valid partner
  location. Escalate to the hardware partner (OEM) to confirm the correct SBE manifest endpoint.
- The sibling SBE health checks also fail (see **Related**), which can indicate a broader SBE
  configuration problem rather than a connectivity one.

## Related

- **Rerun a deployment / update after fixing prerequisites** (Azure Local deployment
  troubleshooting): https://learn.microsoft.com/en-us/azure-stack/hci/deploy/deployment-tool-troubleshoot#rerun-deployment
- **Solution Builder Extension** overview and partner content:
  https://learn.microsoft.com/en-us/azure-stack/hci/update/solution-builder-extension
- Sibling SBE health checks that validate other parts of the same SBE:
  `Test-Endpoint-Matches-ModelSKU` (the SBE manifest at the endpoint matches this hardware model
  and SKU), `Test-Installed-SBE-Env-Vars` (the installed-SBE environment variables are consistent),
  and `Test-SolutionExtensionModule` (the staged SBE `SolutionExtension` module is present,
  integrity-intact, and signed).
