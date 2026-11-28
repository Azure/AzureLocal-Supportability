This issue occurs if the cluster is configured with Network ATC prior to performing the 22H2 to 23H2 OS upgrade.  The issue is that once a node is upgraded to 23H2, the management virtual network interface card (vNIC) is renamed back to the default ‘vEthernet’ name in the output of `Get-NetAdapter`.  Note this does NOT change the name under `Get-VMNetworkAdapter -ManagementOS`.  Functionally, this does not cause an issue.  But it does cause the management intent to fail with an error ‘PhysicalAdapterNotFound’ which you can see using `Get-NetIntentStatus`.  Network ATC expects both outputs (`Get-NetAdapter` and `Get-VMNetworkAdapter -ManagementOS`) to have the same vNIC name.

# Symptoms
The Network ATC management intent fails with error ‘PhysicalAdapterNotFound’ after upgrading OS from 22H2 to 23H2.

# Issue Validation
Run `Get-NetAdapter` from the node that was upgraded to 23H2.  The adapter will be named `vEthernet (ConvergedSwitch(IntentName))` which is **NOT** the name Network ATC is expecting for this adapter.  

Run `Get-VMNetworkAdapter -ManagementOS`.  The adapter will be named `vManagement(IntentName)` which **IS** the name Network ATC is expecting for this adapter.

# Cause
This is a known issue when installing the feature update for Azure Local version 23H2.

# Mitigation Details
To fix this issue, rename the management vNIC back to the name expected by Network ATC using the steps below on each host:

1. If you ONLY have a management vNIC, you can use this command:

   ```
   Get-NetAdapter | Where-Object {$_.Name -IMatch "vEthernet"} | Rename-NetAdapter -NewName (Get-VMNetworkAdapter -ManagementOS).Name
   ```

1. If you have multiple vNICs, you can get the correct name of the vNIC using `Get-VMNetworkAdapter -ManagementOS` then using `Rename-NetAdapter` command.

   Example:
   
   ```PowerShell
   PS C:\> Get-NetIntentStatus -Name mgmtcompute #This command shows the intents in a failed state.


   IntentName            : mgmtcompute
   Host                  : hcihost01
   IsComputeIntentSet    : True
   IsManagementIntentSet : True
   IsStorageIntentSet    : False
   IsStretchIntentSet    : False
   LastUpdated           : 09/13/2024 11:20:44
   LastSuccess           : 09/13/2024 03:26:18
   RetryCount            : 3
   LastConfigApplied     : 1
   Error                 : PhysicalAdapterNotFound
   Progress              : 1 of 1
   ConfigurationStatus   : Failed
   ProvisioningStatus    : Completed

   IntentName            : mgmtcompute
   Host                  : hcihost02
   IsComputeIntentSet    : True
   IsManagementIntentSet : True
   IsStorageIntentSet    : False
   IsStretchIntentSet    : False
   LastUpdated           : 09/13/2024 11:18:29
   LastSuccess           : 09/13/2024 04:09:24
   RetryCount            : 3
   LastConfigApplied     : 1
   Error                 : PhysicalAdapterNotFound
   Progress              : 1 of 1
   ConfigurationStatus   : Failed
   ProvisioningStatus    : Completed

   PS C:\> Get-NetAdapter | ft -AutoSize #This command shows the incorrect name for the Hyper-V Virtual Ethernet Adapter.

   Name                                     InterfaceDescription                                                                    ifIndex Status       MacAddress         LinkSpeed
   ----                                     --------------------                                                                    ------- ------       ----------         ---------
   vEthernet (ConvergedSwitch(mgmtcompute)) Hyper-V Virtual Ethernet Adapter                                                             14 Up           02-00-00-00-00-5E    10 Gbps
   Storage1                                 QLogic FastLinQ QL41262-DE 25GbE Adapter (VBD Client)                                        13 Up           02-00-00-00-01-AE    25 Gbps
   Mgmt_Compute2                            Broadcom NetXtreme E-Series Advanc...#2                                                       9 Up           02-00-00-00-00-5F    10 Gbps
   Ethernet                                 Remote NDIS Compatible Device #2                                                             36 Up           02-00-00-00-02-6F 426.0 Mbps
   Storage2                                 QLogic FastLinQ QL41262-DE 25GbE A...#2                                                       8 Up           02-00-00-00-01-AF    25 Gbps
   NIC4                                     Broadcom NetXtreme Gigabit Ethernet                                                           7 Disconnected 02-00-00-00-00-5D      0 bps
   NIC3                                     Broadcom NetXtreme Gigabit Ethernet #2                                                        6 Disconnected 02-00-00-00-00-5C      0 bps
   Mgmt_Compute1                            Broadcom NetXtreme E-Series Advanced Dual-port 10Gb SFP+ Ethernet Network Daughter Card       3 Up           02-00-00-00-00-5E    10 Gbps
   
   PS C:\> Get-VMNetworkAdapter -ManagementOS #This command shows the correct name that BOTH NICs need to have.

   Name                     IsManagementOs VMName SwitchName                   MacAddress   Status IPAddresses
   ----                     -------------- ------ ----------                   ----------   ------ -----------
   vManagement(mgmtcompute) True                  ConvergedSwitch(mgmtcompute) 02000000005E {Ok} 

   PS C:\> Rename-NetAdapter -Name “vEthernet (ConvergedSwitch(mgmtcompute))” -NewName “vManagement(mgmtcompute)” #This command renames the adapter to the correct name.

   PS C:\> Get-NetAdapter #This command now shows the correct name for the Hyper-V Virtual Ethernet Adapter.

   Name                      InterfaceDescription                    ifIndex Status       MacAddress             LinkSpeed
   ----                      --------------------                    ------- ------       ----------             ---------
   vManagement(mgmtcompute)  Hyper-V Virtual Ethernet Adapter             14 Up           02-00-00-00-00-5E        10 Gbps
   Storage1                  QLogic FastLinQ QL41262-DE 25GbE Ada...      13 Up           02-00-00-00-01-AE        25 Gbps
   Mgmt_Compute2             Broadcom NetXtreme E-Series Advanc...#2       9 Up           02-00-00-00-00-5F        10 Gbps
   Ethernet                  Remote NDIS Compatible Device #2             36 Up           02-00-00-00-02-6F     426.0 Mbps
   Storage2                  QLogic FastLinQ QL41262-DE 25GbE A...#2       8 Up           02-00-00-00-01-AF        25 Gbps
   NIC4                      Broadcom NetXtreme Gigabit Ethernet           7 Disconnected 02-00-00-00-00-5D          0 bps
   NIC3                      Broadcom NetXtreme Gigabit Ethernet #2        6 Disconnected 02-00-00-00-00-5C          0 bps
   Mgmt_Compute1             Broadcom NetXtreme E-Series Advanced...       3 Up           02-00-00-00-00-5E        10 Gbps
   ```

1. Once the adapter has been renamed, force Network ATC to retry the failed intent.  Note that you must specify a `NodeName` in this command, so you must run it for each node where the intent needs to be retried.

   ```
   PS C:\> Set-NetIntentRetryState -Name mgmtcompute -NodeName hcihost01 #These commands retry the intent on each node.
   -- Successfully reset Intent retry state for 'mgmtcompute'

   PS C:\> Set-NetIntentRetryState -Name mgmtcompute -NodeName hcihost02
   -- Successfully reset Intent retry state for 'mgmtcompute'

   PS C:\> Get-NetIntentStatus -Name mgmtcompute #This command shows that the intents are now successfully applied.


   IntentName            : mgmtcompute
   Host                  : hcihost01
   IsComputeIntentSet    : True
   IsManagementIntentSet : True
   IsStorageIntentSet    : False
   IsStretchIntentSet    : False
   LastUpdated           : 09/13/2024 11:45:22
   LastSuccess           : 09/13/2024 11:45:22
   RetryCount            : 0
   LastConfigApplied     : 1
   Error                 :
   Progress              : 1 of 1
   ConfigurationStatus   : Success
   ProvisioningStatus    : Completed

   IntentName            : mgmtcompute
   Host                  : hcihost02
   IsComputeIntentSet    : True
   IsManagementIntentSet : True
   IsStorageIntentSet    : False
   IsStretchIntentSet    : False
   LastUpdated           : 09/13/2024 11:45:36
   LastSuccess           : 09/13/2024 11:45:36
   RetryCount            : 0
   LastConfigApplied     : 1
   Error                 :
   Progress              : 1 of 1
   ConfigurationStatus   : Success
   ProvisioningStatus    : Completed
   ```
