# Symptoms
After upgrading the Azure Local OS from 22H2 to 23H2 and prior to installing the solution update, customers will see that they are unable to manage their OS updates from either Windows Admin Center (WAC) or the Azure portal.

# Issue Validation
In WAC, customers that attempt to update their clusters via the 'Updates' page will be presented a message stating, **"To update the OS of this version of Azure Local, use the Azure portal."**

But when customers go to the Azure portal, navigate to the cluster, then select 'Operations' and 'Updates' from the left column, they will see a message stating **"Only systems that have the Azure Local, version 23H2 OS can be managed here."**

# Cause
Windows Admin Center blocks updates to any node or cluster running Azure Local version 23H2 by-design.  This is because WAC does not have the ability to determine if the cluster does or does not have the solution update installed.

However, only Azure Local version 23H2 clusters that have the solution update installed can be managed via Azure Update Manager in the portal.  

# Mitigation Details
Customers should use PowerShell to invoke cluster-aware updating (CAU) to scan and update the cluster.

To check for available updates, customers can use the following PowerShell commands, updating the `ClusterName` parameter with the appropriate cluster name.

```PowerShell
$parameters = @{
    ClusterName = 'hci-cluster'
    CauPluginName = 'Microsoft.WindowsUpdatePlugin'
    CauPluginArguments = @{'IncludeRecommendedUpdates'='True'}
}
Invoke-CauScan @parameters
```

To install the available updates, customers can use the following PowerShell commands, updating the `ClusterName` parameter with the appropriate cluster name.

```PowerShell
$parameters = @{
    ClusterName = 'hci-cluster'
    CauPluginName = 'Microsoft.WindowsUpdatePlugin'
    CauPluginArguments = @{'IncludeRecommendedUpdates'='True'}
    MaxFailedNodes = '1'
    MaxRetriesPerNode = '3'
    RequireAllNodesOnline = $true
    Force = $true
}
Invoke-CauRun @parameters
```

> :ledger: **NOTE**
>
> There are additional options available when running CAU from PowerShell that are not mentioned here.  These commands are sufficient to scan and install the updates, but customers can review the available options and make changes as they desire.
