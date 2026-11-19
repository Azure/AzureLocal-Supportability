# AzStackHci_Hardware_Test_PhysicalDisk

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Hardware_Test_PhysicalDisk, 
AzStackHci_Hardware_Test_PhysicalDisk_Instance_Consistency_Count_ByGroup, 
AzStackHci_Hardware_Test_PhysicalDisk_Instance_Consistency_Count, 
AzStackHci_Hardware_Test_PhysicalDisk_Minimum_Count
</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment, AddNode, RepairNode</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Virtualization Scenarios</th>
    <td><strong>Not applicable</strong></td>
  </tr>
</table>

## Overview

This environment validator failure occurs when the Physical Disks in the cluster do not meet requirements. If prerequisites are not met, this validator will block the pending lifecycle event.

> **Note:** Physical Disks in this case refers to the data disks made available for Storage Spaces.

## Requirements

Physical Disks on every node in the cluster must meet the following criteria:

- Minimum number of data disks for Azure Local <a href="https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-direct-hardware-requirements#physical-deployments" target="_blank">Deployments</a>, <a href="https://learn.microsoft.com/en-us/azure/azure-local/concepts/system-requirements-small-23h2#device-requirements" target="_blank">(Low Capacity)</a> 
- Disk Consistency - All nodes should have the same number of instances per disk type.
- Disk Health - All disks should have a healthy status, operational status and no indicator light on.

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output in the portal or in the result JSON under `C:\CloudContent\MasLogs\AzStackHciEnvironmentCheckerReport.json`. Depending on which prerequisite is not met, a different result may be shown.  The following are 3 different examples, one or more of these results may be shown depending on the environment i.e. No supported disks, a missing disk, inconsistent disks etc.

#### Example 1 - AzStackHci_Hardware_Test_PhysicalDisk

This rule is checking that disks suitable for Storage Spaces are present.  If none are found this result is shown.  The result attempts to list all disks in the `AdditionalData.Detail` (this may be omitted in large environments).

```json
{
    "Name":  "AzStackHci_Hardware_Test_PhysicalDisk",
    "DisplayName":  "Test PhysicalDisk API NODE3",
    "Title":  "Test PhysicalDisk API",
    "Status":  1,
    "Severity":  2,
    "Description":  "Checking PhysicalDisk has CIM data",
    "Remediation":  "See AdditionalData / Detail for more information. Or run Get-PhysicalDiskSupport -PsSession <node>",
    "TargetResourceID":  "Machine: NODE3, Class: PhysicalDisk",
    "TargetResourceName":  "Machine: NODE3, Class: PhysicalDisk",
    "TargetResourceType":  "PhysicalDisk",
    "Timestamp":  "\/Date(1758977970006)\/",
    "AdditionalData":  {
                           "Detail":  "## Supported Data Disk Diagnostic Helper ##

                                        Node: NODE3
                                        Scenario: Deployment\\RackAware\\Medium\\Hardware\\3b48f3eb
                                        IsSupportedHelp: Data Disks must be the right bustype (SATA, SAS, NVMe or SCM), mediatype (HDD, SSD, SCM), not a boot device and CanPool should be true.
                                        Data disks must be consistent across all nodes. Use the following command to check data disks meet these requirements:
                                        Get-PhysicalDisk | Format-Table PhysicalLocation, UniqueId, SerialNumber, CanPool, CannotPoolReason, BusType, MediaType, Size
                                        HCISupportedData:
                                        
                                        ServerName PhysicalLocation                                           UniqueId                             HCISupported
                                        ---------- ----------------                                           --------                             ------------
                                        NODE3   Integrated : Bus 130 : Device 0 : Function 0 : Adapter 8   eui.61124572600061BE1238970000000000        False
                                        NODE3   PCI Slot 9 : Bus 194 : Device 0 : Function 0 : Adapter 5   eui.00000000000000008CE29FE205E4F901        False
                                        NODE3   PCI Slot 10 : Bus 133 : Device 0 : Function 0 : Adapter 9  eui.00000000000000008CE29FE206537601        False
                                        NODE3   PCI Slot 11 : Bus 196 : Device 0 : Function 0 : Adapter 7  eui.00000000000000008CE29FE205E50301        False
                                        NODE3   PCI Slot 8 : Bus 193 : Device 0 : Function 0 : Adapter 4   eui.00000000000000008CE29FE205E4FC01        False
                                        NODE3   PCI Slot 11 : Bus 134 : Device 0 : Function 0 : Adapter 10 eui.00000000000000008CE29FE205E4FF01        False
                                        NODE3   PCI Slot 10 : Bus 195 : Device 0 : Function 0 : Adapter 6  eui.00000000000000008CE29FE20653B701        False",
                           "Status":  "FAILURE",
                           "TimeStamp":  "09/27/2025 12:59:30",
                           "Resource":  "Null",
                           "Source":  "NODE3"
                       },
    "HealthCheckSource":  "Deployment\\RackAware\\Medium\\Hardware\\3b48f3eb"
}
```

#### Example 2 - AzStackHci_Hardware_Test_PhysicalDisk_Minimum_Count

This rule is checking that the minimum number of disks are present.  This result is shown during a failure.

```json
{
    "Name":  "AzStackHci_Hardware_Test_PhysicalDisk_Minimum_Count",
    "DisplayName":  "Test PhysicalDisk Minimum Count NODE1",
    "Tags":  {

             },
    "Title":  "Test PhysicalDisk Minimum Count",
    "Status":  1,
    "Severity":  2,
    "Description":  "Checking PhysicalDisk minimum count",
    "Remediation":  "https://aka.ms/hci-envch",
    "TargetResourceID":  "Machine: NODE1, Class: PhysicalDisk",
    "TargetResourceName":  "Machine: NODE1, Class: PhysicalDisk",
    "TargetResourceType":  "PhysicalDisk",
    "Timestamp":  "\/Date(1758902669891)\/",
    "AdditionalData":  {
                           "Detail":  "Total number of PhysicalDisk '1'. Expected at least '3'",
                           "Status":  "FAILURE",
                           "TimeStamp":  "09/26/2025 16:04:29",
                           "Resource":  "1",
                           "Source":  "PhysicalDisk Minimum Count"
                       },
    "HealthCheckSource":  "Deployment\\Standard\\Medium\\Hardware\\7a144597"
}
```

#### Example 3 - AzStackHci_Hardware_Test_PhysicalDisk_Instance_Consistency_Count

This rule is checking that all nodes have the same number of disks, in total or by type i.e. SDD, NVMe, HDD.  This result is shown during a failure.

```json
{
    "Name":  "AzStackHci_Hardware_Test_PhysicalDisk_Instance_Consistency_Count",
    "DisplayName":  "Test PhysicalDisk Instance Count Consistency AllServers",
    "Tags":  {

             },
    "Title":  "Test PhysicalDisk Instance Count Consistency",
    "Status":  1,
    "Severity":  2,
    "Description":  "Checking all servers have same PhysicalDisk instance count",
    "Remediation":  "https://aka.ms/hci-envch",
    "TargetResourceID":  "Machine: AllServers, Class: PhysicalDisk",
    "TargetResourceName":  "Machine: AllServers, Class: PhysicalDisk",
    "TargetResourceType":  "PhysicalDisk",
    "Timestamp":  "\/Date(1758902748783)\/",
    "AdditionalData":  {
                           "Detail":  "[FAILURE] Instance count consistency for PhysicalDisk 
                                        NODE13 x 23
                                        NODE14 x 24
                                        Expected them to be the same.
                
                                        [FAILURE] Instance count consistency for PhysicalDisk (NVMe) 
                                        NODE13 x 23
                                        NODE14 x 24
                                        Expected them to be the same.
                
                
                                        ## Supported Data Disk Diagnostic Helper ##
                
                                        Node: NODE13
                                        Scenario: Deployment\\Standard\\Medium\\Hardware\\d6c9ca17
                                        IsSupportedHelp: Data Disks must be the right bustype (SATA, SAS, NVMe or SCM), mediatype (HDD, SSD, SCM), not a boot device and CanPool should be true.
                                        Data disks must be consistent across all nodes. Use the following command to check data disks meet these requirements:
                                        Get-PhysicalDisk | Format-Table PhysicalLocation, UniqueId, SerialNumber, CanPool, CannotPoolReason, BusType, MediaType, Size
                                        HCISupportedData:
                                        
                                        ServerName PhysicalLocation                                                  UniqueId                             HCISup
                                                                                                                                                        ported
                                        ---------- ----------------                                                  --------                             ------
                                        NODE13 PCIe SSD in Slot 23 Bay 2                                         eui.363145304E8015010025384500000005   True
                                        NODE13 PCIe SSD in Slot 9 Bay 1                                          eui.363145304E9001670025384500000005   True
                                        NODE13 PCIe SSD in Slot 8 Bay 1                                          eui.363145304E7000880025384500000005   True
                                        NODE13 PCIe SSD in Slot 18 Bay 2                                         eui.363145304E7000350025384500000005   True
                                        NODE13 PCIe SSD in Slot 22 Bay 2                                         eui.363145304E8033700025384500000005   True
                                        NODE13 PCIe SSD in Slot 17 Bay 2                                         eui.363145304E8061580025384500000005   True
                                        NODE13 PCIe SSD in Slot 16 Bay 2                                         eui.363145304E7000330025384500000005   True
                                        NODE13 PCIe SSD in Slot 5 Bay 1                                          eui.363145304E8032860025384500000006   True
                                        NODE13 PCIe SSD in Slot 4 Bay 1                                          eui.363145304E7000850025384500000005   True
                                        NODE13 PCIe SSD in Slot 7 Bay 1                                          eui.363145304E7000920025384500000005   True
                                        NODE13 PCIe SSD in Slot 21 Bay 2                                         eui.363145304E8033890025384500000005   True
                                        NODE13 PCIe SSD in Slot 19 Bay 2                                         eui.363145304E7000980025384500000005   True
                                        NODE13 PCIe SSD in Slot 1 Bay 1                                          eui.363145304E8015060025384500000005   True
                                        NODE13 PCIe SSD in Slot 0 Bay 1                                          eui.363145304E8015020025384500000005   True
                                        NODE13 PCIe SSD in Slot 11 Bay 1                                         eui.363145304E9001630025384500000005   True
                                        NODE13 PCIe SSD in Slot 6 Bay 1                                          eui.363145304E7000970025384500000005   True
                                        NODE13 PCIe SSD in Slot 15 Bay 2                                         eui.363145304E8033780025384500000005   True
                                        NODE13 PCIe SSD in Slot 3 Bay 1                                          eui.363145304E7000360025384500000005   True
                                        NODE13 PCIe SSD in Slot 10 Bay 1                                         eui.363145304E8033850025384500000005   True
                                        NODE13 PCIe SSD in Slot 13 Bay 2                                         eui.363145304E7000560025384500000005   True
                                        NODE13 PCIe SSD in Slot 14 Bay 2                                         eui.363145304E9001280025384500000005   True
                                        NODE13 PCI Slot 5 : Bus 129 : Device 0 : Function 0 : Adapter 0 : Port 0      ATADELLBOSS VD                   False
                                        NODE13 PCIe SSD in Slot 20 Bay 2                                         eui.363145304E9001290025384500000005   True
                                        NODE13 PCIe SSD in Slot 2 Bay 1                                          eui.363145304E8014840025384500000005   True

                                        Node: NODE14
                                        Scenario: Deployment\\Standard\\Medium\\Hardware\\d6c9ca17
                                        IsSupportedHelp: Data Disks must be the right bustype (SATA, SAS, NVMe or SCM), mediatype (HDD, SSD, SCM), not a boot device and CanPool should be true.
                                        Data disks must be consistent across all nodes. Use the following command to check data disks meet these requirements:
                                        Get-PhysicalDisk | Format-Table PhysicalLocation, UniqueId, SerialNumber, CanPool, CannotPoolReason, BusType, MediaType, Size
                                        HCISupportedData:
                                        
                                        ServerName PhysicalLocation                                                  UniqueId                             HCISup
                                                                                                                                                        ported
                                        ---------- ----------------                                                  --------                             ------
                                        NODE14 PCIe SSD in Slot 6 Bay 1                                          eui.363145304D8134540025384500000005   True
                                        NODE14 PCIe SSD in Slot 14 Bay 2                                         eui.363145304E7000680025384500000005   True
                                        NODE14 PCIe SSD in Slot 22 Bay 2                                         eui.363145304D8134410025384500000005   True
                                        NODE14 PCIe SSD in Slot 20 Bay 2                                         eui.363145304E9001300025384500000005   True
                                        NODE14 PCIe SSD in Slot 8 Bay 1                                          eui.363145304D8134350025384500000005   True
                                        NODE14 PCIe SSD in Slot 2 Bay 1                                          eui.363145304D8134560025384500000005   True
                                        NODE14 PCIe SSD in Slot 3 Bay 1                                          eui.363145304D8134640025384500000005   True
                                        NODE14 PCIe SSD in Slot 18 Bay 2                                         eui.363145304E9001310025384500000005   True
                                        NODE14 PCIe SSD in Slot 17 Bay 2                                         eui.363145304D8134450025384500000005   True
                                        NODE14 PCIe SSD in Slot 15 Bay 2                                         eui.363145304D8134580025384500000005   True
                                        NODE14 PCIe SSD in Slot 4 Bay 1                                          eui.363145304E9001110025384500000005   True
                                        NODE14 PCIe SSD in Slot 5 Bay 1                                          eui.363145304E8033800025384500000005   True
                                        NODE14 PCIe SSD in Slot 12 Bay 2                                         eui.363145304D8134360025384500000005   True
                                        NODE14 PCIe SSD in Slot 9 Bay 1                                          eui.363145304E8061570025384500000005   True
                                        NODE14 PCIe SSD in Slot 16 Bay 2                                         eui.363145304D8134420025384500000005   True
                                        NODE14 PCIe SSD in Slot 0 Bay 1                                          eui.363145304D8134440025384500000005   True
                                        NODE14 PCIe SSD in Slot 10 Bay 1                                         eui.363145304D8134330025384500000005   True
                                        NODE14 PCIe SSD in Slot 21 Bay 2                                         eui.363145304E8033790025384500000005   True
                                        NODE14 PCIe SSD in Slot 23 Bay 2                                         eui.363145304E9001090025384500000005   True
                                        NODE14 PCI Slot 5 : Bus 129 : Device 0 : Function 0 : Adapter 0 : Port 0      ATADELLBOSS VD                   False
                                        NODE14 PCIe SSD in Slot 13 Bay 2                                         eui.363145304D8134590025384500000005   True
                                        NODE14 PCIe SSD in Slot 7 Bay 1                                          eui.363145304D8134530025384500000005   True
                                        NODE14 PCIe SSD in Slot 1 Bay 1                                          eui.363145304D8134320025384500000005   True
                                        NODE14 PCIe SSD in Slot 19 Bay 2                                         eui.363145304D8134570025384500000005   True
                                        NODE14 PCIe SSD in Slot 11 Bay 1                                         eui.363145304D8134470025384500000005   True",
                           "Status":  "FAILURE",
                           "TimeStamp":  "09/26/2025 16:05:48",
                           "Resource":  "PhysicalDisk",
                           "Source":  "AllServers"
                       },
    "HealthCheckSource":  "Deployment\\Standard\\Medium\\Hardware\\f5c7ca18"
}
```



**Root Cause:** 

It is necessary to breakdown the `AdditionalData.Detail` field as it explains the scenario's requirements. 
```
Scenario: Deployment\\Standard\\Medium\\Hardware\\f5c7ca18
```
This is for deployment of standard cluster pattern on medium hardware.  Addnode with a Small form factor hardware for example.
```
IsSupportedHelp: Data Disks must be the right bustype (SATA, SAS, NVMe or SCM), mediatype (HDD, SSD, SCM), not a boot device and CanPool should be true.
```
The criteria used to determine if the disks are supported. E.g. The bustype, media type, CanPool and boot device criteria that must be satisfied.  

```
Get-PhysicalDisk | Format-Table PhysicalLocation, UniqueId, SerialNumber, CanPool, CannotPoolReason, BusType, MediaType, Size
```
The command to use to confirm these settings locally on the node.  This command is simple to use and useful if the count of disks is inconsistent. 

There is also a diagnostic helper cmdlet (Get-PhysicalDiskSupport) to help retrieve the current support state of the disks in the cluster, this will also explain why each disk is supported or not.

The following example passes an array PsSessions (one for each node)

```
Import-Module "C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker\AzStackHciHardware\AzStackHci.Hardware.Diagnostic.Helpers.psm1"

$PsSession = New-PSSession -ComputerName $Nodes -Credential $cred;

Get-PhysicalDiskSupport -PsSession $pssession | select -ExpandProperty DiskData | Ft HCISupported, ServerName, PhysicalLocation, HCISupportedData

HCISupported ServerName   PhysicalLocation                                                 HCISupportedData
------------ ----------   ----------------                                                 ----------------
        True NODE5 Integrated : Bus 0 : Device 23 : Function 0 : Adapter 1 : Port 1
       False NODE5 PCI Slot 6 : Bus 1 : Device 0 : Function 0 : Adapter 3           @{CanPool=False; MediaTypeIsSupported=True; CannotPoolReason=Insufficient Capacity BusTypeIsSupported=True; IsBootDevice=True}
       False NODE5 Integrated : Bus 0 : Device 23 : Function 0 : Adapter 1 : Port 0 @{CanPool=False; MediaTypeIsSupported=True; CannotPoolReason=Insufficient Capacity; BusTypeIsSupported=True; IsBootDevice=False}
       False NODE7 PCI Slot 6 : Bus 1 : Device 0 : Function 0 : Adapter 3           @{CanPool=False; MediaTypeIsSupported=True; CannotPoolReason=Insufficient Capacity; BusTypeIsSupported=True; IsBootDevice=True}
       False NODE7 Integrated : Bus 0 : Device 23 : Function 0 : Adapter 1 : Port 0 @{CanPool=False; MediaTypeIsSupported=True; CannotPoolReason=Insufficient Capacity; BusTypeIsSupported=True; IsBootDevice=False}
        True NODE7 Integrated : Bus 0 : Device 23 : Function 0 : Adapter 1 : Port 1
```

#### Remediation Steps

Looking at the last output from the helper cmdlet, each node in the 2-node system has:

- 1 disk where IsBootDevice:true - These are not eligible as data disks.
- 2 disks where CanPool:false & CannotPoolReason:"Insufficient Capacity" - these are not eligible as data disks.
- 1 disk which is supported as data disk.

Overall, this is not a supported scenario for a medium sized deployment because only 1 supported disk exists in the system. It is likely that the disks with "Insufficient Capacity" need remediating.  For this and other pooling issues see <a href="https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-direct-hardware-requirements#physical-deployments" target="_blank">Deployments</a>, <a href="https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-states#reasons-a-drive-cant-be-pooled" target="_blank">Storage Spaces: Reasons a drive can't be pooled</a>

### Conclusion 

**For disks to be eligible** they should have a CanPool value of true*, have a BusType of SATA, SAS, NVMe or SCM, MediaType of HDD, SSD or SCM and not be a boot disk.

For storage to be eligible across a cluster, all nodes should have the same **eligible disk layout** e.g. 5 HDD and 3 SSDs, or 4 SSDs and 2 NVMe.

Common issues:  
- Data Disks CanPool property is false, from the output above there will be a CannotPoolReason property indicating why the disk cannot be pooled. Check the following article to help with remediation https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-states
- Data Disk BusType is RAID. For Azure Local RAID controller cards or SAN (Fibre Channel, iSCSI, FCoE) storage, shared SAS enclosures connected to multiple machines, or any form of multi-path IO (MPIO) where drives are accessible by multiple paths, aren't supported. https://learn.microsoft.com/en-us/azure/azure-local/concepts/system-requirements-23h2#machine-and-storage-requirements
- Nodes do not have the same number of supported disks, including the same number disks of the same type.