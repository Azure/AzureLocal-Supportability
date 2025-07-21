# Support.AksArc Module Troubleshooting Guide

The Support.AksArc PowerShell module provides diagnostic and remediation capabilities for Azure Kubernetes Service on Azure Arc environments.

## Prerequisites

- PowerShell 5.1+, Administrator privileges, Moc module, Azure Stack HCI

## Installation

```powershell
Install-Module -Name Support.AksArc

Import-Module Support.AksArc

```

## Commands 

### Test for known issues

Run this command to check if your cluster is running into any of the known issues.

```powershell
Test-SupportAksArcKnownIssues

```

### Test for issues with remediation

Run this command to fix issues which have a remediation.

```powershell
Invoke-SupportAksArcRemediation

```


## Support
Review Azure Local  documentation or contact Microsoft Support for unresolved issues.
