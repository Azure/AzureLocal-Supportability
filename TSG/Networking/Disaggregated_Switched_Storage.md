# Disaggregated Switch Storage Design

# DRAFT Document

![Disaggregated_Switched_Storage_Design](./images/Disaggregated_Switched_Storage.png)

- [Disaggregated Switch Storage Design](#disaggregated-switch-storage-design)
- [DRAFT Document](#draft-document)
  - [Scope](#scope)
  - [Terminology](#terminology)
  - [Example Device](#example-device)
  - [Environment](#environment)
  - [Attributes](#attributes)
    - [Nodes](#nodes)
    - [Switch](#switch)
  - [Cable Map](#cable-map)
    - [Node 1 and Node 2](#node-1-and-node-2)
    - [TOR 1 and TOR 2](#tor-1-and-tor-2)
  - [Switch Configuration Overview](#switch-configuration-overview)
    - [QoS](#qos)
    - [Compute, Management, Storage Network Intents](#compute-management-storage-network-intents)
  - [ToR Configuration](#tor-configuration)
    - [Enabled Capabilities](#enabled-capabilities)
  - [QOS](#qos-1)
  - [Loop prevention](#loop-prevention)
    - [VLAN](#vlan)
      - [VLAN Design Rationale](#vlan-design-rationale)
      - [Key Configuration Details](#key-configuration-details)
    - [Interface](#interface)
      - [Compute/Management Intent](#computemanagement-intent)
      - [Configuration Analysis](#configuration-analysis)
      - [Storage Intent TOR 1](#storage-intent-tor-1)
      - [Configuration Details](#configuration-details)
      - [Heartbeat/iBGP](#heartbeatibgp)
      - [MLAG](#mlag)
    - [BGP Routing](#bgp-routing)
  - [Example SDN Configuration](#example-sdn-configuration)
  - [Layer 3 Forwarding Gateway](#layer-3-forwarding-gateway)
  - [References Documents](#references-documents)

## Scope

This document assists administrators in designing a network architecture that aligns with Azure Local cluster requirements. It provides reference architectures and sample configurations for network devices supporting cluster deployments. Equipment such as switches, firewalls, or routers located on customer premises is considered out of scope, as it is assumed to be part of the existing infrastructure. The focus is on Node-to-ToR, ToR-to-ToR, and ToR uplink configurations.

## Terminology

Definitions

- **ToR**: Top of Rack network switch. Supports Management, Compute, and Storage intent traffic.
- **p-NIC**: Physical Network Interface Card attached to an Azure Local node.
- **v-Switch**: Virtual Switch configured on the Azure Local Cluster.
- **VLAN**: Virtual Local Area Network.
- **SET**: [Switch Embedded Teaming][Teaming_in_Azure_Stack_HCI], supporting switch-independent teaming (Windows Server feature).
- **MLAG**: Multi-Chassis Link Aggregation, a technique that lets two or more network switches work together as if they were one logical switch. (Cisco Nexus uses vPC for MLAG.)
- **Border Router**: Uplink device with the ToR switches, providing routing to endpoints external to the Azure Local environment.
- **AS**: Autonomous System number used to define a BGP neighbor.
- **WRED**: Weighted Random Early Detection, a congestion avoidance mechanism used in QoS policies.
- **ECN**: [Explicit Congestion Notification][ECN], a congestion notification mechanism used to mark packets when congestion is encountered in the communication path. A DSCP bit is modified in the packet to identify congestion.

## Example Device

- Make: Cisco
- Model: Nexus 93180YC-FX
- Firmware: 10.3 or greater recommended

## Environment

This document discusses a 2-16 node environment where the Management and Compute network intents share a SET team interface. Storage1 and Storage2 network intents utilize isolated network interfaces and connect to a switch to support storage traffic.

Within this environment, there are two ToR devices (TOR1 and TOR2). Both devices are connected to each other using an MLAG (vPC) configuration and a dedicated port-channel for MLAG heartbeat and iBGP routing.

The ToR devices are set up as Layer 2/Layer 3 devices within an iBGP configuration.

## Attributes

### Nodes

Each node is equipped with two physical network interface cards, each with two physical interfaces (p-NICs):

- 🟦 p-NICs A and B handle both compute and management intent traffic.
- 🟦 p-NIC interfaces support 25Gbps bandwidth.
- 🟦 p-NICs A and B are configured as part of a Switch Embedded Teaming (SET) team, transmitting compute and management traffic. These NICs are assigned to a virtual switch (v-Switch) to support multiple network intents. Management intent traffic is untagged, and Compute traffic is tagged.
- 🟪 p-NICs C and D are dedicated to storage intent traffic and are RDMA-capable devices.
- 🟪 p-NICs C and D can support RoCEv2 or iWARP.
- 🟪 p-NICs C and D are connected to the ToR devices. VLAN 711 is assigned to p-NIC C and VLAN 712 to p-NIC D. The interfaces operate in trunk mode, and only one storage intent VLAN is assigned per interface.

> [!IMPORTANT]
> If your Azure Local environment uses iWARP-based network cards and you enable Jumbo Frames, ensure that Jumbo Frames are also enabled on all switch interfaces and network paths carrying Storage Intent traffic. For RoCEv2-based systems, enabling Jumbo Frames on the switch is not required for Storage Intent traffic.

### Switch

- TOR1 is in an MLAG (vPC) configuration with TOR2. Three interfaces are assigned to the MLAG peer link between the devices. Peer link bandwidth should be sized based on customer workloads.
- MLAG supports two network intents: Management and Compute.
- Layer 2 traffic is supported between the cluster nodes and the ToR devices. External connectivity is only established via Layer 3 sessions.
- Storage intent traffic is isolated to a specific ToR and is not expected to traverse between the ToR devices.
- TOR1 and TOR2 operate as Layer 2/Layer 3 devices. Layer 3 is supported by BGP as the primary routing protocol.
- TOR1 and TOR2 are configured to support an iBGP session; all external links are configured as eBGP sessions.

## Cable Map

The cable map below shows two nodes as an example. For larger environments, extend the pattern accordingly. Maintaining a consistent wiring pattern is essential for successful Azure Local deployments.

> [!NOTE]
> Azure Local deployments require consistent wiring patterns for proper operation:
> - All p-NIC A interfaces should connect to TOR1
> - All p-NIC B interfaces should connect to TOR2
> - All p-NIC C interfaces should connect to TOR1
> - All p-NIC D interfaces should connect to TOR2
>
> Consistent cabling ensures proper traffic flow, simplifies troubleshooting, and helps avoid deployment challenges. We recommend verifying your wiring pattern matches this guidance before beginning deployment.

### Node 1 and Node 2

| Device    | Interface |      | Device | Interface    |     | Device    | Interface |      | Device | Interface    |
| --------- | --------- | ---- | ------ | ------------ | --- | --------- | --------- | ---- | ------ | ------------ |
| **Node1** | p-NIC A   | <==> | TOR1   | Ethernet1/1  |     | **Node2** | p-NIC A   | <==> | TOR1   | Ethernet1/2  |
| **Node1** | p-NIC B   | <==> | TOR2   | Ethernet1/1  |     | **Node2** | p-NIC B   | <==> | TOR2   | Ethernet1/2  |
| **Node1** | p-NIC C   | <==> | TOR1   | Ethernet1/15 |     | **Node2** | p-NIC C   | <==> | TOR1   | Ethernet1/16 |
| **Node1** | p-NIC D   | <==> | TOR2   | Ethernet1/15 |     | **Node2** | p-NIC D   | <==> | TOR2   | Ethernet1/16 |

### TOR 1 and TOR 2

| Device   | Interface    |      | Device  | Interface    |     | Device   | Interface    |      | Device  | Interface    |
| -------- | ------------ | ---- | ------- | ------------ | --- | -------- | ------------ | ---- | ------- | ------------ |
| **TOR1** | Ethernet1/1  | <==> | Node1   | p-NIC A      |     | **TOR2** | Ethernet1/1  | <==> | Node1   | p-NIC B      |
| **TOR1** | Ethernet1/2  | <==> | Node2   | p-NIC A      |     | **TOR2** | Ethernet1/2  | <==> | Node2   | p-NIC B      |
| **TOR1** | Ethernet1/15 | <==> | Node1   | p-NIC C      |     | **TOR2** | Ethernet1/15 | <==> | Node1   | p-NIC D      |
| **TOR1** | Ethernet1/16 | <==> | Node2   | p-NIC C      |     | **TOR2** | Ethernet1/16 | <==> | Node2   | p-NIC D      |
| **TOR1** | Ethernet1/41 | <==> | TOR2    | Ethernet1/41 |     | **TOR2** | Ethernet1/41 | <==> | TOR1    | Ethernet1/41 |
| **TOR1** | Ethernet1/42 | <==> | TOR2    | Ethernet1/42 |     | **TOR2** | Ethernet1/42 | <==> | TOR1    | Ethernet1/42 |
| **TOR1** | Ethernet1/47 | <==> | Border1 | Ethernet1/x  |     | **TOR2** | Ethernet1/47 | <==> | Border1 | Ethernet1/x  |
| **TOR1** | Ethernet1/48 | <==> | Border2 | Ethernet1/x  |     | **TOR2** | Ethernet1/48 | <==> | Border2 | Ethernet1/x  |
| **TOR1** | Ethernet1/49 | <==> | TOR2    | Ethernet1/49 |     | **TOR2** | Ethernet1/49 | <==> | TOR1    | Ethernet1/49 |
| **TOR1** | Ethernet1/50 | <==> | TOR2    | Ethernet1/50 |     | **TOR2** | Ethernet1/50 | <==> | TOR1    | Ethernet1/50 |
| **TOR1** | Ethernet1/51 | <==> | TOR2    | Ethernet1/51 |     | **TOR2** | Ethernet1/51 | <==> | TOR1    | Ethernet1/51 |

## Switch Configuration Overview

This section provides a high-level overview of the switch configuration required for Azure Local environments. The configuration focuses on enabling features and policies that support Management, Compute, and Storage network intents, as well as redundancy and high availability.

### QoS

Quality of Service (QoS) policies are implemented to prioritize critical traffic types, such as storage (RDMA) and cluster heartbeat, and to ensure efficient bandwidth allocation for all network intents. The following sections detail the required class maps, policy maps, and system QoS application.

### Compute, Management, Storage Network Intents

- **Compute and Management:** These intents share a SET team interface and are typically carried over tagged and untagged VLANs, respectively. Ensure proper VLAN tagging and trunk configuration on switch ports.
- **Storage:** Storage intent traffic uses dedicated RDMA-capable interfaces and is isolated to specific VLANs. Lossless transport is required for RDMA (RoCEv2 or iWARP), which is achieved through Priority Flow Control (PFC) and appropriate buffer allocation.

## ToR Configuration

### Enabled Capabilities

Enable the following features on Cisco Nexus 93180YC-FX to support this Azure Local environment:

```console
feature bgp
feature interface-vlan
feature hsrp
feature lacp
feature vpc
feature lldp
```

- **BGP** is used as the primary routing protocol.
- **interface-vlan** enables SVI creation for management and compute networks.
- **LACP** is used for port-channels between ToR devices.
- **HSRP** provides gateway redundancy for SVIs, used in conjunction with vPC for high availability.
- **vPC** (Cisco's MLAG implementation) is used for switch redundancy and active-active uplinks.
- **LLDP** is used to transmit host interface configuration values, which can be leveraged by Azure Local for enhanced support scenarios.

## QOS

[Quality of Service (QoS) Policy](qos.md)

## Loop prevention

The spanning tree configuration implements Multiple Spanning Tree (MST) protocol to prevent network loops while allowing redundant paths. The spanning-tree port type edge bpduguard default command configures all ports as edge ports by default (typically used for end devices) and enables BPDU guard protection, which will disable ports that unexpectedly receive spanning tree BPDUs. The priority settings establish a hierarchy where MST instances 0 and 1 have higher priority (lower numerical value of 20480) compared to MST instance 2 (28672), making instances 0 and 1 more likely to become the root bridge.

The MST configuration section creates a spanning tree region named "AzureLocal" with revision 1, which helps identify switches that should share the same MST configuration. The VLAN-to-instance mappings distribute different VLANs across multiple spanning tree instances: instance 1 handles VLANs 1-710 and 713-1999, instance 2 manages VLANs 2000-4094, and instance 3 is dedicated to VLANs 711-712. This segmentation allows for better load balancing and convergence times by having different spanning tree calculations for different groups of VLANs.

```console
spanning-tree port type edge bpduguard default
spanning-tree mst 0-1 priority 20480
spanning-tree mst 2 priority 28672
spanning-tree mst configuration
  name AzureLocal
  revision 1
  instance 1 vlan 1-710,713-1999
  instance 2 vlan 2000-4094
  instance 3 vlan 711-712
```

### VLAN

This section configures the necessary VLANs to support Azure Local network intents and establishes Switched Virtual Interfaces (SVIs) for Layer 3 connectivity. The VLAN structure is designed to provide network segmentation, security, and optimal traffic flow for different Azure Local workloads.

```console
vlan 1-2,7-8,99,711
vlan 2
  name UNUSED_INTERFACE
vlan 7
  name Management_7
vlan 8
  name Compute_8
vlan 99
  name NativeVlan
vlan 711
  name Storage_711_TOR1

interface Vlan7
  description Management_7
  no shutdown
  mtu 9216
  no ip redirects
  ip address 10.101.176.2/26
  no ipv6 redirects
  hsrp version 2
  hsrp 7
    priority 150 forwarding-threshold lower 1 upper 150
    ip 10.101.176.1
interface Vlan8
  description Compute_8
  no shutdown
  mtu 9216
  no ip redirects
  ip address 10.101.177.2/26
  no ipv6 redirects
  hsrp version 2
  hsrp 8
    priority 150 forwarding-threshold lower 1 upper 150
    ip 10.101.177.1
```

#### VLAN Design Rationale

**Management VLAN (VLAN 7)**: Configured as an SVI with IP address 10.101.176.2/26, this VLAN provides out-of-band management access to Azure Local nodes. This network segment carries Windows Admin Center traffic, PowerShell remoting, and other administrative communications. The SVI enables the ToR switch to act as the default gateway for management traffic, providing Layer 3 routing to external management systems and administrative networks. HSRP is configured with virtual IP 10.101.176.1 and priority 150 to provide gateway redundancy with TOR2.

**Compute VLAN (VLAN 8)**: Configured as an SVI with IP address 10.101.177.2/26, this VLAN handles Azure Local virtual machine traffic and compute workloads. The SVI provides gateway services for tenant VMs and enables north-south traffic flow between Azure Local workloads and external networks. This configuration supports SDN virtual networks and provides connectivity for Azure Arc-enabled services. HSRP is configured with virtual IP 10.101.177.1 and priority 150 to ensure high availability gateway services across both ToR switches.

**Storage VLAN (VLAN 711)**: This VLAN operates exclusively at Layer 2 and intentionally has no SVI configuration. Storage traffic uses RDMA protocols (RoCEv2 or iWARP) that bypass the traditional TCP/IP stack, eliminating the need for Layer 3 routing. VLAN 711 is isolated to TOR1 only and carries storage traffic from Azure Local nodes connected to TOR1 (p-NIC C interfaces). This ensures optimal performance and maintains the lossless characteristics required for Storage Spaces Direct operations.

**Native VLAN (VLAN 99)**: Serves as a security boundary for untagged traffic. Any misconfigured or untagged frames are automatically assigned to this VLAN, preventing unauthorized access to production networks. This follows Cisco security best practices and provides operational visibility into potential configuration issues.

**Unused Interface VLAN (VLAN 2)**: Acts as a parking VLAN for unused switch ports. Assign unused interfaces to this VLAN to prevent unauthorized device connections and maintain network security posture.

#### Key Configuration Details

- **MTU 9216**: Jumbo frames are configured on management and compute SVIs to support Software Defined Networking (SDN) services in Azure Local environments. This MTU setting is specifically required for SDN virtual networks, Network Controller communications, and gateway services. If your Azure Local deployment does not utilize SDN features, standard MTU (1500) can be used instead.

- **IP Redirects Disabled**: Both IPv4 and IPv6 redirects are disabled on SVIs as a best practice for Azure Local deployments. IP redirects can conflict with various Azure Local services including Network Controller, SDN gateway operations, and cluster networking components. Disabling redirects ensures proper traffic flow and prevents routing conflicts within the Azure Local environment.

- **Subnet Sizing**: /26 subnets provide 62 usable IP addresses per network intent, sufficient for typical Azure Local cluster deployments while maintaining efficient IP space utilization.  See the [Azure Local Network Patterns guide][AzureLocalNetworkPattern] to determine the correct subnet size.

> [!NOTE]
> **TOR2 Storage VLAN Configuration**: TOR2 requires a separate storage VLAN 712 configuration:
>
> ```console
> vlan 712
>   name Storage_712_TOR2
> ```
>
> VLAN 712 is isolated to TOR2 and carries storage traffic from Azure Local nodes connected to TOR2 (p-NIC D interfaces). Each ToR switch maintains its own dedicated storage VLAN to ensure traffic isolation and optimal RDMA performance. Storage traffic never traverses between ToR switches, even in the vPC configuration.

> [!IMPORTANT]
> Ensure HSRP is configured on VLANs 7 and 8 to provide gateway redundancy between TOR1 and TOR2. This configuration will be detailed in the HSRP section of the interface configuration.

### Interface

#### Compute/Management Intent

These interfaces connect to Azure Local nodes' p-NIC A and p-NIC B interfaces, which are configured as Switch Embedded Teaming (SET) members. This configuration supports both management and compute network intents through VLAN separation while providing redundancy across both ToR switches.

```console
interface Ethernet1/1
  description Switched-Compute-Management
  no cdp enable
  switchport
  switchport mode trunk
  switchport trunk native vlan 7
  switchport trunk allowed vlan 8
  spanning-tree port type edge trunk
  mtu 9216
  logging event port link-status
  no shutdown

interface Ethernet1/2
  description Switched-Compute-Management
  no cdp enable
  switchport
  switchport mode trunk
  switchport trunk native vlan 7
  switchport trunk allowed vlan 8
  spanning-tree port type edge trunk
  mtu 9216
  logging event port link-status
  no shutdown
```

#### Configuration Analysis

**VLAN Configuration**:

- **VLAN 7 (Management Intent)**: Configured as the native VLAN to carry untagged management traffic from Azure Local nodes. This includes Windows Admin Center communications, PowerShell remoting, cluster management traffic, and health monitoring services.

- **VLAN 8 (Compute Intent)**: Configured as a tagged VLAN to carry compute workload traffic, including virtual machine communications, tenant network traffic, and Azure Arc-enabled services.

**Network Redundancy**: Both VLANs 7 and 8 are supported on both TOR1 and TOR2 switches, providing high availability through the vPC (MLAG) configuration. The HSRP configuration on the corresponding SVIs (interface Vlan7 and Vlan8) utilizes the peer link between ToR devices to maintain gateway redundancy and ensure seamless failover for Azure Local nodes.

**MTU Configuration**: The MTU 9216 setting is optional and specifically configured to support Software Defined Networking (SDN) environments. This jumbo frame configuration is required for:

- Network Controller communications
- SDN gateway operations  
- Virtual network overlay protocols

If your Azure Local deployment does not utilize SDN features, the MTU can be set to the standard 1500 bytes.

**Interface Optimization**:

- **CDP Disabled**: Cisco Discovery Protocol is disabled as it's not required for Azure Local environments and reduces unnecessary protocol overhead
- **Spanning Tree Edge**: Configured as edge trunk ports since these connect directly to end devices (Azure Local nodes), enabling faster convergence
- **Link Status Logging**: Enabled to provide visibility into interface state changes for troubleshooting and monitoring

> [!NOTE]
> These interfaces support the SET team configuration on Azure Local nodes, where p-NIC A connects to TOR1 and p-NIC B connects to TOR2. This provides active-active connectivity with automatic failover capabilities, ensuring high availability for both management and compute traffic.

#### Storage Intent TOR 1

These interfaces connect to Azure Local nodes' dedicated storage NICs (p-NIC C interfaces) and are specifically configured to support RDMA traffic for Storage Spaces Direct operations. The configuration ensures lossless transport and optimal performance for storage workloads.

```console
interface Ethernet1/21
  description Switched-Storage
  no cdp enable
  switchport
  switchport mode trunk
  switchport trunk native vlan 99
  switchport trunk allowed vlan 711
  priority-flow-control mode on send-tlv
  spanning-tree port type edge trunk
  mtu 9216
  logging event port link-status
  service-policy type qos input AZS_SERVICES
  no shutdown

interface Ethernet1/22
  description Switched-Storage
  no cdp enable
  switchport
  switchport mode trunk
  switchport trunk native vlan 99
  switchport trunk allowed vlan 711
  priority-flow-control mode on send-tlv
  spanning-tree port type edge trunk
  mtu 9216
  logging event port link-status
  service-policy type qos input AZS_SERVICES
  no shutdown
```


#### Configuration Details

**Physical Connectivity**:

- **Ethernet1/21**: Connects to **Node1 p-NIC C** (dedicated storage interface)
- **Ethernet1/22**: Connects to **Node2 p-NIC C** (dedicated storage interface)
- **Pattern**: All p-NIC C interfaces from every Azure Local node connect to TOR1 for storage traffic isolation

**VLAN Configuration**:

- **VLAN 99 (Native)**: Configured as the default native VLAN to capture any untagged traffic. This serves as a security boundary and operational best practice, ensuring that misconfigured or untagged frames are isolated from production storage traffic.
- **VLAN 711 (Storage)**: The dedicated storage intent VLAN that carries all RDMA traffic for Storage Spaces Direct operations. Each storage interface is assigned to only one storage VLAN (711 for TOR1, 712 for TOR2) to maintain traffic isolation and prevent cross-switch storage communication.

**LLDP Integration**:

- **priority-flow-control mode on send-tlv**: Enables LLDP transmission of Priority Flow Control capabilities and Data Center Bridging Exchange (DCBX) information from the ToR switch to the Azure Local nodes. The switch advertises its QoS configuration, PFC capabilities, and traffic class mappings to the connected nodes. Azure Local nodes operate in "willing mode 0" (non-willing mode), meaning they will not accept or apply DCBX configuration changes from the switch. Instead, Azure Local uses this DCBX information strictly for diagnostic and validation purposes - allowing administrators and support teams to verify that the switch interface configuration matches the expected QoS settings and troubleshoot any configuration mismatches during deployment or operation.

**MTU Configuration**:

- **MTU 9216**: Configures jumbo frame support, but actual utilization depends on the RDMA transport protocol:
  - **iWARP-based RDMA**: Utilizes the configured jumbo frames (9216 bytes) for improved performance and reduced CPU overhead
  - **RoCEv2-based RDMA**: Operates with standard Ethernet frames (1500 bytes) and ignores the jumbo frame configuration, as RoCEv2 handles frame segmentation differently

**Quality of Service**:

- **service-policy type qos input AZS_SERVICES**: Applies the QoS policy that enables traffic classification, bandwidth guarantees, and congestion management for storage and cluster heartbeat traffic. This policy ensures that storage RDMA traffic receives appropriate priority and lossless transport characteristics.

**Lossless Transport**:

- **Priority Flow Control (PFC)**: Combined with the QoS policy, PFC ensures lossless delivery of storage traffic by providing per-priority pause capabilities, preventing packet drops that would severely impact RDMA performance.

> [!NOTE]
> **TOR2 Storage Configuration**: The corresponding interfaces on TOR2 (connecting to p-NIC D) would be configured identically but allow VLAN 712 instead of VLAN 711, maintaining storage traffic isolation between the two ToR switches.

> [!IMPORTANT]
> **RDMA Protocol Considerations**: Verify your Azure Local cluster's RDMA configuration (iWARP vs. RoCEv2) to ensure optimal switch configuration. While jumbo frames benefit iWARP deployments, they are not utilized by RoCEv2. Properly configure the MTU and QoS settings based on the deployed RDMA protocol to achieve the best performance and reliability for storage workloads.

#### Heartbeat/iBGP

```console
interface port-channel50
  description VPC:HEARTBEAT
  logging event port link-status
  mtu 9216
  ip address 100.71.55.25/30

interface Ethernet1/41
  description P2P_HEARTBEAT
  no cdp enable
  mtu 9216
  logging event port link-status
  channel-group 50 mode active
  no shutdown

interface Ethernet1/42
  description P2P_HEARTBEAT
  no cdp enable
  mtu 9216
  logging event port link-status
  channel-group 50 mode active
  no shutdown
```

#### MLAG

```console
vpc domain 2
  peer-switch
  role priority 1
  peer-keepalive destination 100.71.55.26 source 100.71.55.25 vrf default
  delay restore 150
  peer-gateway
  auto-recovery

interface port-channel101
  description VPC:MLAG_PEER
  switchport
  switchport mode trunk
  switchport trunk native vlan 99
  switchport trunk allowed vlan 7-8
  spanning-tree port type network
  logging event port link-status
  vpc peer-link

interface Ethernet1/49
  description MLAG_Peer
  no cdp enable
  switchport
  switchport mode trunk
  switchport trunk native vlan 99
  switchport trunk allowed vlan 7-8
  logging event port link-status
  channel-group 101 mode active
  no shutdown

interface Ethernet1/50
  description MLAG_Peer
  no cdp enable
  switchport
  switchport mode trunk
  switchport trunk native vlan 99
  switchport trunk allowed vlan 7-8
  logging event port link-status
  channel-group 101 mode active
  no shutdown
```

### BGP Routing

```console
!!! Only advertise the default route
ip prefix-list DefaultRoute seq 10 permit 0.0.0.0/0
ip prefix-list DefaultRoute seq 50 deny 0.0.0.0/0 le 32

!!! Receive BGP Advertisements for 0.0.0.0/0, deny all others.
ip prefix-list FROM-BORDER seq 10 permit 0.0.0.0/0
ip prefix-list FROM-BORDER seq 30 deny 0.0.0.0/0 le 32

!!! Advertise any network except for 0.0.0.0/0
ip prefix-list TO-BORDER seq 5 deny 0.0.0.0/0
ip prefix-list TO-BORDER seq 10 permit 0.0.0.0/0 le 32

router bgp 64511
  router-id <Loopback-IP>
  bestpath as-path multipath-relax
  log-neighbor-changes
  address-family ipv4 unicast
    network <Loopback-IP>/32
    network <Border1-IP>/30
    network <Border2-IP>/30
    network <Port-Channel50-IP>/30
    ! VLAN7
    network 10.101.176.0/24
    ! VLAN8
    network 10.101.177.0/24
    maximum-paths 8
    maximum-paths ibgp 8
  neighbor <Border1-IP>
    remote-as 64404
    description TO_Border1
    address-family ipv4 unicast
      prefix-list FROM-BORDER in
      prefix-list TO-BORDER out
      maximum-prefix 12000 warning-only
  neighbor <Border2-IP>
    remote-as 64404
    description TO_Border2
    address-family ipv4 unicast
      prefix-list FROM-BORDER in
      prefix-list TO-BORDER out
      maximum-prefix 12000 warning-only
  neighbor <Port-Channel50-IP>
    remote-as 64511
    description TO_TOR2
    address-family ipv4 unicast
      maximum-prefix 12000 warning-only
```

## Example SDN Configuration

## Layer 3 Forwarding Gateway

## References Documents

- [Teaming in Azure Stack HCI][Teaming_in_Azure_Stack_HCI]
- [Network considerations for cloud deployments of Azure Local][AzureLocalNetworkConsiderationForCloudDeploymentOfAzureLocal]
- [Physical network requirements for Azure Local][AzureLocalPhysicalNetworkRequirements]
- [Manage Azure Local gateway connections][AzureLocalManageGatewayConnections]
- [Microsoft Azure Local Connectivity to Cisco Nexus 9000 Series Switches in Cisco NX-OS and Cisco® Application Centric Infrastructure (Cisco ACI™) Mode][CiscoNexus9000NXOSACI]
- [RoCE Storage Implementation over NX-OS VXLAN Fabrics][ROCEStorageNXOSVXLANFabric]
- [Cisco Nexus 9000 Series NX-OS Quality of Service Configuration Guide, Release 10.5(x)][CiscoNexusNetworkQOS]
- [Cisco Nexus Configure Queuing and Scheduling][CiscoNexusQueuingAndScheduling]
- [Cisco WRED-Explicit Congestion Notification][CiscoWredECN]
- [RFC 3168 - The Addition of Explicit Congestion Notification (ECN) to IP][rfc3168]
- [Azure Local network deployment patterns][AzureLocalNetworkPattern]

[AzureLocalPhysicalNetworkRequirements]: https://learn.microsoft.com/en-us/azure/azure-local/concepts/physical-network-requirements
[Teaming_in_Azure_Stack_HCI]: https://techcommunity.microsoft.com/blog/networkingblog/teaming-in-azure-stack-hci/1070642 "Switch Embedded Teaming (SET) and was introduced in Windows Server 2016. SET is available when Hyper-V is installed on any Server OS (Windows Server 2016 and higher) and Windows 10 version 1809 (and higher)"
[AzureLocalNetworkConsiderationForCloudDeploymentOfAzureLocal]: https://learn.microsoft.com/en-us/azure/azure-local/plan/cloud-deployment-network-considerations "This article discusses how to design and plan an Azure Local system network for cloud deployment. Before you continue, familiarize yourself with the various Azure Local networking patterns and available configurations."
[AzureLocalManageGatewayConnections]: https://learn.microsoft.com/en-us/azure/azure-local/manage/gateway-connections?#create-an-l3-connection "L3 forwarding enables connectivity between the physical infrastructure in the data center and the SDN virtual networks. With an L3 forwarding connection, tenant network VMs can connect to a physical network through the SDN gateway. In this case, the SDN gateway acts as a router between the SDN virtual network and the physical network."
[ROCEStorageNXOSVXLANFabric]: https://www.cisco.com/c/en/us/td/docs/dcn/whitepapers/roce-storage-implementation-over-nxos-vxlan-fabrics.html
[CiscoNexus9000NXOSACI]: https://www.cisco.com/c/en/us/td/docs/dcn/whitepapers/ACI_AzureLocal_whitepaper.html
[CiscoNexusNetworkQOS]: https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/105x/configuration/qos/cisco-nexus-9000-series-nx-os-quality-of-service-configuration-guide-105x/m-configuring-network-qos.html "Configuration guide: The network QoS policy defines the characteristics of QoS properties network wide."
[CiscoNexusQueuingAndScheduling]: https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/105x/configuration/qos/cisco-nexus-9000-series-nx-os-quality-of-service-configuration-guide-105x/m-configuring-queuing-and-scheduling.html#task_4FB1415CDE92466FB347121D96D6D8C2
[CiscoWredECN]: https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_conavd/configuration/15-mt/qos-conavd-15-mt-book/qos-conavd-wred-ecn.html "WRED drops packets, based on the average queue length exceeding a specific threshold value, to indicate congestion. ECN is an extension to WRED in that ECN marks packets instead of dropping them when the average queue length exceeds a specific threshold value. When configured with the WRED -- Explicit Congestion Notification feature, routers and end hosts would use this marking as a signal that the network is congested and slow down sending packets."
[rfc3168]: https://www.rfc-editor.org/rfc/rfc3168 "We begin by describing TCP's use of packet drops as an indication of congestion.  Next we explain that with the addition of active queue management (e.g., RED) to the Internet infrastructure, where routers detect congestion before the queue overflows, routers are no longer limited to packet drops as an indication of congestion.  Routers can instead set the Congestion Experienced (CE) codepoint in the IP header of packets from ECN-capable transports.  We describe when the CE codepoint is to be set in routers, and describe modifications needed to TCP to make it ECN-capable.  Modifications to other transport protocols (e.g., unreliable unicast or multicast, reliable multicast, other reliable unicast transport protocols) could be considered as those protocols are developed and advance through the standards process.  We also describe in this document the issues involving the use of ECN within IP tunnels, and within IPsec tunnels in particular."
[ECN]: ./ecn.md "Explicit Congestion Notification (ECN) is a network congestion management mechanism that enables switches and routers to signal congestion without dropping packets. In Azure Local QoS implementations, ECN is specifically configured for storage (RDMA) traffic to maintain lossless transport while providing congestion feedback to endpoints."
[AzureLocalNetworkPattern]: https://learn.microsoft.com/en-us/azure/azure-local/plan/choose-network-pattern "This article describes a set of network patterns references to architect, deploy, and configure Azure Local using either one, two or three physical hosts. Depending on your needs or scenarios, you can go directly to your pattern of interest. Each pattern is described as a standalone entity and includes all the network components for specific scenarios."
