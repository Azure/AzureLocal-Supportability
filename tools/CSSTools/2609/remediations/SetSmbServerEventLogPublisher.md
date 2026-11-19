<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "reference",
  "products": ["Azure Local"],
  "detector": {
    "type": "none",
    "signal": null
  },
  "validation": {
    "fidelity_level": "L0",
    "technical_grade": null,
    "reproduction_substrate": "none",
    "automation_status": "not-assessed",
    "last_validated": "2026-11-02",
    "spec_ref": ""
  }
}
-->

# SetSmbServerEventLogPublisher

## Table of contents

- [Synopsis](#synopsis)
- [Description](#description)
- [Syntax](#syntax)
- [Parameters](#parameters)
- [Examples](#examples)
- [Notes](#notes)

## SYNOPSIS
Sets the SMBServer Event Log publisher Enabled registry value on the local node.

## DESCRIPTION
Sets Enabled to REG_DWORD 0 (default) or 1 under the SMBServer Event Log publisher registry path
HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Publishers\{d48ce617-33a2-4bc3-a5c7-11aa4f29619e}.
Enabled 0 applies the registry workaround for SMBServer crashes. Enabled 1 reverts it.
The default environment gate permits 24H2. An installed Azure Local solution is not required.

Run through Invoke-AzsSupportInsightRemediation in an elevated session on the explicitly selected
node. There is no cluster enumeration or remote fan-out. A missing registry path is created, and a
missing or different Enabled value is written as a DWORD. If Enabled is already the requested
DWORD value, nothing is changed and NO_CHANGE_APPLIED is returned.

Evidence in the returned object and the framework's JSON remediation history records the target,
the requested value, the value before the change, and the read-back value.
SUCCESS means that a change completed and the requested DWORD was verified.

| Property | Value |
| --- | --- |
| **Risk** | [MEDIUM RISK] |
| **Maintenance Window Recommended** | Yes |
| **Expected Impact** | Changes SMB-Server ETW tracing and reduces diagnostic visibility when Enabled is 0. An operator-managed reboot is required and can interrupt workloads on the selected node unless handled through an approved maintenance procedure. |
| **Supported OS Versions** | 24H2 |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "SetSmbServerEventLogPublisher" [-Parameters <Hashtable>]
```

## PARAMETERS

### -Enabled
The Enabled value to set: 0 applies the workaround (default), 1 reverts it.

### -Force
If specified, the remediation proceeds without prompting for confirmation. Use with caution, as this may apply changes to the system unexpectedly.

### -SkipEnvironmentCheck
If specified, the remediation proceeds even if environment requirements are not met. Use with caution, as applying the remediation in an unsupported environment could cause issues.

## EXAMPLES

All examples are **[MEDIUM RISK]**, including rollback. Before running an example, verify the
selected node, administrative access, and supported OS; confirm that SMBServer tracing evidence
is not needed and that an approved maintenance and workload-protection plan covers the reboot.
Review the stop conditions, evidence, rollback, and verification in [Notes](#notes).

### EXAMPLE 1
On the explicitly selected node, review and confirm applying the workaround.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "SetSmbServerEventLogPublisher" -ErrorAction Stop
```

### EXAMPLE 2
After approval for this node, apply without another confirmation and inspect the evidence.
```powershell
$result = Invoke-AzsSupportInsightRemediation -ScriptName "SetSmbServerEventLogPublisher" -Parameters @{ Force = $true } -ErrorAction Stop
$result.Evidence
```

### EXAMPLE 3
Revert the workaround on the same node by setting Enabled back to 1.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "SetSmbServerEventLogPublisher" -Parameters @{ Enabled = 1 } -ErrorAction Stop
```

Expected result for each example: SUCCESS with the requested DWORD verified, or
NO_CHANGE_APPLIED if the requested DWORD was already present. Preserve the returned result;
stop on any other outcome or failed verification and contact Microsoft Support.

## NOTES
- Trigger: The AzureLocal.KI.SmbServer.EventLogPublisher Known Issues rule reports WARNING when
  the registry path or Enabled is absent, or Enabled is not REG_DWORD 0.
  The rule never applies this remediation.
- Prerequisites: Administrative rights and 24H2 by default. An installed Azure Local solution is
  not required.
- Risk and impact: **[MEDIUM RISK]**. Modifying this toggles SMB-Server ETW tracing. This remediation
  only sets a registry value and will not reboot the computer. You must perform the reboot
  yourself for the change to take effect. Use an approved maintenance procedure to protect
  workloads before rebooting; do not reboot nodes together.
- Stop conditions: Do not proceed while SMBServer Event Log evidence is required or on an
  unintended node. Stop on access, write, or verification errors; preserve the result and do not
  assume a failed operation changed nothing.
- Evidence: BeforeKeyExists and BeforeData record the state before the change; AfterData records
  the read-back. KeyCreated records creation of a missing publisher registry path.
  ChangesApplied records a completed write or a created registry path.
  Save the returned object and copy the JSON history outside its normal retention.
- Rollback: Run this remediation again with -Parameters @{ Enabled = 1 }. Do not delete the
  publisher registry path. The operator-managed reboot requirement also applies after rollback.
- Verification: PersistedStateVerified confirms that Enabled was read back as the requested
  REG_DWORD value. After the planned reboot, verify that the node and its workloads return to
  their expected operational state; stop and contact Microsoft Support if they do not.
- Documentation validation: Static review only (L0), based on the module's 1.2609.30.2
  documentation. The remediation has not been executed as part of this documentation update.
