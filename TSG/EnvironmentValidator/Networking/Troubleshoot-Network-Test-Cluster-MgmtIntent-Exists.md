# AzStackHci_Network_Test_Network_Cluster_MgmtIntent_Exists

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_Network_Cluster_MgmtIntent_Exists</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Add-Server, Pre-Update</strong></td>
  </tr>
</table>

## Overview

This validator checks that exactly one management intent exists on the cluster. The management intent defines which network adapters are used for management traffic, and there must be exactly one management intent configured for the cluster to operate correctly.

## Requirements

The cluster must meet the following requirement:
1. Exactly one network intent must have `IsManagementIntentSet` equal to `True`

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about how many management intents were found.

```json
{
  "Name": "AzStackHci_Network_Test_Network_Cluster_MgmtIntent_Exists",
  "DisplayName": "Test one management intent exists on cluster",
  "Title": "Test one management intent exists on cluster",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking if there is one and only one management intent on existing cluster",
  "Remediation": "To check cluster network intent information, run below cmdlet on your cluster:\n    Get-NetIntent\n Make sure one and only one intent is management intent: IsManagementIntentSet == \"True\"",
  "TargetResourceID": "NetworkIntent",
  "TargetResourceName": "NetworkIntent",
  "TargetResourceType": "NetworkIntent",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "ClusterMgmtIntent",
    "Resource": "ClusterMgmtIntent",
    "Detail": "There are [ 0 ] management intent(s) on the cluster. Expecting [ 1 ]. Please check the cluster network intent configuration.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: No Management Intent Found

**Error Message:**
```text
There are [ 0 ] management intent(s) on the cluster. Expecting [ 1 ]. Please check the cluster network intent configuration.
```

**Root Cause:** No network intent is configured with `IsManagementIntentSet` set to `True`. This means the cluster has no defined management traffic path.

#### Remediation Steps

##### Configure Management Intent

1. Check existing intents to see if one should be designated as the management intent:

   ```powershell
   Get-NetIntent
   ```

2. If an intent exists that should be the management intent but isn't configured correctly, you'll need to remove it and re-configure it:

   ```powershell
   # Example: Recreate an intent with management traffic
   Remove-NetIntent -ClusterName (Get-Cluster).Name -Name $intentName

   # Wait for removal
   Start-Sleep -Seconds 10

   # Create new management intent
   Add-NetIntent -ClusterName (Get-Cluster).Name -Name $intentName `-AdapterName $adapters -Management ... # Replace make sure string $intentName and string array $adapters, and put other necessary parameters as well
   ```

3. Verify the management intent was created:

   ```powershell
   Get-NetIntent | Where-Object { $_.IsManagementIntentSet -eq $true }
   ```

4. Check the intent status:

   ```powershell
   Get-NetIntentStatus
   ```

---

## Additional Information

### Common Scenarios

| Scenario | Configuration | Example |
|----------|--------------|---------|
| **Dedicated Management/Compute** | Separate adapters for management/compute + storage | Management/Compute: eth0, eth1<br>Storage: eth2, eth3 |
| **Fully Converged** | Management + Compute + Storage | ConvergedIntent: eth0, eth1<br>(all traffic types) |

Note that management intent is always a compute intent as well.

### Checking Intent Configuration

```powershell
# Detailed view of all intents
Get-NetIntent
```

### Best Practices

1. **Plan network design** before creating intents
2. **Document intent configuration** for future reference
3. **Test intent changes** in a non-production environment first
4. **Wait for intents to stabilize** (ConfigurationStatus = Success) before proceeding
5. **Verify connectivity** after making intent changes

### Related Documentation

- [Network ATC overview](https://learn.microsoft.com/en-us/azure/azure-local/concepts/network-atc-overview)
- [Manage network intents](https://learn.microsoft.com/azure-stack/hci/manage/manage-network-atc)
- [Host network requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
- [Add servers to an Azure Local cluster](https://learn.microsoft.com/azure-stack/hci/manage/add-server)
