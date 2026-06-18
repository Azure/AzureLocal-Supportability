# Known Issue: SAN LUN Visibility Check Fails

| Field | Value |
|---|---|
| **Component** | Environment Validator - SAN Storage |
| **Check** | Test SAN LUN Visibility (`AzureLocal_SAN_Test_LUN_Visibility`) |
| **Severity** | Critical - blocks Deployment / Add Node |
| **Applies to** | Deployment and Add Node with SAN-attached (Fibre Channel or iSCSI) external storage |
| **Affected versions** | Azure Local 2607 and later |
| **Fixed in** | N/A - this is an environmental readiness failure, not a product defect |

## Overview

When you deploy Azure Local (or add a node) with **SAN-attached external storage**, the Environment Validator runs a **Test SAN LUN Visibility** readiness check. The check confirms that every configured SAN LUN is both **visible** to each server and reporting a **Healthy** status. If any configured LUN is missing or unhealthy on any server, the check returns a **Critical** failure and blocks the operation.

This is a correct readiness gate: it stops a deployment that would otherwise fail later because the storage fabric is not fully and consistently presented to every server. The configured volumes the check looks for are `Infrastructure_1`, `ClusterPerformanceHistory`, and - for deployments that use a SAN witness - `Witness`.

## Symptoms

The Environment Validator reports a **Critical** failure on the **Test SAN LUN Visibility** check. The error text matches one of these two patterns:

1. A LUN is **missing** on a server:

   ```
   The following SAN LUN(s) are not visible to this node: <Volume> (UniqueId '<id>'), ...
   ```

2. A LUN is **present but unhealthy** on a server:

   ```
   The following SAN LUN(s) are visible but not healthy on this node: <Volume> (UniqueId '<id>') reports HealthStatus '<Warning|Unhealthy>'
   ```

The failure is reported **per server** and names the affected server(s). A partial zoning or LUN-masking gap shows up as a failure on a subset of servers only, so always read which server is named.

The two patterns have different causes:

- **Missing** almost always means a **connectivity** problem - SAN switch **zoning** or array **LUN-masking** does not include that server's initiator (WWPN for Fibre Channel, IQN for iSCSI), or the LUN was never created or mapped.
- **Visible but unhealthy** almost always means a **multipath (MPIO) / path** problem - failed paths, MPIO not installed, or the storage array not claimed by the Microsoft device-specific module (MSDSM).

## Resolution

Work on the **server named in the failure**. The commands below are read-only until Step 3.

### Step 1: Confirm what the server actually sees

```powershell
# Refresh the storage view first
Update-HostStorageCache
Update-StorageProviderCache -DiscoveryLevel Full

# List every disk this server sees, with health
Get-Disk |
    Select-Object Number, FriendlyName, BusType, UniqueId, OperationalStatus, HealthStatus |
    Format-Table -AutoSize

# Resolve a specific configured LUN by the UniqueId shown in the error
Get-Disk | Where-Object { $_.UniqueId -ieq '<lunid>' } |
    Format-List Number, FriendlyName, BusType, HealthStatus, OperationalStatus
```

Interpret the result:

- The configured LUN is **absent** -> connectivity / masking problem. Go to Step 3 (missing).
- The LUN is **present** but `HealthStatus` is `Warning` or `Unhealthy` -> path / MPIO problem. Go to Step 2, then Step 3 (unhealthy).

### Step 2: Check multipath (MPIO) - the most common cause of "visible but unhealthy"

```powershell
# Is the Multipath-IO feature installed?
Get-WindowsFeature -Name Multipath-IO

# Which vendor/product IDs has MPIO been told to claim?
Get-MSDSMSupportedHW

# Is iSCSI auto-claim enabled?
Get-MSDSMAutomaticClaimSettings

# Current multipath map and active path count
mpclaim -s -d

# Read the exact VendorId / ProductId your array reports (use these in the next step)
Get-MPIOAvailableHW
```

If `Get-MSDSMSupportedHW` does **not** list your array's VendorId/ProductId, MPIO has not claimed the LUNs. You can register the array, enable auto-claim for iSCSI, then reboot so MPIO re-enumerates the paths.

> [!WARNING]
> The commands below change MPIO configuration and reboot the server. Run them only during a maintenance window and follow your change-control process.

    New-MSDSMSupportedHW -VendorId "<VendorId>" -ProductId "<ProductId>"
    Enable-MSDSMAutomaticClaim -BusType iSCSI     # iSCSI only
    Restart-Computer                              # reboot required for MPIO claim changes to take effect
> [!IMPORTANT]
> Supported SAN vendors for Azure Local are **NetApp, Pure, HPE, Dell, Hitachi, and Lenovo**. Use the **exact** VendorId/ProductId your array reports - run `Get-MPIOAvailableHW` to read them.
> Notes: NetApp ONTAP in C-Mode reports its ProductId as `LUN C-Mode` (with the trailing ` C-Mode`), **not** `LUN`. Hitachi VSP arrays are registered with `mpclaim` instead of `New-MSDSMSupportedHW`: `mpclaim -r -i -d "HITACHI OPEN-V"` (then restart). Lenovo ThinkSystem DM/DG arrays are NetApp ONTAP-based and report the NetApp IDs. The complete per-vendor registration table is in the [Connect an external storage array to Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/deploy/enable-external-storage) setup guide.

### Step 3: Fix the underlying issue, then rescan

| Symptom | Likely cause | Fix |
|---|---|---|
| LUN missing on **one** server | Zoning / LUN-masking excludes that server's WWPN (FC) or IQN (iSCSI) | Add the server's initiator to the array host group and the fabric zone, re-present the LUN, then rescan. |
| LUN missing on **all** servers | LUN not created/mapped, or the initiator is down | Verify the LUN exists and is mapped to the host group. For iSCSI, confirm the target portal is reachable on TCP **3260** and the session is connected (`Connect-IscsiTarget -IsPersistent $true -IsMultipathEnabled $true`); for FC, verify HBA links. |
| LUN visible but **Unhealthy/Warning** | Failed paths / MPIO not installed / array not claimed | Install Multipath-IO, claim the array (Step 2), and restore redundant paths. |

After any SAN-side change, rescan on **every** affected server:

```powershell
Update-HostStorageCache
Update-StorageProviderCache -DiscoveryLevel Full
```

### Step 4: Verify and re-run

Confirm every configured LUN is present and `Healthy` on each server:

```powershell
Get-Disk |
    Select-Object Number, FriendlyName, BusType, UniqueId, OperationalStatus, HealthStatus |
    Format-Table -AutoSize
```

Then re-run the readiness check and resume the operation from the Azure portal: open the failed **Deployment** or **Add Node** operation and select **Try again** (re-validate). The deployment continues once the Test SAN LUN Visibility check passes on all servers.

## Applicable Versions

| Azure Local version | SAN LUN Visibility check |
|---|---|
| 2606 and earlier | Not present |
| 2607 and later | Present - Critical, blocks Deployment / Add Node |

## Related Articles

- [Connect an external storage array to Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/deploy/enable-external-storage) - SAN setup, the MPIO vendor registration table, and official troubleshooting.
- [SAN storage requirements for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/concepts/san-requirements) - supported arrays, transports, and prerequisites.
- [MPIO troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-server/backup-and-storage/windows-server-mpio-troubleshooting)
- [iSCSI connectivity troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-server/backup-and-storage/iscsi-storage-connectivity-troubleshooting)
