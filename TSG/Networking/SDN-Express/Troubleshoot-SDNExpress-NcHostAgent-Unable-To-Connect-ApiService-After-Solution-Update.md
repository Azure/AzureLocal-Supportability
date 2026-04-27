# NcHostAgent Unable to Connect to ApiService After Solution Update

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>SDN Express / Network Controller</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Solution Update</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td><strong>2506,2507,2508,2509,2510,2511,2512,2601,2602,2603,2604</strong></td>
  </tr>
</table>

## Overview

After completing an Azure Local solution update, Network Controller (NC) loses the ability to manage Hyper-V hosts due to a certificate rotation failure. The solution update rotates host certificates, but the corresponding AzureStackCertificationAuthority certificate is not properly propagated to the Network Controller VMs. This causes the NcHostAgent on each host to fail authentication when connecting to the NC ApiService, effectively breaking SDN management across the cluster.

This issue recurs after every subsequent solution update until the underlying root cause is addressed.

## Symptoms

**Common error messages:**

ConfigurationState reported for /servers/{resourceId} may show failure indicating:

```
PolicyConfigurationFailure
```

If you run `Debug-SdnFabricInfrastructure`, you may see the following test reporting failure:

```
Test-SdnHostAgentConnectionStateToApiService
Description = "Network Controller Host Agent is not connected to the Network Controller API Service."
Impact = "Policy configuration may not be pushed to the Hyper-V host(s) if no southbound connectivity is available."
```

**Observable behaviors:**

- Network Controller is unable to program VFP policies to VMs.
- Network connectivity issues for workloads.
- Network connectivity issues after performing live migration.

## Root Cause

During a solution update, the host certificates are rotated automatically. For the certificate rotation to also propagate the AzureStackCertificationAuthority certificate to the Network Controller VMs, several conditions must be met. A failure in any of the following causes the NcHostAgent-to-ApiService connection to break after the update.

### 1. Missing NetworkControllerNodeNames Registry Key

The certificate rotation process depends on the following registry key being present and populated on each Hyper-V host:

```
HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters\NetworkControllerNodeNames
```

This registry key is created by Windows Admin Center (WAC) and is created when you use WAC to manage Network Controller. In environments where WAC is not used this registry key does not exist. If this key is not present for SdnExpress deployments, we will not rotate the AzureStackCertificationAuthority.

### 2. HCI Deployment User Not Added to Local Administrators on NC VMs

The certificate rotation process uses PowerShell remoting (`Invoke-Command`) from the Hyper-V hosts to the Network Controller VMs to install the updated certificates. If the HCI deployment user is not a member of the Local Administrators group on the NC VMs, the remote commands fail and certificate propagation does not complete.

### 3. Code Defect in Certificate Rotation Logic

There is a known defect in the certificate rotation logic where incorrect name validation is performed, resulting in us skipping the rotate and marking the step as Success.

> **Note:** A fix for these code defects is currently in development and will be addressed in a future update.

## Resolution

### Missing NetworkControllerNodeNames Registry Key

On each Hyper-V host, verify that the `NetworkControllerNodeNames` registry key exists and contains the Network Controller VM names.

```powershell
# Check if the registry key exists and has a value
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters"
$regValue = Get-ItemProperty -Path $regPath -Name "NetworkControllerNodeNames" -ErrorAction SilentlyContinue

if ($null -eq $regValue) {
    Write-Host "NetworkControllerNodeNames registry key is MISSING." -ForegroundColor Red
}
elseif ([string]::IsNullOrWhiteSpace($regValue.NetworkControllerNodeNames)) {
    Write-Host "NetworkControllerNodeNames registry key EXISTS but is EMPTY." -ForegroundColor Yellow
}
else {
    Write-Host "NetworkControllerNodeNames: $($regValue.NetworkControllerNodeNames)" -ForegroundColor Green
}
```

If the key is missing or empty, populate it with the Network Controller VM names (comma-separated):

```powershell
# Replace <NC-VM1>,<NC-VM2>,<NC-VM3> with your actual NC VM names
$ncNodeNames = "<NC-VM1>,<NC-VM2>,<NC-VM3>"

# update existing key if present
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters" -Name "NetworkControllerNodeNames" -Value $ncNodeNames

# create key if missing
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters' -Name 'NetworkControllerNodeNames' -Value $nodeNames -PropertyType "MultiString" -Force
```

> **Important:** Repeat this step on every Hyper-V host in the cluster.

### HCI Deployment User Not Added to Local Administrators on NC VMs

The certificate rotation process requires that the Hyper-V hosts can remotely manage the Network Controller VMs. Verify that the Azure Local Deployment User has local administrator permissions on each NC VM. To determine your deployment user, leverage `Get-AzsSupportLcmDeploymentUserName` included with the [Support Diagnostics Tool](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools).

```powershell
# run this against all the NC VMs
Invoke-Command -ComputerName 'NC1','NC2','NC3' -ScriptBlock {
    $adminGroup = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue
    $adminGroup | Format-Table Name, ObjectClass, PrincipalSource
}
```

If the deployment user is not listed as local administrators, add them:

```powershell
# Replace <DOMAIN\DEPLOY_USER> with your deployment user account identified
Invoke-Command -ComputerName 'NC1','NC2','NC3' -ScriptBlock {
    Add-LocalGroupMember -Group "Administrators" -Member "<DOMAIN\DEPLOY_USER>"
}
```

### Install AzureStackCertificationAuthority certificate to NC manually
This is a short term mitigation that you should perform as part of your post solution update steps until a code fix is released. This only needs to be executed from one of the Hyper-V hosts.This requires [SdnDiagnostics](https://learn.microsoft.com/en-us/azure/azure-local/manage/sdn-log-collection#install-the-sdn-diagnostics-powershell-module-on-the-client-computer) to be installed on the Network Controller VMs as well as the Hyper-V hosts. By default for Azure Local, SdnDiagnostics is included for the Hyper-V hosts.

Connect to a Hyper-V host and copy the .cer file to each NC node.
  ```powershell
  $currentVersion = (Get-SolutionUpdateEnvironment -ErrorAction Stop).CurrentVersion
  if ($($currentVersion.Minor) -ge 2604) {
    $rootDir = 'C:\ProgramData\AzureEdge\CertificateStore\LocalMachine\Root'
  }
  else {
    $rootDir = 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\AzureStackCertificateAuthority'
  }
  Copy-SdnFileToComputer -Path (Join-Path -Path $rootDir -ChildPath "AzureStackCertificationAuthority.cer") -Destination (Get-SdnWorkingDirectory) -ComputerName 'NC1','NC2','NC3'
  ```

Install the certificate into trusted root store.
  ```powershell
  Invoke-SdnCommand -ComputerName 'NC1','NC2','NC3' -ScriptBlock {
    $cert = Get-ChildItem -Path "$(Get-SdnWorkingDirectory)\AzureStackCertificationAuthority.cer"
    Import-SdnCertificate -FilePath $cert.FullName -CertStore 'Cert:\LocalMachine\Root'
  }
  ```

Alternatively, if you have SdnDiagnostics with version 4.2604 or later, you can leverage [Start-SdnServerCertificateRotation](https://learn.microsoft.com/en-us/azure/azure-local/manage/update-sdn-infrastructure-certificates) from the Hyper-V host which will automatically detect the AzureStackCertificationAuthority certificate and copy to Network Controller VMs.
