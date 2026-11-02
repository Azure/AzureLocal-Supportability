# ClearStorageHealthData

## SYNOPSIS
Clear Health Service data entries for storage components.

> [!WARNING]
> This script is invoked through [`Invoke-AzsSupportScript`](../functions/Invoke-AzsSupportScript.md)
> and **must only be run by Microsoft CSS or Engineering.** It erases Health Service data records from
> CLUSDB and volatile storage. Erasing the wrong record can leave physical disks, pools, or the Health
> Service in an inconsistent state. Confirm the target entity keys and preconditions before running,
> and prefer running with `-Verbose` (without `-Force`) first so you are prompted before each change.

## DESCRIPTION
A general-purpose tool for erasing Health Service data records from CLUSDB and volatile storage. It
provides preset parameter sets for common scenarios and a generic mode for arbitrary data entries.

**Preset modes:**

- `-MaintenanceModeIntent` — Erases the `MaintenanceModeIntent` private data store (StorHealth
  provider). Use when physical disks are stuck in maintenance mode due to orphaned intent after a
  Health Service failover.
- `-PhysicalDiskIntent` / `-PhysicalDiskPolicy` — Erases the per-disk `Intent` bitmask flags or `Policy`
  data. Use when a disk shows a stuck operational status like "Removing from Pool".

**Generic mode:**

- `-Name` / `-Key` — Erase any named data record on any entity key. Use `-ProviderGuid` to target
  private data stores.

After running, move the Health Service resource to trigger a fresh startup:

```powershell
Move-ClusterGroup "SDDC Group"
```

## WHERE TO RUN
This script must run **on a cluster node**. It compiles and calls into `healthapi.dll` on the local
machine to read and erase Health Service records, so it requires a Storage Spaces Direct / Health
Service–enabled node with the appropriate local privileges.

## PARAMETERS

| Parameter | Type | Parameter set | Description |
|-----------|------|---------------|-------------|
| `MaintenanceModeIntent` | switch | MaintenanceMode | Erase the `MaintenanceModeIntent` private data store (Intent/InheritedIntent/InProgress/Workflows maps). |
| `PhysicalDiskIntent` | switch | PDByUniqueId / PDBySerial | Clear the per-disk `Intent` bitmask flags (operational status indicators). |
| `PhysicalDiskPolicy` | switch | PDByUniqueId / PDBySerial | Clear the per-disk `Policy` data (S2D usage, firmware compliance state). |
| `UniqueId` | string | PDByUniqueId | The `UniqueId` of a physical disk (from `Get-PhysicalDisk`). Accepts pipeline input by property name. |
| `SerialNumber` | string | PDBySerial | The `SerialNumber` of a physical disk (from `Get-PhysicalDisk`). |
| `Name` | string | Generic | The data record name to erase. |
| `Key` | string | Generic | The entity key (objectId) that owns the data record. |
| `ProviderGuid` | string | Generic | Optional provider GUID for private data stores. When specified, `Name` is prefixed with `{ProviderGuid}::`. |
| `Force` | switch | (All) | Skip the confirmation prompt. |

The script declares `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]`, so it also honors
the common `-WhatIf`, `-Confirm`, and `-Verbose` parameters.

## EXAMPLES

### EXAMPLE 1 — Physical disks stuck in maintenance mode after a Health Service failover
```powershell
Invoke-AzsSupportScript -ScriptName "ClearStorageHealthData" -Parameters @{
    MaintenanceModeIntent = $true
    Verbose               = $true
}
Move-ClusterGroup "SDDC Group"
```

### EXAMPLE 2 — Physical disk stuck in "Removing from Pool" status
```powershell
Invoke-AzsSupportScript -ScriptName "ClearStorageHealthData" -Parameters @{
    PhysicalDiskIntent = $true
    UniqueId           = "5000C5007952B6E8"
    Verbose            = $true
    Force              = $true
}
```

### EXAMPLE 3 — Clear both intent and policy on a disk by serial number
```powershell
Invoke-AzsSupportScript -ScriptName "ClearStorageHealthData" -Parameters @{
    PhysicalDiskIntent = $true
    PhysicalDiskPolicy = $true
    SerialNumber       = "Z1Z5L2SX"
    Verbose            = $true
    Force              = $true
}
```

### EXAMPLE 4 — Clear an arbitrary private data store entry
```powershell
Invoke-AzsSupportScript -ScriptName "ClearStorageHealthData" -Parameters @{
    Name         = "MaintenanceModeSblDrainState"
    Key          = "{3fedb9cb-0cfd-43c6-aa07-19253f282529}:PD:{896cbde3-a568-03cf-27c9-39e7128557fe}"
    ProviderGuid = "29D1F3EE-DBCF-44E9-B0CC-085BFA362499"
    Verbose      = $true
    Force        = $true
}
```

## NOTES
- Based on `Clear-PhysicalDiskHealthData.ps1` by Don MacGregor, extended for maintenance mode and
  generic scenarios.
- The script's comment-based help lists the known provider GUIDs, private/public data stores, and
  entity keys. Consult [the source script](../../src/scripts/ClearStorageHealthData.ps1) for the full
  reference table before targeting a record in generic mode.
