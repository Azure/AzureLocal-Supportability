# AzStackHci_Network_Test_NetworkIntentRequirement

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_NetworkIntentRequirement</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment</strong></td>
  </tr>
</table>

## Overview

This validator checks that Rack Aware clusters have exactly one storage-only intent defined. Rack Aware deployments require a dedicated storage intent to ensure proper storage network configuration across racks.

## Requirements

For Rack Aware clusters:
1. Exactly one storage-only intent must be defined (TrafficType contains "Storage" only, without "Management" or "Compute")

For Standard or Stretch clusters:
- This validation is skipped (not applicable)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about storage intent configuration.

```json
{
  "Name": "AzStackHci_Network_Test_NetworkIntentRequirement",
  "DisplayName": "Test host network intent requirements for Rack Aware cluster",
  "Title": "Test host network intent requirements for Rack Aware cluster",
  "Status": 1,
  "Severity": 2,
  "Description": "Test that only one storage-only intent is present for Rack Aware cluster",
  "Remediation": "",
  "TargetResourceID": "NetworkIntentRequirement",
  "TargetResourceName": "NetworkIntentRequirement",
  "TargetResourceType": "NetworkIntentRequirement",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "<ComputerName>",
    "Resource": "NetworkIntentRequirement",
    "Detail": "No storage-only intent is present for Rack Aware cluster.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: No Storage-Only Intent for Rack Aware Cluster

**Error Message:**
```text
No storage-only intent is present for Rack Aware cluster.
```

**Root Cause:** The Rack Aware cluster deployment is missing a dedicated storage-only intent. Rack Aware clusters require a storage-only intent to ensure proper storage traffic isolation and routing across racks.

#### Remediation Steps

##### Verify Current Intent Configuration

1. Check existing intents in the deployment configuration:

   ```powershell
   # If intents are already created, check them
   Get-NetIntent | Select-Object IntentName, TrafficType, Adapter | Format-Table -AutoSize
   ```

2. Identify if any intent is storage-only:

   ```powershell
   # Check for storage-only intents
   Get-NetIntent | Where-Object { 
       $_.TrafficType -contains "Storage" -and 
       $_.TrafficType -notcontains "Management" -and 
       $_.TrafficType -notcontains "Compute"
   }
   ```

##### Add Storage-Only Intent

For Rack Aware deployments, create a dedicated storage-only intent:

1. Identify adapters to use for storage traffic:
   - Use high-speed adapters (10Gbps+, preferably 25Gbps or higher)
   - Use RDMA-capable adapters if possible
   - Ensure adapters are available on all nodes

2. Add the storage-only intent to your deployment configuration:

   **During deployment (before cluster creation):**
   - Update your deployment configuration file or parameters
   - Add a storage-only intent definition

   **Example intent configuration:**
   ```powershell
   # Example: Storage-only intent for Rack Aware cluster
   $storageIntent = @{
       Name = "StorageIntent"
       Adapter = @("Ethernet 2", "Ethernet 3")  # Replace with your storage adapter names
       TrafficType = @("Storage")
   }
   ```

3. If using deployment configuration files (JSON/YAML), add the storage intent:

   **Example JSON configuration:**
   ```json
   {
       "intents": [
           {
               "name": "ManagementComputeIntent",
               "trafficType": ["Management", "Compute"],
               "adapter": ["Ethernet", "Ethernet 2"]
           },
           {
               "name": "StorageIntent",
               "trafficType": ["Storage"],
               "adapter": ["Ethernet 3", "Ethernet 4"]
           }
       ]
   }
   ```

4. If using PowerShell deployment, add the intent during cluster creation:

   ```powershell
   # During cluster deployment, add storage-only intent
   Add-NetIntent -ClusterName "MyCluster" `
       -Name "StorageIntent" `
       -AdapterName @("Ethernet 3", "Ethernet 4") `
       -Storage
   ```

##### Retry Deployment

After adding the storage-only intent to your deployment configuration, retry the deployment operation.

---

### Failure: Multiple Storage-Only Intents for Rack Aware Cluster

**Error Message:**
```text
More than 1 storage-only intents are present for Rack Aware cluster.
```

**Root Cause:** The deployment configuration includes more than one storage-only intent. Rack Aware clusters should have exactly one storage-only intent.

#### Remediation Steps

1. Review your deployment configuration to identify all storage-only intents.

2. Determine which storage intent should be used and remove the others from your deployment configuration.

3. Update the deployment configuration to include only one storage-only intent.

4. Retry the deployment operation.

---

## Additional Information

### Understanding Rack Aware Clusters

Rack Aware clusters are designed for:
- **Multi-rack deployments** where cluster nodes span multiple physical racks
- **Fault domain awareness** based on rack placement
- **Improved resilience** by distributing resources across racks

### Why Storage-Only Intent is Required for Rack Aware

Rack Aware clusters require a dedicated storage-only intent because:
1. **Cross-rack storage traffic** must be properly routed
2. **Storage network isolation** prevents interference from other traffic
3. **Performance optimization** for storage across rack boundaries
4. **Fault tolerance** ensures storage connectivity even if a rack has issues

### Network Intent Patterns for Rack Aware

**Recommended pattern for Rack Aware:**

| Intent Name | Traffic Types | Adapters | Purpose |
|------------|---------------|----------|---------|
| ManagementComputeIntent | Management, Compute | eth0, eth1 | Management and VM traffic |
| StorageIntent | Storage | eth2, eth3 | Dedicated storage traffic |

**Not recommended (converged):**

| Intent Name | Traffic Types | Adapters | Issue |
|------------|---------------|----------|-------|
| ConvergedIntent | Management, Compute, Storage | eth0, eth1 | Not allowed for Rack Aware |

### Comparing Cluster Patterns

| Cluster Pattern | Storage Intent Requirement |
|----------------|---------------------------|
| **Standard** | Storage can be converged or dedicated (no requirement) |
| **Stretch** | Storage can be converged or dedicated (no requirement) |
| **Rack Aware** | Must have exactly one storage-only intent (not converged) |

### Checking Cluster Pattern

To verify your cluster pattern:

```powershell
# Check cluster configuration
# The cluster pattern is typically defined during deployment configuration
# Check your deployment parameters or configuration file
```

### Storage-Only Intent Validation

A storage-only intent must:
- **Include** "Storage" in TrafficType
- **Exclude** "Management" from TrafficType
- **Exclude** "Compute" from TrafficType

```powershell
# Validate an intent is storage-only
$intent = Get-NetIntent -Name "StorageIntent"
$isStorageOnly = ($intent.TrafficType -contains "Storage") -and 
                  ($intent.TrafficType -notcontains "Management") -and 
                  ($intent.TrafficType -notcontains "Compute")

if ($isStorageOnly) {
    Write-Host "✓ Intent is storage-only" -ForegroundColor Green
} else {
    Write-Host "✗ Intent is NOT storage-only" -ForegroundColor Red
    Write-Host "Traffic Types: $($intent.TrafficType -join ', ')"
}
```

### Related Documentation

- [Network ATC overview](https://learn.microsoft.com/azure-stack/hci/deploy/network-atc-overview)
- [Rack-aware clusters](https://learn.microsoft.com/azure-stack/hci/concepts/fault-domains)
- [Plan host networking](https://learn.microsoft.com/azure-stack/hci/plan/plan-host-networking)
- [Manage Network ATC](https://learn.microsoft.com/azure-stack/hci/manage/manage-network-atc)
