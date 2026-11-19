The issue is during solution upgrade, the step to clean up deployment package on other node is failing due to module missing. This TSG will explain how to mitigate the issue and resume upgrade.
# Symptoms
This exception message will be thrown during Solution upgrade and can be seen from the Portal. 

**Exception**:

`Type 'CleanUpDeploymentPackageAndNugetStoreOnNonSeedNodes' of Role 'BareMetal' raised an exception: The specified module 'CloudCommon' was not loaded because no valid module file was found in any module directory. at CleanUpDeploymentPackageAndNugetStoreOnNonSeedNodes, C:\CloudDeployment\Classes\BareMetal\BareMetal.psm1: line 557 at <ScriptBlock>, C:\CloudDeployment\ECEngine\InvokeInterfaceInternal.psm1: line 139 at Invoke-EceInterfaceInternal, C:\CloudDeployment\ECEngine\InvokeInterfaceInternal.psm1: line 134 at <ScriptBlock>, <No file>: line 33`

# Issue Validation

Azure Local Solution Upgrade fails with the above exception message.
Verify if the CloudCommon folder exists in C:\Program Files\WindowsPowerShell\Modules\ on non-seed nodes. If it does not exist, apply the below the mitigation. Seed node is typically the first node in the cluster.

# Cause
We have a change in LCM Extension that does not bootstrap the deployment package on each node anymore. Due to this, the cloudcommon module only exist in seednode (first node in the cluster) and does not exist on non-seednode.  

# Mitigation Details

**Manually copy the file**

- Manually copy the C:\Program Files\WindowsPowerShell\Modules\CloudCommon folder from seed node (first node in the cluster that has the CloudCommon folder) to all other nodes in the cluster to C:\Program Files\WindowsPowerShell\Modules\
- Run ```Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\CloudCommon" -Recurse | Unblock-File```

**Resume Solution Upgrade**

- Click resume Solution upgrade through Azure Portal.
