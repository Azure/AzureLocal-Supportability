# AzStackHci_Software_IsNotPartofDomain

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_Software_IsNotPartofDomain</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Display name</th>
    <td>Domain Membership</td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><code>Test-IsNotPartofDomain</code> (run with <code>Invoke-AzStackHciSoftwareValidation</code>)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Software (Environment Validator / Environment Checker)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>: this validator blocks deployment until the machine is back in a workgroup.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Requirement</th>
    <td>Each machine must be in a <strong>workgroup</strong> (not joined to an Active Directory domain) before deployment.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>Deployment (pre-deployment validation).</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td>Azure Local, version 23H2 and later.</td>
  </tr>
</table>

## Overview

This validator checks that each Azure Local machine is **not** joined to an Active
Directory domain before deployment. Azure Local requires every machine to be in a
workgroup at the start of deployment; the deployment process performs the domain join
itself, as part of standing up the cluster. The check fails when a machine is already
domain-joined.

It runs by querying `(Get-WmiObject Win32_ComputerSystem).PartOfDomain` on each
machine. A machine that is part of a domain returns a **FAILURE**; a machine in a
workgroup returns a **SUCCESS**.

While this check is failing, deployment is blocked at the Software validation stage,
and the machine cannot proceed to cluster deployment. This is a pre-deployment gate,
so it does not affect a cluster that is already deployed; it stops a new machine from
being deployed while it is still attached to a domain.

## Where this failure appears

You can see this failure in two places, the Azure portal and the machine itself. Both
show the same underlying result.

### In the Azure portal

This check runs during the deployment validation step. When you deploy Azure Local
from the portal (or with a deployment template), the **Validation** phase runs the
environment checks and lists any that fail:

1. Open the Azure Local deployment for your cluster and go to its **Validation**
   results (the deployment surfaces these before it proceeds to apply).
2. In the list of checks, this one appears under its display name, **Domain
   Membership**, with a **Critical** severity.
3. Select the failing check to see the per-machine detail, which names the machine
   that is still domain-joined.

### On the machine

Two on-box sources carry the result.

**Run the single validator (fastest).** The Environment Checker module ships on every
Azure Local machine, so you can run this one Software check directly and read the
result in a few seconds. This check is excluded from the default Software validation
run, so include it explicitly:

```powershell
$r = Invoke-AzStackHciSoftwareValidation -Include Test-IsNotPartofDomain -PassThru
$r | Select-Object Name, Status, Severity
$r.AdditionalData.Detail
```

A machine that is still domain-joined returns `Status` of `FAILURE` and a detail line
of the form:

```
'AzL-Node-01' is part of a domain. Please remove 'AzL-Node-01' from the domain.
```

**Event log (per machine).** The Environment Checker writes every check result to the
**AzStackHciEnvironmentChecker** event log, located at
`C:\Windows\System32\winevt\Logs\AzStackHciEnvironmentChecker.evtx`. Each result is the
JSON body of an **Event ID 17205** entry. To read this check's most recent result on a
machine:

```powershell
Get-WinEvent -LogName AzStackHciEnvironmentChecker -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    Where-Object { $_.Message -match 'AzStackHci_Software_IsNotPartofDomain' } |
    Select-Object -First 1 -ExpandProperty Message
```

In both sources the result for this check looks like this:

```json
{
  "Name": "AzStackHci_Software_IsNotPartofDomain",
  "DisplayName": "Domain Membership",
  "Title": "Domain Membership",
  "Severity": "Critical",
  "Status": "FAILURE",
  "Description": "Validates nodes are not pre-joined to an Active Directory domain by querying (Get-WmiObject Win32_ComputerSystem).PartOfDomain on each node. Nodes must not be domain-joined before Azure Local deployment.",
  "TargetResourceType": "OperatingSystem",
  "TargetResourceName": "AzL-Node-01",
  "Remediation": "Nodes must not be domain-joined before deployment. Remove the node from the domain using 'Remove-Computer -UnjoinDomainCredential <cred> -Force' and restart.",
  "AdditionalData": {
    "Detail": "'AzL-Node-01' is part of a domain. Please remove 'AzL-Node-01' from the domain.",
    "Status": "FAILURE",
    "Resource": "Domain"
  }
}
```

The `Detail` line is the key part. It names the machine (`AzL-Node-01` above) and tells
you to remove it from the domain. A passing result has `Status` of `SUCCESS` and a
detail line of `'AzL-Node-01' is not part of a domain.`

## Requirements

1. Each Azure Local machine must be in a **workgroup** (not joined to an Active
   Directory domain) before deployment.
2. You run the steps below on the affected machine, signed in as an administrator, in
   a PowerShell session.
3. You have a domain account with permission to remove the machine's computer object
   from the domain (used once to unjoin).

## Troubleshooting Steps

### 1. Confirm which machine is domain-joined

On each machine you are deploying, check its domain membership directly:

```powershell
Get-CimInstance Win32_ComputerSystem | Select-Object Name, PartOfDomain, Domain
```

If `PartOfDomain` is `True`, this check will fail on that machine, and `Domain` shows
the domain it is joined to. A machine that is ready for deployment shows
`PartOfDomain` of `False` and a workgroup name (for example `WORKGROUP`).

### 2. Remove the machine from the domain

Unjoin the machine from the domain and restart it, so it comes back up in a workgroup.
This is the remediation the validator itself recommends. It is reversible (the machine
can be rejoined later if needed), but it does change machine state and requires a
restart, so treat it as a [MEDIUM RISK] change and run it during your deployment
preparation window.

```powershell
# Supply a domain account allowed to remove this machine from the domain.
Remove-Computer -UnjoinDomainCredential (Get-Credential) -Force -PassThru
Restart-Computer
```

Notes:

- After the restart, sign in with the machine's **local** administrator account, since
  the machine is now a workgroup member rather than a domain member.
- The machine keeps its computer name; only its domain membership changes.
- Make sure nothing will automatically rejoin the machine to the domain before
  deployment (for example a Group Policy, an imaging or provisioning task, or a
  scheduled join). If the machine rejoins the domain, this check fails again.

### 3. Verify the fix

First confirm the machine is no longer domain-joined:

```powershell
Get-CimInstance Win32_ComputerSystem | Select-Object Name, PartOfDomain, Domain
```

`PartOfDomain` should now be `False`. Then re-run the single validator:

```powershell
$r = Invoke-AzStackHciSoftwareValidation -Include Test-IsNotPartofDomain -PassThru
$r | Select-Object Name, Status, Severity
$r.AdditionalData.Detail
```

A workgroup machine returns `Status` of `SUCCESS` and a detail line of
`'<NODE>' is not part of a domain.` Once every machine you are deploying reports
success, re-run the deployment validation; the **Domain Membership** check should now
pass and deployment can proceed.

## When to escalate

Open a support case if any of the following are true:

- The machine reports `PartOfDomain` of `False`, but the **Domain Membership** check
  still fails during deployment validation.
- The machine rejoins the domain on its own after you unjoin it, and you cannot find
  the Group Policy, provisioning task, or imaging step that is rejoining it.
- `Remove-Computer` fails with a permissions or trust error that you cannot resolve
  with a domain account that has rights to remove the computer object.

## Related

- General Environment Checker remediation link shown in the validator output:
  https://aka.ms/hci-envch
- Azure Local deployment prerequisites (machines must start in a workgroup; the
  deployment performs the domain join).
