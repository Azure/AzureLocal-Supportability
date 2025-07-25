# Azure Local - SDN and Layer 3 Gateway Configuration

This document provides configuration guidance for Software Defined Networking (SDN) gateway connectivity in Azure Local cluster deployments using Cisco Nexus switches. The configurations support both Layer 3 forwarding scenarios and SDN load balancer integration for Azure Local environments.

## Overview

Azure Local SDN gateway functionality enables connectivity between virtual networks running on Azure Local clusters and external physical networks. This capability is essential for hybrid scenarios where workloads need to communicate across both virtualized and traditional network infrastructure.

### SDN Gateway Features

- **Layer 3 Forwarding**: Provides routing between SDN virtual networks and external physical networks
- **Load Balancer Integration**: Supports Azure Local Software Load Balancer (SLBMUX) for traffic distribution
- **Dynamic Routing**: Uses BGP for automatic route advertisement and learning
- **Static Routing**: Supports manual route configuration for controlled environments
- **Multi-Tenant Support**: Enables isolated networking for different workloads and tenants

### Configuration Applicability

This SDN gateway configuration applies to both Azure Local deployment patterns:

- **Hyper-Converged Deployments**: Where management, compute, and storage traffic share network interfaces with QoS-based traffic separation. SDN gateways utilize the compute network (typically VLAN 8) for external connectivity.

- **Disaggregated Deployments**: Where storage traffic uses dedicated network interfaces and isolated VLANs. SDN gateways operate independently of storage networks, using the compute network infrastructure for external routing.

The gateway configurations leverage the existing compute network infrastructure (VLAN 8 in the reference examples) while maintaining isolation from storage networks, which always remain at Layer 2 using RDMA protocols.

## Example SDN configuration

This section of the BGP configuration is tailored to support an [Azure Local SDN](https://learn.microsoft.com/en-us/azure/azure-local/manage/load-balancers) scenario using VLAN8. 
For complete BGP routing configuration details, including iBGP setup and route filtering, see the [Azure Local BGP Routing Configuration][BGP] document.

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
- `maximum-prefix 12000 warning-only`
  This command serves as a safeguard, issuing warnings if the number of received prefixes approaches a set limit, thereby helping maintain stability in the peer session.

**Cisco Nexus 93180YC-FX Configuration:**

```console
  neighbor 10.101.177.0/24
    remote-as 65158
    description TO_SDN_SLBMUX
    update-source loopback0
    ebgp-multihop 3
    address-family ipv4 unicast
      prefix-list DefaultRoute out
      maximum-prefix 12000 warning-only
```

## Layer 3 Forwarding Gateway

There are two primary methods for supporting [Layer 3 Forwarding Gateways](https://learn.microsoft.com/en-us/azure/azure-local/manage/gateway-connections?view=azloc-2505#create-an-l3-connection) in Azure Local configurations: BGP and static routing.

With BGP, the Layer 3 Gateway establishes a BGP session with the ToR switch and advertises its V-NET routes directly into the ToR routing table. This dynamic approach allows the routing table to be automatically updated as new networks are added or removed, reducing manual intervention and supporting scalable, automated network operations.

In contrast, static routing requires the Forwarding Gateway to be a member of the VLAN, with the ToR switch manually configured with static routes for each required network. This method is more manual and requires the network team to update the ToR configuration whenever new internal networks are introduced. While BGP is recommended for environments that require flexibility and automation, static routing may be preferred in scenarios where a controlled, predictable routing configuration is needed.

For both methods, the subnet used for the gateway can be much smaller than the examples shown—typically as small as a /30 or /28, depending on the number of required IP addresses.

### BGP Mode

As mentioned above, BGP provides a dynamic way to add internal networks to the ToR switch routing table. When an administrator adds new networks in the portal, the Layer 3 Gateway advertises these networks to the switch using BGP, allowing the routing table to update automatically.

In the sample configuration below

- `neighbor 10.101.177.0/24`  
  Defines the BGP neighbor as the entire 10.101.177.0/24 subnet, which is associated with VLAN8. This allows any device within that subnet—such as a Layer 3 Gateway VM to establish a BGP session with the switch, provided it matches the remote AS number.

- `remote-as 65158`  
  Specifies the remote Autonomous System (AS) number that the switch will allow to form a BGP session. In this case, the remote AS is set to 65158, which should match the AS number configured on the Gateway VM. Only eBGP sessions are supported in this configuration.

- `update-source Vlan8`  
  Ensures that BGP peering uses the VLAN8 interface as the source IP address. The source IP can be any address assigned to the VLAN8 configuration. Refer to the VLAN section above for more details.

- `ebgp-multihop 5`  
  Allows the BGP session to be established even if the Gateway VM is up to five hops away from the switch. This is useful in scenarios where the VM is not directly connected.

- `prefix-list DefaultRoute out`  
  Within the IPv4 unicast address family, this command restricts the switch to only advertise the default route (0.0.0.0/0) to the Layer 3 Gateway. The Gateway VM must receive at least the default route from the ToR switch.

- `maximum-prefix 12000 warning-only`  
  Sets a safeguard by issuing a warning if the number of received prefixes approaches 12,000. This helps prevent routing table overload and maintains network stability.

This configuration enables the ToR switch to dynamically learn and advertise routes as the network evolves, reducing manual intervention and supporting scalable, automated network operations.

**Cisco Nexus 93180YC-FX Configuration:**

```console
    neighbor 10.101.177.0/24
      remote-as 65158
      description TO_L3Forwarder
      update-source Vlan8
      ebgp-multihop 5
      address-family ipv4 unicast
        prefix-list DefaultRoute out
        maximum-prefix 12000 warning-only
```

### Static Mode

In static routing mode, the network team must plan in advance which subnet will be used by the V-NET and which IP address will serve as the gateway for internal routing. For example, in the configuration below, 10.101.177.226 is designated as the gateway VM. This IP address acts as the Layer 3 peering point with the ToR switch and serves as the gateway to the internal subnet 10.68.239.0/24.

It is recommended to configure the required static routes on the ToR switch before deploying the gateway VM. If additional internal networks are needed in the future, the ToR configuration must be updated to include static routes for those networks prior to their deployment. This ensures that traffic destined for the internal subnet is correctly forwarded to the gateway VM, supporting seamless connectivity within the larger Azure Local environment.

This approach is particularly useful in environments where dynamic routing protocols like BGP are not used, or where a more controlled, manual routing configuration is preferred.

**Cisco Nexus 93180YC-FX Configuration:**

```console
  ip route 10.101.177.226/32 10.68.239.0/24
```

## Related Documentation

- [Azure Local BGP Routing Configuration][BGP] - Complete BGP configuration for Azure Local environments
- [Disaggregated Switch Storage Design](../Top-Of-Rack-Switch/Reference-TOR-Disaggregated-Switched-Storage.md) - Complete switch configuration guide for Azure Local disaggregated deployments

[BGP]: ./azurelocal-bgp.md "BGP routing configuration for Azure Local environments, including iBGP and eBGP setup, route filtering, and load balancing for both hyper-converged and disaggregated deployments."
