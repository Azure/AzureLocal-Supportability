# ControlPlaneOperations

This script checks the state of the Azure Local Control Plane services, such as Microsoft Onprem Cloud, Azure Resource Bridge, Arc Services, etc.

## AzStackHci.DiagnosticSettings.NetworkConnectivity

Uses the AzStackHci.DiagnosticSettings module and Test-AzureLocalConnectivity function to test connectivity 
    to required endpoints for Azure Local. Data is also collected from the Arc for Servers Agent on each node.
    The results of the connectivity tests are then evaluated in the
    associated rules, which set the status of the analyzer accordingly.

| Rule | Synopsis |
| --- | --- |
| AzStackHci.DiagnosticSettings.NetworkConnectivity | Rule to evaluate the results of network connectivity tests performed by the AzStackHci.DiagnosticSettings.NetworkConnectivity analyzer. |
| AzStackHci.DiagnosticSettings.SslInspection | Rule to flag TLS / SSL inspection (HTTPS interception) in front of Azure Local endpoints. |
| AzStackHci.DiagnosticSettings.PrivateLinkConfiguration | Rule to evaluate Azure Local Private Link configuration health from the connectivity test results. |
| AzStackHci.DiagnosticSettings.CrlRevocationOffline | Rule to flag certificate revocation (CRL / OCSP) checks that could not be completed because the
    CA's revocation responder is unreachable from an Azure Local node. |
| AzStackHci.DiagnosticSettings.AzureConnectionStatus | Reports this Azure Local node's Azure connection state: its cloud registration status (Get-AzureStackHCI),
    its Arc for Servers agent status (azcmagent), and whether the Arc machine has an Azure Private Link Scope. |

## Support.AksArc

This script checks the state of the AKS ARC.

_No rules defined._

## MocArb

This script validates network connectivity and configuration for MOC and ARB.

| Rule | Synopsis |
| --- | --- |
| MocArb.MocHostAgentService | Validate that the MOC Host Agent service (mochostagent) is running on this node. |
| MocArb.MocHostAgentLogStale | Detect a hung MOC Host Agent (mochostagent) service by checking for stale logs. |
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

Checks the health of the SDN Failover Cluster Network Controller components using SdnDiagnostics PSModule

| Rule | Synopsis |
| --- | --- |
| SdnDiagnostics.HealthTest | Parses the results of the SDN diagnostics health test and converts them into an insight rule object. |

### SdnDiagnostics Health Tests

Tests are sourced from `Debug-SdnNetworkController` in **SdnDiagnostics version 4.2607.14.122**, scoped to the FailoverCluster Network Controller (FCNC) cluster type.

| Test Function | Description |
| --- | --- |
| Test-SdnNonSelfSignedCertificateInTrustedRootStore | Validate the Cert in Host's Root CA Store to detect if any Non Root Cert exist. |
| Test-SdnEncryptionCertificateIsPresent | Validates that the encryption certificate is present on the network controller node. |
| Test-SdnDiagnosticsCleanupTaskEnabled | Ensures the scheduled task (FcDiagnostics) responsible for etl compression is enabled and running. |


