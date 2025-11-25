# AzStackHci_Network_Test_StorageAdapterIpConfiguration

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_StorageAdapterIpConfiguration</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>
      <ul style="margin:0; padding-left:1.2em;">
        <li><strong>Update</strong> with storage intent configured in the cluster</li>
      </ul>
    </td>
  </tr>
</table>

## Overview

This environment validator checks before Update that the Storage Adapters are properly configured with valid IP after Azure Local Deployment. For this requirement, **Storage Adapter** refers to the network adapters for the Storage Network Intent.

_This validator only applies to Azure Local update with a Storage Network Intent configured._

### Requirements

After Storage Network Intent configured in the cluster, each Storage Adapter on every node in the cluster must:

- Have only 1 valid IPv4 address configured on the adapter, or
- If multiple IP addresses are configured on the adapter, they must be in the same subnet

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. It might shown as a failure on the cloud health check result. Here is an example:

```json
{
  "Name": "AzStackHci_Network_Test_StorageAdapterIpConfiguration",
  "DisplayName": "Test storage adapter IP configuration on node",
  "Tags": {},
  "Title": "Test storage adapter IP configuration on node",
  "Status": "FAILURE",
  "Severity": "CRITICAL",
  "Description": "Test storage adapter IP configuration on node: should have only 1 IPv4 address configured or all IPs should be in the same subnet.",
  "Remediation": "Storage intent adapter(s) should have only 1 IPv4 address configured on each or all IPs on the same adapter should be in the same subnet.
                     You have Storage intent adapter(s) in the system: [ storage1,storage2 ]:
                     Please run below PowerShell cmdlet to check the IP configuration on all the adapter(s):
                         Get-NetIPaddress -InterfaceAlias <INTERFACE_ALIAS> -AddressFamily IPv4 -PrefixOrigin Manual
                     If you find multiple IPs on the storage adapter(s), please remove the extra IPs that you do not need.
                         Remove-NetIPAddress -InterfaceAlias <INTERFACE_ALIAS> -IPAddress <IPADDRESS> -Confirm:False",
  "TargetResourceID": "StorageAdapterIpConfiguration",
  "TargetResourceName": "StorageAdapterIpConfiguration",
  "TargetResourceType": "StorageAdapterIpConfiguration",
  "Timestamp": "/Date(1747080202442)/",
  "AdditionalData": {
    "Detail": "Storage adapter IP configuration check on AZLOC-NODE1
            Passed: Storage adapter [ storage1 ] have one and only one valid IPv4 defined on it.
            !! Expect one valid IPv4 address configured on storage adapter [ storage2 ].
            !! Please run below command to confirm:
            !!     Get-NetIPaddress -InterfaceAlias storage2 -AddressFamily IPv4 -PrefixOrigin Manual",
    "Status": "FAILURE",
    "TimeStamp": "05/12/2025 20:03:22",
    "Resource": "storage1,storage2",
    "Source": "*.*.*.*"
  },
  "HealthCheckSource": "PreUpdate\\Standard\\Medium\\Network\\7720abf7"
}
```

Check the `AdditionalData` field for summary of which Storage Adapters are not configured properly. Then refer to the remediation steps below. You can identify the resource by checking the `Detail` field in `AdditionalData` section.

In this example, the node name is `AZLOC-NODE1` and the problematic adapter name is `storage2`.
Adapter `storage2` on node `AZLOC-NODE1` has 1 issue: It does not have a valid IPv4 address defined on it.

---

### Failure: Expect one valid IPv4 address configured on storage adapter

The Storage Adapter does not have a valid IP address configured on it.

If user choose to use AutoIP for storage adapters, there is an issue in Windows that might cause the storage adapter ends up using an APIPA address (from 169.254.0.0/16 subnet). This APIPA address is not a valid configuration for the storage adapters.

If user choose to not use AutoIP for storage adapters (but using a customized IP provided during Azure Local deployment time), then it is possible that the IP configured on the adapter is not in Preferred state.

#### Verification and Remediation Steps

##### If you are using AutoIP for your storage adapters
1. Check if the adapter contains valid IP on it:
   ```powershell
   Get-NetIPaddress -InterfaceAlias "storage2" -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue
   ```
   You can also verify this by running `ipconfig /all` to check the result. Like below:
   ```
   Ethernet adapter storage1:

        Connection-specific DNS Suffix  . :
        Description . . . . . . . . . . . : Intel(R) Ethernet 25G 2P E810-XXV Adapter
        Physical Address. . . . . . . . . : 00-AB-01-CD-02-EE
        DHCP Enabled. . . . . . . . . . . : No
        Autoconfiguration Enabled . . . . : Yes
        Link-local IPv6 Address . . . . . : fe80::14f1:76bb:7de:a3%11(Preferred)
        Autoconfiguration IPv4 Address. . : 10.71.1.20(Preferred)
        Subnet Mask . . . . . . . . . . . : 255.255.0.0
        Default Gateway . . . . . . . . . :
        NetBIOS over Tcpip. . . . . . . . : Enabled

    Ethernet adapter storage2:

        Connection-specific DNS Suffix  . :
        Description . . . . . . . . . . . : Intel(R) Ethernet 25G 2P E810-XXV Adapter #2
        Physical Address. . . . . . . . . : 00-AB-01-CD-02-EF
        DHCP Enabled. . . . . . . . . . . : No
        Autoconfiguration Enabled . . . . : Yes
        Link-local IPv6 Address . . . . . : fe80::c57d:73ab:7807:c842%5(Preferred)
        Autoconfiguration IPv4 Address. . : 169.254.247.194(Preferred)
        Subnet Mask . . . . . . . . . . . : 255.255.0.0
        Default Gateway . . . . . . . . . :
        NetBIOS over Tcpip. . . . . . . . : Enabled
   ```

2. Check Windows event log from provider `Microsoft-Windows-Networking-NetworkAtc` to see if there is any event that contains message saying IP address ".255" is used, like "IPAddress 10.71.2.255 is assigned to network adapter storage2"
   ```powershell
   Get-WinEvent -ProviderName "Microsoft-Windows-Networking-NetworkAtc" | Where-Object { $_.Message -like "*.255*"} | Format-List Id, Message
   ```
   You might found event like below in the output:
   ```
   Id             : 52
   Message        : Network ATC made the following configuration changes when provisioning intent (INTENTNAME)
                    IPAddress 10.71.2.255 assigned to network adapter storage2
   ```

   This indicates that NetworkATC is trying to allocate IP `.255` (which is not a valid IP in subnet `10.71.2.0/24`) to storage adapter `storage2`.

3. If you found the the above event 52, you could run below to mitigate:

   ```powershell
   Remove-Netintent -Name <StorageIntentName>
   Add-NetIntent -Wait -Name <StorageIntentName> <Other parameters...>
   ```

    NOTE: Please make sure you are using right parameters while trying to run `Add-NetIntent`, like `-StorageVlan`, `-AdapterName`, `-AdapterRssPropertyOverrides`, etc. Check [Add-NetIntent](https://learn.microsoft.com/en-us/powershell/module/networkatc/add-netintent?view=windowsserver2025-ps) for detailed information on how to run this command.

4. After `Add-NetIntent` finished, run `ipconfig /all` and make sure that the storage adapter is getting valid IP address configured on it.

   If the storage adapter still has APIPA IP configured on it, you might want to try step 3 above again.

### Failure: Expect all IP address on storage adapter [ $($expectedAdapter) ] to be in same subnet.

The Storage Adapter has multiple IP addresses configured on the adapter, but those IP addresses are not in the same subnet. This is not supported.


#### Remediation Steps

1. Please check what storage adapter the system is using:
    ```
    Get-NetAdapter | ft InterfaceAlias, Status, LinkSpeed
    ```
    * For separate storage configuration, it should be physical adapter(s);
    * For converged storage configuration, it should be adapter(s) with name "vSMB(CONVERGED_INTENTNAME#pNICNAME)" (like "vSMB(mgmtcomputestorage#storage1)", "vSMB(mgmtcomputestorage#storage2)", etc.).

    Will use `<STORAGE Adapter Name>` in below to refer the storage adapters.
2. You could check the current IP of the storage adapters using below cmdlet call on all nodes:
    ```
    Get-NetIPAddress -InterfaceAlias "<STORAGE Adapter Name>" | ft InterfaceAlias, IPAddress, PrefixLength
    ```
3. Verify the storage adapter IP configuration on __all nodes of the cluster__:
    * Please check the IP of the storage adapter and then remove only the IP that you do NOT need anymore.
      Make sure to run this on __all the nodes__.
      ```
      Remove-NetIPAddress -InterfaceAlias "<STORAGE Adapter Name>" -AddressFamily IPv4 -IPAddress "<IP TO REMOVE>" -Confirm:$false
      ```
    Also, make sure you run this "Remove-NetIPAddress" cmdlet for __all the storage adapters__ in the system.

4. Run below script to make sure the storage intent is back to healthy state. This need to be run only once on __one node of the cluster__:
    ```
    [System.String] $currentCluster = (Get-Cluster).Name
    [System.String[]] $allNodes = (Get-ClusterNode).Name
    $storageIntent = Get-NetIntent | Where-Object {$_.IsStorageIntentSet -eq $true}

    foreach ($nodeToCheck in $allNodes) {
        Set-NetIntentRetryState -ClusterName $currentCluster -Name $storageIntent.IntentName -NodeName $nodeToCheck -Wait
    }
    ```

5. Now try to run "Get-NetIPAddress" again, if you find multiple IP for one storage adapter again, then most likely you are using AutoIP
   * Verify the storage intent automatic IP generation setting on __one node of the cluster__:
     ```
     $storageIntent = Get-NetIntent | Where-Object {$_.IsStorageIntentSet -eq $true}
     Write-Host "### AutoIP? [ $($storageIntent.IPOverride.EnableAutomaticIPGeneration) ] ###"
     ```
    The output of above call should be "### AutoIP? [] ###" or "### AutoIP? [ true ] ###"
    You will need to remove a different IP that was used in above step 3: try to run step 3 and step 4 again with a different IP.
