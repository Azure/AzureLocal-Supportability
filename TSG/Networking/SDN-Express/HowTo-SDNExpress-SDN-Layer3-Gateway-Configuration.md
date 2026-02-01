# Azure Local - SDN and Layer 3 Gateway Configuration

This document provides configuration guidance for Software Defined Networking (SDN) gateway connectivity in Azure Local cluster deployments using Cisco Nexus switches. The configurations support both Layer 3 forwarding scenarios and SDN load balancer integration for Azure Local environments.

## Overview

Azure Local SDN gateway functionality enables connectivity between virtual networks running on Azure Local clusters and external physical networks. This capability is essential for hybrid scenarios where workloads need to communicate across both virtualized and traditional network infrastructure.

### SDN Gateway Features

- **Layer 3 Forwarding**: Provides routing between SDN virtual networks and external physical networks
- **Load Balancer Integration**: Supports Azure Local Software Load Balancer (SLBMUX) for traffic distribution
- **Dynamic Routing**: Uses BGP for automatic route advertisement and learning
- **Multi-Tenant Support**: Enables isolated networking for different workloads and tenants

### Configuration Applicability

This SDN gateway configuration applies to both Azure Local deployment patterns:

- **Hyper-Converged Deployments**: Where management, compute, and storage traffic share network interfaces with QoS-based traffic separation. SDN gateways utilize the compute network (typically VLAN 8) for external connectivity.

- **Disaggregated Deployments**: Where storage traffic uses dedicated network interfaces and isolated VLANs. SDN gateways operate independently of storage networks, using the compute network infrastructure for external routing.

The gateway configurations leverage the existing compute network infrastructure (VLAN 8 in the reference examples) while maintaining isolation from storage networks, which always remain at Layer 2 using RDMA protocols.

## SDN configuration

This section of the BGP configuration is tailored to support an [Azure Local SDN](https://learn.microsoft.com/en-us/azure/azure-local/manage/load-balancers) scenario using VLAN8.

For complete BGP routing configuration details, including iBGP setup and route filtering, see the [Azure Local BGP Routing Configuration][BGP] document.

**Cisco Nexus 93180YC-FX Configuration:**

```console
!!! Prefix list addition
ip prefix-list BlockSDNDefault seq 10 deny 0.0.0.0/0
ip prefix-list BlockSDNDefault seq 20 permit 0.0.0.0/0 le 32

!!! BGP snip
  neighbor 10.101.177.0/24
    remote-as 65158
    description TO_SDN_SLBMUX
    update-source loopback0
    ebgp-multihop 3
    address-family ipv4 unicast
      prefix-list DefaultRoute out
      prefix-list BlockSDNDefault in
      maximum-prefix 12000 warning-only
```

**Dynamic BGP Neighbor Definition**:

A BGP neighbor is defined using the 10.101.177.0/24 subnet, which corresponds to VLAN8 and is reserved for the SLBMUX. The SLBMUX can use any IP address within this subnet, so the configuration specifies the entire subnet as the neighbor. The remote AS is set to 65158, and the neighbor is labeled TO_SDN_SLBMUX for clarity. When a subnet is used as the BGP neighbor, the switch operates in passive mode and waits for the SLBMUX to initiate the BGP connection.

**Peering and Connectivity**:

- `neighbor 10.101.177.0/24`
  Defines the BGP neighbor as the entire 10.101.177.0/24 subnet, which is associated with VLAN8. This allows any device within that subnet—such as a SLBMUX to establish a BGP session with the switch, provided it matches the remote AS number.
- `remote-as 65158`  
  Specifies the remote Autonomous System (AS) number that the switch will allow to form a BGP session. In this case, the remote AS is set to 65158, which should match the AS number configured on the Gateway VM. Only eBGP sessions are supported in this configuration.
- `update-source loopback0`
  This ensures that BGP traffic originates from the stable loopback interface on the TOR, which helps maintain consistent peering even if physical interfaces change.
- `ebgp-multihop 3`
  Allows the BGP session to traverse up to three hops, accommodating scenarios where the SLBMUX is not directly connected.
- `prefix-list DefaultRoute out`
  Within the IPv4 unicast address family for this neighbor, the outbound route policy is governed by the DefaultRoute prefix list. This list is designed to advertise only the default route (0.0.0.0/0) to the SLBMUX. This aligns with the design goal of having the SLBMUX receive only the default route from the switch.
- `prefix-list BlockSDNDefault in`
  Within the IPv4 unicast address family, this command prevents the switch from accepting default route advertisements (0.0.0.0/0) from the SLBMUX. This security measure ensures that SDN services cannot become the default gateway for the Azure Local environment, while still allowing the gateway to advertise more specific routes for internal virtual networks. Any default route received from the gateway will be filtered out before being installed in the switch's routing table.
- `maximum-prefix 12000 warning-only`
  This command serves as a safeguard, issuing warnings if the number of received prefixes approaches a set limit, thereby helping maintain stability in the peer session.

## Layer 3 Forwarding Gateway

![Layer 3 Forwarding Gateway Diagram](https://learn.microsoft.com/en-us/azure/azure-local/concepts/media/gateway-overview/layer-3-forwarding-example.png)

The recommended approach for [Layer 3 Forwarding Gateways](https://learn.microsoft.com/en-us/azure/azure-local/manage/gateway-connections#create-an-l3-connection) in Azure Local is BGP-based dynamic routing with a required static route to enable BGP session establishment. This approach combines the flexibility of dynamic routing with the precision of targeted static routing.

With this configuration, the Layer 3 Gateway operates using dual address spaces:
- **Provider address** (15.0.0.5 in VLAN 10) - The physical-facing IP that connects to the ToR switch
- **Customer address** (10.0.1.6/32) - The internal BGP endpoint that exists within the SDN virtual network

The Layer 3 Gateway establishes a BGP session from its customer address (10.0.1.6) to the ToR switch and advertises its virtual network routes directly into the ToR routing table. This dynamic approach allows the routing table to be automatically updated as virtual networks are added or removed, reducing manual intervention and supporting scalable, automated network operations.

A static route on the ToR switch (`ip route 10.0.1.6/32 15.0.0.5`) is essential to enable BGP connectivity, as it provides the path between the physical network and the virtual BGP endpoint inside the SDN environment.

**Cisco Nexus 93180YC-FX Configuration:**

```console

!!! Vlan 10
interface Vlan10
  description L3 Forward Gateway10
  no shutdown
  mtu 9216
  no ip redirects
  ip address 15.0.0.2/29
  no ipv6 redirects
  hsrp version 2
  hsrp 7
    priority 150 forwarding-threshold lower 1 upper 150
    ip 15.0.0.1

!!! Prefix list addition
ip prefix-list BlockSDNDefault seq 10 deny 0.0.0.0/0
ip prefix-list BlockSDNDefault seq 20 permit 0.0.0.0/0 le 32

!!! BGP snip
    neighbor 10.0.1.6/32
      remote-as 65158
      description TO_L3ForwarderGateway
      update-source Vlan10
      ebgp-multihop 5
      address-family ipv4 unicast
        prefix-list DefaultRoute out
        prefix-list BlockSDNDefault in
        maximum-prefix 12000 warning-only

!!! Add required static route to connect to the BGP Gateway
ip route  10.0.1.6/32 15.0.0.5
```

As mentioned above, BGP provides a dynamic way to add internal virtual networks to the ToR switch routing table. When an administrator adds new networks in the Azure Local portal, the Layer 3 Gateway advertises these networks to the switch using BGP, allowing the routing table to update automatically.

The Layer 3 forwarding gateway configuration requires coordination between the Azure Local administrator and the network administrator to establish proper connectivity. The configuration involves multiple IP addresses and network segments that must be properly aligned.

**Network Architecture Overview:**

Based on the [Layer 3 forwarding example](https://learn.microsoft.com/en-us/azure/azure-local/concepts/media/gateway-overview/layer-3-forwarding-example.png), the configuration implements:

- **VLAN 10**: Dedicated gateway subnet (15.0.0.0/29) for Layer 3 forwarding connectivity
- **Gateway IP**: 15.0.0.1 (HSRP virtual IP providing high availability)
- **Node Host IP**: 15.0.0.5 (Layer 2 extension point on VLAN 10)
- **BGP Endpoint**: 10.0.1.6/32 (BGP peering address for the forwarding gateway)

**Configuration Parameters:**

- `neighbor 10.0.1.6/32`  
  Defines the BGP neighbor using the gateway's BGP peering IP address. This IP address (10.0.1.6/32 in this example) is customer-defined and must be coordinated between the Azure Local administrator and network administrator during deployment planning.

- `remote-as 65158`  
  Specifies the remote Autonomous System (AS) number that the switch will allow to form a BGP session. In this case, the remote AS is set to 65158, which must match the AS number configured on the Layer 3 Gateway VM. Only eBGP sessions are supported in this configuration.

- `update-source Vlan10`  
  Ensures that BGP peering uses the VLAN10 interface (15.0.0.2) as the source IP address for BGP session establishment. VLAN10 provides the Layer 2 extension between the ToR switch and the gateway node.

- `ebgp-multihop 5`  
  Allows the BGP session to be established even if the Gateway VM is up to five hops away from the switch. This accommodates the routing path from the switch through VLAN10 to reach the internal BGP endpoint.

- `prefix-list DefaultRoute out`  
  Within the IPv4 unicast address family, this command restricts the switch to only advertise the default route (0.0.0.0/0) to the Layer 3 Gateway. The Gateway VM requires the default route from the ToR switch to provide external connectivity for internal virtual networks.

- `prefix-list BlockSDNDefault in`
  Within the IPv4 unicast address family, this command prevents the switch from accepting default route advertisements (0.0.0.0/0) from the Layer 3 Gateway. This security measure ensures that SDN services cannot become the default gateway for the Azure Local environment, while still allowing the gateway to advertise more specific routes for internal virtual networks. Any default route received from the gateway will be filtered out before being installed in the switch's routing table.

- `maximum-prefix 12000 warning-only`  
  Sets a safeguard by issuing a warning if the number of received prefixes approaches 12,000. This helps prevent routing table overload and maintains network stability.

- `ip route 10.0.1.6/32 15.0.0.5`
  This static route enables the ToR switch to reach the BGP endpoint IP address (10.0.1.6/32) through the gateway node's provider address (15.0.0.5) on VLAN10. This route is essential for BGP session establishment because 10.0.1.6 exists in the customer address space (internal to the SDN virtual network) and is not directly reachable without this static route pointing through the gateway's provider address.

**Deployment Coordination Requirements:**

The following IP addresses and network parameters must be coordinated between Azure Local and network administrators:

1. **VLAN10 Subnet**: 15.0.0.0/29 (provides 6 usable IP addresses)
2. **Gateway Virtual IP**: 15.0.0.1 (HSRP virtual IP on both ToR switches)
3. **Node Host IP**: 15.0.0.5 (configured on the gateway node during Azure Local deployment)
4. **BGP Endpoint IP**: 10.0.1.6/32 (internal IP for BGP peering, customer-defined)
5. **AS Numbers**: Remote AS 65158 must match the gateway VM configuration

This configuration enables the ToR switch to dynamically learn virtual network routes from Azure Local SDN while maintaining proper security boundaries and routing control.

## Related Documentation

- [Azure Local BGP Routing Configuration][BGP] - Complete BGP configuration for Azure Local environments
- [Disaggregated Switch Storage Design][DISAGGDESIGN] - Complete switch configuration guide for Azure Local disaggregated deployments
- [Azure Local Software Load Balancer][SDN] - Manage Software Load Balancer for SDN
- [Layer Forwarding Gateway][RASGateway] - Layer 3 (L3) forwarding enables connectivity between the physical infrastructure in the datacenter and the virtualized infrastructure in the Hyper-V network virtualization cloud. By using L3 forwarding connection, tenant network VMs can connect to a physical network through the SDN gateway, which is already configured in the SDN environment. In this case, the SDN gateway acts as a router between the virtualized network and the physical network.

[BGP]: ../Top-Of-Rack-Switch/Reference-TOR-BGP.md "BGP routing configuration for Azure Local environments, including iBGP and eBGP setup, route filtering, and load balancing for both hyper-converged and disaggregated deployments."
[DISAGGDESIGN]: ../Top-Of-Rack-Switch/Reference-TOR-Disaggregated-Switched-Storage.md
[RASGateway]: https://learn.microsoft.com/en-us/azure/azure-local/concepts/gateway-overview?#layer-3-forwarding "Layer 3 (L3) forwarding enables connectivity between the physical infrastructure in the datacenter and the virtualized infrastructure in the Hyper-V network virtualization cloud. By using L3 forwarding connection, tenant network VMs can connect to a physical network through the SDN gateway, which is already configured in the SDN environment. In this case, the SDN gateway acts as a router between the virtualized network and the physical network."
[SDN]: https://learn.microsoft.com/en-us/azure/azure-local/manage/load-balancers "Software Load Balancer (SLB) policies using Windows Admin Center after you deploy Software Defined Networking (SDN). SLBs are used to evenly distribute network traffic among multiple resources. SLB enables multiple machines to host the same workload, providing high availability and scalability. You can create load balancers for your workloads hosted on traditional VLAN networks (SDN logical networks) as well as for workloads hosted on SDN virtual networks."
