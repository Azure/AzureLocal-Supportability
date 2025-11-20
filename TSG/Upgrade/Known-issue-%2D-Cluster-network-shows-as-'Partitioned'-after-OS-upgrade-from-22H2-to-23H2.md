# Symptoms
After upgrading the Azure Local OS from 22H2 to 23H2, customers may notice a 'Partitioned' network in their environment.

> :ledger: **NOTE**
>
> There are scenarios where networks may show as 'Partitioned' that do not match this scenario where this TSG does not apply and should not be used.  There are also scenarios where the issue described in this article is known to occur outside of the OS upgrade where the mitigation steps in this TSG can be used.  Please evaluate your scenario accordingly, and if you are unsure if these steps apply, please open a support request.  

# Issue Validation
Run `Get-ClusterNetwork` from one of the nodes and view the output.  You may see a network as 'Partitioned'.  

Example:

```
PS C:\> Get-ClusterNetwork

Name                           State Metric             Role
----                           ----- ------             ----
Cluster Network 1        Partitioned  40000          Cluster
storage(Storage_VLAN711)          Up  20401          Cluster
storage(Storage_VLAN712)          Up  20402          Cluster
Unused:Cluster Network 1          Up  70240 ClusterAndClient
```

OR

Browsing the network connections in Failover Cluster Manager, you may see a network as 'Partitioned'.

# Cause
The issue is caused by a change in the InterfaceDescription of the BMC adapter.  

The BMC adapter is excluded from the cluster by using the `ExcludeAdaptersByDescription` REG_SZ registry value.  This value is located under `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\ClusSvc\Parameters` and which is created by default.

When the OS is upgraded, the InterfaceDescription changes appending `#2` to the end of the description string.  This causes the value expected by the registry to no longer match and further causes the cluster to now include the network as a cluster network.  

Example:

```PowerShell
PS C:\> Get-ClusterNetwork | Where-Object {$_.State -eq "Partitioned"} | fl * #This command shows the partitioned network.


Address           :
AddressMask       :
AutoMetric        : True
Cluster           : hcicluster
Description       :
Id                : c39b56cd-6c81-4557-bbe0-b85d17d343a6
Ipv4Addresses     : {}
Ipv4PrefixLengths : {}
Ipv6Addresses     : {fde1:53ba:e9a0:de11::}
Ipv6PrefixLengths : {64}
Metric            : 40000
Name              : Cluster Network 1
Role              : Cluster
State             : Partitioned

PS C:\> Get-ClusterNetwork | Where-Object {$_.State -eq "Partitioned"} | Get-ClusterNetworkInterface | fl * #This command shows the adapter name that is associated with the partitioned network.


Adapter       : Remote NDIS Compatible Device #2
AdapterId     : 7E31A928-04DB-4BFD-86B1-9DBBA427F827
Address       :
Cluster       : hcicluster
Description   :
DhcpEnabled   : 1
Id            : fd057638-22a0-427c-9bb7-22863f345f9b
Ipv4Addresses : {}
Ipv6Addresses : {fde1:53ba:e9a0:de11:8412:5aa4:b420:9ed9}
Name          : hcihost01 - Ethernet
Network       : Cluster Network 1
Node          : hcihost01
State         : Unreachable

Adapter       : Remote NDIS Compatible Device #2
AdapterId     : 7A539A4A-1F41-4CE0-97CB-A8BA1046CE51
Address       :
Cluster       : hcicluster
Description   :
DhcpEnabled   : 1
Id            : bbe4f75a-b4c7-4138-83a3-bed4d5763ca2
Ipv4Addresses : {}
Ipv6Addresses : {fde1:53ba:e9a0:de11:4c94:1268:7602:c29b}
Name          : hcihost02 - Ethernet
Network       : Cluster Network 1
Node          : hcihost02
State         : Unreachable

PS C:\> Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Clussvc\Parameters -Name ExcludeAdaptersByDescription #This command shows the currently configured values.


ExcludeAdaptersByDescription : Remote NDIS based Device,Remote NDIS Compatible Device
PSPath                       : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Clussvc\Parameters
PSParentPath                 : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Clussvc
PSChildName                  : Parameters
PSDrive                      : HKLM
PSProvider                   : Microsoft.PowerShell.Core\Registry
```

# Mitigation Details
To resolve this issue, update the `ExcludeAdaptersByDescription` registry value to match the `InterfaceDescription` string in the output of `Get-NetAdapter`.  You can use the PowerShell commands below to append the new name to the string.  Note that these commands will need to be run on each cluster node, and a reboot of the node is required for the new value to take effect.

```PowerShell
$REGDesc = (Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Clussvc\Parameters -Name ExcludeAdaptersByDescription).ExcludeAdaptersByDescription
$NDISDesc = (Get-NetAdapter | Where-Object{$_.InterfaceDescription -imatch "NDIS"}).InterfaceDescription
New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Clussvc\Parameters -Name ExcludeAdaptersByDescription -Value $REGDesc","$NDISDesc -Force
```
> :ledger: **NOTE**
>
> There is a second scenario where the legacy IMDS adapter "AZSHCI_HOST-IMDS_DO_NOT_MODIFY" may also cause a partitioned network to appear.  If this occurs, you can use the same script above to also add this adapter to the excluded list by modifying the `imatch` value from `"NDIS"` to `"AZSHCI_HOST-IMDS"` and running it again.  This script is written to append the additional values to the existing string, so if you are seeing both issues, you would run the script twice with the appropriate description to append both values.  You can run both scripts before performing the reboot to minimize downtime.

```
#The command above will automatically provide an output confirming the new registry value.

ExcludeAdaptersByDescription : Remote NDIS based Device,Remote NDIS Compatible Device,Remote NDIS Compatible Device #2
PSPath                       : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Clussvc\Parameters
PSParentPath                 : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Clussvc
PSChildName                  : Parameters
PSDrive                      : HKLM
PSProvider                   : Microsoft.PowerShell.Core\Registry
```
