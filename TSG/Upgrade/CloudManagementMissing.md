# Troubleshooting: Missing Cloud Management Cluster Group in Azure Local

## Issue
After upgrade in Azure Local from 22H2, if the Cloud Management cluster group is missing, certain cloud management features may not work properly. This typically occurs when the "cluster agent" service is missing or the cluster registration is using an older version.

## Symptoms
- Cloud Management features are not working as expected
- Cluster Updates are not syncing to the cloud therefore not showing up on the portal
- Alerts extension not syncing alerts
- The "cluster agent" service is missing
- Cloud Management cluster group is not present in the cluster

## Cause
This issue can occur in the following scenarios:
1. The cluster was registered using one of the earlier versions of 22H2
2. The cluster agent service was not properly initialized
3. An upgrade from 22H2 didn't properly configure the Cloud Management components

## Solution

### Step 1: Check Cluster MSI Authentication
Before proceeding with the cluster group creation, it's important to verify if your cluster is using ClusterMSI for authentication, as older registrations might not have this configured properly.

1. Open a PsExec window with system privileges:
```powershell
PsExec.exe -i -s powershell.exe
```

2. Check the registration context information to verify if ClusterMSI is configured by running these commands:
```powershell
$splitFormat = @('_#_')
$fullContext = [System.Text.Encoding]::Unicode.GetString((Get-ItemProperty "registry::HKEY_LOCAL_MACHINE\Cluster\5bc0980c-5c04-4771-887c-ab6e676fd92e").'3a778d3c-2f6b-4105-aac3-2def5dfcb987')
$context = $fullContext.Split($splitFormat, [System.StringSplitOptions]::None)[1]
$context | ConvertFrom-Json
```

3. Look for the ClusterMSI parameter in the output. If it's not present, you need to repair the registration using:
```powershell
Register-AzStackHCI -SubscriptionId <SubscriptionId> -TenantId <TenantId> -region <region> -verbose –RepairRegistration
```

### Step 2: Create Cloud Management Cluster Group
After ensuring proper ClusterMSI configuration, run the `CreateCloudManagementClusterGroup` PowerShell function to set up the required cluster group. Here is the complete implementation:

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

            $svcResourcesToRemove = Invoke-Command -Session $clusterNodeSession -ScriptBlock { Get-ClusterGroup -Name $using:clusterGroupName | Get-ClusterResource -ErrorAction Ignore | Where-Object {$_.Name -ne $using:displayName} }
            if($null -ne $svcResourcesToRemove){
                Write-Host ("Removing unnecessary cluster resources: $($svcResourcesToRemove | Format-List | Out-String)")
                Invoke-Command -Session $clusterNodeSession -ScriptBlock { Remove-ClusterResource -Name $using:svcResourcesToRemove.Name -ErrorAction Ignore -Force}
            }

            $svcResource = Invoke-Command -Session $clusterNodeSession -ScriptBlock { Get-ClusterGroup -Name $using:clusterGroupName | Get-ClusterResource -ErrorAction Ignore | Where-Object {$_.Name -eq $using:displayName} }
            if ($null -eq $svcResource)
            {
                Write-Host ("Creating cluster resource for Cloud Management agent")
                $svcResource = Invoke-Command -Session $clusterNodeSession -ScriptBlock { Add-ClusterResource -Name $using:displayName -ResourceType "Generic Service" -Group $using:clusterGroupName -ErrorAction Ignore }
            }

            if ($null -ne $svcResource)
            {
                Write-Host ("Cloud Management cluster resource: $($svcResource | Format-List | Out-String)")
                Write-Host ("Setting cluster resource parameter ServiceName = $cloudManagementServiceName")
                Invoke-Command -Session $clusterNodeSession -ScriptBlock { Get-ClusterGroup -Name $using:clusterGroupName | Get-ClusterResource -ErrorAction Ignore | Where-Object {$_.Name -eq $using:displayName} | Set-ClusterParameter -Name ServiceName -Value $using:cloudManagementServiceName -ErrorAction Ignore}
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
```

### Function Overview
The CreateCloudManagementClusterGroup function performs the following operations:
1. Checks for the existence of the HciCloudManagementSvc service
2. Creates a Cloud Management cluster group if it doesn't exist
3. Removes any unnecessary cluster resources
4. Creates and configures the cluster resource for the Cloud Management agent
5. Ensures the cluster group is online
6. Adds required cluster extensions

### Prerequisites
- Active cluster connection
- Valid cluster node session

## Usage
To use the function:

1. First, establish a PSSession to a cluster node:
```powershell
$session = New-PSSession -ComputerName <ClusterNodeName>
```

2. Then run the function:
```powershell
CreateCloudManagementClusterGroup -clusterNodeSession $session
```

## Verification
After running the solution, verify the fix by:

1. Checking if the Cloud Management cluster group exists and is online:
```powershell
Get-ClusterGroup -Name "Cloud Management"
```

2. Verifying the cluster agent service is running:
```powershell
Get-Service -Name "HciCloudManagementSvc"
```

3. Confirming cluster extensions are properly installed (you should see at least CoreExtension and UpdatesExtension):
```powershell
Get-ClusterExtension
```

## Additional Notes
- If you encounter any errors, check the detailed error messages in the function output
- Ensure all nodes in the cluster are running and healthy before executing the function
- The function includes error handling and will report specific failures
- After completion, the cluster will automatically sync to cloud within 15 minutes
