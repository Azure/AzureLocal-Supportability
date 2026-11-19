# Symptoms

From Azure Portal, you received health alert about **HostNotConnectedToController** for either a Server/Host or a VM Network Interface. 

**HostNotConnectedToController** occurs when the Network Controller does not receive any VM's Network Interface arrival notification from the Host. If the VM owning the reported Network Interface is indeed offline or disconnected as expected, the error can be ignored. Otherwise, you should investigate further.


# Issue Validation
To narrow down the issue, you need to determine whether it is a host-level issue or a VM issue. If all VMs on the Host report the same error, it usually indicates a host-level issue, and you should validate the host. If only some VMs report the error, the host might be in the correct status, and you should focus on validating the VM's Network Interface setting.

To confirm the issue and help with root causing the problem, please follow the steps below:

## Step1: Validate if the HostId match Server Resource InstanceId

Verify if the HostId configured on the Host match the InstanceId of server resource. Run below from the Host where the error reported.

```Powershell
# Get The HostId from NcHostAgent Registry key
$nchaParams = Get-ItemProperty HKLM:System\CurrentControlSet\Services\NcHostAgent\Parameters
$nchaParams.HostId
# NcUri based on PeerCertificateName from NcHostAgent Parameters
$ncuri = "https://" + $nchaParams.PeerCertificateCName

# Get all Server Resources
$servers = Get-NetworkControllerServer -ConnectionUri $ncuri

# Find the Server resource per Server's FQDN
$serverFQDN = "$(HostName).$((Get-WmiObject Win32_ComputerSystem).Domain)"
$serverResource = $servers | where {
    $_.Properties.Connections[0].ManagementAddresses[0] -eq "$serverFQDN"
    }
if($serverResource -eq $null){
    Write-Host "No Server Resource found with FQDN $serverFQDN" -ForegroundColor Red
}else{
    # Validate if there is the server resource's InstanceId match HostId
    if($serverResource.InstanceId -eq $nchaParams.HostId){
        Write-Host "Server Resource InstanceId Matched HostId. No issue found" -ForegroundColor Green
    }else{
        Write-Host "Server Resource InstanceId: $($serverResource.Properties.InstanceId) not match HostId: $($nchaParams.HostId)" -ForegroundColor Red
    }
}

```
When no issue detected, the output is `Server Resource InstanceId Matched HostId. No issue found`

If the InstanceId mismatch with HostId, follow mitigation steps to mitigate the issue.
### Mitigation Details

You can update the HostId in registry key setting with below PowerShell command, continue from above validation script.

```Powershell
Set-ItemProperty HKLM:System\CurrentControlSet\Services\NcHostAgent\Parameters -Name HostId -Value $serverResource.InstanceId
```

## Step2: Validate the VM's Network Interface Setting
When the VM is online and has its VM Network Adapter connected to Host’s Virtual Switch. The Network Controller is notified with VM Network Adapter’s Port Profile ID together with Host’s Host ID. Network Controller uses this information to determine what the network settings are needed to push to which Host. In the above step, we have validated the HostId match the server resource’s Instance ID to ensure Network Controller correctly link to the Host. Next, we need to ensure VM Network Adapter’s Port Profile ID matches the Network Interface Resource’s InstanceId.

Prerequisites: Install the SdnDiagnostics Module per wiki: 
[Home · microsoft/SdnDiagnostics Wiki](https://github.com/microsoft/SdnDiagnostics/wiki) 

Find the Port Profile ID for the VM Network Adapter. Run from the Host where the VM is running:
```Powershell
Get-SdnVMNetworkAdapterPortProfile -VMName testvm1
```
> Note: Replace testvm1 with your VM 

Reference: [Get SdnVMNetworkAdapterPortProfile · microsoft/SdnDiagnostics Wiki](https://github.com/microsoft/SdnDiagnostics/wiki/Get-SdnVMNetworkAdapterPortProfile) 

Sample output:
```Powershell
VMName      : testvm1 
Name        : nic1 
MacAddress  : 00155D000F04 
ProfileId   : {0b536664-5529-408b-8c1e-8bfd5aabcaed} #NOTICE
ProfileData : 1 
PortId      : 732A69F0-B555-4AB2-8A30-6D77639BEC31
```
> Note:  
> *   The ProfileData should be 1 here for tenant VM. 
> *   The ProfileId need to match the InstanceId we are to check later.

Find the InstanceId for the VM’s Network Interface Resource using below PowerShell:
```Powershell
# NcUri based on NC Rest Name 
$nchaParams = Get-ItemProperty HKLM:System\CurrentControlSet\Services\NcHostAgent\Parameters
# NcUri based on PeerCertificateName from NcHostAgent Parameters
$ncuri = "https://" + $nchaParams.PeerCertificateCName
Get-NetworkControllerNetworkInterface -ConnectionUri $ncuri

```
Sample output:
```Powershell
Tags             : 
ResourceRef      : /networkInterfaces/testvm1nic 
InstanceId       : 0b536664-5529-408b-8c1e-8bfd5aabcaed #NOTICE
Etag             : W/"229b1db1-b3d0-407a-8607-44455832a074" 
ResourceMetadata : 
ResourceId       : testvm1nic 
Properties       : Microsoft.Windows.NetworkController.NetworkInterfaceProperties
```
The VM Network Adapter’s Port Profile ID need to match **InstanceId**

### Mitigation Details

In case the Port Profile ID didn’t match InstanceId of Network Interface resource. You can update by PowerShell:
```Powershell
Set-SdnVMNetworkAdapterPortProfile -VMName testvm1 -MacAddress 00155D000F04 -ProfileId "{0b536664-5529-408b-8c1e-8bfd5aabcaed}" -ProfileData 1
```
Reference: [Set SdnVMNetworkAdapterPortProfile · microsoft/SdnDiagnostics Wiki](https://github.com/microsoft/SdnDiagnostics/wiki/Set-SdnVMNetworkAdapterPortProfile)

# Cause
The **HostNotConnectedToController** issue arises when the Network Controller does not receive any notification from the Host about the arrival of a VM's Network Interface. The issue can be caused by misconfiguration of HostId on the Host's NcHostAgent registry key or misconfiguration of the Port Profile ID of the VM Network Adapter on the Host. 

> Note: If the VM associated with the reported Network Interface is offline or disconnected as expected, this error can be disregarded.


