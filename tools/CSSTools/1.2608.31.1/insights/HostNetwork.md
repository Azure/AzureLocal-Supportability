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
| Windows.Network.NetworkAdapter.NameMismatch | Detects if NetAdapter names do not match corresponding VMNetworkAdapter names |

## Windows.Network.ClusterNetwork

This analyzer checks the state of Cluster Networks.

| Rule | Synopsis |
| --- | --- |
| Windows.Network.ClusterNetwork.UnusedNetworks | This script checks for any cluster ClusterNetworks that are marked as Unused. |
| Windows.Network.ClusterNetwork.MergedStorageNetwork | This script checks for merged storage cluster networks. |

## Windows.Network.VMSwitch.OpState

This analyzer checks the state of the core network components

| Rule | Synopsis |
| --- | --- |
| Windows.Network.VMSwitch.NetAdapterInboxDriver | Checks if any adapters are using the Microsoft Inbox driver. |
| Windows.Network.VMSwitch.duplicateGUID | Detects if there are duplicated VM Switch GUIDs in the cluster |
| Windows.Network.VMSwitch.SRIOVConfig | Checks if VM switches with SR-IOV enabled are backed by hardware that supports it |
| Windows.Network.VMSwitch.MacSpoofingOnSRIOV | Detects VM network adapters with MAC address spoofing enabled that are connected to an SR-IOV (IOV) enabled VM switch. |

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
| Windows.Network.Dns.ResolveClusterNodes | Validates that all cluster node DNS names can be resolved from a specified DNS server. |

## SdnDiagnostics.Server

Checks the health of the SDN Server components using SdnDiagnostics PSModule

| Rule | Synopsis |
| --- | --- |
| SdnDiagnostics.HealthTest | Parses the results of the SDN diagnostics health test and converts them into an insight rule object. |

### SdnDiagnostics Health Tests

Tests are sourced from `Debug-SdnServer` in **SdnDiagnostics.4.2607.14.122**.

| Test Function | Description |
| --- | --- |
| Test-SdnDiagnosticsCleanupTaskEnabled | Ensures the scheduled task responsible for etl compression is enabled and running. |
| Test-SdnNonSelfSignedCertificateInTrustedRootStore | Validate the Cert in Host's Root CA Store to detect if any Non Root Cert exist. |
| Test-SdnEncapOverhead | Validate EncapOverhead configuration on the network adapter. |
| Test-VfpDuplicateMacAddress | Checks VFP ports for duplicate MAC addresses. |
| Test-VMNetAdapterDuplicateMacAddress | Checks VM network adapters for duplicate MAC addresses. |
| Test-SdnProviderNetwork | Validate the health of the provider network by pinging the provider addresses. |
| Test-SdnHostAgentConnectionStateToApiService | Validate the health of the Network Controller Host Agent connection to the Network Controller API Service. |
| Test-SdnVfpEnabledVMSwitch | Enumerates the VMSwitches on the system and validates that only one VMSwitch is configured with VFP. |
| Test-SdnVfpEnabledVMSwitchMultiple | Enumerates the VMSwitches on the system and validates that only one VMSwitch is configured with VFP. |
| Test-SdnCertificateExpired | Checks if the SDN Server certificate has expired. |
| Test-SdnCertificateMultiple | Checks for multiple (extraneous) SDN Server certificates with the Network Controller OID. |
| Test-SdnNetworkControllerApiNameResolution | Validates that the Network Controller API is resolvable via DNS. |
| Test-SdnServiceState | Checks that each SDN Server service is in the Running state. |


