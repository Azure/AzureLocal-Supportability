# AzStackHci_MOCStack_Network_Port

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_MOCStack_Network_Port</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment</strong></td>
  </tr>
</table>

## Overview

This environment validator fails when the node that runs the MOCStack checks does not have outbound TCP connectivity on ports 80 and 443 to `internetbeacon.msedge.net`. The validator calls `Test-NetConnection` without an explicit target which uses that endpoint to probe generic internet reachability. If either port is blocked the check fails and deployment cannot proceed.

> **Notes**
>
> * This happens during the validation phase before the deployment begins.  
> * `internetbeacon.msedge.net` is used only by the connectivity probe behavior of `Test-NetConnection`. It is **not** listed among the required Azure Local service endpoints in Microsoft’s Firewall Requirements page for Azure Local: https://learn.microsoft.com/en-us/azure/azure-local/concepts/firewall-requirements

## Requirements

All nodes participating in validation must provide outbound TCP connectivity from the datacenter to `internetbeacon.msedge.net` on the following ports

* TCP 80  
* TCP 443

Enable only what is needed on your perimeter or intermediate firewall. Prefer FQDN based allow rules for `internetbeacon.msedge.net`. The IP used by this endpoint can change.

## Example failure from Environment Validator

```
Exception
Type 'ValidateMOCStack' of Role 'EnvironmentValidator' raised an exception: {
  "ExceptionType": "json",
  "ErrorMessage": {
    "Message": "MOCStack requirements not met. Review output and remediate.",
    "Results": {
      "Name": "AzStackHci_MOCStack_Network_Port",
      "DisplayName": "MOCStack Network Port Requirement AZLNODE01",
      "Tags": { "OperationType": "Deployment" },
      "Title": "MOCStack Network Port Requirement",
      "Status": 1,
      "Severity": 2,
      "Description": "Test to check MOCStack Network Port requirement is met",
      "Remediation": "Enable the mandatory network port required for MOCStack",
      "TargetResourceID": "AZLNODE01",
      "TargetResourceName": "AZLNODE01",
      "TargetResourceType": "Computer",
      "Timestamp": "/Date(1758213952852)/",
      "AdditionalData": {
        "Source": "AZLNODE01",
        "Status": "FAILURE",
        "DisablePort": " 443, 80,",
        "HardwareType": "",
        "Resource": "Error occurred in Environment Validator MOCStack network port test.",
        "Detail": "MOCStack mandatory network port is currently disabled.",
        "ExpectedEnablePort": ""
      },
      "HealthCheckSource": "Deployment\\Standard\\Medium\\Connectivity\\dff65990"
    }
  }
}
```

### Failure

`MOCStack mandatory network port is currently disabled`

**Root cause:** Outbound TCP 80 or 443 to `internetbeacon.msedge.net` is blocked by a firewall that sits between the node and the internet. The probe cannot complete.

## What runs this check

The validation is implemented in the PowerShell module **AzStackHci.EnvironmentChecker**, within the helper file  
**AzStackHciMOCStack/AzStackHci.MOCStack.Helpers.psm1**:  
https://www.powershellgallery.com/packages/AzStackHci.EnvironmentChecker/1.2100.2531.331/Content/AzStackHciMOCStack%5CAzStackHci.MOCStack.Helpers.psm1

The function `Test-MOCStackNetworkPort` performs the connectivity test by iterating the expected ports and calling `Test-NetConnection` without a destination, which triggers the reachability probe (commonly hitting `internetbeacon.msedge.net`).

``` Powershell
function Test-MOCStackNetworkPort
{
    <#
    .SYNOPSIS
        Verify that the required network ports for MOCStack are open.
    .DESCRIPTION
        Verify that the required network ports for MOCStack are open.
    .PARAMETER PsSession
        Specify the PsSession(s) used to validation from.
    .PARAMETER OperationType
        Specify the Operation Type to target for MOCStack validation. e.g. Deployment, Update, etc
    #>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession[]]
        $PsSession,

        [Parameter(Mandatory = $false)]
        [string[]]
        $OperationType
    )

    try
    {
        $portList = '443','80'
        Log-Info -Message ($VvsTxt.MOCStackPortInfo) -Type Info
        $disabledPortMsg = ($VvsTxt.DisablePortMsg)

        # Scriptblock to test network port on each server
        $testPortSb = {
            $AdditionalData = @()
            $status = "Succeeded"
            $errorMsg = $null
            $hardwareType = $null
            $expectedPortList = $args[0]
            $failedPort = $null
            $resourceMsg = $null

            try
            {
                # Check each network port is enabled on the node
                foreach ($port in $expectedPortList)
                {
                    # Added retry logic
                    $retryCount = 0
                    $tcpSucceeded = $false
                    while (!$tcpSucceeded -and $retryCount -lt 5)
                    {
                        $tcpSucceeded = Test-NetConnection -Port $port -InformationLevel Quiet
                        $retryCount ++
                    }
                    
                    # Validate the TCP connection
                    if($tcpSucceeded -ne $true)
                    {
                        $failedPort += " $port,"
                        $status = "Failed"
                    }
                }
                
                # Check overall network port enable status
                if ($status -eq 'Failed')
                {
                    $resourceMsg = "The network port validation for MOCStack requires $($failedPort) to be enabled."
                    throw $args[1]
                }
            }
            catch
            {
                $errorMsg = $_.Exception.Message
                $resourceMsg = "Error occurred in Environment Validator MOCStack network port test."
                $status = "Failed"
            }
            finally
            {
                $AdditionalData += New-Object -TypeName PsObject -Property @{
                    HardwareType  = $hardwareType
                    ExpectedEnablePort = $portList
                    DisablePort = $failedPort
                    Status    = $status
                    Source    = $ENV:COMPUTERNAME
                    Resource  = $resourceMsg
                    Detail    = $errorMsg
                }
            }
            return $AdditionalData
        }

        # Run scriptblock
        $MOCStackPortResult = Invoke-Command -Session $PsSession -ScriptBlock $testPortSb -ArgumentList $portList, $disabledPortMsg
        # build result
        $now = [datetime]::UtcNow
        $targetComputerName = if ($PsSession.PSComputerName) { $PsSession.PSComputerName } else { $ENV:COMPUTERNAME }
        $aggregateStatus = if ($MOCStackPortResult.Status -contains 'Failed') { 'Failed' } else { 'Succeeded' }

        $PortResult = New-Object -Type AzStackHciMOCStackPortTarget -Property @{
            Name               = 'AzStackHci_MOCStack_Network_Port'
            Title              = 'MOCStack Network Port Requirement'
            Severity           = 'Critical'
            Description        = 'Test to check MOCStack Network Port requirement is met'
            Tags               =  $OperationType
            Remediation        = 'Enable the mandatory network port required for MOCStack'
            TargetResourceID   = $targetComputerName
            TargetResourceName = $targetComputerName
            TargetResourceType = $MOCStackPortResult.HardwareType | Get-Unique
            Timestamp          = $now
            Status             = $aggregateStatus
            AdditionalData     = $MOCStackPortResult
            HealthCheckSource  = $ENV:EnvChkrId
            ExpectedEnablePort = $MOCStackPortResult.ExpectedEnablePort
            DisablePort = $MOCStackPortResult.DisablePort
        }
        return $PortResult
    }
    catch
    {
        throw $_
    }
}
```

## Troubleshooting

### Manually test from the affected node

Run these tests from an elevated PowerShell session on the node. If they fail, the blockage is outside the node and must be addressed on your firewall appliance.

```
# Quick reachability tests
Test-NetConnection -ComputerName internetbeacon.msedge.net -Port 443
Test-NetConnection -ComputerName internetbeacon.msedge.net -Port 80
```

If `TcpTestSucceeded` is false for either port continue with remediation.

## Remediation

Allowlist `internetbeacon.msedge.net` on your network firewall appliance for outbound TCP 80 and TCP 443 from the Azure Local nodes or subnets that perform validation.

**Guidance**

* Create FQDN based rules for `internetbeacon.msedge.net` on TCP 80 and TCP 443  
* If the firewall does not support FQDN rules, allow the IP (13.107.4.52) that resolves at validation time, understanding that this can change  
* Scope the rule to the source subnet or specific node IPs that run the check  
* Keep the rule active for the duration of validation. You can remove or tighten it afterward if your policy requires it

**Re test**

From the node run

```
Test-NetConnection -ComputerName internetbeacon.msedge.net -Port 443
Test-NetConnection -ComputerName internetbeacon.msedge.net -Port 80
```

Then run the Environment Validator again. The status for `AzStackHci_MOCStack_Network_Port` should change to `Succeeded`.

## Notes

* This validator checks generic internet reachability through `internetbeacon.msedge.net` using the default behavior of `Test-NetConnection`  
* The requirement applies during validation before deployment  
* `internetbeacon.msedge.net` is not part of the documented Azure Local firewall allowlist for service endpoints: https://learn.microsoft.com/en-us/azure/azure-local/concepts/firewall-requirements  
* Document any temporary firewall changes and remove them after validation if they are not needed for ongoing operations

## Quick summary

* Symptom: `AzStackHci_MOCStack_Network_Port` failure blocks validation  
* Cause: outbound TCP 80 or 443 to `internetbeacon.msedge.net` is not allowlisted on the firewall appliance  
* Fix: allow TCP 80 and 443 to `internetbeacon.msedge.net` on the appliance and run validation again
