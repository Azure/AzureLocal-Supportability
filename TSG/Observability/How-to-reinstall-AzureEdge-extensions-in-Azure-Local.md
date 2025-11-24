This article describes the proper steps to reinstall extensions in Azure Local 23H2 and later.

# Overview
Extensions are initially installed as part of the deployment workflow and should not be manually installed prior. However, there are times when extensions may fail or reinstalling the extension post-deployment may be required. In these scenarios, the use of the AzConnectedMachineExtension cmdlets is now discouraged. Instead, use the automated remediation steps to ensure the correct extension versions are installed.

# Affected extensions
The following extensions are included in this process.

- AzureEdgeRemoteSupport
- AzureEdgeTelemetryAndDiagnostics
- AzureEdgeDeviceManagement
- AzureEdgeLifecycleManager

> :ledger: **NOTE**
>
> Extensions that are not listed here are not reinstalled using this method.  Please consult the documentation for the extension for information on troubleshooting or reinstalling the extension.

# Reinstalling extensions using the automated remediation
To correctly reinstall any of the extensions listed above to an Azure Local node, follow the steps below.

1. From within the Azure portal, navigate to the node with the failed extension.  
   a. Expand 'Settings' in the left menu column and select 'Locks'.  Make a note of any locks present (as you should recreate them after).  Delete any locks present on the node as these will prevent deleting a failed extension.
   b. Select 'Extensions'.  Uninstall or delete the failed extension or extension that needs to be reinstalled.
1. Once the extension has been removed, log onto any cluster node and execute the command `Sync-AzureStackHCI`.  When the cluster connects to Azure, an automated workflow will kick off that will check the versions of the extensions on the cluster nodes.  Any extensions that are not installed or installed with incorrect versions will be remediated so the correct version is installed.  
1. If any locks were removed, recreate the lock by clicking "Add", entering the name for the lock, setting the "Lock type" to "Delete", and clicking "OK".

Note that not all failed extension issues will be fixed using these steps.  If an extension is reinstalled and continues to fail, further investigation will be required to understand the cause of the failure.  For this, you may need to open a support request.