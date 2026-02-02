# AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNSClientServerAddress_Readiness

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNSClientServerAddress_Readiness</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment (without ArcGateway), Upgrade (without ArcGateway)</strong></td>
  </tr>
</table>

## Overview

This validator checks that DNS client server addresses are properly configured on the management adapter. DNS servers are required for the validator to test infrastructure IP connectivity to public Azure endpoints.

## Requirements

1. DNS client server addresses must be configured on the management adapter
2. At least one DNS server IP must be available
3. DNS servers must be accessible for connectivity testing

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information.

```json
{
  "Name": "AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNSClientServerAddress_Readiness",
  "DisplayName": "Test DNS client server addresses readiness for all IP in infra IP pool",
  "Title": "Test DNS client server addresses readiness for all IP in infra IP pool",
  "Status": 1,
  "Severity": 2,
  "Description": "Test DNS client server addresses readiness for all IP in infra IP pool",
  "Remediation": "Set DNS client server address correctly on management adapter [ vManagement(ManagementIntent) ] on SERVER01. Check it using Get-DnsClientServerAddress",
  "TargetResourceID": "Infra_IP_Connection_DNSClientReadiness",
  "TargetResourceName": "Infra_IP_Connection_DNSClientReadiness",
  "TargetResourceType": "Infra_IP_Connection_DNSClientReadiness",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "SERVER01",
    "Resource": "DNSClientReadiness",
    "Detail": "[FAILED] Cannot find correctly DNS client server address on host SERVER01.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: DNS Client Server Address Not Found

**Error Message:**
```text
[FAILED] Cannot find correctly DNS client server address on host SERVER01.
```

**Root Cause:** No DNS server addresses are configured on the management adapter, or the validator cannot retrieve them. DNS servers are required to resolve public endpoint names during infrastructure IP connectivity testing.

#### Remediation Steps

##### 1. Check Current DNS Configuration

Verify DNS settings on management adapters:

```powershell
# Check DNS servers on all adapters
Get-DnsClientServerAddress -AddressFamily IPv4 |
    Where-Object { $_.ServerAddresses.Count -gt 0 } |
    Format-Table InterfaceAlias, ServerAddresses -AutoSize

# Check specifically on management adapter
$mgmtAdapter = Get-NetAdapter -Name "myAdapter" # Replace with your actual adapter name in the system

if ($mgmtAdapter) {
    Write-Host "Management Adapter: $($mgmtAdapter.Name)" -ForegroundColor Cyan
    $dnsServers = Get-DnsClientServerAddress -InterfaceAlias $mgmtAdapter.Name -AddressFamily IPv4
    Write-Host "DNS Servers: $($dnsServers.ServerAddresses -join ', ')" -ForegroundColor White
} else {
    Write-Host "No management adapter found" -ForegroundColor Red
}
```

##### 2. Configure DNS Servers

Set DNS server addresses on the management adapter:

```powershell
# Set DNS servers on management adapter
$mgmtAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*vManagement*" } | Select-Object -First 1

if ($mgmtAdapter) {
    # Example: Set DNS servers (replace with your actual DNS server IPs)
    $dnsServers = @("192.168.1.100", "192.168.1.101")  # Replace with your DNS servers

    Set-DnsClientServerAddress -InterfaceAlias $mgmtAdapter.Name -ServerAddresses $dnsServers

    # Verify configuration
    Get-DnsClientServerAddress -InterfaceAlias $mgmtAdapter.Name -AddressFamily IPv4 |
        Select-Object InterfaceAlias, ServerAddresses

    Write-Host "✓ DNS servers configured successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Management adapter not found" -ForegroundColor Red
}
```
##### 3. Test DNS Resolution

Verify DNS is working:

```powershell
# Test DNS resolution
$testDomains = @("microsoft.com", "azure.com", "portal.azure.com")

foreach ($domain in $testDomains) {
    try {
        $result = Resolve-DnsName $domain -ErrorAction Stop
        Write-Host "✓ Successfully resolved $domain" -ForegroundColor Green
        Write-Host "  IP: $($result[0].IPAddress)" -ForegroundColor White
    } catch {
        Write-Host "✗ Failed to resolve $domain" -ForegroundColor Red
    }
}
```

##### 4. Check DNS Server Connectivity

Verify the configured DNS servers are reachable:

```powershell
$mgmtAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*vManagement*" } | Select-Object -First 1
$dnsConfig = Get-DnsClientServerAddress -InterfaceAlias $mgmtAdapter.Name -AddressFamily IPv4

foreach ($dnsServer in $dnsConfig.ServerAddresses) {
    Write-Host "`nTesting DNS server: $dnsServer" -ForegroundColor Cyan

    # Test ping
    $ping = Test-Connection -ComputerName $dnsServer -Count 2 -Quiet
    if ($ping) {
        Write-Host "  ✓ Ping successful" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Ping failed" -ForegroundColor Red
    }

    # Test port 53 (DNS)
    $tcpTest = Test-NetConnection -ComputerName $dnsServer -Port 53 -InformationLevel Quiet
    if ($tcpTest) {
        Write-Host "  ✓ Port 53 (DNS) accessible" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Port 53 (DNS) not accessible" -ForegroundColor Red
    }
}
```

##### 5. Check Firewall Rules

Ensure firewall is not blocking DNS:

```powershell
# Check DNS Client firewall rule
Get-NetFirewallRule -DisplayName "*DNS*" | Where-Object { $_.Enabled -eq $true } |
    Select-Object DisplayName, Direction, Action, Enabled |
    Format-Table -AutoSize

# Ensure DNS Client rule is enabled
Enable-NetFirewallRule -DisplayGroup "Network Discovery"
```

##### 6. Retry the Validation

After configuring DNS servers, re-run the Environment Validator.

---

## Additional Information

### Why DNS is Required

The infrastructure IP connectivity validator needs DNS to:

1. **Resolve public Azure endpoint names** - Endpoints like `management.azure.com`, `login.microsoftonline.com`
2. **Test name resolution** - Validates infrastructure IPs can reach DNS servers
3. **Verify end-to-end connectivity** - From infrastructure IP → DNS → Public endpoint

### DNS Server Requirements

For Azure Local deployments:

| Deployment Type | DNS Requirements |
|----------------|------------------|
| **Static IP** | Must manually configure DNS servers on management adapter |
| **DHCP** | DNS servers should be provided by DHCP server |
| **Domain-joined** | Use domain DNS servers (typically domain controllers) |
| **Workgroup** | Use corporate DNS servers or public DNS (e.g., 8.8.8.8) |

### Recommended DNS Server Configuration

**For production deployments:**
- Use at least 2 DNS servers for redundancy
- DNS servers should be internal corporate DNS that can resolve public names
- DNS servers must be reachable from infrastructure IP pool

**Example configurations:**
```powershell
# Domain-joined (recommended)
$dnsServers = @("10.0.0.1", "10.0.0.2")  # Domain controllers

# Workgroup with corporate DNS
$dnsServers = @("192.168.1.10", "192.168.1.11")  # Corporate DNS servers

# Testing only (not recommended for production)
$dnsServers = @("8.8.8.8", "8.8.4.4")  # Google Public DNS
```
### Common DNS Configuration Issues

#### Issue: DNS servers configured but not working

**Solution:**
```powershell
# Flush DNS cache
Clear-DnsClientCache

# Reset DNS client
Restart-Service Dnscache

# Test again
Resolve-DnsName microsoft.com
```

#### Issue: DNS servers not accessible from infrastructure IPs

**Solution:**
- Ensure DNS servers are on a routable network from infrastructure IP subnet
- Check firewall rules between infrastructure IP pool and DNS servers
- Verify routing tables allow traffic to DNS servers
- Test connectivity using `Test-NetConnection -ComputerName <DNSServer> -Port 53`

### DNS and Infrastructure IP Pool

The infrastructure IP pool must be able to reach DNS servers:

```
Infrastructure IP Pool (e.g., 10.0.0.100-10.0.0.150)
           ↓
       Default Gateway
           ↓
       DNS Servers (e.g., 192.168.1.100)
           ↓
       Public Internet / Azure Endpoints
```

Ensure:
- Infrastructure IPs can reach default gateway
- Default gateway can route to DNS servers
- DNS servers can resolve public names

### Prerequisites for This Validator

This validator requires:
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_Hyper_V_Readiness** - Hyper-V installed
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_VMSwitch_Readiness** - Virtual switch exists
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_MANAGEMENT_VNIC_Readiness** - Management vNIC exists
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_vNIC_Readiness** - Test vNIC can be created

### Related Validators

Validators that run after this validator:
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_IPReadiness** - Tests infrastructure IP assignment
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNS_Server_Port_53** - Tests DNS port 53 connectivity

### Related Documentation

- [Azure Local host network requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/host-network-requirements)
- [Firewall requirements for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/concepts/firewall-requirements)
