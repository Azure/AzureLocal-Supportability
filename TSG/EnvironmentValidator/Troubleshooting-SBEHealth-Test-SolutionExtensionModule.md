# AzStackHci_SBEHealth_Test-SolutionExtensionModule

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_SBEHealth_Test-SolutionExtensionModule</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>Solution Builder Extension module health</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-SolutionExtensionModule</code> (run with <code>Invoke-AzStackHciSBEHealthValidation</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>SBEHealth (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>: when the module cannot be validated the check fails and the operation (deployment or update) is blocked at SBE health validation.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Requirement</th>
    <td>The staged Solution Builder Extension (SBE) package must contain a valid, integrity-intact, correctly signed <code>SolutionExtension</code> module.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>Deployment and Update (SBE health validation), on solutions that ship a Solution Builder Extension.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td>Azure Local, version 23H2 and later.</td>
  </tr>
</table>

## Overview

A **Solution Builder Extension (SBE)** is the hardware partner (OEM) content that ships
alongside the Azure Local solution: drivers, firmware, and a partner **SolutionExtension**
PowerShell module that can contribute health tests during deployment and updates. This
validator checks that the staged SBE package contains a `SolutionExtension` module that can
be **validated** for health testing.

The check runs `Test-SolutionExtensionModule` against the SBE package path. It looks for the
module at `<SBE package>\Configuration\SolutionExtension`, runs an **SBE content integrity
check** (the staged content must match the SBE manifest), confirms the module is signed with a
valid partner certificate, and confirms it carries the `HealthServiceIntegration` tag. The
outcome is one of:

- **SUCCESS (validated).** The module is present, intact, signed, and health-integration
  capable, so SBE health testing proceeds.
- **SUCCESS (skipped).** There is no SBE, or the SBE does not implement health tests / does
  not carry the `HealthServiceIntegration` tag. This is a benign skip, not a failure.
- **FAILURE (Critical).** The module **could not be validated**: the staged SBE content
  failed its integrity check, the module is not correctly signed, or the SBE metadata expected
  for the installed SBE version could not be found. The detail reads *"The SolutionExtension
  module could not be validated"*.

A FAILURE blocks the operation at SBE health validation. This is almost always a problem with
the **staged SBE content** (corrupt, incomplete, hand-edited, or mismatched against the
manifest), not with the cluster hardware itself.

## Before you start: who should do this, and is it safe?

- **Who owns this.** This is a Solution Builder Extension / deployment task, owned by the
  person running the deployment or update together with the **hardware partner (OEM)** whose
  SBE is in use. It is **not** a generic Windows task and **not** a networking task, so do not
  route it to the network team.
- **Do not hand-edit the staged SBE content.** The integrity check compares the staged
  content against the SBE manifest, so editing, adding, or removing files under the SBE
  package will itself cause this check to fail. The fix is to re-stage the correct partner
  package, never to patch files inside it.
- **This is safe to investigate read-only.** Reading the validator result, the event log, and
  the integrity error report changes nothing. The remediation (re-staging the SBE and
  re-running the precheck) is a normal deployment/update action.
- **It does not restart nodes or bounce running workloads.** This is a deployment/update
  validation gate, not a runtime operation. Reading the check and re-staging the SBE content do
  not restart cluster nodes or move running VMs. On an already-deployed cluster a failure blocks
  the in-progress update from proceeding, but it does not by itself disrupt running workloads.

## Where this failure appears

You can see this failure in two places, the Azure portal and the node itself.

### In the Azure portal

When you deploy or update from the portal, the validation phase runs the Environment Checker
and surfaces failed checks on the cluster's **Updates** (or deployment **Validation**) view.
A failed `Test-SolutionExtensionModule` appears there in red, under the SBE health checks,
with the "could not be validated" detail.

### On the node

The Environment Checker writes each check result to the `AzStackHciEnvironmentChecker` event
log as the JSON body of an **Event ID 17205** entry, and to the cluster-wide
`HealthCheckResult.*.json` on the infrastructure share. Read this check's most recent result
on a node with:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    ForEach-Object { $_.Message | ConvertFrom-Json } |
    Where-Object { $_.Name -like '*Test-SolutionExtensionModule*' } |
    Select-Object -First 1 Name, Status, Severity, Description, @{n='Detail';e={$_.AdditionalData.Detail}}
```

When the failure is an **integrity** mismatch, the check also writes a detailed report next to
the SBE metadata, named `SBEContentIntegrityErrors_<NODE>_<timestamp>.txt`. The failure detail
points at that file and summarizes what it found (for example files with hash mismatches, or
extra or missing files). Read that report to see exactly which staged files diverged from the
manifest, which is the fastest way to tell a corrupt or hand-edited stage from an incomplete
one.

## Requirements

- The staged SBE package contains `Configuration\SolutionExtension\SolutionExtension.psd1` and
  `SolutionExtension.psm1`.
- The staged SBE content matches the SBE manifest (passes the content integrity check).
- The `SolutionExtension` module is signed with a valid partner (OEM) certificate.
- The SBE metadata for the installed SBE version is present and reachable.

## Troubleshooting Steps

### 1. Read the failure detail and classify it

Run the Event ID 17205 query above (or open the `HealthCheckResult.*.json`) and read the
`Detail`. Then classify the cause:

- **"SBE content integrity check failed"** (with a `SBEContentIntegrityErrors_*.txt` reference):
  the staged content does not match the manifest. Open the referenced report to see whether it
  is *hash mismatches* (files were changed or corrupted), *extra files* (content was added, for
  example a hand copied or partially extracted stage), or *missing files* (an incomplete stage).
- **A certificate or module-load error:** the `SolutionExtension` module is present but is not
  correctly signed, or its manifest is malformed.
- **"could not find the SBE Metadata directory"** for an installed SBE version: the SBE is
  registered as installed but its staged metadata is missing.

### 2. Re-stage the correct partner SBE package

Do not patch the staged files. Replace the **whole** SBE package with the exact one your solution
expects from the hardware partner (OEM), staged through the same path the operation uses. Which
path depends on the operation:

- **During an update** (the SBE arrives as a solution update): re-add or re-download the SBE
  update through the same channel you used to add it (the Azure Local update / Solution Builder
  Extension flow), so the staged copy is replaced with the correct partner content. Then re-run
  the readiness check with `Invoke-SolutionUpdatePrecheck`.
- **During deployment** (the SBE comes from your deployment media / source): replace the SBE
  content in that deployment source with the OEM-provided package, then re-run the deployment
  validation step.

In both cases, confirm the SBE version matches what the cluster expects and that the transfer
completed (no partial extraction, no added files). If you did not stage this SBE yourself (most
customers do not; the deployment or partner engineer, or the OEM, does), hand this off to them
along with the `SBEContentIntegrityErrors_*.txt` report and the SBE version. For the exact
per-solution steps, see the Solution Builder Extension guidance under **Related**.

### 3. Re-run the check

Re-run SBE health validation and confirm the check now passes. During an update you can drive
this with the update precheck; during deployment, re-run the deployment validation step (see
the Azure Local deployment troubleshooting guidance under **Related**). Confirm
`Test-SolutionExtensionModule` returns **SUCCESS** (validated, or a benign skip if this SBE
does not implement health tests).

### 4. Verify the fix

Re-read the Event ID 17205 result (step 1). A fixed check reports `Status = SUCCESS` for
`Test-SolutionExtensionModule`, and no new `SBEContentIntegrityErrors_*.txt` is written on the
next run. In the portal, the SBE health check clears from red on the next validation pass.

## When to escalate

- The **OEM-provided** SBE package fails the integrity check even after a clean re-stage from
  the partner source. That points at a bad partner package rather than a staging problem;
  escalate to the hardware partner (OEM) with the `SBEContentIntegrityErrors_*.txt` report and
  the SBE version. The package the OEM returns must satisfy all three of the module's validation
  requirements, which the OEM can confirm before handing it back: its content matches the SBE
  manifest (passes the integrity check), the `SolutionExtension` module is signed with a valid
  partner (OEM) certificate, and the module manifest (`SolutionExtension.psd1`) declares the
  `HealthServiceIntegration` tag.
- The module is present and intact but fails certificate validation. That is a partner signing
  issue; escalate to the OEM.
- The sibling SBE health checks also fail (see **Related**), which can indicate a broader SBE
  configuration or credential problem rather than a content-integrity one.

## Related

- **Rerun a deployment / update after fixing prerequisites** (Azure Local deployment
  troubleshooting): https://learn.microsoft.com/en-us/azure-stack/hci/deploy/deployment-tool-troubleshoot#rerun-deployment
- Sibling SBE health checks that validate other parts of the same SBE:
  `Test-SBEPropertiesValid` (partner property values match the SBE manifest; remediated with
  `Set-SolutionExtensionProperty`) and `Test-SBECredentialsValid` (SBE credentials in the secret
  store match the SBE manifest).
- **Solution Builder Extension** overview and partner content:
  https://learn.microsoft.com/en-us/azure-stack/hci/update/solution-builder-extension
