# Azure Local - Arc Gateway Outbound Connectivity Deep Dive

## Overview

Azure Local with the Arc gateway simplifies and secures the connectivity of your on-premises servers to Azure. Instead of managing hundreds of firewall rules, you only need to allow fewer than 30 outbound connections. This significantly reduces administrative overhead, enhances security, and simplifies compliance with your organization's policies.

### Key Benefits:

- **Better Security:** Fewer open connections reduce the potential attack surface.
- **Easier Setup:** Leverage your existing network and security infrastructure while the Arc gateway manages Azure connectivity.
- **Simpler Management:** Fewer endpoints to manage means easier tracking and troubleshooting.

This guide explains how outbound connections work with the Arc gateway and Azure Local, including detailed diagrams and configuration requirements.

---

## Azure Local Components Required for Arc Gateway Connectivity

The following diagram introduces the core components involved in Azure Local connectivity using the Arc gateway:

- **Azure Local Instance:** Your on-premises Azure Local cluster.
- **Nodes:** Individual servers within your Azure Local instance.
- **Arc Proxy (on Arc connected machine agent):** A local proxy service running on each node, responsible for securely routing HTTPS traffic through the Arc gateway.
- **Arc Gateway Public Endpoint:** The Azure-hosted endpoint establishing a secure HTTPS tunnel between your local Arc proxy and Azure.
- **Firewall/Proxy:** Your organization's existing security infrastructure controlling outbound traffic.
- **Azure Public Endpoints:** Azure services (e.g., Azure Resource Manager, Key Vault, Microsoft Graph) required by your local environment.

![Azure Local with Arc gateway outbound connectivity](./images/AzureLocalPublicPathFlowsFinal-1Node-ComponentsOnly.dark.svg)

---
## Types of Network Traffic and Routing with Azure Local and Arc Gateway

When using Azure Local with the Arc gateway, operating system (OS) and Arc Resource Bridge appliance VM network traffic is categorized based on how it should be routed. Clearly distinguishing these categories helps administrators correctly configure network routing rules, ensuring secure, efficient, and compliant connectivity between on-premises infrastructure and Azure services.

### Traffic Categories:

1. **🟦 OS HTTP and HTTPS traffic that must bypass your proxy** 
   Specific HTTP and HTTPS connections that should not pass through your organization's standard proxy infrastructure or through Arc proxy. Instead, these connections directly reach their intended internal destinations, typically due to technical requirements or performance considerations.

2. **🟨 OS HTTP traffic that cannot use Arc proxy and must be sent to your enterprise proxy or firewall**  
   HTTP traffic incompatible with the Arc proxy. This traffic must instead be routed through your organization's existing enterprise proxy or firewall infrastructure, ensuring compliance with internal security policies.

3. **🟩 OS HTTPS traffic that always uses Arc proxy**  
   HTTPS traffic that must always be routed through the Arc proxy. This ensures secure, controlled, and consistent connectivity to Azure endpoints, leveraging the Arc gateway's built-in security and management capabilities.

4. **🟥 Third-party OS HTTPS traffic not permitted through Arc gateway**
   All HTTPS traffic from the operating system initially goes to the Arc proxy. However, the Arc gateway only permits connections to Microsoft-managed endpoints. This means that HTTPS traffic destined for third-party services—such as OEM endpoints, hardware vendor update services, or other third-party agents installed on your servers—cannot pass through the Arc gateway. Instead, this traffic is redirected to your organization's enterprise proxy or firewall. To ensure these third-party services function correctly, you must explicitly configure your firewall or proxy to allow access to these external endpoints based on your organization's requirements.

5. **📘 Arc Resource Bridge VM and AKS Clusters using Azure Local Instance cluster IP as proxy**
   Azure Arc Resource Bridge is a Kubernetes-based management solution deployed as a virtual appliance (also called the Arc appliance) on your on-premises infrastructure. Its main purpose is to enable your local resources to appear and be managed as Azure resources through Azure Resource Manager (ARM). To achieve this, the Arc Resource Bridge requires outbound connectivity to specific Azure endpoints. In an Azure Local environment, this outbound traffic is routed through the Cluster IP as proxy, which then securely forwards the traffic through the Arc gateway tunnel established by your Azure Local nodes. This approach simplifies network configuration, enhances security, and ensures compliance with your organization's network policies.
   Also, when deploying AKS cluster in Azure Local, by default the control plane VM and the pods will also use the Cluster IP as proxy to send the outbound traffic through the Arc gateway. However, for some services running inside your AKS clusters you might also need to allow additional endpoints that will be send directly to your firewall. 


## Traffic Flow Scenarios

### 1. Azure Local Node OS Traffic Bypassing the Proxy

This diagram illustrates traffic from Azure Local nodes that bypasses the Arc proxy entirely. Typical scenarios include:

- Internal communications within your local intranet.
- Node-to-node communications within the Azure Local cluster.
- Traffic destined for internal management or monitoring systems.

This traffic is sent directly to internal endpoints without passing through the Arc gateway or external proxies, ensuring low latency and efficient internal communication.

When defining your proxy bypass string for your Arc initialization script or when using the Companion App make sure your meet the following conditions:

- At least the IP address of each Azure Local machine.
- At least the IP address of the Cluster.
- At least the IPs you defined for your infrastructure network. Arc Resource Bridge, AKS, and future infrastructure services using these IPs require outbound connectivity.
- Or you can bypass the entire infrastructure subnet.
- NetBIOS name of each machine.
- NetBIOS name of the Cluster.
- Domain name or domain name with asterisk * wildcard at the beginning to include any host or subdomain.  For example, 192.168.1.* for subnets or *.contoso.com for domain names.
- Parameters must be separated with comma ,.
- CIDR notation to bypass subnets isn't supported.
- The use of <local> strings isn't supported in the proxy bypass list.

![Azure Local Node OS Traffic Bypassing Proxy](./images/AzureLocalPublicPathFlowsFinal-1Node-Step1-BypassFlows.dark.svg)

---

### 2. Azure Local Node OS HTTP Traffic via Enterprise Proxy or Firewall

This diagram shows how standard HTTP (non-HTTPS) traffic from Azure Local nodes is managed:

- If an enterprise proxy is configured, HTTP traffic routes through this proxy. Make sure you don't use a .local domain as your proxy server name. For example it is not supported to use proxy.local:8080 as proxy server. Use the proxy server IP instead if your proxy belongs to a .local domain.
- If no enterprise proxy is configured, HTTP traffic is sent directly to your firewall, where your organization's security policies determine whether the traffic is allowed or blocked.

This ensures standard HTTP traffic aligns with your existing security infrastructure.

![Azure Local Node OS HTTP Traffic](./images/AzureLocalPublicPathFlowsFinal-1Node-Step2-HTTPFlows.dark.svg)

---

### 3. Azure Local Node OS HTTPS Traffic via Arc Proxy

This diagram explains how HTTPS traffic from Azure Local nodes is securely routed:

- HTTPS traffic destined for allowed Azure endpoints routes through the Arc proxy running on each node. Make sure you allowed your Arc gateway URL in your proxy and/or firewall.
- The Arc proxy establishes a secure HTTPS tunnel to the Arc gateway public endpoint hosted in Azure.
- Traffic not allowed by the Arc proxy (non-approved endpoints) is redirected to your firewall/proxy for further inspection or blocking.

This ensures secure, controlled, and compliant outbound HTTPS connectivity.

![Azure Local Node OS HTTPS Traffic](./images/AzureLocalPublicPathFlowsFinal-1Node-Step3-HTTPSFlows.dark.svg)

---

### 4. Azure Resource Bridge Appliance VM HTTPS Traffic via Cluster IP Proxy

This diagram illustrates HTTPS traffic handling for the Azure Resource Bridge (ARB) appliance VM:

- ARB appliance VM sends HTTPS traffic through a Cluster IP proxy.
- The Cluster IP proxy securely routes allowed traffic through the Arc gateway's HTTPS tunnel to Azure.
- Non-allowed traffic is redirected to your firewall/proxy for security enforcement.

This ensures ARB appliance VM traffic is securely managed and compliant with your organization's policies.

![ARB Appliance VM HTTPS Traffic](./images/AzureLocalPublicPathFlowsFinal-1Node-Step4-ARBFlows.dark.svg)

---

### 5. AKS Clusters HTTPS Traffic via Cluster IP Proxy

This diagram shows HTTPS traffic handling for Azure Kubernetes Service (AKS) clusters within Azure Local:

- This scenario represents AKS cluster running on the same subnet used for Azure Local infrastructure. If AKS cluster is running on a separated subnet, please check the next scenario 5bis.
- AKS cluster Control Plane VM routes HTTPS traffic through the Cluster IP proxy on port 40343.
- AKS Worker Node VM routes HTTPS traffic through the Cluster IP proxy on port 40343.
- The Cluster IP proxy securely forwards allowed traffic through the Arc gateway's HTTPS tunnel to Azure endpoints.
- AKS Pods creates the Arc gateway connection to route HTTPS traffic over the Arc gateway HTTP connect tunnel.
- Traffic not permitted by the Arc gateway is sent to your firewall/proxy for further security checks.

This ensures AKS clusters maintain secure and compliant outbound connectivity.

![AKS Clusters HTTPS Traffic](./images/AzureLocalPublicPathFlowsFinal-1Node-Step5-AKSFlows.dark.svg)

---

### 5 bis. AKS Clusters on separated subnet from Infra subnet

The diagram below shows HTTPS traffic handling and firewall requirements for Azure Kubernetes Service (AKS) cluster when running on separated subnet from the Azure Local infrastructure subnet. The example below represents how each type of TCP and HTTPS traffic from AKS subnet is being routed to help security teams to understand what ports or FQDN endpoints must be opened in their firewall or/and proxy that is filtering traffic from AKS subnet to infrastructure subnet and internet.

#### Firewall requirements for traffic between AKS subnet and Azure Local infrastructure subnet (light blue 📘 and light yellow arrows 📒)

1. AKS subnet must have access to Azure Local Cluster IP on port 40343.
   - Firewall must be configured to allow this traffic in both L4 and L7 for HTTPS and HTTP Connect. (light blue arrow).
2. AKS subnet must have access to Azure Local Cluster IP on port 55000.
   - Firewall must be configured to allow this TCP traffic. (light blue arrow).
3. AKS subnet must have access to Azure Local Cluster IP on port 65000.
   - Firewall must be configured to allow this TCP traffic. (light light arrow).
4. Bidirectional traffic from AKS subnet to Azure Local infra subnet and vice versa must access TCP port 22.
   - Firewall must be configured to allow this traffic. (light yellow arrows).
5. Bidirectional traffic from AKS subnet to Azure Local infra subnet and vice versa must access TCP port 6443.
   - Firewall must be configured to allow this traffic. (light yellow arrows).

For additional information about these required firewall rules please check the following AKS article: [AKS subnet required ports when using Arc gateway](https://learn.microsoft.com/en-us/azure/aks/aksarc/network-system-requirements?branch=main&branchFallbackFrom=pr-en-us-18420#network-port-and-cross-vlan-requirements)

#### Firewall requirements on AKS subnet for HTTPS traffic not supported by Arc gateway (Pink arrow traffic 🟥)

Although when running Arc gateway on the Azure Local hosts and AKS reduces the amount of HTTPS endpoints required to be opened on the AKS subnet, it is still required to allow access to those endpoints that are not supported by Arc gateway. Please check the following article for a comprehensive list of FQDN endpoints required for AKS on a separated subnet, when using Arc gateway [AKS subnet required FQDN endpoints when using Arc gateway](https://learn.microsoft.com/en-us/azure/aks/aksarc/arc-gateway-aks-arc#confirm-access-to-required-urls)

![AKS Clusters on separated subnet](./images/AzureLocalPublicPathFlowsFinal-AKSSubnetFirewallRequirements.dark.svg)

---

### 6. Azure Local VMs HTTPS Traffic via Dedicated Arc Proxy

This diagram explains HTTPS traffic handling for Azure Local virtual machines (VMs):

- Each Azure Local VM uses its own dedicated Arc proxy to route HTTPS traffic.
- Allowed HTTPS traffic is securely tunneled through the Arc gateway to Azure public endpoints.
- Non-allowed traffic is redirected to your firewall/proxy for security enforcement.
- If Azure Local VMs are running on a separated subnet from the infrastructure you will need to configure the firewall/proxy to allow the traffic from that subnet.

This ensures Azure Local VMs have secure, controlled, and compliant outbound connectivity.

![Azure Local VMs HTTPS Traffic](./images/AzureLocalPublicPathFlowsFinal-1Node-Step6-VMFlows.dark.svg)

---

## Summary of the Overall Connectivity Model

- **Allowed HTTPS traffic** is securely tunneled through the Arc gateway, significantly reducing firewall rules required (fewer than 30 endpoints).
- **Non-allowed traffic** (highlighted in pink in diagrams) is redirected to your organization's firewall/proxy for inspection and enforcement.
- **Internal traffic** bypasses proxies entirely, ensuring efficient local communication.

This structured approach simplifies network management, enhances security, and ensures compliance with organizational policies.