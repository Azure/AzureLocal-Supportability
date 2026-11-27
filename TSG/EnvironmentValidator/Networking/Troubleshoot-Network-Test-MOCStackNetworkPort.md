<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v2",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "envchecker",
    "signal": "AzStackHci_MOCStack_Network_Port"
  }
}
-->

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
    <td><strong>Deployment</strong>, <strong>Add node</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator</th>
    <td><code>Invoke-AzStackHciMOCStackValidation</code>, test <code>Test-MOCStackNetworkPort</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Environment Checker versions</th>
    <td>10.2509 and earlier. Version 10.2510 and later don't run this check.</td>
  </tr>
</table>

## Table of contents

- [Overview](#overview)
- [When this check runs](#when-this-check-runs)
- [Requirements](#requirements)
- [Example failure from Environment Validator](#example-failure-from-environment-validator)
- [What runs this check](#what-runs-this-check)
- [Troubleshooting](#troubleshooting)
- [Remediation](#remediation)
- [Administrator detection surfaces](#administrator-detection-surfaces)
- [Notes](#notes)
- [Quick summary](#quick-summary)

## Overview

This environment validator fails when a node being validated can't open an outbound TCP connection on port 443 or port 80 to `internetbeacon.msedge.net`. The validator calls `Test-NetConnection` without a target, and `Test-NetConnection` then uses `internetbeacon.msedge.net` as its default target to probe generic internet reachability. If either port fails on a node, the check fails for that node and deployment or add node can't continue.

> **Notes**
>
> * This happens during the validation phase, before the deployment begins or before a node is added.  
> * `internetbeacon.msedge.net` is used only by the connectivity probe behavior of `Test-NetConnection`. It is **not** listed among the required Azure Local service endpoints in Microsoft’s Firewall Requirements page for Azure Local: https://learn.microsoft.com/en-us/azure/azure-local/concepts/firewall-requirements

### When this check runs

* During deployment validation and add-node validation, in the **Azure Local MOC Stack** validation step.
* On every node being validated. Each node gets its own result, named `MOCStack Network Port Requirement <node name>`.
* Only when no WinHTTP proxy is configured on the node that runs the validation. If `netsh winhttp show advproxy` on that node shows a `Proxy` value, the check is skipped and reports no result. Registering the nodes with Azure Arc through a proxy server or through Arc gateway configures this proxy.
* Only with Environment Checker (`AzStackHci.EnvironmentChecker`) version 10.2509 and earlier. Version 10.2510 and later skip this check, so it doesn't appear for deployments that use a newer Environment Checker. To see the installed version, run this on the node:

```powershell
Get-Module -Name AzStackHci.EnvironmentChecker -ListAvailable | Select-Object Name, Version
```

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

`DisablePort` lists the ports that failed on that node, for example ` 443, 80,`.

**Root cause:** The node can't complete a TCP connection to `internetbeacon.msedge.net` on port 443 or 80. The usual causes are:

* A firewall between the node and the internet blocks outbound TCP 443 or 80 to this endpoint.
* The node can't resolve `internetbeacon.msedge.net` in DNS.
* A Windows Firewall rule or policy on the node itself blocks the connection.
* Your network allows internet access only through a proxy server, but no WinHTTP proxy is configured on the node that runs validation.

## What runs this check

The check is the function `Test-MOCStackNetworkPort` in the **AzStackHci.EnvironmentChecker** PowerShell module (file `AzStackHciMOCStack\AzStackHci.MOCStack.Helpers.psm1`). `Invoke-AzStackHciMOCStackValidation` runs it. The module is published on the PowerShell Gallery: https://www.powershellgallery.com/packages/AzStackHci.EnvironmentChecker

What the check does:

1. On the node that runs the validation, it reads the WinHTTP proxy setting (`netsh winhttp show advproxy`). If a proxy is set, it stops and reports no result.
2. On each node being validated, it runs `Test-NetConnection -Port 443 -InformationLevel Quiet` and then the same command for port 80. With no `-ComputerName`, `Test-NetConnection` connects to `internetbeacon.msedge.net` (see [Test-NetConnection](https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection)). It tries each port up to five times.
3. If a port still fails, that node's result is `FAILURE`, with the detail `MOCStack mandatory network port is currently disabled.` and the failed ports in `DisablePort`. Otherwise the node's result is `SUCCESS`.

The check only opens a TCP connection. It doesn't send HTTP or HTTPS requests, and a failed ping doesn't affect it.

## Troubleshooting

### Manually test from the affected node

Run these tests in PowerShell on each node named in the failure. They make the same connection the check makes.

```powershell
# Quick reachability tests
Test-NetConnection -ComputerName internetbeacon.msedge.net -Port 443
Test-NetConnection -ComputerName internetbeacon.msedge.net -Port 80
```

Read the result:

| What you see | What it means | Next step |
| --- | --- | --- |
| `TcpTestSucceeded : True` for both ports | The node reaches the endpoint now. | Run the validation again. |
| `TcpTestSucceeded : False` and `RemoteAddress` shows an address | The name resolves, but the TCP connection is blocked. | [Check the node's own firewall](#check-the-nodes-own-firewall), then your network firewall. |
| A warning that name resolution failed, and no `RemoteAddress` | The node can't resolve `internetbeacon.msedge.net`. | [Fix name resolution](#if-the-node-cant-resolve-the-name). |

A warning that a ping failed doesn't matter by itself. The check reads only the TCP result.

The check tries each port up to five times before it reports a failure. If a test fails, run it again a few times before you change anything, and act on a result that keeps failing.

### Check the node's own firewall

This read-only block lists the Windows Firewall settings on the node that can block the check: each profile's default outbound action, and each enabled outbound block rule that covers TCP 80 or 443. You don't need an elevated session for it.

```powershell
# Read-only: list Windows Firewall settings on this node that can block the check
& {
    $Endpoint = 'internetbeacon.msedge.net'
    $addresses = @(Resolve-DnsName -Name $Endpoint -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique)
    "Endpoint addresses: $($addresses -join ', ')"
    Get-NetFirewallProfile -PolicyStore ActiveStore | Format-Table Name, Enabled, DefaultOutboundAction
    $portParts = { param($Ports) @($Ports | ForEach-Object { "$_" -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    $rules = @(Get-NetFirewallRule -PolicyStore ActiveStore |
        Where-Object { "$($_.Direction)" -eq 'Outbound' -and "$($_.Action)" -eq 'Block' -and "$($_.Enabled)" -eq 'True' } |
        ForEach-Object {
            $pf = $_ | Get-NetFirewallPortFilter
            $remote = @(($_ | Get-NetFirewallAddressFilter).RemoteAddress)
            $ports = @(& $portParts $pf.RemotePort)
            $portMatch = @($ports | Where-Object {
                $_ -eq 'Any' -or $_ -eq '80' -or $_ -eq '443' -or
                ($_ -match '^(\d+)-(\d+)$' -and ((([int]$Matches[1] -le 80) -and ([int]$Matches[2] -ge 80)) -or
                    (([int]$Matches[1] -le 443) -and ([int]$Matches[2] -ge 443))))
            }).Count -gt 0
            if ((@('TCP', '6', 'Any') -contains "$($pf.Protocol)") -and $portMatch) {
                $endpointOnly = (@('TCP', '6') -contains "$($pf.Protocol)") -and
                    @($ports | Where-Object { @('80', '443') -notcontains $_ }).Count -eq 0 -and
                    $remote.Count -gt 0 -and @($remote | Where-Object { $addresses -notcontains $_ }).Count -eq 0
                $match = if (@($remote | Where-Object { $addresses -contains $_ }).Count -gt 0) {
                             if ($endpointOnly) { 'Endpoint only' } else { 'Endpoint and other traffic' }
                         }
                         elseif ($remote -contains 'Any') { 'Any address' }
                         else { 'Other addresses (check whether they include the endpoint)' }
                [pscustomobject]@{
                    Rule          = $_.DisplayName
                    Name          = $_.Name
                    Source        = $_.PolicyStoreSourceType
                    Protocol      = $pf.Protocol
                    RemotePort    = $ports -join ','
                    RemoteAddress = $remote -join ','
                    Match         = $match
                }
            }
        })
    if ($rules.Count -gt 0) { $rules | Format-List } else { 'No enabled outbound block rule on this node covers TCP 80 or 443.' }
}
```

Expected result on a node that isn't blocking the check: an address after `Endpoint addresses:`, no profile with `DefaultOutboundAction` `Block`, and the line `No enabled outbound block rule on this node covers TCP 80 or 443.`

* If nothing follows `Endpoint addresses:`, the node can't resolve the name, so the list can't show which rules match the endpoint. Go to [If the node can't resolve the name](#if-the-node-cant-resolve-the-name) first.

* If a rule is listed with `Match` `Endpoint only`, the rule blocks only `internetbeacon.msedge.net` addresses on TCP 80 or 443. See [If a firewall rule on the node blocks the connection](#if-a-firewall-rule-on-the-node-blocks-the-connection).
* If a rule is listed with `Match` `Endpoint and other traffic`, the rule also blocks other addresses, other ports, or other protocols. Don't disable it, because that also removes its other restrictions. Ask the rule's owner to remove the `internetbeacon.msedge.net` addresses from it or to narrow it. Windows Firewall applies block rules before allow rules, so adding an allow rule doesn't get around it.
* If a rule with `Any address` is listed, or a profile's `DefaultOutboundAction` is `Block`, your organization restricts outbound traffic on the node. Ask the owner of that rule or policy to allow TCP 80 and 443 to `internetbeacon.msedge.net`. Don't disable a broad rule to pass this check.

## Remediation

Use the step that matches what you found in [Troubleshooting](#troubleshooting).

### If your network firewall blocks the connection

Allowlist `internetbeacon.msedge.net` on your network firewall appliance for outbound TCP 80 and TCP 443 from the Azure Local nodes or subnets that perform validation.

**Changes:** Adds one outbound allow rule on your network firewall. Nothing changes on the nodes, and running workloads aren't affected.

**Guidance**

* Create FQDN based rules for `internetbeacon.msedge.net` on TCP 80 and TCP 443  
* If the firewall does not support FQDN rules, allow the IP (13.107.4.52) that resolves at validation time, understanding that this can change. `Resolve-DnsName -Name internetbeacon.msedge.net` shows the current addresses  
* Scope the rule to the source subnet or specific node IPs that run the check  
* Keep the rule active for the duration of validation. You can remove or tighten it afterward if your policy requires it

### If the node can't resolve the name

Fix DNS on the nodes first. A node that can't resolve `internetbeacon.msedge.net` usually can't resolve other required endpoints either. See [Troubleshoot external DNS resolution](../Troubleshooting-DNS-External-DNS-Resolution.md).

Then run the tests in [Manually test from the affected node](#manually-test-from-the-affected-node) again. If a port still fails, continue with [Check the node's own firewall](#check-the-nodes-own-firewall).

### If a firewall rule on the node blocks the connection

Use this block only when [Check the node's own firewall](#check-the-nodes-own-firewall) listed a rule with `Match` `Endpoint only`. It disables a rule only when the rule's whole scope is `internetbeacon.msedge.net` addresses on TCP 80 or 443, so disabling it removes no other restriction. It changes nothing when any matching rule is broader than that, or when a matching rule comes from Group Policy or another policy source, and it lists those rules so you can take them to their owner. If someone added the rule on purpose, check with your security team first.

Run the block in an elevated PowerShell session (**Run as administrator**). Changing Windows Firewall rules needs administrator rights, and the block stops without changing anything if the session isn't elevated.

**Changes:** Disables the local Windows Firewall outbound block rules on this node whose only scope is `internetbeacon.msedge.net` on TCP 80 or 443. Broader rules, policy-managed rules, other rules, and the profile defaults don't change. To undo, run the `Enable-NetFirewallRule` command that the block prints for each rule.

Paste and run the whole block at once. It stops at the first error, and it changes nothing if it can't resolve the endpoint or read the firewall rules.

```powershell
# Disable local outbound block rules whose only scope is internetbeacon.msedge.net on TCP 80 or 443
& {
    $ErrorActionPreference = 'Stop'
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        'This session is not elevated, so nothing was changed. Open PowerShell with Run as administrator, then run this block again.'
        return
    }
    $Endpoint = 'internetbeacon.msedge.net'
    $addresses = @()
    foreach ($try in 1..3) {
        if ($try -gt 1) { Start-Sleep -Seconds 5 }
        $addresses = @(Resolve-DnsName -Name $Endpoint -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique)
        if ($addresses.Count -gt 0) { break }
    }
    if ($addresses.Count -eq 0) {
        "This node can't resolve $Endpoint, so nothing was changed. Fix name resolution first, then run this block again."
        return
    }
    $portParts = { param($Ports) @($Ports | ForEach-Object { "$_" -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    $matching = @(Get-NetFirewallRule -PolicyStore ActiveStore |
        Where-Object { "$($_.Direction)" -eq 'Outbound' -and "$($_.Action)" -eq 'Block' -and "$($_.Enabled)" -eq 'True' } |
        ForEach-Object {
            $pf = $_ | Get-NetFirewallPortFilter
            $ports = @(& $portParts $pf.RemotePort)
            $remote = @(($_ | Get-NetFirewallAddressFilter).RemoteAddress)
            $portMatch = @($ports | Where-Object {
                $_ -eq 'Any' -or $_ -eq '80' -or $_ -eq '443' -or
                ($_ -match '^(\d+)-(\d+)$' -and ((([int]$Matches[1] -le 80) -and ([int]$Matches[2] -ge 80)) -or
                    (([int]$Matches[1] -le 443) -and ([int]$Matches[2] -ge 443))))
            }).Count -gt 0
            if ((@('TCP', '6', 'Any') -contains "$($pf.Protocol)") -and $portMatch -and
                (@($remote | Where-Object { $addresses -contains $_ }).Count -gt 0)) {
                [pscustomobject]@{
                    Rule         = $_
                    EndpointOnly = (@('TCP', '6') -contains "$($pf.Protocol)") -and
                        @($ports | Where-Object { @('80', '443') -notcontains $_ }).Count -eq 0 -and
                        @($remote | Where-Object { $addresses -notcontains $_ }).Count -eq 0
                }
            }
        })
    $broad = @($matching | Where-Object { -not $_.EndpointOnly })
    $managed = @($matching | Where-Object { $_.EndpointOnly -and "$($_.Rule.PolicyStoreSourceType)" -ne 'Local' })
    if ($matching.Count -eq 0) {
        'No enabled outbound block rule on this node names an internetbeacon.msedge.net address. Nothing was changed.'
    } elseif ($broad.Count -gt 0 -or $managed.Count -gt 0) {
        foreach ($m in $broad) {
            "Not changed: '$($m.Rule.DisplayName)' also blocks other addresses, ports, or protocols. Don't disable it. Ask its owner to remove the $Endpoint addresses from it or to narrow it."
        }
        foreach ($m in $managed) {
            "Not changed: '$($m.Rule.DisplayName)' comes from Group Policy or another policy source. Ask the policy owner to remove the block for this endpoint."
        }
        'Nothing was changed. Resolve the rules above with their owners, then run this block again.'
    } else {
        foreach ($m in $matching) {
            Disable-NetFirewallRule -Name $m.Rule.Name
            "Disabled rule '$($m.Rule.DisplayName)'. To undo: Enable-NetFirewallRule -Name '$($m.Rule.Name)'"
        }
    }
}
```

Expected result: one `Disabled rule` line for each rule that was blocking the endpoint. Then run the re-test below.

* If the block prints `Not changed:` lines, no rule was changed. Take each listed rule to its owner, then run the block again.
* If the block prints `This node can't resolve internetbeacon.msedge.net, so nothing was changed`, go to [If the node can't resolve the name](#if-the-node-cant-resolve-the-name), and run the block again once `Resolve-DnsName -Name internetbeacon.msedge.net` returns addresses.
* If the block stops with any other error, nothing after that point ran. Read the error, and if a rule was already disabled, its `Disabled rule` line shows the command that undoes it.

### If your network requires a proxy server

If your network allows internet access only through a proxy server, the nodes must be set up to use it, which you do when you register them with Azure Arc. See [Register Azure Local with Azure Arc without using Arc gateway](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-without-azure-arc-gateway). When a WinHTTP proxy is configured on the node that runs validation, this check is skipped. Don't open direct internet access only to pass this check. To verify, see [After you configure a proxy server](#after-you-configure-a-proxy-server).

### Re test

Use the verification that matches the fix you made.

#### After a firewall or DNS fix

From the node run

```powershell
Test-NetConnection -ComputerName internetbeacon.msedge.net -Port 443
Test-NetConnection -ComputerName internetbeacon.msedge.net -Port 80
```

Both should show `TcpTestSucceeded : True`. Then run the Environment Validator again, for example by retrying the deployment or add-node validation. The result for `AzStackHci_MOCStack_Network_Port` should change to `SUCCESS` for every node.

To rerun only this check for the node you're signed in to, use this read-only block in an elevated PowerShell session (**Run as administrator**), because it opens a PowerShell remoting session to the node. It works only with Environment Checker 10.2509 and earlier. Later versions skip this check: they print `No tests to run.` and return an empty row.

```powershell
# Read-only: rerun only this check for this node (Environment Checker 10.2509 and earlier)
$session = New-PSSession -ComputerName $env:COMPUTERNAME
Invoke-AzStackHciMOCStackValidation -PsSession $session -OperationType Deployment -Include Test-MOCStackNetworkPort -PassThru |
    Select-Object Name, TargetResourceName, Status, @{ Name = 'Detail'; Expression = { $_.AdditionalData.Detail } }
Remove-PSSession -Session $session
```

Expected result: `Status` `SUCCESS` and an empty `Detail`. If both ports test `True` on every node but validation still reports this failure, collect the output of the tests above and the files listed under [Administrator detection surfaces](#administrator-detection-surfaces), and contact Microsoft Support.

#### After you configure a proxy server

On a network that allows internet access only through a proxy server, the `Test-NetConnection` tests above still show `TcpTestSucceeded : False`, because `Test-NetConnection` connects directly and doesn't use the proxy. That result is expected, so don't open direct internet access to make it pass.

Instead, on the node that runs the validation, confirm that the WinHTTP proxy is set. This command is read-only:

```powershell
netsh winhttp show advproxy
```

Expected result: the output includes a `"Proxy"` value with your proxy server. If it doesn't, the proxy isn't configured on this node, and the check still runs. Go back to [If your network requires a proxy server](#if-your-network-requires-a-proxy-server).

Then run the Environment Validator again. Because the check is skipped when a WinHTTP proxy is set, `AzStackHci_MOCStack_Network_Port` no longer appears in the results: it reports neither `SUCCESS` nor `FAILURE`, and the rerun block above returns no result for it. If the proxy is shown but validation still reports this failure, collect the output of `netsh winhttp show advproxy` and the files listed under [Administrator detection surfaces](#administrator-detection-surfaces), and contact Microsoft Support.

## Administrator detection surfaces

| Surface | Status | Where to look |
| --- | --- | --- |
| PowerShell on a node | shown | `Test-NetConnection -ComputerName internetbeacon.msedge.net -Port 443` and `-Port 80` return `TcpTestSucceeded : False`. With Environment Checker 10.2509 and earlier, the rerun block in [Re test](#re-test) returns the result with `Status` `FAILURE` and the detail `MOCStack mandatory network port is currently disabled.` |
| Azure portal | shown | Deployment or add-node validation fails, and the error details contain the text in [Example failure from Environment Validator](#example-failure-from-environment-validator), starting with `Type 'ValidateMOCStack' of Role 'EnvironmentValidator' raised an exception`. |
| Windows event logs | shown | On the node that ran the validation: Event Viewer > Applications and Services Logs > **AzStackHciEnvironmentChecker**, source `AzStackHciEnvironmentChecker/Telemetry`, Event ID **17205**. There is one event per validated node. A failing node's event is a Warning whose message contains `"Name": "AzStackHci_MOCStack_Network_Port"`. |
| Cluster logs (Get-ClusterLog) | not-evident | Not evident in the cluster logs. The check runs before deployment or before a node joins, and it writes nothing to the failover cluster. |
| Failover Cluster Manager | not-evident | Not evident in Failover Cluster Manager. The check isn't a cluster role, resource, or node state. |
| Windows Admin Center (standalone) | shown | Inferred from the Windows event logs row: on a connection to the node that ran the validation, the **Events** tool reads the same **AzStackHciEnvironmentChecker** log, so it shows the same Event ID 17205 entry. The cluster **Alerts** don't list this failure, because it raises no Health Service fault. |
| Windows Admin Center in the Azure portal | shown | Inferred from the Windows event logs row: where Windows Admin Center in the Azure portal can connect to the node that ran the validation, for example for add node on a deployed instance, its **Events** tool shows the same Event ID 17205 entry. Before deployment, use one of the other surfaces. |
| Component / tool log files | shown | When you run the validator yourself, it writes `AzStackHciEnvironmentChecker.log` and `AzStackHciEnvironmentReport.json` to `%USERPROFILE%\.AzStackHci` for the account that ran it, or to the folder you pass in `-OutputPath`. The log records the run, and the report lists each node's result with its `Status` and detail. During deployment, the validation run is also logged in `C:\CloudDeployment\Logs\EnvironmentValidatorFull.<date>.log` on the node that runs the deployment. |

## Notes

* This validator checks generic internet reachability through `internetbeacon.msedge.net` using the default behavior of `Test-NetConnection`  
* The requirement applies during validation before deployment or add node, with Environment Checker 10.2509 and earlier, when no WinHTTP proxy is configured  
* `internetbeacon.msedge.net` is not part of the documented Azure Local firewall allowlist for service endpoints: https://learn.microsoft.com/en-us/azure/azure-local/concepts/firewall-requirements  
* Document any temporary firewall changes and remove them after validation if they are not needed for ongoing operations

## Quick summary

* Symptom: `AzStackHci_MOCStack_Network_Port` failure blocks validation  
* Cause: the node can't open outbound TCP 80 or 443 to `internetbeacon.msedge.net`, most often because a network firewall blocks it. DNS failures and Windows Firewall rules on the node fail the same way  
* Fix: allow TCP 80 and 443 to `internetbeacon.msedge.net` on the firewall, or fix the DNS or node rule you found, and run validation again
* Applies to: Environment Checker 10.2509 and earlier, without a WinHTTP proxy
