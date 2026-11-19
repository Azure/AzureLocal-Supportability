# Azure Local - BGP Routing Configuration

This document provides BGP routing configuration guidance for Azure Local cluster deployments using Cisco Nexus switches. The configuration establishes Layer 3 connectivity, redundant gateway services, and external network reachability for Azure Local environments.

## Overview

BGP serves as the primary routing protocol for Azure Local ToR switch configurations, enabling:

- **External Connectivity**: Provides routing between Azure Local clusters and external networks through upstream border routers
- **High Availability**: Implements redundant paths and automatic failover for continuous cluster connectivity
- **Load Balancing**: Distributes traffic across multiple uplinks using ECMP (Equal Cost Multi-Path) routing
- **Route Control**: Filters and controls route advertisements to maintain network security and optimize routing tables

## Configuration Applicability

This BGP configuration applies to both Azure Local deployment patterns:

- **Hyper-Converged Deployments**: Where management, compute, and storage traffic share network interfaces with QoS-based traffic separation
- **Disaggregated Deployments**: Where storage traffic uses dedicated network interfaces and isolated VLANs

The configuration implements iBGP sessions between ToR switches for route synchronization and eBGP sessions to upstream border routers for external connectivity. Storage networks remain at Layer 2 only, using RDMA protocols that bypass traditional IP routing.

## BGP Configuration

### BGP Routing

The BGP routing configuration establishes Layer 3 connectivity for Azure Local environments, providing redundant gateway services and external network reachability. This configuration applies to both hyper-converged and disaggregated Azure Local deployments, implementing both iBGP sessions between ToR switches and eBGP sessions to upstream border routers.

```console
!!! Only advertise the default route
ip prefix-list DefaultRoute seq 10 permit 0.0.0.0/0
ip prefix-list DefaultRoute seq 50 deny 0.0.0.0/0 le 32

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
      prefix-list DefaultRoute in
      maximum-prefix 12000 warning-only
  neighbor <Border2-IP>
    remote-as 64404
    description TO_Border2
    address-family ipv4 unicast
      prefix-list DefaultRoute in
      maximum-prefix 12000 warning-only
  neighbor <Port-Channel50-IP>
    remote-as 64511
    description TO_TOR2_IBGP
    address-family ipv4 unicast
      maximum-prefix 12000 warning-only
```

**Configuration Details**

**BGP Autonomous System**:

- **AS 64511**: Private ASN assigned to both ToR switches, enabling iBGP peering between TOR1 and TOR2 while maintaining separate eBGP sessions to upstream infrastructure
- **Router ID**: Unique loopback IP address that identifies this BGP speaker within the AS

**Prefix Lists and Route Filtering**:

- **DefaultRoute prefix-list**: Controls route advertisements to external neighbors, only permitting the default route (0.0.0.0/0) while denying all more specific prefixes. This ensures upstream routers receive only essential routing information from the Azure Local environment.

**Network Advertisements**:

The BGP process advertises the following networks:
- **Loopback Network**: Router's loopback interface for management and BGP session establishment
- **Point-to-Point Links**: Border router connection subnets for proper reachability
- **iBGP Peer Link**: Port-channel 50 subnet for inter-switch BGP communication
- **VLAN 7 (Management)**: 10.101.176.0/24 network for Azure Local management traffic
- **VLAN 8 (Compute)**: 10.101.177.0/24 network for Azure Local compute workloads

**Load Balancing Configuration**:

- **bestpath as-path multipath-relax**: Enables ECMP (Equal Cost Multi-Path) routing even when AS paths differ in length, supporting load balancing across multiple border router connections
- **maximum-paths 8**: Supports up to 8 equal-cost paths for external BGP routes
- **maximum-paths ibgp 8**: Supports up to 8 equal-cost paths for internal BGP routes

**BGP Neighbors**:

**eBGP Neighbors (Border Routers)**:
- **Remote AS 64404**: External ASN assigned to border router infrastructure
- **Prefix Filtering**: Only accepts default routes from border routers using the DefaultRoute prefix-list, preventing unwanted route advertisements
- **Route Limiting**: maximum-prefix 12000 with warning-only prevents session termination while alerting to excessive route advertisements

**iBGP Neighbor (TOR2)**:
- **Same AS (64511)**: iBGP session ensures route synchronization between ToR switches
- **No Prefix Filtering**: Full route table exchange between internal peers for optimal redundancy
- **Route Limiting**: Protects against route table overflow while maintaining session stability

**Routing Protocol Benefits**:

- **Redundancy**: Dual eBGP sessions to border routers provide automatic failover for external connectivity
- **Load Balancing**: ECMP support enables efficient utilization of multiple uplink paths
- **Route Synchronization**: iBGP ensures both ToR switches maintain consistent routing information
- **Scalability**: BGP scales efficiently as Azure Local environments grow and network complexity increases

> [!NOTE]
> **TOR2 Configuration**: TOR2 requires identical BGP configuration with the following key differences:
>
> ```console
> router bgp 64511
>   router-id <TOR2-Loopback-IP>
>   neighbor <Port-Channel50-TOR1-IP>
>     remote-as 64511
>     description TO_TOR1_IBGP
> ```
>
> The iBGP neighbor points to TOR1's port-channel 50 IP address to establish the peer relationship.

> [!IMPORTANT]
> **Storage Network Exclusion**: Storage networks are intentionally excluded from BGP advertisements in both hyper-converged and disaggregated Azure Local configurations. Storage traffic operates exclusively at Layer 2 using RDMA protocols (RoCEv2 or iWARP) that bypass the traditional TCP/IP stack, eliminating the need for Layer 3 routing. This applies to both dedicated storage VLANs in disaggregated deployments and storage traffic classes in hyper-converged deployments.

## Related Documentation

- [Disaggregated Switch Storage Design](Reference-TOR-Disaggregated-Switched-Storage.md) - Complete switch configuration guide for Azure Local disaggregated deployments, including VLAN design, interface configuration, HSRP setup, and physical connectivity patterns
- [Quality of Service (QoS) Policy](Reference-TOR-QOS-Policy-Configuration.md) - QoS configuration for Azure Local environments, including traffic classification, bandwidth allocation, and lossless transport for storage traffic