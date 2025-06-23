# QoS Policy

Below is a sample Cisco Nexus QoS configuration tailored for Azure Local environments. This policy is designed to ensure that storage (RDMA) and cluster heartbeat traffic are consistently prioritized and protected from congestion, while allowing efficient bandwidth sharing for all other traffic classes. The configuration defines traffic classes, sets bandwidth guarantees, enables congestion management, and configures MTU settings to meet Azure Local requirements.

Implementing QoS is mandatory for Azure Local deployments that support Storage intent workloads on network switches. For QoS to be effective, the policy must be applied consistently across all devices and interfaces that carry Storage intent traffic, ensuring end-to-end protection and performance for critical workloads.

## Requirements

1. Support three CoS values will be utilized within the Azure Local environment, default values are as follows:
   - CoS 3: Storage, also referred to as RDMA.
   - CoS 7: Cluster Heartbeat
   - CoS 0: Default traffic
2. Support Storage and Cluster heartbeat traffic with Priority Flow Control (802.1Qbb)
   - Establish Storage as a no-drop traffic class.
   - Cluster heartbeat traffic will have the highest Priority to protect against packet loss.
   - Default traffic is the lowest priority, in the event of congestion.  Default will be dropped to protect Storage and Cluster.
3. Bandwidth Reservations utilizing ETS (802.1Qaz)
   - Storage assigned a minimum 50% of the interface bandwidth.
   - Cluster assigned a minimum 1 - 2% of the interface bandwidth.  The percentage is based on the Interface speed
     - 10G: 2%
     - 25G or Greater: 1%
4. Congestion Notification
   - Support for Explicit Congestion Notification (ECN) with Storage traffic.

## Azure Local Defaults

### Network ATC Data Center Bridging (DCB) and VLAN Defaults

| Setting                | Default Value                                      | Description                                                                                                       |
| ---------------------- | -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| DCBX                   | Enabled                                            | Data Center Bridging Exchange protocol is enabled for LLDP configuration notification only.                       |
| Priority Flow Control  | Enabled                                            | PFC (IEEE 802.1Qbb) is enabled for lossless transport on storage traffic.                                         |
| ETS (Bandwidth)        | Storage 50%<br>Cluster 1-2%<br>Default (Remainder) | Bandwidth reservations <br>Cluster Heartbeat:<br>2% if the adapter are <=10Gbps<br>1% if the adapter are >10 Gbps |
| ECN                    | Enabled                                            | Explicit Congestion Notification is enabled for RDMA/Storage traffic.                                             |
| VLAN                   | 711<br>712                                         | Default Storage Intent VLAN assignments. These values can be customized.                                          |
| CoS (Class of Service) | Storage: 3<br>Cluster: 7<br>Default: 0             | Default CoS values for traffic classification.  These values can be customized.                                   |

> [!NOTE]
> These defaults can be overridden using [Network ATC][NetworkAtc] custom settings. For more details, see [Manage Network ATC][NetworkAtcOverride].

## In Scope network patterns

This QoS policy is applicable to the following Azure Local deployment models:

- **Fully hyperconverged:** Compute, management, and storage traffic all share the same network interface.
- **Disaggregated:** Compute and management traffic are assigned to dedicated interfaces, while storage traffic is isolated on its own separate interface.
  - [Disaggregated Design](./Disaggregated_Switched_Storage.md)
- **Rack Aware Cluster:** Based on Disaggregated design with room to room to storage links.

## Out of Scope network patterns

Switchless configurations do not require a switch QoS policy, as the switch is not used to transport storage traffic. In these scenarios, storage traffic is handled directly between endpoints without traversing a network switch, making switch-based QoS settings unnecessary.

## QOS Policy Overview

```mermaid
flowchart TD
  A[Packet Ingress]:::ingress --> B{Ingress Queue}:::ingressqueue
  B -- CoS 3 --> C[Class Map: RDMA]:::cos3
  B -- CoS 7 --> D[Class Map: CLUSTER]:::cos7
  B -- Other --> E[Class Map: Default]:::defaultclass

  C --> F[Policy Map<br>Type: qos<br>AZLocal_SERVICES]:::qosmap
  D --> F
  E --> F

  F -- RDMA --> F3[set qos-group 3]:::cos3
  F -- CLUSTER --> G7[set qos-group 7]:::cos7
  F -- Default --> H0[default qos-group 0]:::defaultclass

  F3 --> X[policy-map type network-qos<br>QOS_NETWORK]:::networkqos
  G7 --> X
  H0 --> X

  X -- qos-group 3 --> J[Queue 3<br>RDMA<br>Buffer carving<br>lossless transport]:::cos3
  X -- qos-group 7 --> K[Queue 7<br>Cluster Heartbeat<br>Buffer carving]:::cos7
  X -- qos-group 0 --> L[Default Queue<br>Buffer carving]:::defaultclass

  J --> M{Egress Queue<br>QOS_EGRESS_PORT}:::egressqueue
  K --> M
  L --> M

  M -- Queue 3 --> N[50% Bandwidth<br>WRED/ECN<br>Congestion: Mark]:::cos3
  M -- Queue 7 --> O[1% Bandwidth]:::cos7
  M -- Default --> P[48% Bandwidth<br>Congestion: Drop]:::defaultclass

  N --> Q[Packet Egress]
  O --> Q
  P --> Q

  %% Annotations
  classDef cos3 fill:#e6ffe6,stroke:#2ecc40,stroke-width:2px;
  classDef cos7 fill:#e6e6ff,stroke:#5b5bd6,stroke-width:2px;
  classDef defaultclass fill:#f7f7f7,stroke:#aaaaaa,stroke-width:2px;
  classDef networkqos fill:#fff3e6,stroke:#ff9900,stroke-width:2px;
  classDef qosmap fill:#e6f0ff,stroke:#0074d9,stroke-width:2px;
  classDef egressqueue fill:#fbeeff,stroke:#b300b3,stroke-width:2px;
```

## ClassMap

```console
class-map type qos match-all RDMA
  match cos 3
class-map type qos match-all CLUSTER
  match cos 7
```

ClassMap identification is performed by matching the packet's CoS (Class of Service) value. If the CoS value is 3 (for RDMA/Storage) or 7 (for Cluster Heartbeat), the traffic is classified into the corresponding class. All other traffic is automatically assigned to the implicit default class. Matching solely on CoS ensures accurate classification and prevents critical traffic from being misclassified as default. This approach simplifies policy management.

## Policy Map (QoS)

```console
policy-map type qos AZLocal_SERVICES
  class RDMA
    set qos-group 3
  class CLUSTER
    set qos-group 7
```

This policy map assigns classified traffic to internal QoS groups. All other traffic classes not represented are placed in an implicit default class (qos-group 0).

## Policy Map (Network QoS)

```console
policy-map type network-qos QOS_NETWORK
  class type network-qos c-8q-nq3
    mtu 9216
    pause pfc-cos 3
  class type network-qos c-8q-nq-default
    mtu 9216
  class type network-qos c-8q-nq7
    mtu 9216
```

This policy map sets global Layer 2 properties for each traffic class by configuring the MTU and enabling Priority Flow Control (PFC) for storage traffic (CoS 3). The `pause pfc-cos 3` command activates PFC on CoS 3, ensuring lossless transport for RDMA and storage traffic. On Cisco NX-OS, this command alone is sufficient to achieve lossless behavior for the specified class, and the `no-drop` keyword is optional and can be added for clarity if needed. The `mtu 9216` command applies a consistent jumbo frame size to all classes, which is recommended for uniformity and optimal support of high-throughput workloads. On Cisco Nexus switches, setting the MTU to 9216 also initiates buffer carving for the ingress queue, which helps optimize buffer allocation for demanding, low-latency applications. Buffer management and MTU configuration may vary on other switch platforms, so it is important to review vendor documentation for platform-specific recommendations.

## Policy Map (Queuing)

```console
policy-map type queuing QOS_EGRESS_PORT
  class type queuing c-out-8q-q3
    bandwidth remaining percent 50
    random-detect minimum-threshold 300 kbytes maximum-threshold 300 kbytes drop-probability 100 weight 0 ecn
  class type queuing c-out-8q-q-default
    bandwidth remaining percent 48
  class type queuing c-out-8q-q7
    bandwidth percent 1
  class type queuing c-out-8q-q1
    bandwidth remaining percent 0
  class type queuing c-out-8q-q2
    bandwidth remaining percent 0
  class type queuing c-out-8q-q4
    bandwidth remaining percent 0
  class type queuing c-out-8q-q5
    bandwidth remaining percent 0
  class type queuing c-out-8q-q6
    bandwidth remaining percent 0
```

- Only queues 3, 7, and default are actively used in this policy. All other queues are configured with 0% bandwidth and remain unused.
- Bandwidth reservations are explicitly configured for queues 3 and 7. Queue 3 (RDMA) is guaranteed a minimum of 50% of the interface bandwidth and can use up to 98% if available. When congestion occurs, tail drop is performed and default traffic may be randomly dropped as needed. Queue 7 (Cluster Heartbeat) is reserved 1% of bandwidth for 25G interfaces and 2% for 10G interfaces. This ensures reliable delivery of critical heartbeat traffic.
- The `random-detect ... ecn` command enables [Explicit Congestion Notification (ECN)](ecn.md) marking for congestion management in queue 3 (RDMA traffic). When congestion is detected, the switch marks packets instead of dropping them, which improves performance for lossless traffic.
- The `random-detect minimum-threshold 300 kbytes maximum-threshold 300 kbytes drop-probability 100 weight 0` configuration sets the minimum and maximum queue thresholds for WRED (Weighted Random Early Detection). When the queue depth reaches 300 kbytes, packets are marked or dropped with a probability of 100%. The weight parameter influences how quickly the average queue size responds to changes in traffic, with a lower value making the response immediate.  RDMA traffic can spike in micro second bursts and having the immediate response ensure the best protection of the lossless traffic.
- Because class 3 (RDMA) is configured as lossless, the switch will not drop packets from this class during congestion. Instead, when the interface is congested, packets from the default class will be dropped to maintain lossless delivery for class 3 traffic.

### Summary Table

| Traffic Type      | CoS | Bandwidth Guarantee | Features Enabled | MTU  | Notes                                  |
| ----------------- | --- | ------------------- | ---------------- | ---- | -------------------------------------- |
| RDMA (Storage)    | 3   | minimum 50%         | PFC, ECN/WRED    | 9216 | Lossless, congestion-aware             |
| Cluster Heartbeat | 7   | 1% (or 2% for 10G)  | Dedicated Queue  | 9216 | Strict minimum for reliability         |
| Default/Other     | -   | Remaining (48%)     | -                | 9216 | Shared among all other traffic classes |

This policy ensures that storage and cluster heartbeat traffic are always prioritized, minimizing latency and packet loss, while still allowing efficient use of available bandwidth for other traffic types.

```console
policy-map type network-qos QOS_NETWORK
  class type network-qos c-8q-nq3
    mtu 9216
    pause pfc-cos 3
  class type network-qos c-8q-nq-default
    mtu 9216
  class type network-qos c-8q-nq7
    mtu 9216
!
class-map type qos match-all RDMA
  match cos 3
class-map type qos match-all CLUSTER
  match cos 7
!
policy-map type qos AZLocal_SERVICES
  class RDMA
    set qos-group 3
  class CLUSTER
    set qos-group 7
!
policy-map type queuing QOS_EGRESS_PORT
  class type queuing c-out-8q-q3
    bandwidth remaining percent 50
    random-detect minimum-threshold 300 kbytes maximum-threshold 300 kbytes drop-probability 100 weight 0 ecn
  class type queuing c-out-8q-q-default
    bandwidth remaining percent 48
  class type queuing c-out-8q-q7
    bandwidth percent 1
  class type queuing c-out-8q-q1
    bandwidth remaining percent 0
  class type queuing c-out-8q-q2
    bandwidth remaining percent 0
  class type queuing c-out-8q-q4
    bandwidth remaining percent 0
  class type queuing c-out-8q-q5
    bandwidth remaining percent 0
  class type queuing c-out-8q-q6
    bandwidth remaining percent 0
```

## System QoS Application

```console
system qos
  service-policy type queuing output QOS_EGRESS_PORT
  service-policy type network-qos QOS_NETWORK
```

This applies the defined queuing and network QoS policies globally to all interfaces.

## Interface Application of QOS

Example of a storage interface supporting a disaggregated Azure Local environment.

```console
interface Ethernet1/17
  description Storage Intent
  switchport
  switchport mode trunk
  switchport trunk native vlan 99
  switchport trunk allowed vlan 711
  priority-flow-control mode on send-tlv
  spanning-tree port type edge trunk
  mtu 9216
  no logging event port link-status
  service-policy type qos input AZLocal_SERVICES
  no shutdown
```

In this example, the key points are the use of `priority-flow-control` and `service-policy`.

- `priority-flow-control mode on send-tlv`: PFC (IEEE 802.1Qbb) allows you to pause traffic on specific CoS (Class of Service) lanes instead of pausing all traffic on the link. This is crucial for lossless Ethernet, especially for storage traffic (like RDMA), which is sensitive to packet loss.
- `service-policy type qos input AZLocal_SERVICES`: Applies a QoS policy, which maps storage and cluster traffic to a specific CoS value that PFC will act upon.

## Terminology

- **ToR**: Top of Rack network switch. Supports Management, Compute, and Storage intent traffic.
- **WRED**: Weighted Random Early Detection, a congestion avoidance mechanism used in QoS policies.
- **ECN**: Explicit Congestion Notification, a congestion notification mechanism used to mark packets when congestion is encountered in the communication path. A DSCP bit is modified in the packet to identify congestion.
- **RDMA**: Remote Direct Memory Access. A technology that enables direct memory access from the memory of one computer into that of another without involving either one's operating system or CPU. This allows for high-throughput, low-latency networking, which is especially beneficial for storage and high-performance computing workloads.

## Reference

- [Azure Local Network Requirements][AzureLocalPhysicalNetworkRequirements]
- [Azure Local Network Considerations for Cloud Deployment of Azure Local][AzureLocalNetworkConsiderationForCloudDeploymentOfAzureLocal]
- [Cisco Azure Local Whitepaper][CiscoNexus9000NXOSACI]
- [RoCE Storage Implementation over NX-OS VXLAN Fabrics][ROCEStorageNXOSVXLANFabric]
- [Cisco Nexus 9000 Series NX-OS Quality of Service Configuration Guide, Release 10.5(x)][CiscoNexusNetworkQOS]
- [Cisco Nexus Configure Queuing and Scheduling][CiscoNexusQueuingAndScheduling]
- [Cisco WRED-Explicit Congestion Notification][CiscoWredECN]
- [RFC 3168 - The Addition of Explicit Congestion Notification (ECN) to IP][rfc3168]
- [802.1Qbb Priority-based Flow Control][802-1qbb]
- [802.1Qaz Enhanced Transmission Selection][802-1qaz]
- [Deploy host networking with Network ATC][NetworkAtc]
- [Manage Network ATC][NetworkAtcOverride]

[AzureLocalPhysicalNetworkRequirements]: https://learn.microsoft.com/en-us/azure/azure-local/concepts/physical-network-requirements
[AzureLocalNetworkConsiderationForCloudDeploymentOfAzureLocal]: https://learn.microsoft.com/en-us/azure/azure-local/plan/cloud-deployment-network-considerations "This article discusses how to design and plan an Azure Local system network for cloud deployment. Before you continue, familiarize yourself with the various Azure Local networking patterns and available configurations."
[ROCEStorageNXOSVXLANFabric]: https://www.cisco.com/c/en/us/td/docs/dcn/whitepapers/roce-storage-implementation-over-nxos-vxlan-fabrics.html
[CiscoNexus9000NXOSACI]: https://www.cisco.com/c/en/us/td/docs/dcn/whitepapers/ACI_AzureLocal_whitepaper.html
[CiscoNexusNetworkQOS]: https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/105x/configuration/qos/cisco-nexus-9000-series-nx-os-quality-of-service-configuration-guide-105x/m-configuring-network-qos.html "Configuration guide: The network QoS policy defines the characteristics of QoS properties network wide."
[CiscoNexusQueuingAndScheduling]: https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/105x/configuration/qos/cisco-nexus-9000-series-nx-os-quality-of-service-configuration-guide-105x/m-configuring-queuing-and-scheduling.html#task_4FB1415CDE92466FB347121D96D6D8C2
[CiscoWredECN]: https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_conavd/configuration/15-mt/qos-conavd-15-mt-book/qos-conavd-wred-ecn.html "WRED drops packets, based on the average queue length exceeding a specific threshold value, to indicate congestion. ECN is an extension to WRED in that ECN marks packets instead of dropping them when the average queue length exceeds a specific threshold value. When configured with the WRED -- Explicit Congestion Notification feature, routers and end hosts would use this marking as a signal that the network is congested and slow down sending packets."
[rfc3168]: https://www.rfc-editor.org/rfc/rfc3168 "We begin by describing TCP's use of packet drops as an indication of congestion.  Next we explain that with the addition of active queue management (e.g., RED) to the Internet infrastructure, where routers detect congestion before the queue overflows, routers are no longer limited to packet drops as an indication of congestion.  Routers can instead set the Congestion Experienced (CE) codepoint in the IP header of packets from ECN-capable transports.  We describe when the CE codepoint is to be set in routers, and describe modifications needed to TCP to make it ECN-capable.  Modifications to other transport protocols (e.g., unreliable unicast or multicast, reliable multicast, other reliable unicast transport protocols) could be considered as those protocols are developed and advance through the standards process.  We also describe in this document the issues involving the use of ECN within IP tunnels, and within IPsec tunnels in particular."
[802-1qbb]: https://1.ieee802.org/dcb/802-1qbb/ "This standard specifies protocols, procedures and managed objects that enable flow control per traffic class on IEEE 802 full-duplex links. Data Center Bridging networks (bridges and end nodes) are characterized by limited bandwidth-delay product and limited hop-count. Traffic class is identified by the VLAN tag priority values. Priority-based flow control is intended to eliminate frame loss due to congestion. This is achieved by a mechanism similar to the IEEE 802.3x PAUSE, but operating on individual priorities. This mechanism, in conjunction with other Data Center Bridging technologies, enables support for higher layer protocols that are highly loss sensitive while not affecting the operation of traditional LAN protocols utilizing other priorities. In addition, PFC complements Congestion Notification in Data Center Bridging networks. Operation of priority-based flow control is limited to a domain controlled by a Data Center Bridging control protocol that controls the application of Priority-based Flow Control, Enhanced Transmission Selection, and Congestion Notification."
[802-1qaz]: https://1.ieee802.org/dcb/802-1qaz/ "This standard specifies enhancement of transmission selection to support allocation of bandwidth amongst traffic classes. When the offered load in a traffic class doesn't use its allocated bandwidth, enhanced transmission selection will allow other traffic classes to use the available bandwidth. The bandwidth-allocation priorities will coexist with strict priorities. It will include managed objects to support bandwidth allocation."
[NetworkAtc]: https://learn.microsoft.com/en-us/windows-server/networking/network-atc/network-atc?pivots=azure-local
[NetworkAtcOverride]:https://learn.microsoft.com/en-us/windows-server/networking/network-atc/manage-network-atc#update-or-override-network-settings

