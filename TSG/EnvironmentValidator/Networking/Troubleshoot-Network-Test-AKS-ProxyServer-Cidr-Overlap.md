# AzureLocal_Network_Test_AKS_Subnet_POD_CIDR_ProxyServer_Overlap

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_Network_Test_AKS_Subnet_POD_CIDR_ProxyServer_Overlap</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Informational</strong>: This validator provides information but will not block operations.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment</strong></td>
  </tr>
</table>

## Overview

This validator checks that proxy server addresses configured on the system do not overlap with the Kubernetes POD CIDR or Service CIDR subnets. While this is informational and will not block deployment, proxy servers in these ranges may cause routing conflicts or connectivity issues with AKS workloads.

## Requirements

Proxy servers should meet the following recommendation:
1. Proxy server IP addresses should not fall within the POD CIDR subnet (default: `10.244.0.0/16`)
2. Proxy server IP addresses should not fall within the Service CIDR subnet (default: `10.96.0.0/12`)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about the proxy server addresses and whether they overlap with AKS CIDR ranges.

```json
{
  "Name": "AzureLocal_Network_Test_AKS_Subnet_POD_CIDR_ProxyServer_Overlap",
  "DisplayName": "Test for Proxy server overlaps with POD CIDR Subnet 10.244.0.0/16 and Service CIDR Subnet 10.96.0.0/12",
  "Title": "Test for Proxy server overlaps with POD CIDR Subnet 10.244.0.0/16 and Service CIDR Subnet 10.96.0.0/12",
  "Status": 1,
  "Severity": 0,
  "Description": "Checking Proxy server address(es) not within the POD CIDR Subnet 10.244.0.0/16 and Service CIDR Subnet 10.96.0.0/12",
  "Remediation": "Verify IP of the proxy server(s) configured are not overlapping with AKS pre-defined POD subnet and Service subnet. Check https://learn.microsoft.com/en-us/azure/aks/aksarc/aks-hci-ip-address-planning for more information.",
  "TargetResourceID": "ProxyServer-proxyserver.contoso.com",
  "TargetResourceName": "ProxyServer-proxyserver.contoso.com",
  "TargetResourceType": "ProxyServer-proxyserver.contoso.com",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "ProxyServerPODServiceCIDR",
    "Resource": "ProxyServerPODServiceCIDR",
    "Detail": "Proxy server address(es): proxyserver.contoso.com. POD CIDR: 10.244.0.0/16; Service CIDR: 10.96.0.0/12",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Informational: Proxy Server Overlaps with POD or Service CIDR

**Message:**
```text
Proxy server address(es): proxyserver.contoso.com. POD CIDR: 10.244.0.0/16; Service CIDR: 10.96.0.0/12
```

**Description:** The proxy server address configured on the system overlaps with the POD CIDR or Service CIDR subnet. This is informational and will not block deployment, but may indicate a configuration issue or potential routing conflicts when deploying AKS workloads. Microsoft will upgrade the severity level in future.

#### Recommended Actions

##### Verify Proxy Server Configuration

The validator checks proxy configuration from three sources:
- WinHTTP proxy settings
- WinINET proxy settings
- Environment variables (HTTP_PROXY and HTTPS_PROXY)

1. Check the current proxy configuration:

   ```powershell
   # Check WinHTTP proxy settings
   netsh winhttp show proxy

   # Check WinINET proxy settings (Internet Explorer proxy)
   Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" | Select-Object ProxyEnable, ProxyServer

   # Check environment variables
   [Environment]::GetEnvironmentVariable("HTTP_PROXY", "Machine")
   [Environment]::GetEnvironmentVariable("HTTPS_PROXY", "Machine")
   [Environment]::GetEnvironmentVariable("HTTP_PROXY", "User")
   [Environment]::GetEnvironmentVariable("HTTPS_PROXY", "User")
   ```

2. Resolve the proxy server hostname to verify its IP address:

   ```powershell
   # Replace <proxyserver> with your proxy server hostname from the error message
   $proxyHostname = "proxyserver.contoso.com"
   [System.Net.Dns]::GetHostAddresses($proxyHostname) | Select-Object IPAddressToString
   ```

3. Check if the resolved IP address is in the POD CIDR or Service CIDR range:
   - POD CIDR: `10.244.0.0/16` (range: `10.244.0.0` to `10.244.255.255`)
   - Service CIDR: `10.96.0.0/12` (range: `10.96.0.0` to `10.111.255.255`)

##### Reconfigure Proxy Settings (If Needed)

If the proxy server IP address conflicts with AKS CIDR ranges, consider one of these options:

**Option 1: Use a different proxy server**

If available, configure a proxy server that is not in the conflicting range:

```powershell
# Set WinHTTP proxy
netsh winhttp set proxy proxy-server="newproxy.contoso.com:8080" bypass-list="<local>"

# Set environment variables
[Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://newproxy.contoso.com:8080", "Machine")
[Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://newproxy.contoso.com:8080", "Machine")
```

**Option 2: Contact your network administrator**

If the proxy server is managed by your network team:
1. Inform them about the IP address conflict with AKS CIDR ranges
2. Request that the proxy server be moved to a non-conflicting IP address
3. Update the proxy configuration once the change is made

**Option 3: Remove proxy configuration (if not required)**

If the proxy is not required for your deployment:

```powershell
# Remove WinHTTP proxy
netsh winhttp reset proxy

# Remove environment variables
[Environment]::SetEnvironmentVariable("HTTP_PROXY", $null, "Machine")
[Environment]::SetEnvironmentVariable("HTTPS_PROXY", $null, "Machine")
```

> **Warning**: Only remove proxy configuration if you're certain it's not required for internet connectivity or deployment requirements.

##### Verify Changes

After making changes, verify the new configuration:

```powershell
# Check WinHTTP proxy
netsh winhttp show proxy

# Check environment variables
[Environment]::GetEnvironmentVariable("HTTP_PROXY", "Machine")
[Environment]::GetEnvironmentVariable("HTTPS_PROXY", "Machine")

# Test connectivity through new proxy
$proxyUri = "http://newproxy.contoso.com:8080"
$webRequest = [System.Net.WebRequest]::Create("https://www.microsoft.com")
$webRequest.Proxy = New-Object System.Net.WebProxy($proxyUri)
$response = $webRequest.GetResponse()
$response.StatusCode
$response.Close()
```

##### Understanding the Impact

Having a proxy server in the POD or Service CIDR ranges may cause:
- **Routing conflicts**: Proxy traffic may be misdirected when AKS workloads are deployed
- **Connectivity issues**: Outbound connections through the proxy may fail
- **AKS deployment problems**: Container image pulls may fail
- **Service mesh conflicts**: If using service mesh, proxy configuration may interfere

##### When to Reconfigure

Consider reconfiguring the proxy server if:
1. You plan to deploy AKS workloads on this cluster
2. The proxy server can be moved to a non-conflicting IP address
3. You want to avoid potential future networking conflicts
4. Your network team can provide an alternative proxy

##### When It's Acceptable to Proceed

You may proceed without changes if:
1. The proxy server is intentionally placed in this range and properly configured
2. Your network routing explicitly handles this scenario
3. You've verified no conflicts exist with your specific AKS deployment plans
4. You've documented this configuration for future reference
5. You've tested connectivity and confirmed it works as expected

---

## Additional Information

### Default AKS CIDR Ranges

- **POD CIDR**: `10.244.0.0/16` (default)
  - Range: `10.244.0.0` to `10.244.255.255`
  - Reserved for Kubernetes pod IP addresses
- **Service CIDR**: `10.96.0.0/12` (default)
  - Range: `10.96.0.0` to `10.111.255.255`
  - Reserved for Kubernetes service IP addresses

### Proxy Configuration Sources

The validator checks the following proxy configuration sources:

1. **WinHTTP Proxy**:
   - System-wide proxy settings
   - Used by Windows services and applications
   - Configured via `netsh winhttp`

2. **WinINET Proxy**:
   - User-level proxy settings (Internet Explorer proxy)
   - Used by some applications
   - Configured via Internet Options or registry

3. **Environment Variables**:
   - `HTTP_PROXY` (Machine and User level)
   - `HTTPS_PROXY` (Machine and User level)
   - Used by many command-line tools and applications

All unique proxy servers found in these sources are checked against the AKS CIDR ranges.

### DNS Resolution

The validator resolves proxy server hostnames to IP addresses using DNS. If DNS resolution fails for a proxy server hostname, that proxy is skipped in the validation.

### Recommended Proxy Server Placement

For optimal network design, place proxy servers in ranges that do not conflict with:
- POD CIDR: `10.244.0.0/16`
- Service CIDR: `10.96.0.0/12`
- Infrastructure IP pools

**Example non-conflicting ranges:**
- `192.168.x.x` - Private network range
- `10.0.x.x` - Private network range (avoid `10.96-10.111` and `10.244`)
- `172.16.x.x` - Private network range

### Proxy Bypass Configuration

If you must keep a proxy server in a conflicting range, consider configuring bypass lists to exclude AKS-related traffic:

```powershell
# Example: Set proxy with bypass list
netsh winhttp set proxy proxy-server="proxyserver.contoso.com:8080" bypass-list="*.local;10.244.*;10.96.*;localhost"
```

This ensures that traffic to AKS CIDR ranges bypasses the proxy, reducing potential conflicts.

### Related Documentation

- [AKS IP Address Planning](https://learn.microsoft.com/en-us/azure/aks/aksarc/aks-hci-ip-address-planning)
- [Azure Local Network Requirements](https://learn.microsoft.com/en-us/azure-stack/hci/concepts/host-network-requirements)
- [Proxy configuration for Azure Local](https://learn.microsoft.com/en-us/azure-stack/hci/manage/configure-proxy-settings)
- [Configure WinHTTP proxy settings](https://learn.microsoft.com/en-us/windows/win32/winhttp/winhttp-autoproxy-support)
