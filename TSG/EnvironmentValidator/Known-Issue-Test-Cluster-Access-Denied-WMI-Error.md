# Troubleshooting Test-Cluster DNS Failure During Deployment

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>EnvironmentValidator - ValidateCluster / DNS</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical - blocks deployment</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment, AddNode</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td><strong>2601 - 2604</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Audience</th>
    <td><strong>Customer</strong></td>
  </tr>
</table>

## Overview

During Azure Local deployment, cluster validation can fail because one or more nodes are missing a DNS A record. After nodes join the Active Directory domain and reboot, each node should automatically register its DNS record. In some environments this automatic registration does not complete, and the deployment fails during the cluster validation step.

## Symptoms

The deployment fails during cluster validation with one of these error messages:

**Error 1 - Node cannot be reached:**

```
Failed to execute Test-Cluster: Unable to connect to <NodeName>.<DomainFQDN> via WMI
```

**Error 2 - Access denied:**

```
Failed to execute Test-Cluster: Access is denied
```

or

```
Failed to execute Test-Cluster: You do not have administrative privileges on the server <NodeName>
```

## Root Cause

After nodes join the domain and reboot, each node should register its DNS A record automatically. When the DNS zone requires secure (Kerberos-authenticated) updates, the registration can fail silently if the node has not fully established its security credentials with Active Directory. This leaves the node with no DNS record, and other nodes cannot find it by name during cluster validation.

## Resolution

### Prerequisites

- Remote PowerShell access to all nodes in the deployment
- Your domain FQDN (for example, `contoso.local`)
- Your DNS server IP address (configured on the nodes)
- Domain administrator or deployment credentials

### Step 1: Identify which nodes are missing DNS records

Run the following from any node or a management workstation that can reach the DNS server:

```powershell
$nodes = @("<Node1>", "<Node2>", "<Node3>")
$domainFqdn = "<domain.fqdn>"
$dnsServer = "<dns-server-ip>"

foreach ($node in $nodes) {
    $fqdn = "$node.$domainFqdn"
    $result = Resolve-DnsName -Name $fqdn -Type A -Server $dnsServer -ErrorAction SilentlyContinue
    if ($result) {
        Write-Host "[OK]      $fqdn -> $($result.IPAddress -join ', ')" -ForegroundColor Green
    }
    else {
        Write-Host "[MISSING] $fqdn has no DNS A record" -ForegroundColor Red
    }
}
```

If all nodes resolve successfully, DNS is not the cause. Contact Microsoft Support for further assistance.

### Step 2: Register DNS on each affected node

Run `ipconfig /registerdns` on each node that is missing a record. This command is safe and can be run multiple times without side effects:

```powershell
$affectedNodes = @("<AffectedNode1>", "<AffectedNode2>")

foreach ($node in $affectedNodes) {
    Write-Host "Registering DNS on $node..." -ForegroundColor Cyan
    Invoke-Command -ComputerName $node -ScriptBlock {
        $output = ipconfig /registerdns
        Write-Output $output
    }
}

# Wait for DNS propagation
Write-Host "Waiting 30 seconds for DNS propagation..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
```

### Step 3: Verify the DNS records now exist

```powershell
foreach ($node in $affectedNodes) {
    $fqdn = "$node.$domainFqdn"
    $result = Resolve-DnsName -Name $fqdn -Type A -Server $dnsServer -ErrorAction SilentlyContinue
    if ($result) {
        Write-Host "[FIXED]   $fqdn -> $($result.IPAddress -join ', ')" -ForegroundColor Green
    }
    else {
        Write-Host "[MISSING] $fqdn - see Step 4" -ForegroundColor Red
    }
}
```

### Step 4: Resume deployment

After confirming all A records are present, resume the deployment from the Azure portal by navigating to the deployment resource and selecting **Resume** or **Retry**.

## Related Issues

- [Known Issue: Test-Cluster Administrative Privileges Failure During Deployment](Known-Issue-Test-Cluster-Administrative-Privileges-Failure.md) - overlapping symptom

## Related Documentation

- [Azure Local deployment prerequisites](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-prerequisites)
- [DNS requirements for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/concepts/host-network-requirements)
- [Troubleshoot cluster validation](https://learn.microsoft.com/en-us/windows-server/failover-clustering/cluster-validation)

---
