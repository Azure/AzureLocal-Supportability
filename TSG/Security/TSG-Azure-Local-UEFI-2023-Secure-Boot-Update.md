# Summary
Secure Boot UEFI 2023 Update has been included in Azure Local Solution Update 2603. This TSG provides answers to the fredently asked questions regarding the Secure Boot Update process on Azure Local as well as things you will need to do before applying BIOS firmware update after Secure Boot Update. 

- [Summary](#summary)
- [Secure Boot Update validation](#secure-boot-update-validation)
  - [How do I verify if Secure Boot Update has been completed on my cluster?](#how-do-i-verify-if-secure-boot-update-has-been-completed-on-my-cluster)
    - [Using cmdlet](#using-cmdlet)
    - [Querying registry](#querying-registry)
  - [What is the impact if my Secure Boot Update is not completed?](#what-is-the-impact-if-my-secure-boot-update-is-not-completed)
  - [Why does the Secure Boot Update result indicate that it is not fully completed?](#why-does-the-secure-boot-update-result-indicate-that-it-is-not-fully-completed)
    - [Case 1: Node is on a not-supported BIOS version](#case-1-node-is-on-a-not-supported-bios-version)
    - [Case 2: Node needs another reboot](#case-2-node-needs-another-reboot)
    - [Case 3: Other causes](#case-3-other-causes)
  - [I’ve deployed Azure Local release 2603 or later. Why don’t I see the Secure Boot Update being applied?](#ive-deployed-azure-local-release-2603-or-later-why-dont-i-see-the-secure-boot-update-being-applied)
  - [If Secure Boot Update results show all my nodes have completed successfully, is there anything I will need to do?](#if-secure-boot-update-results-show-all-my-nodes-have-completed-successfully-is-there-anything-i-will-need-to-do)
- [Prerequisites for BIOS Firmware Update after 2603 or later Solution Update](#prerequisites-for-bios-firmware-update-after-2603-or-later-solution-update)
  - [I have completed Azure Local Solution Update 2603, and I would like to update BIOS firmware separately. What should I do before starting BIOS firmware installation?](#i-have-completed-azure-local-solution-update-2603-and-i-would-like-to-update-bios-firmware-separately-what-should-i-do-before-starting-bios-firmware-installation)
  - [I plan to run Azure Local 2604 Solution Update and install SBE package **during the Solution Update**. What should I do before starting the Solution Update?](#i-plan-to-run-azure-local-2604-solution-update-and-install-sbe-package-during-the-solution-update-what-should-i-do-before-starting-the-solution-update)
- [Support and escalation guidance](#support-and-escalation-guidance)
  - [Severity mapping for Azure Local Secure Boot scenarios](#severity-mapping-for-azure-local-secure-boot-scenarios)
  - [When to contact support versus and when to wait](#when-to-contact-support-versus-and-when-to-wait)


# Secure Boot Update validation
## How do I verify if Secure Boot Update has been completed on my cluster?
### Using cmdlet

For systems containing the following cmdlet, you can run the following **on each node** to confirm the Secure Boot Update results:

```powershell
Test-AzSSecureBootUpdateCompleted [-Verbose]
```
A result of `true` signifies the update has been successfully completed and all expected changes have been applied to the node.
A result of `false` means at least one planned update item is not yet finished.

You can use the `-Verbose` parameter to see more granular completion results. In the verbose output, the following values showing status of corresponding components are provided. You can use these values to determine if update on a specific component has been done.
- WindowsUEFICAInstalled
- MicrosoftUEFICAInstalled
- MicrosoftOptionROMUEFICAInstalled
- KEKInstalled
- BootEFISignerUpdated

### Querying registry

For nodes without access to the above cmdlet, you can check Secure Boot Update results via the registry by running the following command **on each node**.
```powershell
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing\" -Name UEFICA2023Status
```

A value of `Updated` signifies the update has been successfully completed and all expected changes have been applied to the node.
A value of `InProgress` or `NotStarted` means at least one planned update item has not yet been started or completed successfully.

## What is the impact if my Secure Boot Update is not completed?

There is no imminent impact on your cluster nodes. Your nodes will still boot and run regardless of the Secure Boot Update result while certain Secure Boot related functions will be limited after expiration.

For more details, please refer to [Q1: What happens if my device doesn’t get the new Secure Boot certificates before the old ones expire?](https://support.microsoft.com/en-us/topic/frequently-asked-questions-about-the-secure-boot-update-process-b34bf675-b03a-4d34-b689-98ec117c7818) from Microsoft Support page.

## Why does the Secure Boot Update result indicate that it is not fully completed?

There are a few possible reasons why your update didn't complete successfully:

### Case 1: Node is on a not-supported BIOS version
We noticed for certain OEM manufacturers and models, a minimum BIOS version may be required to install the Secure Boot Update. For more details, please refer to this Microsoft Support page for OEM specific information. [Original Equipment Manufacturer (OEM) pages for Secure Boot - Microsoft Support](https://support.microsoft.com/en-us/topic/original-equipment-manufacturer-oem-pages-for-secure-boot-9ecc3ba4-fb50-4bd3-9e9b-f16b35b8fb68)

For example, here is a list of known impacted OEM manufacturers and models for Dell.

```json
{
  "OEMs": [
    {
      "Manufacturer": "Dell Inc.",
      "Models": [
        { "Model": "AX-640", "MinimumBiosVersion": "2.21.2" },
        { "Model": "AX-6515", "MinimumBiosVersion": "2.14.1" },
        { "Model": "AX-740", "MinimumBiosVersion": "2.21.2" },
        { "Model": "C6420", "MinimumBiosVersion": "2.21.0" },
        { "Model": "R440", "MinimumBiosVersion": "2.21.1" },
        { "Model": "R640", "MinimumBiosVersion": "2.21.2" },
        { "Model": "R740", "MinimumBiosVersion": "2.21.2" },
        { "Model": "R940", "MinimumBiosVersion": "2.21.2" },
        { "Model": "XC740xd", "MinimumBiosVersion": "2.21.2" }
      ]
    }
  ]
}
```

If you find your BIOS version is below the minimum required version, please **refer to [the BIOS Firmware update section](#prerequisites-for-bios-firmware-update-after-2603-or-later-solution-update) first** and work with your OEM provider to properly apply BIOS firmware update following the guidance.

BIOS version can be retrieved from BMC console or calling the following cmdlet. If you cannot find accurate information from output of this cmdlet, please refer to OEM documentation to confirm your BIOS version.

```powershell
(Get-CimInstance -Class Win32_BIOS).SMBIOSBIOSVersion
```

In future Solution Update releases, we will retry applying the Secure Boot Update on nodes that satisfy the BIOS minimum version requirements.

### Case 2: Node needs another reboot
Because the number of reboots required during Secure Boot Update is not deterministic, you may still need one or more reboots.

Run the following cmdlets to validate the case:
```powershell
$UEFICA2023Status = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing\" -Name UEFICA2023Status -ErrorAction Continue
$UEFICA2023Error = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing\" -Name UEFICA2023Error -ErrorAction Continue
$rebootFlagExist = $null -ne (Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\" -ErrorAction Continue | Where-Object Name -match "RestartRequired")
$rebootPending = $rebootFlagExist -or ($UEFICA2023Status.UEFICA2023Status -eq "InProgress" -and $UEFICA2023Error.UEFICA2023Error -eq 2147942750)
if ($rebootPending) {
  Write-Host "Another reboot is needed on node $env:ComputerName"
} else {
  Write-Host "Reboot pending status not found on node $env:ComputerName"
}
```
If any other reboot is needed, you may either properly reboot the node until the update is completed or wait for future Azure Local solution update.

### Case 3: Other causes

We have seen non-successful cases that do not belong to case 1 and 2 mentioned above. Microsoft is actively monitoring the process of update and will keep this TSG updated. If you case does not match the known cases mentioned above, please contact Microsoft Support team for more details.

## I’ve deployed Azure Local release 2603 or later. Why don’t I see the Secure Boot Update being applied?

So far, we only support Secure Boot Update in Solution Update 2603. Newly deployed 2603 clusters or added nodes will have the Secure Boot Update applied during next Solution Update. Deployment and AddNode operations themselves will support Secure Boot Update in a future Azure Local Solution release.

If your cluster went through Azure Local Upgrade before 2603, Secure Boot Update should happen during Solution Update 2603. If you upgrade the cluster while in 2603, the Secure Boot Update should happen in a future Solution Update release.

## If Secure Boot Update results show all my nodes have completed successfully, is there anything I will need to do?

If you would like to install BIOS firmware update manually, either by triggering SBE update yourself or install BIOS firmware manually, please refer to the section below.

Otherwise, no action is required.

# Prerequisites for BIOS Firmware Update after 2603 or later Solution Update
## I have completed Azure Local Solution Update 2603, and I would like to update BIOS firmware separately. What should I do before starting BIOS firmware installation?

Please follow the below steps to prepare for BIOS firmware update. Please note **these steps are always applicable regardless of the result of Secure Boot Update**, which we introduced in Azure Local 2603 release. This is applicable to all firmware update approaches including Solution Builder Extension (SBE) as well as any manual installation.

1. Please go through the normal preparation workflow on target node, including suspending node from cluster and suspending BitLocker Boot Volume (when applicable). Please do the steps manually on the target node even if you are using SBE package for BIOS firmware update.
2. Run the following cmdlet on target node to disable secure boot update task:

   ```powershell
   Disable-ScheduledTask -TaskPath "\Microsoft\Windows\PI\" -TaskName "Secure-Boot-Update"
   ```
3. Reboot the target node.
4. If multiple nodes are pending a BIOS firmware update, perform steps 1,2 and 3 on **each node** respectively, one at a time.
5. Start the BIOS firmware installation through SBE update or manual installation.
6. After the BIOS update completes and any required post-installation reboot is performed, resume the cluster node and re-enable BitLocker boot volume protection, if applicable.

## I plan to run Azure Local 2604 Solution Update and install SBE package **during the Solution Update**. What should I do before starting the Solution Update?
Azure Local Solution Update 2604 will handle the SBE update. There is no specific pre-requisite for SBE to work properly during Azure Local Solution Update 2604. There is no manual action required under this scenario.

# Support and escalation guidance

If you have issues while planning, orchestrating, or verifying Secure Boot updates, contact Microsoft Support before proceeding with other firmware (BIOS or UEFI) changes or enabling revocations in production environments.

## Severity mapping for Azure Local Secure Boot scenarios

| Severity | When to use it | Examples | What to include |
| --- | --- | --- | --- |
| Severity A (Critical) | Production outage or imminent business-critical impact. One or more nodes can't boot, or the cluster is down or can't provide service. | - Host fails to boot after Secure Boot update or revocation.  <br>- Repeated boot loops.  <br>- Cluster unavailable because nodes are stuck during boot.  <br>- Recovery, WinRE, or installation media can't boot and recovery is blocked. | - Exact failure point and recent changes.  <br>- Firmware (BIOS or UEFI) version and OEM model.  <br>- Secure Boot-related event logs and last reboot time.  <br>- BitLocker state or recovery prompt details (if applicable). |
| Severity B (High) | Production functionality is degraded or at-risk, but the cluster remains operational. Requires timely investigation. | - Secure Boot update stuck in a pending or scheduled state across reboots,  <br>- Repeated Secure Boot DB or DBX update failure in event logs.  <br>- Azure Local health shows persistent out-of-policy related to Secure Boot servicing.  <br>- Planned firmware update must proceed but Secure Boot mitigation is mid-flight. | - Current mitigation stage (DB, Boot Manager, DBX).  <br>- Relevant Secure Boot event IDs and messages.  <br>- Evidence of pending reboot requirements.  <br>- Planned maintenance window details. |
| Severity C (Normal) | Questions, guidance requests, or non-production and testing issues with no service impact. | - Planning and validation questions.  <br>- Confirming firmware readiness for certificate updates.  <br>- Updating boot media or WinPE and validating compatibility.  <br>- Interpreting Secure Boot events and expected timing. | - Environment inventory (OEM models, firmware versions).  <br>- Pilot or test results.  <br>- Relevant KB references and completed steps. |

## When to contact support versus and when to wait

1. Is any Azure Local node unable to boot, or is the cluster down or unavailable?
   - Yes: Open a Severity A support request immediately.
   - No: Continue.
2. Did you recently apply a Secure Boot update step that requires one or more reboots?
   - Yes: Allow the required reboots to complete, then re-check Secure Boot event logs.
   - No or not sure: Continue.
3. Do Secure Boot event logs show a blocking condition, such as BitLocker recovery risk, customized keys, or firmware not supporting the update?
   - Yes: Don't proceed with other steps or firmware updates. Open a Severity B request.
   - No: Continue.
4. Is a firmware (BIOS or UEFI) update, including SBE-driven firmware updates, scheduled while a certificate update step is pending or scheduled?
   - Yes: Pause or defer the firmware update if possible, and open a Severity B request for coordination guidance.
   - No: Continue.
5. Are you validating the process in a test or lab environment with no service impact?
   - Yes: Use Severity C for guidance and best practices.
   - No: If production risk exists, use Severity B.

For more information about how to get support, see [Get support for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/manage/get-support?view=azloc-2603).