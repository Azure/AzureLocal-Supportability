# HostNetwork

This script checks the state of the host network.

## Windows.Network.NetworkATC.OpState

This analyzer checks the state of NetworkATC, NetIntentConfig, and NetIntentProvisioning services.

| Rule | Synopsis |
| --- | --- |
| Windows.Network.NetworkATC.NetIntent.ConfigState | This script checks the configurationStatus of the NetIntent of NetworkATC. |
| Windows.Network.NetworkATC.NetIntent.ProvisioningState | Checks the provisioning status of the NetIntent |
| Windows.Network.NetworkATC.NetIntent.StorageVLANs | Checks the provisioning status of the NetIntent |
| Windows.Network.NetworkATC.NetworkAdapter.State | Checks the provisioning status of the NetIntent |
| Windows.System.Service.State | This script checks the state of a service on the system. |

## Windows.Network.NetworkAdapter

This analyzer checks the state of Cluster Networks.

| Rule | Synopsis |
| --- | --- |
| Windows.Network.NetworkAdapter.AdapterExclusionList | Identifies adapters that might need to be added to the Adapter Exclusion List |
| Windows.Network.NetworkAdapter.AdapterSymmetry | Identifies adapters that are part of a Network Intent and are not symmetric |

## Windows.Network.ClusterNetwork

This analyzer checks the state of Cluster Networks.

| Rule | Synopsis |
| --- | --- |
| Windows.Network.ClusterNetwork.UnusedNetworks | This script checks for any cluster ClusterNetworks that are marked as Unused. |

## Windows.Network.VMSwitch.OpState

This analyzer checks the state of the core network components

| Rule | Synopsis |
| --- | --- |
| Windows.Network.VMSwitch.NetAdapterInboxDriver | Checks if any adapters are using the Microsoft Inbox driver. |
| Windows.Network.VMSwitch.duplicateGUID | Detects if there are duplicated VM Switch GUIDs in the cluster |

## Windows.Network.Storage.Rdma

This analyzer checks the RDMA configuration for storage networks.

| Rule | Synopsis |
| --- | --- |
| Windows.Network.Storage.NetAdapter.RdmaEnabled | Detects if there are duplicated VM Switch GUIDs in the cluster |
| Windows.Network.QoS.DcbxEnabled | Checks if Data Center Bridging Exchange (DCBX) is enabled on the system. |
| Windows.Network.QoS.TrafficClass | Checks if Data Center Bridging (DCB) Traffic Classes are properly configured on the system. |

## Windows.Network.TCPIP

Performs analysis of the TCP/IP stack on the system.

| Rule | Synopsis |
| --- | --- |
| Windows.Network.TCP.PortUsage | Checks the number of ephemeral ports in use on the system. |

## Windows.Network.Dns

This analyzer checks the DNS configuration on the host.

| Rule | Synopsis |
| --- | --- |
| Windows.Network.Dns.Server.IsPresent | Ensures that a  DNS Server defined for the management adapter on the host |
| Windows.Network.Dns.ResolveAzureRegionEndpoints | Ensure that the Azure Local host is able to resolve the Azure Region endpoints used for Azure Local services |


