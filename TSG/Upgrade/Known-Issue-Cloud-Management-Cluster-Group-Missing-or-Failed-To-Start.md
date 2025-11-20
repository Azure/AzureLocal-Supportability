---
author: alexavila@microsoft.com, brnichol@microsoft.com
foundinbuild: Azure Local, Azure Stack HCI 22H2+
---

# Table of Contents

- [Description](#description)
- [Cause](#cause)
- [Prerequisites](#prerequisites)
- [Resolution](#resolution)
  - [Identify Your Scenario](#identify-your-scenario)
  - [Scenario A: Cloud Management Group Completely Missing](#scenario-a-cloud-management-group-completely-missing)
    - [Step 1: Check and Repair ClusterMSI Authentication](#step-1-check-and-repair-clustermsi-authentication)
    - [Step 2: Create Cloud Management Cluster Group](#step-2-create-cloud-management-cluster-group)
    - [What the Function Does](#what-the-function-does)
    - [Verification](#verification)
  - [Scenario B: Cloud Management Group Exists But Fails to Start](#scenario-b-cloud-management-group-exists-but-fails-to-start)
    - [Repair Registration to Enable Cloud Management](#repair-registration-to-enable-cloud-management)
    - [What Repair-AzureStackHCIRegistration Does](#what-repair-azurestackhciregistration-does)
- [Details](#details)
  - [Identifying Your Scenario](#identifying-your-scenario)
    - [Scenario A: Cloud Management Group Completely Missing](#scenario-a-cloud-management-group-completely-missing-1)
    - [Scenario B: Cloud Management Group Fails to Start](#scenario-b-cloud-management-group-fails-to-start-1)
  - [Diagnostic Commands](#diagnostic-commands)
  - [Additional Troubleshooting](#additional-troubleshooting)
    - [Cloud Management Service Not Installed](#cloud-management-service-not-installed)
  - [Final Verification](#final-verification)

# Description

After upgrading from 22H2, the Cloud Management cluster group is either completely missing or fails to come online, preventing cluster management operations. This issue prevents cloud management features, cluster updates syncing to the portal, and alerts from functioning properly.

# Cause

<div style="border: 2px solid #fdd835; background-color: #fffde7; padding: 15px; margin: 20px 0; border-radius: 8px;">
  <h3 style="color: #fdd835; margin-top: 0;">Common Causes</h3>
  <ul>
    <li>Cluster was registered before Cloud Management support was required (typically before 2024)</li>
    <li>Upgrade from 22H2 did not properly initialize Cloud Management components</li>
    <li>Original registration missing MSI (Managed Service Identity) configuration</li>
    <li>Cluster agent service not properly configured during upgrade</li>
  </ul>
</div>

---

# Prerequisites

<div style="border: 2px solid #2e7d32; background-color: #e8f5e9; padding: 15px; margin: 20px 0; border-radius: 8px;">
  <p style="margin: 0;"><strong>⚠️ Important:</strong> Before proceeding, you <strong>must</strong> verify that all cluster nodes show <code>ConnectionStatus: Connected</code> and are <strong>NOT</strong> in an <code>OutOfPolicy</code> state.</p>
</div>

**Check registration status on all nodes:**

```powershell
# Check all nodes for registration status
Invoke-Command (Get-ClusterNode) {Get-AzureStackHCI}

# Expected on each node:
# ConnectionStatus   : Connected
# RegistrationStatus : Registered
# (NOT OutOfPolicy)
```

<div style="border: 1px dashed #007bff; background-color: #f0f8ff; padding: 12px; margin: 20px 0; border-radius: 6px;">
  <h3 style="color: #0056b3; margin: 0 0 6px; font-size: 1em;">☁️ OutOfPolicy Scenario</h3>
  <p style="margin: 0 0 8px; font-size: 0.9em;">
    If any node reports <code>OutOfPolicy</code> status, the Cloud Management failure is due to the broken registration state, <strong>not</strong> the missing Cloud Management configuration.
  </p>
  <p style="margin: 0; font-size: 0.9em;">
    <strong>You must resolve the OutOfPolicy condition first</strong> before proceeding with this guide. See: <a href="https://dev.azure.com/msazure/One/_wiki/wikis/AzureStackHCIWiki/453034/TSG-OutOfPolicy-Error-Resolution">TSG | OutOfPolicy Error Resolution</a>
  </p>
</div>

---

# Resolution

## Identify Your Scenario

Before proceeding, determine which scenario applies to your cluster:

```powershell
# Check if Cloud Management cluster group exists
Get-ClusterGroup | ? Name -like "*Cloud*" | ft Name, State, OwnerNode

# Check if Cloud Management service exists on nodes
Invoke-Command (Get-ClusterNode) {Get-Service HciCloudManagementSvc -ErrorAction SilentlyContinue}
```

<div style="border: 1px solid #007bff; background-color: #e6f3ff; padding: 10px; margin: 10px 0; border-radius: 6px;">
  <h4 style="color: #007bff; margin: 0 0 8px; font-size: 1em;">🔍 Decision Logic</h4>
  <table style="width:100%; border-collapse: collapse; font-size: 0.9em; margin-bottom: 8px;">
    <thead>
      <tr>
        <th style="text-align:left; padding:4px 8px; border-bottom:2px solid #007bff; width: 30%;">Diagnostic Result</th>
        <th style="text-align:left; padding:4px 8px; border-bottom:2px solid #007bff;">Scenario</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td style="padding:4px 8px; vertical-align:top;"><strong>Cluster group NOT found</strong></td>
        <td style="padding:4px 8px;">→ <strong>Scenario A</strong>: Cloud Management group completely missing</td>
      </tr>
      <tr>
        <td style="padding:4px 8px; vertical-align:top;"><strong>Cluster group exists but State = Failed</strong></td>
        <td style="padding:4px 8px;">→ <strong>Scenario B</strong>: Cloud Management group fails to start</td>
      </tr>
    </tbody>
  </table>
</div>

---

## Scenario A: Cloud Management Group Completely Missing

This scenario occurs when the Cloud Management cluster group does not exist after upgrade, typically in 22H2 → Azure Local upgrades.

### Step 1: Check and Repair ClusterMSI Authentication

Before creating the cluster group, verify if your cluster is using ClusterMSI for authentication. Older registrations might not have this configured properly.

**To verify ClusterMSI configuration:**

1. Navigate to your cluster resource in the **Azure Portal**
2. Open the **JSON view** of the cluster resource
3. Look for the `identity` section with `type: SystemAssigned` indicating ClusterMSI is configured

**Alternatively**, you can simply run the repair registration command, which will add ClusterMSI if it's missing:

```powershell
Register-AzStackHCI -SubscriptionId <SubscriptionId> -TenantId <TenantId> -Region <region> -RepairRegistration
```

<div style="border: 2px solid #007bff; background-color: #e6f3ff; padding: 15px; margin: 20px 0; border-radius: 8px;">
  <strong>📘 Note:</strong> Running repair registration is safe and idempotent - it will add missing configuration without disrupting existing settings.
</div>

### Step 2: Create Cloud Management Cluster Group

After ensuring proper ClusterMSI configuration, run the `CreateCloudManagementClusterGroup` PowerShell function to set up the required cluster group.

**Establish a PSSession to a cluster node:**

```powershell
$session = New-PSSession -ComputerName <ClusterNodeName>
```

**Run the CreateCloudManagementClusterGroup function:**

```powershell
Function CreateCloudManagementClusterGroup {
    param(
        $clusterNodeSession
    )

    $cloudManagementServiceName = "HciCloudManagementSvc"
    $clusterGroupName = "Cloud Management"

    Write-Host ("Using Cloud Management Service Name: $($cloudManagementServiceName)")
    $service = Invoke-Command -Session $clusterNodeSession -ScriptBlock { Get-Service -Name $using:cloudManagementServiceName -ErrorAction Ignore }
    Write-Host "$('$service'): $($service)"

    $serviceError = $null
    if ($null -eq $service)
    {
        $serviceError = "{0} service doesn't exist." -f $cloudManagementServiceName
        Write-Error $serviceError
    }
    else
    {
        $displayName = $service.DisplayName
        Write-Host ("Found Cloud Management Agent: $displayName")

        $group = Invoke-Command -Session $clusterNodeSession -ScriptBlock { Get-ClusterGroup -Name $using:clusterGroupName -ErrorAction Ignore }
        if ($null -eq $group)
        {
            Write-Host ("Creating Cloud Management cluster group: $clusterGroupName")
            $group = Invoke-Command -Session $clusterNodeSession -ScriptBlock { Add-ClusterGroup -Name $using:clusterGroupName -ErrorAction Ignore }
        }

        if ($null -ne $group)
        {
            Write-Host ("Cloud Management cluster group: $($group | Format-List | Out-String)")

            $svcResourcesToRemove = Invoke-Command -Session $clusterNodeSession -ScriptBlock { Get-ClusterGroup -Name $using:clusterGroupName | Get-ClusterResource -ErrorAction Ignore | ? {$_.Name -ne $using:displayName} }
            if($null -ne $svcResourcesToRemove){
                Write-Host ("Removing unnecessary cluster resources: $($svcResourcesToRemove | Format-List | Out-String)")
                Invoke-Command -Session $clusterNodeSession -ScriptBlock { Remove-ClusterResource -Name $using:svcResourcesToRemove.Name -ErrorAction Ignore -Force}
            }

            $svcResource = Invoke-Command -Session $clusterNodeSession -ScriptBlock { Get-ClusterGroup -Name $using:clusterGroupName | Get-ClusterResource -ErrorAction Ignore | ? {$_.Name -eq $using:displayName} }
            if ($null -eq $svcResource)
            {
                Write-Host ("Creating cluster resource for Cloud Management agent")
                $svcResource = Invoke-Command -Session $clusterNodeSession -ScriptBlock { Add-ClusterResource -Name $using:displayName -ResourceType "Generic Service" -Group $using:clusterGroupName -ErrorAction Ignore }
            }

            if ($null -ne $svcResource)
            {
                Write-Host ("Cloud Management cluster resource: $($svcResource | Format-List | Out-String)")
                Write-Host ("Setting cluster resource parameter ServiceName = $cloudManagementServiceName")
                Invoke-Command -Session $clusterNodeSession -ScriptBlock { Get-ClusterGroup -Name $using:clusterGroupName | Get-ClusterResource -ErrorAction Ignore | ? {$_.Name -eq $using:displayName} | Set-ClusterParameter -Name ServiceName -Value $using:cloudManagementServiceName -ErrorAction Ignore}
                $group = Invoke-Command -Session $clusterNodeSession -ScriptBlock { Get-ClusterGroup -Name $using:clusterGroupName -ErrorAction Ignore }
            }
            else
            {
                $serviceError = "Failed to create cluster resource {0} in group {1}." -f $cloudManagementServiceName, $clusterGroupName
                Write-Error -Message $serviceError -ErrorAction Continue
            }
        }
        else
        {
            $serviceError = "Failed to create cluster group {0}." -f $clusterGroupName
            Write-Error -Message $serviceError -ErrorAction Continue
        }

        if ($null -ne $group -and $group.State -ne "Online")
        {
            Write-Host ("Cloud Management cluster resource: $($svcResource | Format-List |Out-String)")
            Write-Host ("Starting Cluster Group $clusterGroupName")
            $group = Invoke-Command -Session $clusterNodeSession -ScriptBlock { Start-ClusterGroup -Name $using:clusterGroupName -Wait 120 -ErrorAction Ignore }
            if ($group.State -ne "Online")
            {
                $serviceError = "Failed to start {0} clustered role." -f $clusterGroupName
                Write-Error -Message $serviceError -ErrorAction Continue
            }
        }
    }

    Write-Host ("Cloud Management group: $($group | Format-List | Out-String)")
    Write-Host ("Cloud Management resource: $($svcResource | Format-List | Out-String)")
    Write-Host ("Cloud Management agent setup complete")
    Write-Host ("Add Cluster Extension")

    Add-ClusterExtension -Path C:\Windows\system32\azshci\cloudmanagement\ClusterExtension.Updates.xml
    Get-ClusterExtension

    Invoke-Command -Session $clusterNodeSession -ScriptBlock { Sync-AzureStackHCI -ErrorAction Ignore}
}

# Execute the function
CreateCloudManagementClusterGroup -clusterNodeSession $session
```

### What the Function Does

The `CreateCloudManagementClusterGroup` function performs the following operations:

1. Verifies the HciCloudManagementSvc service exists
2. Creates the Cloud Management cluster group if missing
3. Removes any unnecessary cluster resources
4. Creates and configures the cluster resource for the Cloud Management agent
5. Sets the ServiceName parameter on the cluster resource
6. Starts the cluster group and brings it online
7. Adds required cluster extensions for updates and core functionality
8. Syncs the cluster to Azure

### Verification

After running the function, verify the resolution:

```powershell
# Check Cloud Management cluster group and resource status
Get-ClusterGroup "Cloud Management" | Get-ClusterResource | ft Name, State, OwnerNode

# Verify cluster registration still shows Connected
Get-AzureStackHCI | Select ConnectionStatus, RegistrationStatus

# Confirm cluster extensions are properly installed
Get-ClusterExtension
```

**Expected Result:** Cloud Management cluster group shows **Online** and remains stable.

---

## Scenario B: Cloud Management Group Exists But Fails to Start

This scenario occurs when the Cloud Management cluster group exists but repeatedly fails to come online. The cluster shows as registered and connected to Azure, but the Cloud Management service cannot start due to missing MSI configuration from the original registration.

### Repair Registration to Enable Cloud Management

```powershell
# Step 1: Verify prerequisites - all nodes connected and NOT OutOfPolicy
Invoke-Command (Get-ClusterNode) {Get-AzureStackHCI} | ft PSComputerName, ConnectionStatus, RegistrationStatus

# Step 2: Repair registration to add Cloud Management support and MSI
Repair-AzureStackHCIRegistration

# Step 3: Start the Cloud Management cluster group
Start-ClusterGroup "Cloud Management"

# Step 4: Verify Cloud Management is online
Get-ClusterGroup "Cloud Management" | Get-ClusterResource | ft Name, State, OwnerNode

# Expected: Azure Stack HCI Cloud Management showing State = Online
```

### What Repair-AzureStackHCIRegistration Does

The repair registration process:

- Adds necessary resource properties for Cloud Management support
- Enables MSI (Managed Service Identity) configuration on the cluster registration
- Updates cluster resource to support new platform features introduced after the original registration

---

# Details

## Identifying Your Scenario

### Scenario A: Cloud Management Group Completely Missing

**Symptoms:**
- Cloud Management features not working (alerts, updates, monitoring)
- Cluster updates not syncing to Azure portal
- Alerts extension not syncing
- `Get-ClusterGroup | ? Name -like "*Cloud*"` returns no results
- HciCloudManagementSvc service may be missing on some nodes

**Common After:**
- Upgrade from 22H2 → Azure Local
- Clusters registered with 22H2 and early 23H2 versions

### Scenario B: Cloud Management Group Fails to Start

**Symptoms:**
- Cluster shows `ConnectionStatus: Connected` and `RegistrationStatus: Registered`
- Cloud Management cluster group in **Failed** state or constantly attempting to come online
- Cluster was originally registered before 2024 (check `RegistrationDate` in `Get-AzureStackHCI`)
- Recent upgrade from 22H2

**Event Log Patterns:**

Key events in the **System** event log indicating this issue:

<div style="border: 1px solid #dcdcdc; padding: 10px; margin-bottom: 10px; border-radius: 5px;">
  <p><strong>🟥 Error Event ID 1254</strong></p>
  <p>Clustered role 'Cloud Management' has exceeded its failover threshold. It has exhausted the configured number of failover attempts within the failover period of time allotted to it and will be left in a failed state.</p>
</div>

<div style="border: 1px solid #dcdcdc; padding: 10px; margin-bottom: 10px; border-radius: 5px;">
  <p><strong>🟥 Error Event ID 1205</strong></p>
  <p>The Cluster service failed to bring clustered role 'Cloud Management' completely online or offline. One or more resources may be in a failed state.</p>
</div>

<div style="border: 1px solid #dcdcdc; padding: 10px; margin-bottom: 10px; border-radius: 5px;">
  <p><strong>🟥 Error Event ID 1069</strong></p>
  <p>Cluster resource 'Azure Stack HCI Cloud Management' of type 'Generic Service' in clustered role 'Cloud Management' failed.</p>
</div>

## Diagnostic Commands

```powershell
# Check cluster group status
Get-ClusterGroup | ? Name -like "*Cloud*" | Get-ClusterResource | ft Name, State, OwnerNode, ResourceType

# Check if Cloud Management service exists on all nodes
Invoke-Command (Get-ClusterNode) {Get-Service HciCloudManagementSvc -ErrorAction SilentlyContinue}

# Check recent failover cluster events related to Cloud Management
Get-WinEvent -LogName System -MaxEvents 100 | 
    ? {$_.ProviderName -eq "Microsoft-Windows-FailoverClustering" -and $_.Message -like "*Cloud Management*"} | 
    ft TimeCreated, Id, LevelDisplayName, Message -Wrap

# Check registration date to confirm cluster age
Get-AzureStackHCI | Select RegistrationDate, ConnectionStatus, RegistrationStatus
```

<div style="border: 2px solid #007bff; background-color: #e6f3ff; padding: 15px; margin: 20px 0; border-radius: 8px;">
  <strong>📘 Note:</strong> Clusters registered before Cloud Management became a platform requirement will need registration repair after upgrading from 22H2. This is expected behavior for clusters registered before mid-2023 to early 2024.
</div>

## Additional Troubleshooting

### Cloud Management Service Not Installed

If the **Cloud Management service (HciCloudManagementSvc)** is not installed on the cluster nodes at all:

```powershell
# Check if Cloud Management service exists on all nodes
Invoke-Command (Get-ClusterNode) {Get-Service HciCloudManagementSvc -ErrorAction SilentlyContinue}
```

<div style="border: 1px dashed #007bff; background-color: #f0f8ff; padding: 12px; margin: 20px 0; border-radius: 6px;">
  <h3 style="color: #0056b3; margin: 0 0 6px; font-size: 1em;">🔧 Service Missing Scenario</h3>
  <p style="margin: 0; font-size: 0.9em;">
    If the service does not exist, this TSG does not apply. The cluster may have an incomplete upgrade or missing components. Investigate upgrade logs and consider contacting support.
  </p>
</div>

---

## Final Verification

After completing either scenario resolution, verify success:

```powershell
# Verify Cloud Management cluster group is online
Get-ClusterGroup "Cloud Management" | ft Name, State, OwnerNode

# Verify cluster resources in the group
Get-ClusterGroup "Cloud Management" | Get-ClusterResource | ft Name, State, OwnerNode

# Verify registration status remains healthy
Get-AzureStackHCI | Select ConnectionStatus, RegistrationStatus

# Wait 15 minutes, then verify cluster sync to Azure
Sync-AzureStackHCI
```

**Success Criteria:**
- Cloud Management cluster group shows **State = Online**
- Group remains stable without failover attempts
- Cluster registration shows **ConnectionStatus = Connected**
- After 15 minutes, updates and alerts begin syncing to Azure portal
