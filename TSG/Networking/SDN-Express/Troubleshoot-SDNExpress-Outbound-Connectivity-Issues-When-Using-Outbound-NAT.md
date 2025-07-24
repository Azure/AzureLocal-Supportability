# Azure Local - Troubleshoot Outbound Network Connectivity when using Outbound NAT

You have deployed Virtual Machines into a Virtual Network and have created an outbound NAT pool to provide native outbound access to the internet. 
In some situations, you may notice that traffic is not working properly when making outbound calls.

# Issue Validation
To confirm the scenario that you are encountering is the issue documented in this article, you can follow the validation steps below:
1. You have workloads deployed on a Virtual Network.
2. You have workloads added to an backend pool that have outbound NAT rules configured.
3. One of the following scenarios is applicable:
    - Scenario 1: You have deployed a Virtual Network with a local DNS server deployed that has external DNS Forwarders configured to point to your datacenter or public DNS endpoint. VMs deployed to the Virtual Network that 
leverage your DNS server. There is no Gateway Connection that traffic is flowing through, or the DNS endpoint is not included in the routes defined within the Gateway Connection.
    - Scenario 2: You have deployed VMs into the Virtual Network that are using a public DNS endpoint. There is no Gateway Connection that traffic is flowing through, or the DNS endpoint is not included in the routes defined within the Gateway Connection.

In addition, if you examine the VFP rules for a VM that is impacted, you will only see a single `dynnat` entry for the protocol. In the screenshot below, only protocol 6 (TCP) exists.

<img width="998" height="114" alt="image" src="https://github.com/user-attachments/assets/18c03b2a-440e-4c34-b508-48d3dcf213d7" />

To confirm which rules are programmed, perform the following steps using cmdlets available in [SdnDiagnostics PowerShell Module]().
1. RDP into the Hyper-V host where the VM you are troubleshooting is located.
1. Determine the port profile for the VM Network Adapter: `Get-SdnVMNetworkAdapterPortProfile -VMName 'Contoso-VM1'`
1. Examine the current VFP policies: `Show-SdnVfpPortConfig -PortName <PortName_From_Previous_Command> -Type IPv4 -Direction OUT`
    - Alternatively, you can leverage `Get-SdnVfpPortRule -PortName <PortName_From_Previous_Command> -Layer "SLB_NAT_LAYER" -Group "SLB_GROUP_NAT_IPv4_OUT"`

# Cause
In this situation, you may not have the proper protocols defined for the outbound NAT rule. If you have a rule configured for TCP, any UDP related traffic will not be NATed properly, resulting in packet being dropped. 

> NOTE: There is a known issue with NetworkController that results in only the first Outbound NAT rule working. Any additional Outbound NAT rules configured will not take effect.

# Mitigation Details
Ensure that your Outbound NAT rule has `Protocol = 'All'` defined. 
> NOTE: WAC does not currently expose the ability to configure `All` for protocol and only allows you to define `TCP` or `UDP`. 

## Update resource using PowerShell
Install or update SdnDiagnostics module. Refer to [Install the SDN diagnostics PowerShell module on the client computer](https://learn.microsoft.com/en-us/azure/azure-local/manage/sdn-log-collection#install-the-sdn-diagnostics-powershell-module-on-the-client-computer) for instructions.

```powershell
$ncUri = 'https://nc.contoso.com'
$loadBalancer = 'loadbalancer1'
$outboundNatRule = 'outboundnatrule1'

$object = Get-SdnResource -NcUri $ncUri -ResourceRef "/loadBalancers/$loadBalancer/outboundNatRules/$outboundNatRule"
if ($object) {
    $object.properties.protocol = "All"
    Set-SdnResource -NcUri $ncUri -ResourceRef $object.resourceRef -Object $object
}
```

After performing the operation, perform the steps in [Issue Validation](#issue-validation) to confirm you see `dynnat` rule for protocol 6 (TCP) and 17 (UDP).

<img width="1002" height="156" alt="image" src="https://github.com/user-attachments/assets/029b9bf5-1ce8-415d-86b6-ab120424e7f0" />





