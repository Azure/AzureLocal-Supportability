Azure Local Update Failed when updating from earlier preview versions (Local Identity Deployment, or ADLess Deployment) to 2601 with Error: "Access is denied"

#Symptoms
An Update action plan fails with an AgentLifecycleManager error message "Access is denied" during update action plan.
```
Connecting to remote server v-Host1 failed with the following error message : Access is denied. For more information, see the about_Remote_Troubleshooting Help topic.  
at New-AgentUpdateTriggerOnNode, C:\NugetStore\Microsoft.AzureStack.Infrastructure.Orchestration.AgentLifecycleManagerRole.1.25.0.2114\content\Powershell\Roles\AgentLifecycleManager\AgentLifecycleManagerUtils.psm1: line 345  
at Update, C:\NugetStore\Microsoft.AzureStack.Infrastructure.Orchestration.AgentLifecycleManagerRole.1.25.0.2114\content\Powershell\Classes\AgentLifecycleManager\AgentLifecycleManager.psm1: line 505  
at UpdateRuntimeAgents, C:\NugetStore\Microsoft.AzureStack.Infrastructure.Orchestration.AgentLifecycleManagerRole.1.25.0.2114\content\Powershell\Classes\AgentLifecycleManager\AgentLifecycleManager.psm1: line 158  
at , C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2510.0.1134\content\ECEWinService\InvokeInterfaceInternal.psm1: line 165  
at Invoke-EceInterfaceInternal, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2510.0.1134\content\ECEWinService\InvokeInterfaceInternal.psm1: line 160  
at , : line 50
```
#Cause
User provided local admin credentials are removed in ECE Store to avoid the situation needing to keep stored credential in-sync, given this is a customer owned local admin account. The update process has a step still trying to access this credential from the ECE Store instead of the input parameters from the update process with local admin credentials for day-N operations.

#Mitigation
This issue is addressed in 2602, if customers can wait and update from earlier version to 2602+. This issue will be resolved.

If customer already started the update to 2601 and would like to complete the update, follow the following steps to add the local admin credential into the ECE Service Secret store after the update failed. After the credential update, the update can be resumed.  This credential should be an active local user credential in "Administrators" Group for every node in the cluster.

First check where the Orchestrator Service is and move it to the node you currently login. If you are already on the same node running the service, skip this step.
```
Get-ClusterGroup -Name "Azure Stack HCI Orchestrator Service Cluster Group"
Get-ClusterGroup -Name "Azure Stack HCI Orchestrator Service Cluster Group" | Move-ClusterGroup -Name <Hostname of your current node>
```

This is the command to update the credential and then move the cluster again to refresh the store:
```
Set-ECEServiceSecret -ContainerName DomainAdmin -Credential (get-Credential)
Get-ClusterGroup -Name "Azure Stack HCI Orchestrator Service Cluster Group" | Move-ClusterGroup
```

Once the credential update completed, the update can be resumed from Azure portal (or manually on the node with the following command).
```
Get-SolutionUpdate | where State -eq InstallationFailed | Start-SolutionUpdate
```
