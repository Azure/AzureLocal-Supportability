# ControlPlaneOperations

This script checks the state of the Azure Local Control Plane services, such as Microsoft Onprem Cloud, Azure Resource Bridge, Arc Services, etc.

## Support.AksArc

This script checks the state of the AKS ARC.

| Rule | Synopsis |
| --- | --- |
| Support.AksArc.KnownIssue | Parses the results of the Support AKS Arc Known Issue test and determines if a known issue exists based on the test results. |

### Support.AksArc Health Tests

Tests are sourced from `Get-SupportAksArcKnownIssues` in **Support.AksArc version 1.3.38**.

| Test ID | Test Name | Description | Critical |
| --- | --- | --- | --- |
| FC-0011 | Failover Cluster service not responsive or not running | Checks if the Failover Cluster service is responsive and running on all nodes. | Yes |
| MOC-0019 | Registry path missing for the MOC PS Config | Checks if the registry path for the MOC PS Config is missing. | Yes |
| MOC-0012 | MOC missing Cloud agent Issues | Checks for any missing Cloud agent issues in the MOC environment. | No |
| MOC-0003 | MOC Cloud Agent Not Running | Validates that the MOC Cloud Agent service is running on all nodes. | No |
| MOC-0010 | MOC Admin Token Expiry | Checks if the MOC admin token has expired or is about to expire. | No |
| MOC-0011 | MOC Missing Node Agent Issues | Validates that all MOC nodes have the Node Agent installed and running. | No |
| MOC-0014 | MOC Missing MocHostAgent Issues | Validates that all MOC nodes have the MocHostAgent installed and running. | No |
| MOC-0001 | MOC Not on Latest Patch Version | Checks if the current MOC version is the latest patch version. | No |
| MOC-0013 | MOC Expired Certificates | Checks if any MOC certificates are expired. | No |
| MOC-0004 | MOC Nodes Not Active | Checks if any MOC nodes are not in the 'Active' state. | No |
| MOC-0005 | MOC Nodes Out of Sync with Cluster Nodes | Validates that all MOC nodes are in sync with the cluster nodes. | No |
| MOC-0006 | Multiple MOC Cloud Agent Instances | Validates that there is only one instance of the MOC Cloud Agent running. | Yes |
| MOC-0007 | MOC Powershell Stuck in Updating State | Validates that the MOC Powershell is not stuck in an updating state. | No |
| MOC-0008 | Windows Event Log Not Running | Validates that the Windows Event Log service is running on all nodes. | No |
| MOC-0009 | Gallery Image Stuck in Deleting State | Validates that no gallery images are stuck in deleting state. | No |
| MOC-0010 | Virtual Machine Stuck in Pending State | Validates if the Virtual Machine is stuck in a pending state. | No |
| MOC-0017 | Virtual Machine Stuck in Delete_Failed State due to OSDisk | Validates if the Virtual Machine is stuck in a delete_failed state. | No |
| VMMS-0012 | Virtual Machine Management service not responsive or not running | Checks if the Virtual Machine Management service is responsive and running on all nodes. | No |
| MOC-0015 | Validate for empty MOC Identity Tokens | Checks if the MOC Identity Tokens are empty. | No |
| MOC-0016 | Validate for corrupted MOC PS Configuration | Checks if the MOC PS Configuration is corrupted. | No |
| MOC-0018 | Validate if Cloud Agent's ClusterAffinityRule is present | Checks if the Cloud Agent is configured with a ClusterAffinityRule. | No |
| MOC-0020 | Stale Moc LoadBalancers on Azure Local 23H2+ | Checks if stale MOC LoadBalancer resources exist that consume IP addresses from the virtual network pool. On 23H2+, MetalLB replaces MOC LoadBalancer. | No |

## MocArb

This script validates network connectivity and configuration for MOC and ARB.

| Rule | Synopsis |
| --- | --- |
| MocArb.MocHostAgentService | Validate that the MOC Host Agent service (mochostagent) is running on this node. |
| MocArb.MocStoragePathAccessible | Validate MOC working directory on ClusterStorage is accessible. |
| MocArb.MocFqdnResolution | Validate MOC FQDN can be resolved via DNS from this node. |
| MocArb.MocTcpPort | Validate MOC Cloud Agent FQDN is listening on TCP port 55000 from this node. |
| MocArb.MocIpAccessibility | Validate MOC FQDN is accessible from all network interfaces on this node. |
| MocArb.MocLogFileRecent | Validate MOC Host Agent log file is recent. |
| MocArb.ArbVmRunningState | Validate ARB control-plane VM is in a Running state in Hyper-V. |
| MocArb.ArbVmNoCheckpoints | Validate ARB control-plane VM has no Hyper-V checkpoints (snapshots). |
| MocArb.ArbClusterResourceOnline | Validate ARB VM cluster resource is Online. |
| MocArb.ArbVSwitchIntent | Validate ARB VM virtual network adapter is on a management or converged intent vSwitch. |
| MocArb.ArbVMVlanId | Check the ARB VM network configuration for VLAN drift |
| MocArb.ArbTcpPort | Validate ARB control-plane VM is listening on TCP port 6443 from this node. |
| MocArb.ArbIpAccessibility | Validate ARB control-plane VM IPs are accessible from network interfaces on this node. |
| MocArb.ArbKubernetesApiHealth | Validate ARB Kubernetes API server is healthy. |
| MocArb.ArbPodHealth | Validate ARB Kubernetes system component health. |
| MocArb.ArbApplianceStatus | Validate that the Arc Resource Bridge appliance is online in Azure. |

## SdnDiagnostics.NC.FailoverCluster

Checks the health of the SDN Failover Cluster Network Controller components using SdnDiagnostics PSModule.

| Rule | Synopsis |
| --- | --- |
| SdnDiagnostics.HealthTest | Parses the results of the SDN diagnostics health test and converts them into an insight rule object. |

### SdnDiagnostics Health Tests

Tests are sourced from `Debug-SdnNetworkController` in **SdnDiagnostics version 4.2604.29.191**, scoped to the FailoverCluster Network Controller (FCNC) cluster type.

| Test Function | Description |
| --- | --- |
| Test-SdnNonSelfSignedCertificateInTrustedRootStore | Validate the certificates in Host's Root CA Store to detect if any non self-signed certificates exist which may cause issues with IIS/WCF. |
| Test-SdnDiagnosticsCleanupTaskEnabled | Ensures the scheduled task (FcDiagnostics) responsible for etl compression is enabled and running |
