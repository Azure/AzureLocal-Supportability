# Azure Local – Physical Network Deployment Patterns Reference

_A comprehensive design reference covering Azure Local physical network deployment patterns, configuration requirements, and hardware specifications for enterprise deployments._

> [!IMPORTANT]
> **Document Purpose**: This document provides guidance and best practices for Azure Local physical network design. Always refer to the latest official Microsoft documentation for the most current requirements and supported configurations.

---

## Table of Contents

- [1. Introduction](#1-introduction)
- [2. Deployment Patterns Overview](#2-deployment-patterns-overview)
- [3. Physical Network Hardware & Configuration Requirements](#3-physical-network-hardware--configuration-requirements)
- [4. Frequently Asked Questions](#4-frequently-asked-questions)
- [5. Additional Resources](#5-additional-resources)

---

## 1. Introduction

This document provides comprehensive guidance for **Azure Local physical networking**, covering deployment patterns and configuration requirements to support enterprise deployments. It serves as a design reference for IT professionals, network architects, and system integrators planning Azure Local infrastructure.

This guide complements the official Azure Local documentation and provides practical implementation guidance with focus on:
- Physical network deployment pattern selection
- Hardware requirements and specifications  
- Configuration best practices and design considerations
- Frequently asked questions about deployment patterns

> [!NOTE]
> This document focuses specifically on physical network infrastructure design patterns. For troubleshooting procedures and diagnostic guidance, refer to the companion document: [Azure Local – Physical Network Connection Troubleshooting Guide](Troubleshoot-TOR-Connectivity-Issues.md).

> [!TIP]  
> For logical networking, SDN configuration, and advanced operational topics, please refer to the dedicated Azure Local documentation resources listed in the Additional Resources section.


### Key Terminology

This section defines essential terms and acronyms used throughout this document:

| Term | Definition |
|------|------------|
| **ToR (Top-of-Rack Switch)** | Physical network switch directly connected to Azure Local nodes, providing Layer 2/3 connectivity |
| **Management VLAN (M)** | Network segment dedicated to cluster management and administrative traffic |
| **Compute VLAN (C)** | Network segment for virtual machine workloads and tenant traffic |
| **Storage VLAN 1 (S1)** | First storage network segment for SMB over RDMA traffic |
| **Storage VLAN 2 (S2)** | Second storage network segment for SMB over RDMA traffic |
| **SET (Switch Embedded Teaming)** | Windows-native NIC aggregation technology providing redundancy without switch-based LACP |
| **RDMA (Remote Direct Memory Access)** | High-performance networking technology enabling direct memory-to-memory communication |
| **LLDP (Link Layer Discovery Protocol)** | IEEE 802.1AB standard for network topology discovery and cable verification |
| **PFC (Priority Flow Control)** | IEEE 802.1Qbb standard enabling lossless Ethernet for RDMA traffic |
| **ETS (Enhanced Transmission Selection)** | IEEE 802.1Qaz standard for bandwidth allocation and traffic class management |
| **DCB (Data Center Bridging)** | IEEE standards suite (PFC, ETS) enhancing Ethernet for data center environments |


---

## 2. Deployment Patterns Overview

Azure Local supports three primary physical network deployment patterns, each optimized for different use cases, scale requirements, and operational considerations. The fundamental difference between these patterns lies in how storage traffic is handled and isolated:

### Deployment Pattern Descriptions

**Switchless Deployment**
A cost-effective design optimized for smaller deployments where storage traffic flows directly between nodes without dedicated switching infrastructure. This pattern minimizes hardware requirements and is ideal for edge locations and remote sites where simplicity and cost optimization are priorities.

![Switchless with 2 ToRs](images/AzureLocalPhysicalNetworkDiagram_Switchless.png)

**Switched Deployment**  
A high-performance design utilizing dedicated NICs for management/compute and storage traffic, providing storage physical isolation. This pattern is recommended for enterprise deployments requiring maximum storage performance and dedicated bandwidth allocation for storage workloads.

![Switched with 2 ToRs](images/AzureLocalPhysicalNetworkDiagram_Switched.png)

**Fully Converged Deployment**
A balanced design where all traffic types (management, compute, storage) share the same physical NICs through VLAN segmentation. This pattern minimizes hardware footprint while maintaining high scalability. **Both storage VLANs must be configured on both ToR switches** because SET (Switch Embedded Teaming) may route either storage VLAN through either physical NIC.

![Fully-Converged with 2 ToRs](images/AzureLocalPhysicalNetworkDiagram_FullyConverged.png)


### Deployment Pattern Comparison

| Deployment Pattern  | Host NIC Configuration | ToR Switch VLAN Configuration | Primary Use Cases |
|---------------------|------------------------|-------------------------------|-------------------|
| **Switchless** | 2 NICs to switches (M+C traffic) + (N−1) direct inter-node NICs (S traffic) | Trunk ports with M, C VLANs only; no storage VLANs on ToRs | Edge deployments, remote sites, cost-sensitive environments |
| **Switched** | 4 NICs per host: 2 for M+C traffic, 2 dedicated for storage | M and C VLANs on both ToRs; S1 VLAN on ToR1 only, S2 VLAN on ToR2 only (dedicated storage NICs) | Enterprise deployments requiring dedicated storage performance and traffic isolation |
| **Fully Converged** | 2 NICs per host carrying all traffic types (M+C+S) via VLAN segmentation | Both storage VLANs (S1, S2) on both ToRs (required for SET) | General-purpose deployments balancing performance, simplicity, and hardware efficiency |

> [!NOTE]
> **Storage VLAN Configuration**: Storage VLANs can be configured as either **Layer 3 (L3) networks with IP subnets** or **Layer 2 (L2) networks without IP subnets**. **Layer 2 configuration is recommended** because it simplifies VLAN tagging, allowing Azure Local hosts to use any IP addresses without hardcoding subnet configurations on the switch or requiring predefined IP ranges. Since Azure Local nodes handle storage traffic tagging, ensure these VLANs are configured as **tagged VLANs on trunk ports** across all ToR switches.


---

## 3. Physical Network Hardware & Configuration Requirements

### Network Switch Requirements

Azure Local requires specific capabilities from physical network switches to ensure performance, compatibility, and integration with RDMA, SET, and VLAN-based traffic separation.

You can find the official list of switch requirements here:  
[Azure Local – Physical Network Switch Requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/physical-network-requirements#network-switch-requirements)

If you're an **OEM** and wish to qualify your switches for Azure Local deployments, Microsoft provides an open-source validation tool:  
[AzureLocal-Network-Switch-Validation](https://github.com/microsoft/AzureLocal-Network-Switch-Validation)


### Network Configuration Requirements

The physical network must be configured in alignment with Azure Local's host networking requirements, and details and official configuration guidance are available here:  
[Azure Local – Host Network Requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/host-network-requirements)


| Requirement           | Notes                                                                 |
|------------------------|-----------------------------------------------------------------------|
| **VLAN**              | Support separate VLANs for M, C, and S networks.                    |
| **Jumbo Frames**      | MTU must support 1514–9174 bytes to enable SDN encapsulation.          |
| **DCB (PFC + ETS)**   | Required for lossless RDMA; must support IEEE 802.1Qbb and 802.1Qaz.  |
| **LLDP with TLVs**    | Switches must support LLDP with VLAN, ETS, and PFC TLVs, which will be used for network discovery and monitoring.              |
| **BGP Support**       | Required for SDN compute overlays.                                    |

> [!NOTE]
>  These are high-level requirements. Please refer to the official documentation to ensure full alignment with your specific deployment needs.

This tool is designed to automate the generation of Azure Local switch configurations based on input JSON files. In addition to automation, it includes sample configuration files that can be used as reference. The tool is actively maintained and will continue to evolve in alignment with Azure Local's latest requirements.  
[Azure_Local_Physical_Network_Config_Tool](https://github.com/microsoft/Azure_Local_Physical_Network_Config_Tool)

---

## 4. Frequently Asked Questions

### Q: How should Storage VLANs be configured across ToR switches?

**A:**  
Storage VLAN configuration depends on the **deployment pattern**:

| Deployment Pattern | ToR VLAN Configuration | Why |
|-------------------|------------------------|-----|
| **Switched** | S1 on ToR1 only, S2 on ToR2 only | Dedicated storage NICs connect to specific ToRs |
| **Fully Converged** | Both S1 & S2 on both ToRs | SET may route either storage VLAN through either physical NIC |

**Switched Deployment (One Storage VLAN per ToR):**
- Each host has **dedicated storage NICs** (4 NICs total)
- Storage NIC1 connects to ToR1 → only needs VLAN 711
- Storage NIC2 connects to ToR2 → only needs VLAN 712
- This reduces MC-LAG utilization and optimizes RDMA performance

**Fully Converged Deployment (Both Storage VLANs on Both ToRs):**
- Each host has only **2 NICs** shared for all traffic
- SET (Switch Embedded Teaming) handles vNIC-to-pNIC mapping
- SET may route either storage VLAN through either physical NIC
- **Both ToRs must carry both storage VLANs** to support SET's flexibility

> [!IMPORTANT]
> In Fully Converged deployments, configuring only one storage VLAN per ToR will cause connectivity issues when SET routes a storage vNIC to a physical NIC connected to a ToR that doesn't have that VLAN configured.


### Q: Are **DCB (Data Center Bridging)** features like **PFC** and **ETS** required for RDMA in Azure Local deployments?

**A:**  
While **DCB features** such as **Priority Flow Control (PFC)** and **Enhanced Transmission Selection (ETS)** are not strictly mandatory, they are **highly recommended** for both **RoCEv2** and **iWARP** to optimize RDMA performance in Azure Local environments.

**Protocol Comparison:**

- **RoCEv2** uses **UDP**, which is fast but **cannot tolerate packet loss**.  
  → **PFC is essential** to prevent packet drops, and DCB is **required** for optimal performance.

- **iWARP** uses **TCP**, which can handle **packet loss** but may introduce additional latency.  
  → **PFC is not mandatory**, but enabling **DCB** can still help reduce latency and improve consistency.

> [!IMPORTANT]
> Even though **iWARP** uses reliable TCP transport and does **not mandate DCB**, enabling **PFC and ETS** can help minimize congestion and latency, especially in mixed RDMA environments. Enabling DCB across the fabric ensures **consistent, predictable low-latency** behavior for RDMA workloads.

### Q: Can Storage VLANs be configured as Layer 3 networks instead of Layer 2?

**A:**
Yes, Storage VLANs can be configured as either **Layer 2 (L2) networks without IP subnets** or **Layer 3 (L3) networks with IP subnets**. However, **Layer 2 configuration is the recommended approach** for the following reasons:

**Layer 2 Benefits (Recommended):**
- Simplified VLAN tagging approach
- No need to pre-configure IP subnets on switches
- Azure Local hosts can use any IP addresses dynamically
- Reduced switch configuration complexity
- Better alignment with Azure Local's network intent configuration

**Layer 3 Configuration:**
- Requires predefined IP subnet configuration on switches
- More complex to manage and troubleshoot
- May require additional routing considerations

> [!NOTE]
> Regardless of the approach chosen, ensure Storage VLANs are configured as **tagged VLANs on trunk ports** across all ToR switches since Azure Local nodes handle storage traffic tagging.

## 5. Additional Resources

For comprehensive Azure Local networking guidance, refer to these official Microsoft documentation resources:

### Official Documentation
- **[Physical network requirements for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/concepts/physical-network-requirements)**  
  Complete hardware and configuration requirements for Azure Local network infrastructure

- **[Host network requirements for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/concepts/host-network-requirements)**  
  Detailed guidance for host-level networking configuration and requirements

- **[Software Defined Networking (SDN) in Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/concepts/software-defined-networking-23h2)**  
  Comprehensive guide to SDN implementation and configuration in Azure Local environments
