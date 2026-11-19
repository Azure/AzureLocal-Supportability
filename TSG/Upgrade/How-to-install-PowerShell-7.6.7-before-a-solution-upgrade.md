<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "how-to",
  "products": ["Azure Local"],
  "detector": {
    "type": "command",
    "signal": "Run C:\\Program Files\\PowerShell\\7\\pwsh.exe in a fresh process and check $PSVersionTable.PSVersion.ToString()."
  },
  "validation": {
    "fidelity_level": "L0",
    "technical_grade": null,
    "reproduction_substrate": "none",
    "automation_status": "manual",
    "last_validated": "2026-10-22",
    "spec_ref": ""
  }
}
-->

# How to install PowerShell 7.6.7 before a solution upgrade

## Table of contents

- [Applies to](#applies-to)
- [Before you begin](#before-you-begin)
- [1. Check the installed version](#1-check-the-installed-version)
- [2. Install PowerShell 7.6.7](#2-install-powershell-767)
- [3. Verify before starting the upgrade](#3-verify-before-starting-the-upgrade)
- [Rollback and escalation](#rollback-and-escalation)
- [References](#references)

## Applies to

Azure Local solution upgrade on connected, hyperconverged deployments with x64 Windows nodes. Applicability to disconnected, disaggregated, or multi-rack deployments has not been validated; do not apply this procedure to those deployment types without Microsoft support guidance.

This guide describes **optional preinstallation** of PowerShell **7.6.7** on **each cluster node**, including the seed node, before starting the solution upgrade. Preinstallation avoids an interruption at **Prepare cluster upgrade > Install software dependencies**, where installing 7.6.7 terminates the running PowerShell process and causes the attempt to appear as **Cancelled**.

If the upgrade is already cancelled at that step, **manual installation is not required**: the dependency step has already installed PowerShell. Select **Resume deployment** as described in [Known issue: solution upgrade cancelled at Install software dependencies](./Known-issue-solution-upgrade-cancelled-at-Install-software-dependencies.md).

This is not a general PowerShell downgrade procedure or guidance for unrelated upgrade failures. The cancellation and recovery are documented in the linked known-issue article; this port has received static review only.

## Before you begin

- **Owner:** The cluster administrator runs this procedure with the maintenance owner's approval. Coordinate with anyone running PowerShell-based management or automation on the target nodes.
- Run the commands with **administrator permissions** on each target node, either locally or through a remote PowerShell session.
- Use this procedure before starting the upgrade, not while it is actively running or as a recovery requirement for the known cancellation. Save any work in the session: installation may terminate it.
- The installation block downloads the official x64 MSI from GitHub. The node must be able to reach the GitHub release download and its redirected asset host.
- The MSI installs machine-wide into `C:\Program Files\PowerShell\7`.
- **Impact:** Installing PowerShell can terminate existing PowerShell sessions and interrupt management scripts. Use an approved maintenance window. The block requests no restart; if the installer log indicates a reboot is required, follow the cluster maintenance procedure before starting the upgrade.

## 1. Check the installed version

**[READ-ONLY]** Risk is not applicable because this check does not change state.

Run this on each node. It starts a new PowerShell 7 process rather than reporting the version of the current shell:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoLogo -NoProfile -NonInteractive `
    -Command '$PSVersionTable.PSVersion.ToString()'
```

If the output is **`7.6.7` or higher**, installation is not required on that node. If PowerShell 7 is missing ("The term 'C:\Program Files\PowerShell\7\pwsh.exe' is not recognized") or an older version is installed, continue to the next section. Stop and contact Microsoft support for other unexpected errors instead of treating them as evidence that installation is needed.

## 2. Install PowerShell 7.6.7

**[MEDIUM RISK]** This changes the machine-wide PowerShell installation and can interrupt management sessions or automation. Proceed only on nodes where step 1 found an older or missing version, the upgrade has not started, and the maintenance window is approved. Stop if any of these conditions is not met.

Copy and paste the commands into an administrator PowerShell session on each node that needs the installation. **Expect that the session may terminate or disconnect during MSI installation.** Afterward, reopen or reconnect and verify the installed version as described below. The expected result is a fresh executable reporting **7.6.7**, not an uninterrupted installer session.

The block verifies that the MSI has a valid Microsoft signature before installation. If signature validation fails, **stop** and contact Microsoft support; do not skip the check or run the MSI manually.

```powershell
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$version = '7.6.7'
$msi = Join-Path $env:TEMP "PowerShell-$version-win-x64.msi"
$log = Join-Path $env:TEMP "PowerShell-$version-install.log"

Invoke-WebRequest -UseBasicParsing `
    -Uri "https://github.com/PowerShell/PowerShell/releases/download/v$version/PowerShell-$version-win-x64.msi" `
    -OutFile $msi

$signature = Get-AuthenticodeSignature -LiteralPath $msi
if ($signature.Status -ne 'Valid' -or
    $signature.SignerCertificate.Subject -notmatch '(^|,\s*)O=Microsoft Corporation(,|$)') {
    throw "MSI signature validation failed; a valid Microsoft signature is required. Status: $($signature.Status). File: $msi"
}

$arguments = "/i `"$msi`" /qn /norestart ALLUSERS=1 REGISTER_MANIFEST=1 ADD_PATH=1 /L*v `"$log`""
Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" `
    -ArgumentList $arguments -Wait
```

If the download fails, stop and resolve access to the official download before retrying. For installation errors or an unresolved result, use the verification and escalation guidance below rather than immediately rerunning or uninstalling PowerShell.

## 3. Verify before starting the upgrade

**[READ-ONLY]** Risk is not applicable because version verification does not change state.

### Session termination or disconnect during installation

The MSI may terminate the current PowerShell session or interrupt the remoting connection. For example, `Enter-PSSession` may return to the local prompt and display **The I/O operation has been aborted because of either a thread exit or an application request**. This may happen during installation and is **not, by itself, an installation failure**.

Reopen PowerShell on the node, or reconnect if installing remotely, then check the installed executable.

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoLogo -NoProfile -NonInteractive `
    -Command '$PSVersionTable.PSVersion.ToString()'
```

Run the version check on the **target node**, not the local client after a disconnect. If the fresh executable reports **7.6.7**, verification has passed. **Do not rerun the installer just because the session ended or the remote connection dropped.**

If PowerShell cannot start or still reports an older version, allow any in-progress installation to finish and inspect `%TEMP%\PowerShell-7.6.7-install.log` on the node before retrying. Use the same account that started installation to locate the log. Stop and contact Microsoft support for an actual installation failure or unresolved outcome.

After verification on every node, use the [normal solution upgrade procedure](https://learn.microsoft.com/azure/azure-local/upgrade/install-solution-upgrade). These manual installation and verification steps are **not required** to recover the known cancelled attempt; use **Resume deployment** as described in the [known-issue TSG](./Known-issue-solution-upgrade-cancelled-at-Install-software-dependencies.md).

## Rollback and escalation

This guide does not provide a downgrade or uninstall rollback. Do not remove the required PowerShell version to recover a disconnected session. If verification fails, leave the solution upgrade unstarted and contact Microsoft support with the installed version or error, installation timestamp, and `%TEMP%\PowerShell-7.6.7-install.log` from the affected node.

## References

- [Install PowerShell on Windows](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows)
- [Get-AuthenticodeSignature](https://learn.microsoft.com/powershell/module/microsoft.powershell.security/get-authenticodesignature)
- [Install solution upgrade on Azure Local](https://learn.microsoft.com/azure/azure-local/upgrade/install-solution-upgrade)
