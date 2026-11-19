# AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_{ServiceName}

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_{ServiceName}</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical or Warning</strong>: Severity varies by service. Most are Critical, some are Warning.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment (without ArcGateway), Upgrade (without ArcGateway)</strong></td>
  </tr>
</table>

## Overview

This is a **dynamically generated validator** that tests connectivity from infrastructure pool IPs to specific Azure and Arc-enabled services endpoints. The validator name varies based on the service being tested (e.g., `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_AzureArc`, `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_AzureResourceManager`, etc.).

The validator uses `curl.exe` to test HTTP/HTTPS connectivity from each infrastructure IP to required service endpoints, ensuring that workloads running on infrastructure IPs can reach essential Azure services.

## Requirements

1. Infrastructure IP must be able to reach the service endpoint via HTTP/HTTPS
2. DNS resolution must work for the endpoint hostname
3. Network path must allow outbound connectivity to the service
4. Firewall rules must permit the required protocol and port
5. If proxy is configured, it must be functional and allow the connection

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. The validator name will include the specific service being tested. Check the `AdditionalData.Detail` field for connection details.

```json
{
  "Name": "AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_AzureArc",
  "DisplayName": "Test outbound connection for IP in infra IP pool to Azure Arc service",
  "Title": "Test outbound connection for IP in infra IP pool",
  "Status": 1,
  "Severity": 2,
  "Description": "Test outbound connection for IP in infra IP pool to Azure Arc service endpoints",
  "Remediation": "Make sure infra IP 10.0.0.100 could connect to public endpoint https://management.azure.com correctly. \nhttps://learn.microsoft.com/azure/azure-arc/servers/network-requirements?tabs=azure-cloud#urls",
  "TargetResourceID": "AzureArc_Connectivity",
  "TargetResourceName": "AzureArc_Connectivity",
  "TargetResourceType": "AzureArc_Connectivity",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "SERVER01",
    "Resource": "10.0.0.100-Ethernet",
    "Detail": "[FAILED] Connection from 10.0.0.100 (Ethernet) to https://management.azure.com failed after 10 attempts",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Cannot Connect to Azure Service Endpoint

**Error Message:**
```text
[FAILED] Connection from 10.0.0.100 (Ethernet) to https://management.azure.com failed after 10 attempts
```

**Root Cause:** The infrastructure IP cannot establish connectivity to the Azure service endpoint. Possible causes:
- Firewall blocking outbound HTTPS traffic
- Network path not allowing connectivity to Azure
- Proxy configuration issues (if proxy is used)
- DNS resolution failing for the endpoint
- Service endpoint unreachable or blocked by network policy

#### Remediation Steps

##### 1. Identify the Failing Service Endpoint

Check the validator name and error message to identify which service is failing:

```powershell
# Common service endpoints tested:
# - Azure Arc: management.azure.com, login.microsoftonline.com
# - Azure Resource Manager: management.azure.com
# - Azure Identity: login.microsoftonline.com, login.windows.net
# - Azure Storage: *.blob.core.windows.net
# - Azure Key Vault: *.vault.azure.net
# - Azure Monitor/Telemetry: *.ods.opinsights.azure.com

# The specific endpoint will be in the error detail
```

##### 2. Test DNS Resolution

Verify the endpoint hostname can be resolved:

```powershell
# Example: Test Azure Resource Manager endpoint
$endpoint = "management.azure.com"  # Replace with your failing endpoint

# Test DNS resolution
Resolve-DnsName $endpoint

# If resolution fails, check DNS servers and connectivity
# See: Troubleshoot-Network-Test-InfraIP-DNS-Client-Readiness.md
```

##### 3. Test Basic Connectivity from Management IP

First verify connectivity works from the management IP:

```powershell
# Test from management IP using Test-NetConnection
$endpoint = "management.azure.com"
Test-NetConnection -ComputerName $endpoint -Port 443 -InformationLevel Detailed

# Test using Invoke-WebRequest
try {
    $response = Invoke-WebRequest -Uri "https://$endpoint" -UseBasicParsing -TimeoutSec 10
    Write-Host "✓ Connection successful from management IP" -ForegroundColor Green
} catch {
    Write-Host "✗ Connection failed from management IP" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}
```

If management IP can't connect either, the issue is with the enterprise's network configuration, not specific to infrastructure IPs.

##### 4. Check Firewall Rules

Verify outbound HTTPS/HTTP traffic is allowed:

```powershell
# Check Windows Firewall for outbound rules
Get-NetFirewallRule -Direction Outbound -Enabled True |
    Where-Object { $_.DisplayName -like "*HTTP*" -or $_.DisplayName -like "*Web*" } |
    Select-Object DisplayName, Action, Enabled |
    Format-Table -AutoSize

# Check if outbound connections are blocked by default
Get-NetFirewallProfile | Select-Object Name, DefaultOutboundAction

# Most corporate environments allow outbound HTTPS (port 443)
# Check with network team if specific Azure IPs/domains need to be allowed
```

##### 5. Test with curl.exe (Same Tool as Validator)

Use curl.exe to test exactly as the validator does:

```powershell
# Test from any IP on the system (management IP)
$endpoint = "https://management.azure.com"
$curlCommand = "curl.exe -sS --connect-timeout 15 --max-time 20 `"$endpoint`" 2>&1"

Write-Host "Running: $curlCommand" -ForegroundColor Cyan
$result = Invoke-Expression $curlCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ curl.exe succeeded" -ForegroundColor Green
    Write-Host "Response (first 200 chars): $($result[0..200] -join '')" -ForegroundColor White
} else {
    Write-Host "✗ curl.exe failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "Error: $result" -ForegroundColor Yellow
}
```

**Common curl.exe exit codes:**
- `0` - Success
- `6` - Couldn't resolve host (DNS issue)
- `7` - Failed to connect (network issue)
- `28` - Timeout
- `35` - SSL/TLS handshake failed
- `60` - SSL certificate problem

##### 6. Check Proxy Configuration

**If your environment uses a proxy**
- Ensure proxy allows traffic to Azure endpoints
- Verify proxy authentication is working
- Check proxy can resolve Azure endpoint names
- Some proxies block non-standard ports (anything other than 80/443)

##### 7. Verify Azure Firewall Requirements

Ensure all required Azure endpoints are accessible. See the Azure Local firewall requirements documentation.

**Core required endpoints (examples):**
- `management.azure.com` - Azure Resource Manager
- `login.microsoftonline.com` - Azure AD authentication
- `*.blob.core.windows.net` - Azure Storage
- `*.servicebus.windows.net` - Azure Service Bus
- `*.vault.azure.net` - Azure Key Vault

**Check endpoint access:**
```powershell
$requiredEndpoints = @(
    "management.azure.com",
    "login.microsoftonline.com",
    "login.windows.net",
    "graph.windows.net",
    "*.blob.core.windows.net",  # Note: wildcards need actual hostname
    "*.servicebus.windows.net"
)

foreach ($endpoint in $requiredEndpoints) {
    if ($endpoint -like "*`**") {
        Write-Host "Wildcard endpoint: $endpoint (test with actual hostname)" -ForegroundColor Yellow
        continue
    }

    Write-Host "`nTesting: $endpoint" -ForegroundColor Cyan
    $test = Test-NetConnection -ComputerName $endpoint -Port 443 -InformationLevel Quiet
    if ($test) {
        Write-Host "  ✓ Port 443 accessible" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Port 443 NOT accessible" -ForegroundColor Red
    }
}
```

##### 8. Check Network Routing

Verify routing to Azure public IPs:

```powershell
# Check default route
Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Format-Table DestinationPrefix, NextHop, InterfaceAlias -AutoSize

# Trace route to Azure endpoint (from management IP)
Test-NetConnection -ComputerName management.azure.com -TraceRoute |
    Select-Object -ExpandProperty TraceRoute
```

Ensure:
- Default route exists and points to correct gateway
- Gateway has internet connectivity
- No routing policies block Azure IP ranges

##### 9. Review Service-Specific Documentation

Each Azure service may have specific requirements:

**Azure Arc:**
- See: [Azure Arc network requirements](https://learn.microsoft.com/azure/azure-arc/servers/network-requirements)
- Requires connectivity to multiple endpoints
- Uses Azure Resource Manager, Azure AD, and Arc-specific endpoints

**Azure Resource Manager:**
- Primary endpoint: `management.azure.com`
- Used for all ARM operations

**Azure Storage:**
- Wildcard endpoints: `*.blob.core.windows.net`, `*.table.core.windows.net`
- May need specific storage account names

**Azure Key Vault:**
- Wildcard: `*.vault.azure.net`
- May need specific vault names

##### 10. Test from Infrastructure IP (Advanced)

To test exactly as the validator does, you could need to temporarily assign an infrastructure IP and test the connection using that IP

> **Warning:** This requires network reconfiguration and may disrupt connectivity. Only perform in a test environment or during maintenance window.

##### 11. Temporary Workarounds

If you cannot immediately fix connectivity:

**Option 1: Use ArcGateway (if applicable)**
- ArcGateway provides an alternative connectivity method
- When enabled, infrastructure IP connectivity tests are skipped
- Check if your scenario supports ArcGateway

**Option 2: Adjust firewall rules temporarily**
- Work with network team to allow required Azure endpoints
- Document which endpoints are blocked
- Plan permanent solution

##### 12. Retry the Validation

After fixing connectivity issues, re-run the Environment Validator.

---

## Additional Information

### How Endpoint Connectivity Testing Works

For each infrastructure IP (up to 9 IPs tested):

1. **Prerequisites validated** (Hyper-V, vSwitch, DNS, etc.)
2. **IP assigned** to temporary test vNIC
3. **Gateway tested** (ICMP ping)
4. **DNS tested** (port 53 TCP)
5. **For each required Azure endpoint:**
   - curl.exe tests connection using `--interface <InfraIP>`
   - Tests both GET and HEADER requests
   - Retries up to 10 times (default)
   - Creates a result object with status

### curl.exe Command Format

The validator uses curl.exe with these parameters:

```bash
curl.exe -sS \
  --connect-timeout 15 \
  --max-time 20 \
  "https://management.azure.com" \
  --interface 10.0.0.100 \
  2>&1
```

Parameters:
- `-sS` - Silent with errors shown
- `--connect-timeout` - TCP connection timeout
- `--max-time` - Maximum total time
- `--interface` - Source IP to use
- `2>&1` - Redirect stderr to stdout

### Service List Source

The list of services to test comes from [Azure Local Endpoints Definition Manifest](https://aka.ms/hciconnectivitytargets).

### Validator Naming Pattern

Validator names follow this pattern:
```
AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_{ServiceName}
```

**Examples:**
- `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_AzureArc`
- `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_AzureResourceManager`
- `AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_AzureStorage`

### Severity Levels

Most endpoint validators use **CRITICAL** severity, but some use **WARNING**:

| Severity | When Used | Impact |
|----------|-----------|--------|
| **CRITICAL** | Core services (Arc, ARM, AAD) | Blocks deployment if fails |
| **WARNING** | Optional services, telemetry | Doesn't block deployment |

The severity is defined for each service in the manifest file.

### Common Failure Scenarios

| Scenario | Error | Solution |
|----------|-------|----------|
| **DNS failure** | "Couldn't resolve host" | Fix DNS configuration |
| **Firewall block** | Connection timeout | Allow outbound HTTPS |
| **Proxy issue** | SSL/certificate error | Check proxy SSL interception |
| **Network down** | "Failed to connect" | Check network infrastructure |
| **Service outage** | HTTP 503 errors | Check Azure service status |
| **Certificate error** | SSL handshake failed | Check system certificates |

### Prerequisites for This Validator

These validators must pass first (in order):
1. Hyper-V Readiness
2. VMSwitch Readiness
3. Management vNIC Readiness
4. Test vNIC Readiness
5. DNS Client Readiness
6. **IP Readiness** - Infrastructure IP reaches gateway
7. **DNS Port 53** - Infrastructure IP reaches DNS servers

Only after all prerequisites pass will endpoint connectivity tests run.

### When This Validator is Skipped

The infrastructure IP connectivity validator (including all endpoint tests) is **skipped** when:

| Condition | Reason |
|-----------|--------|
| **ArcGateway enabled** | ArcGateway provides alternative connectivity |
| **Deployment scenario** | Only runs if ArcGateway is NOT enabled |
| **Upgrade scenario** | Only runs if ArcGateway is NOT enabled |

### Verifying Azure Service Health

If endpoints are failing, check Azure service health:

```powershell
# Check Azure status page
Start-Process "https://status.azure.com"

# From portal: portal.azure.com -> Service Health
```

### Related Validators

**Prerequisites:**
- AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_Hyper_V_Readiness
- AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_VMSwitch_Readiness
- AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_MANAGEMENT_VNIC_Readiness
- AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_vNIC_Readiness
- AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNSClientServerAddress_Readiness
- AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_IPReadiness
- AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNS_Server_Port_53

### Related Documentation
- [Azure Local firewall requirements](https://learn.microsoft.com/azure/azure-local/concepts/firewall-requirements)
- [Azure Arc network requirements](https://learn.microsoft.com/azure/azure-arc/servers/network-requirements)
- [Azure Local network requirements](https://learn.microsoft.com/azure/azure-local/concepts/host-network-requirements)
- [Configure proxy settings](https://learn.microsoft.com/azure/azure-local/manage/configure-proxy-settings-23h2)
