# AzStackHci_Software_IsNotPartofDomain

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Name</th>
    <td><strong>AzStackHci_Software_IsNotPartofDomain</strong></td>
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
    <th style="text-align:left;">Owner</th>
    <td>Customer Windows / Active Directory administrator or the deployment partner.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Estimated effort</th>
    <td>About 15 minutes of hands-on work per machine, plus one restart and a validator rerun. Multiply this estimate by the number of pre-deployment machines.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Operational impact</th>
    <td>The affected machine is unavailable during the restart. After the unjoin, use the verified local administrator; do not apply this change to a live cluster member.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Domain-controller dependency</th>
    <td>The unjoin requires DNS and network reachability to a domain controller for the current domain, a healthy trust path, and a credential allowed to remove the computer object.</td>
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
domain-joined. Azure Local also refers to these machines as **nodes** (including in the
validator detail you match against below); the two terms mean the same thing here.

It runs by querying `(Get-WmiObject Win32_ComputerSystem).PartOfDomain` on each
machine. A machine that is part of a domain returns a **FAILURE**; a machine in a
workgroup returns a **SUCCESS**.

While this check is failing, deployment is blocked at the Software validation stage,
and the machine cannot proceed to cluster deployment. The Software validator includes
this test for Deployment and Upgrade, while the AddNode path explicitly excludes it.
The unjoin procedure in this guide is only for a machine being prepared for a new
deployment. If the result names an already deployed cluster member during Upgrade or
another workflow, do not unjoin that member; stop and route the case to the cluster
owner or Azure Local support.

## Before you start: who should do this, and is it safe?

- **Who owns this.** This is a customer Windows / Active Directory task (the server or
  identity admin, or the deployment partner). It is **not** a networking task and **not** a
  hardware-vendor (OEM) issue, so do not route it to the network team or escalate it to your
  server vendor.
- **Confirm the workload boundary.** The remediation below is for a pre-deployment host
  that is not carrying Azure Local cluster roles or workloads. **[HIGH RISK] Do not
  unjoin a machine that is already a deployed Azure Local cluster member.** Unjoining
  and restarting a live member can make the node unavailable to the cluster and
  interrupt VMs or other workloads that depend on it. If you cannot prove that the
  machine is still a pre-deployment host, stop and confirm with the cluster owner.
- **Confirm the domain-controller dependency.** Removing a computer from the domain
  requires a reachable domain controller, working DNS, a healthy trust path, and a
  domain credential with permission to remove the computer object. Run the
  domain-controller check in step 1 before attempting the unjoin. If it fails, stop
  and engage the Active Directory or DNS owner; do not try to force an offline unjoin.
- **You will restart the machine and must sign in locally afterward.** Removing the
  machine from the domain requires a restart, after which domain sign-in no longer
  applies. Confirm a working local administrator sign-in with the executable gate in
  step 2, and do not continue unless it reports success.
- **Check the provisioning path.** If Group Policy, imaging, or provisioning
  automatically rejoins machines to the domain, have its owner change that process so
  pre-deployment hosts remain in a workgroup.

## Where this failure appears

You can see this failure in two places, the Azure portal and the machine itself. Both
show the same underlying result.

### In the Azure portal

This check runs during the deployment validation step. When you deploy Azure Local
from the portal (or with a deployment template), the **Validation** phase runs the
environment checks and lists any that fail. The same Software validation family can
also run during Upgrade, but the AddNode path excludes this test:

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
result in a few seconds. Use `-Include Test-IsNotPartofDomain` to run only this check,
so you do not have to run the full Software validation suite:

```powershell
$r = Invoke-AzStackHciSoftwareValidation -Include Test-IsNotPartofDomain -PassThru
$r | Select-Object Name, Status, Severity
$r.AdditionalData.Detail
```

A machine that is still domain-joined returns `Status` of `FAILURE` and a detail line
of the form (the machine name, `AzL-Node-01` here, is an example; your output shows the
actual name):

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

**Component / tool log files (on disk).** The Environment Checker also writes its
own log and report on the machine where the validation ran:
`%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` and
`%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentReport.json`. These files can provide
the same per-machine detail when you are collecting an evidence bundle.

**Where this does not appear.** This is a pre-deployment operating-system check, not
a clustered role or workload event. It does not appear in `Get-ClusterLog`, Windows
Failover Cluster Manager, Windows Admin Center on a standalone host, or Windows Admin
Center in the Azure portal. In Windows Admin Center in the Azure portal, this result is
not evident here; use the deployment Validation view instead. Use the node PowerShell
result, the Environment Checker event log, or the component files above.

In both sources the result for this check looks like this:

```json
{
  "Name": "AzStackHci_Software_IsNotPartofDomain",
  "DisplayName": "Domain Membership",
  "Title": "Domain Membership",
  "Severity": 2,
  "Status": 1,
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

The persisted Event ID 17205 and health-check JSON use numeric top-level `Status` and
`Severity` values. Read the human-readable status and message from
`AdditionalData.Status` and `AdditionalData.Detail`. The `Detail` line is the key part:
it names the machine (`AzL-Node-01` above) and tells you to remove it from the domain.
A passing result has `AdditionalData.Status` of `SUCCESS` and a detail line of
`'AzL-Node-01' is not part of a domain.`

## Requirements

1. Each Azure Local machine must be in a **workgroup** (not joined to an Active
   Directory domain) before deployment.
2. You run the steps below on the affected machine, signed in as an administrator, in
   a PowerShell session.
3. You have a domain account with permission to remove the machine's computer object
   from the domain (used once to unjoin).
4. The machine can resolve and reach a domain controller for its current domain, and
   the secure channel is usable. Step 1 verifies this dependency before the unjoin.
5. Keep the same elevated PowerShell session open for steps 2 and 3 so the verified
   `$localCredential` remains available to the pre-unjoin gate.

## Troubleshooting Steps

### 1. Confirm which machine is domain-joined

On each machine you are deploying, check its domain membership directly:

```powershell
$computerSystem = Get-CimInstance Win32_ComputerSystem
$computerSystem | Select-Object Name, PartOfDomain, Domain

if ($computerSystem.PartOfDomain) {
    nltest /dsgetdc:$($computerSystem.Domain)
    if ($LASTEXITCODE -ne 0) {
        throw "No reachable domain controller was found for $($computerSystem.Domain). Stop and fix DNS, network, or trust connectivity before unjoining."
    }
    if (-not (Test-ComputerSecureChannel -Verbose)) {
        throw "The secure channel to $($computerSystem.Domain) is not healthy. Stop and repair the domain trust before unjoining."
    }
}
```

If `PartOfDomain` is `True`, this check will fail on that machine, and `Domain` shows
the domain it is joined to. A machine that is ready for deployment shows
`PartOfDomain` of `False` and a workgroup name (for example `WORKGROUP`). For a
multi-machine deployment, repeat this check on every host; one passing host does not
clear another host.

### 2. Make sure you can sign in locally after the unjoin

The next step unjoins the machine and restarts it, so it comes back up as a workgroup
member and the next sign-in must use a **local** account. On a machine that has been
domain-joined, the built-in local administrator account may be disabled, renamed (for
example, `ASBuiltInAdmin`), or have an unknown password. Establish and test a known
local administrator credential before you unjoin. Otherwise the restart can lock you
out of the machine.

```powershell
# Windows can rename the built-in Administrator account. Its stable RID is -500,
# so discover the account instead of assuming its name is "Administrator".
$localUser = Get-LocalUser -ErrorAction Stop |
    Where-Object { $_.SID.Value -match '-500$' } |
    Select-Object -First 1
if ($null -eq $localUser) {
    throw 'The built-in local administrator account (SID ending in -500) was not found.'
}
$localAdmin = $localUser.Name

if (-not $localUser.Enabled) {
    Enable-LocalUser -Name $localAdmin -ErrorAction Stop
}

$isLocalAdministrator = Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop |
    Where-Object { $_.SID.Value -eq $localUser.SID.Value }
if (-not $isLocalAdministrator) {
    throw "$env:COMPUTERNAME\$localAdmin is not a member of the local Administrators group."
}

$localPassword = Read-Host -Prompt "Enter a known password for $env:COMPUTERNAME\$localAdmin" -AsSecureString
Set-LocalUser -Name $localAdmin -Password $localPassword -ErrorAction Stop

# Verify that Windows accepts the local credentials before any domain change.
$localCredential = [pscredential]::new("$env:COMPUTERNAME\$localAdmin", $localPassword)
$localAccessTest = Start-Process -FilePath "$env:SystemRoot\System32\whoami.exe" `
    -Credential $localCredential -Wait -PassThru -ErrorAction Stop
if ($localAccessTest.ExitCode -ne 0) {
    throw "The local credential test failed. Do not unjoin the domain."
}
"Verified local administrator credentials for $env:COMPUTERNAME\$localAdmin."
```

The block must finish with the explicit verification message and a zero exit code.
If any command errors, the account is not a local administrator, or the credential
test fails, stop and correct local access before continuing. Keep this PowerShell
session open because step 3 repeats the credential test using `$localCredential`.

### 3. Remove the machine from the domain

Unjoin the machine from the domain and restart it, so it comes back up in a workgroup.
This is the remediation the validator itself recommends. It is reversible (the machine
can be rejoined later if needed), but it does change machine state and requires a
restart, so treat it as a [MEDIUM RISK] change and run it during your deployment
preparation window.

You will be prompted for a domain account that can remove this machine from the domain
(enter it as `DOMAIN\username`), and then asked to confirm the unjoin. Confirm to proceed.

**[MEDIUM RISK] Required pre-unjoin gate:** Run the following block only after step 2
completed successfully. It repeats the local credential test and stops before the
unjoin if the local access gate is not met.

```powershell
# Fail closed if step 2 was not completed in this same PowerShell session, or if
# the credential no longer identifies the account that step 2 verified.
if ([string]::IsNullOrWhiteSpace($localAdmin) -or
    $null -eq $localCredential -or
    -not ($localCredential -is [pscredential])) {
    throw 'Run step 2 and keep its verified $localCredential in this PowerShell session before unjoining.'
}
if ($localCredential.UserName -ne "$env:COMPUTERNAME\$localAdmin") {
    throw 'The verified local credential does not match the local administrator account from step 2.'
}
$localAccessTest = Start-Process -FilePath "$env:SystemRoot\System32\whoami.exe" `
    -Credential $localCredential -Wait -PassThru -ErrorAction Stop
if ($localAccessTest.ExitCode -ne 0) {
    throw 'The local credential test failed. Do not unjoin the domain.'
}

# Required precondition: the local credential gate above passed in this session.
# Supply a domain account allowed to remove this machine from the domain.
$unjoinResult = Remove-Computer -UnjoinDomainCredential (Get-Credential) `
    -PassThru `
    -ErrorAction Stop
if (-not $unjoinResult.HasSucceeded) {
    throw "Domain removal did not succeed for $($unjoinResult.ComputerName). The machine will not restart."
}
# Restart only after Remove-Computer returned a confirmed successful result.
Restart-Computer -Force
```

Notes:

- After the restart, sign in with the **local** administrator account you confirmed in
  step 2, since the machine is now a workgroup member rather than a domain member.
- The machine keeps its computer name; only its domain membership changes.
- Unjoining does not delete the machine's computer account in Active Directory; that
  object stays until a domain administrator removes it. It is harmless for deployment
  (the machine starts fresh in a workgroup), but the AD administrator may want to clean
  up the stale computer object, especially if the machine will not rejoin this domain.
- Make sure nothing will automatically rejoin the machine to the domain before
  deployment (for example a Group Policy, an imaging or provisioning task, or a
  scheduled join). If the machine rejoins the domain, this check fails again.

### 4. Verify the fix

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
`'AzL-Node-01' is not part of a domain.` Once every machine you are deploying reports
success, repeat the same verification on every machine, then re-run the deployment
validation. The **Domain Membership** check should now pass and deployment can proceed.
If a machine rejoins the domain, stop the deployment and correct the provisioning or
Group Policy path before retrying.

## When to escalate

Open a support case if any of the following are true:

- The machine reports `PartOfDomain` of `False`, but the **Domain Membership** check
  still fails during deployment validation.
- The machine rejoins the domain on its own after you unjoin it, and you cannot find
  the Group Policy, provisioning task, or imaging step that is rejoining it.
- `nltest /dsgetdc` cannot find a domain controller, or the unjoin fails with a DNS,
  trust, or domain-controller connectivity error.
- The result names an already deployed cluster member. Do not unjoin that member;
  engage the cluster owner or Azure Local support for a workload-safe procedure.
- `Remove-Computer` fails with a permissions or trust error that you cannot resolve
  with a domain account that has rights to remove the computer object.

## Related

- General Environment Checker remediation link shown in the validator output:
  https://aka.ms/hci-envch
- [Azure Local deployment prerequisites](https://learn.microsoft.com/azure/azure-local/deploy/deployment-local-identity-with-key-vault)
  (machines must start in a workgroup; the deployment performs the domain join).
