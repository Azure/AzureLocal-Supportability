# AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNS_Server_Port_53

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNS_Server_Port_53</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong> (or <strong>Warning</strong> if proxy is enabled): This validator will block operations until remediated, or provide a warning if proxy is configured.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment (without ArcGateway), Upgrade (without ArcGateway)</strong></td>
  </tr>
</table>

## Overview

This validator tests TCP connectivity from infrastructure pool IPs to DNS servers on port 53. This ensures that services running on infrastructure IPs will be able to perform DNS name resolution for accessing Azure services and other resources.

## Requirements

1. Infrastructure IPs must be able to reach DNS servers on TCP port 53
2. DNS servers must be configured and accessible
3. Network path must allow DNS traffic from infrastructure IPs
4. Firewall rules must permit DNS queries (TCP port 53)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field.

```json
{
  "Name": "AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNS_Server_Port_53",
  "DisplayName": "Test DNS server port connection for all IP in infra IP pool",
  "Title": "Test DNS server port connection for all IP in infra IP pool",
  "Status": 1,
  "Severity": 2,
  "Description": "Test DNS server port connection for all IP in infra IP pool",
  "Remediation": "Make sure infra IP 10.0.0.100 could connect to your DNS server correctly.",
  "TargetResourceID": "Infra_IP_Connection_DNS_Connection_10.0.0.100",
  "TargetResourceName": "Infra_IP_Connection_DNS_Connection_10.0.0.100",
  "TargetResourceType": "Infra_IP_Connection_DNS_Connection_10.0.0.100",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "SERVER01",
    "Resource": "10.0.0.100-Ethernet",
    "Detail": "[FAILED] Connection from 10.0.0.100 (via physical adapter Ethernet) to DNS server port 53 failed after 3 attempts. DNS server used: 192.168.1.100 192.168.1.101",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Cannot Connect to DNS Server Port 53

**Error Message:**
```text
[FAILED] Connection from 10.0.0.100 (via physical adapter Ethernet) to DNS server port 53 failed after 3 attempts. DNS server used: 192.168.1.100 192.168.1.101
```

**Root Cause:** Infrastructure IP cannot establish TCP connection to DNS servers on port 53. Possible causes:
- DNS servers are not reachable from infrastructure IP subnet
- Firewall blocking DNS traffic
- DNS servers not listening on TCP port 53
- Network routing issues
- DNS servers offline or misconfigured

#### Remediation Steps

##### 1. Verify DNS Server Configuration

Check which DNS servers are being tested:

```powershell
# Get DNS servers configured on management adapter
$mgmtAdapter = Get-NetAdapter -Name "MyAdapterName" # Replace with the actual name in the system
$dnsServers = (Get-DnsClientServerAddress -InterfaceAlias $mgmtAdapter.Name -AddressFamily IPv4).ServerAddresses

Write-Host "DNS Servers configured:" -ForegroundColor Cyan
$dnsServers | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
```

##### 2. Test DNS Server Connectivity from Management IP

First verify DNS works from management IP:

```powershell
# Test from management IP
$mgmtIP = (Get-NetIPAddress -InterfaceAlias $mgmtAdapter.Name -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "169.254.*" }).IPAddress

Write-Host "Testing from management IP: $mgmtIP" -ForegroundColor Cyan

foreach ($dnsServer in $dnsServers) {
    Write-Host "`nTesting DNS server: $dnsServer" -ForegroundColor Yellow

    # Ping test
    $ping = Test-Connection -ComputerName $dnsServer -Count 2 -Quiet
    Write-Host "  Ping: $(if ($ping) { '✓ Success' } else { '✗ Failed' })" -ForegroundColor $(if ($ping) { 'Green' } else { 'Red' })

    # TCP Port 53 test
    $tcpTest = Test-NetConnection -ComputerName $dnsServer -Port 53 -InformationLevel Quiet
    Write-Host "  Port 53 (TCP): $(if ($tcpTest) { '✓ Open' } else { '✗ Closed/Filtered' })" -ForegroundColor $(if ($tcpTest) { 'Green' } else { 'Red' })

    # UDP Port 53 test (typical DNS)
    # Note: Test-NetConnection doesn't support UDP well, but DNS primarily uses UDP
    try {
        $dnsResolve = Resolve-DnsName microsoft.com -Server $dnsServer -ErrorAction Stop
        Write-Host "  DNS Resolution: ✓ Working" -ForegroundColor Green
    } catch {
        Write-Host "  DNS Resolution: ✗ Failed" -ForegroundColor Red
    }
}
```

##### 3. Check Routing from Infrastructure IP Subnet

Verify routing configuration:

```powershell
# Check routing table
Get-NetRoute | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } |
    Format-Table DestinationPrefix, NextHop, InterfaceAlias, RouteMetric -AutoSize

# For infrastructure IP subnet, verify gateway can reach DNS servers
$infraGateway = "10.0.0.1"  # Your infrastructure IP gateway
$dnsServer = "192.168.1.100"  # Your DNS server

Write-Host "`nChecking if gateway $infraGateway can reach DNS server $dnsServer" -ForegroundColor Cyan
# This assumes you can access the gateway - may need to check on gateway device
```

##### 4. Check Firewall Rules

Verify DNS traffic is allowed:

```powershell
# Check Windows Firewall rules for DNS
Get-NetFirewallRule -DisplayName "*DNS*" | Where-Object { $_.Enabled -eq $true } |
    Select-Object DisplayName, Direction, Action, Enabled |
    Format-Table -AutoSize

# Check if DNS Client service is running
Get-Service Dnscache | Select-Object Name, Status, StartType

# Enable DNS client firewall rule if needed
Enable-NetFirewallRule -DisplayGroup "Network Discovery"
```

##### 5. Verify DNS Servers Are Operational

Check DNS server status:

```powershell
foreach ($dnsServer in $dnsServers) {
    Write-Host "`nDNS Server: $dnsServer" -ForegroundColor Cyan

    # Test basic connectivity
    $reachable = Test-Connection -ComputerName $dnsServer -Count 1 -Quiet
    if (-not $reachable) {
        Write-Host "  ✗ DNS server is not reachable" -ForegroundColor Red
        continue
    }

    # Test DNS service is listening
    $portOpen = Test-NetConnection -ComputerName $dnsServer -Port 53 -WarningAction SilentlyContinue
    if ($portOpen.TcpTestSucceeded) {
        Write-Host "  ✓ DNS service is listening on port 53" -ForegroundColor Green
    } else {
        Write-Host "  ✗ DNS service is NOT listening on port 53" -ForegroundColor Red
        Write-Host "    Check DNS server configuration and service status" -ForegroundColor Yellow
    }

    # Test actual DNS resolution
    try {
        $result = Resolve-DnsName -Name "microsoft.com" -Server $dnsServer -ErrorAction Stop
        Write-Host "  ✓ DNS resolution is working" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ DNS resolution failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

##### 6. Check Network Path Between Infrastructure IP and DNS

Verify network connectivity path:

```powershell
# Trace route from management IP to DNS server (as a proxy for infrastructure IP path)
$dnsServer = $dnsServers[0]
Write-Host "Tracing route to DNS server $dnsServer..." -ForegroundColor Cyan
Test-NetConnection -ComputerName $dnsServer -TraceRoute |
    Select-Object -ExpandProperty TraceRoute
```

**Network path requirements:**
- Infrastructure IP subnet → Default Gateway → DNS Server subnet
- All routers/firewalls in path must allow DNS traffic (port 53 TCP/UDP)
- VLANs must be properly configured and routed

##### 7. Test with Manual Connection from Infrastructure IP

If possible, manually test from an infrastructure IP:

```powershell
# This requires temporarily assigning an infrastructure IP to test with
$testIP = "10.0.0.100"  # Infrastructure IP
$dnsServer = "192.168.1.100"  # Your DNS server

# Use Test-NetConnection with specific source if possible
# Note: Windows doesn't directly support source IP specification in Test-NetConnection
# The validator uses curl.exe internally with --interface parameter

# Alternative: Use PowerShell TCP client
$tcpClient = New-Object System.Net.Sockets.TcpClient
try {
    $tcpClient.Connect($dnsServer, 53)
    if ($tcpClient.Connected) {
        Write-Host "✓ Successfully connected to $dnsServer :53" -ForegroundColor Green
        $tcpClient.Close()
    }
} catch {
    Write-Host "✗ Failed to connect to $dnsServer :53" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}
```

##### 8. If Using Proxy

If proxy is enabled, DNS connectivity failure is downgraded to WARNING severity:

**Why:** When proxy is configured, DNS resolution may happen on the proxy server rather than from the infrastructure IP directly.

**Considerations:**
- Proxy must be configured to handle DNS requests
- Proxy must be reachable from infrastructure IPs
- Some Azure services may require direct DNS connectivity even with proxy

**Check proxy configuration:**
```powershell
# Check proxy settings
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" |
    Select-Object ProxyEnable, ProxyServer

# Check WinHTTP proxy
netsh winhttp show proxy
```

##### 9. Retry the Validation

After fixing DNS connectivity issues, re-run the Environment Validator.

---

## Additional Information

### Why DNS Port 53 Connectivity Is Important

Azure Local services running on infrastructure IPs need DNS for:

1. **Azure service endpoint resolution** - Resolving names like `management.azure.com`, `login.microsoftonline.com`
2. **Certificate validation** - Accessing CRL/OCSP endpoints for certificate validation
3. **Service discovery** - Finding other cluster services and resources
4. **Monitoring and telemetry** - Sending data to Azure monitoring endpoints

### TCP vs UDP for DNS

DNS typically uses:
- **UDP port 53** - Primary protocol for DNS queries (fast, lightweight)
- **TCP port 53** - Used for large responses, zone transfers, and some security features

The validator tests **TCP port 53** because:
- More reliable for connectivity testing
- Required for DNSSEC and large responses
- Indicates DNS server is fully operational

### Retry Logic

The validator attempts DNS connectivity **10 times** (configurable via retryTimes parameter) before reporting failure:
- Each attempt tests TCP connection to port 53
- Short delays between retries
- Tests against all configured DNS servers
- Stops on first successful connection

### Severity Levels

| Configuration | Severity | Reason |
|--------------|----------|--------|
| **No proxy** | CRITICAL | DNS connectivity is essential |
| **Proxy enabled** | WARNING | DNS may be handled by proxy |

### Infrastructure IP → DNS Path

```
Infrastructure IP (10.0.0.100)
        ↓
    vNIC on Virtual Switch
        ↓
    Physical Adapter (Ethernet)
        ↓
    Network Switch/Router
        ↓
    Default Gateway (10.0.0.1)
        ↓
    Network Infrastructure
        ↓
    DNS Server (192.168.1.100) Port 53
```

Each hop must allow and route DNS traffic correctly.

### Common DNS Connectivity Issues

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Firewall blocking** | Timeout on port 53 | Allow DNS in firewall rules |
| **DNS server offline** | No response | Check DNS server status |
| **Routing issue** | Cannot reach DNS subnet | Fix routing tables/gateway config |
| **Wrong DNS IPs** | Connection refused | Verify DNS server IPs are correct |
| **VLAN misconfiguration** | Intermittent failures | Check VLAN settings on switches |
| **DNS service not running** | Port closed | Start DNS service on DNS server |

### Alternative DNS Testing Tools

For advanced troubleshooting:

```powershell
# nslookup with specific DNS server
nslookup microsoft.com 192.168.1.100

# Resolve-DnsName with specific server
Resolve-DnsName -Name microsoft.com -Server 192.168.1.100 -Type A

# Test DNS port with Test-NetConnection
Test-NetConnection -ComputerName 192.168.1.100 -Port 53

### DNS Server Requirements

For Azure Local deployments:

| DNS Server Type | Requirements |
|----------------|--------------|
| **Domain Controllers** | Must be reachable from infrastructure IPs |
| **Corporate DNS** | Must resolve external/public names |
| **Public DNS** | Use only for testing (not recommended for production) |
| **Forwarders** | Must be configured if internal DNS does not resolve public names |


**Best practice**: Use at least 2 DNS servers for redundancy.

### Prerequisites for This Validator

Requires these validators to pass first:
- Hyper-V Readiness
- VMSwitch Readiness
- Management vNIC Readiness
- Test vNIC Readiness
- DNS Client Readiness
- **IP Readiness** - Infrastructure IP must be configured and reach gateway

### Related Validators

After this validator passes, the validator tests connectivity to Azure endpoints (if DNS passed).

### Related Documentation

- [DNS requirements](https://learn.microsoft.com/windows-server/networking/dns/dns-top)
- [Azure Local firewall requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/firewall-requirements)
- [Network requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/host-network-requirements)
