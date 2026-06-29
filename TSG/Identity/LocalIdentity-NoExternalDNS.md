# Azure Local Deployment with Local Identity (No External DNS)

Azure Local Deployment with Local Identity Supports deployment without Active Directory and No External DNS within the local network.

In the DNS Service configuration during Azure Local Deployment, there are 2 options:
- Yes - there is an existing DNS
- No - thjere is NO existing DNS

![DNS Service Configuration](dnsService.png)

When there is **NO** existing DNS, the initial network validation will depends on mDNS service to resolve the hostname to IP address for the selected server nodes. The Zone Name intended for the Azure Local Deployment may be different from the existing DNS Suffix defaulted on the network interface. The DNS Suffix can be:

1) Empty - mDNS service will append ".LOCAL" to the hostname as the FQDN
2) Gateway/Router provided DNS Suffix - the local network will pick up the DNS Suffix from the internet facing gateway default. This DNS Suffix can be internet service provider specific and different from the intended Zone Name.
3) User Specific DNS Suffix - User can specify a DNS Suffix on the network interface, or if they can update the gateway/router default to the Zone name specified in the DNS Service configuration during Azure Local Deployment.

With (1) and (2), the Azure local deployment will fail on the deployment validation since the network DNS Suffix is different from the one entered in the DNS Service configuration.

User should prepare as in (3), setting up the local network gateway or the server node network interface with the intended DNS Suffix before proceeding with deployment.


