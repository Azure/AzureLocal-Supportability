# How to collect SDN or Networking related logs


<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td>Networking</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Topic</th>
    <td>Send diagnostic data to microsoft</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Applicable Scenarios</th>
    <td> 
     Opening a support ticket to Microsoft after an environment validator failure or other lifecycle operations failing.
    </td>
  </tr>
</table>



## Table of Contents
- [Overview](#overview)
- [When to collect](#when-to-collect)
- [How to collect](#how-to-collect)
- [What to collect](#what-to-collect)


## Overview
See [Collect diagnostic logs from azure local](https://learn.microsoft.com/en-us/azure/azure-local/manage/collect-logs?view=azloc-2509&tabs=azureportal)

This guide shows how to collect networking and SDN related logs for azure local, and send them to Microsoft. These logs are helpful to identify SDN or networking configuration related problems in the azure local cluster.


## When to collect

Customers or support engineers send diagnostic data to Microsoft to help identify and resolve issues with azure local. When a support case is opened, Microsoft engineers typically need these logs to resolve it.

You may need to send these logs if you open a support case related to networking lifecycle operations. You may also collect these logs locally without sending them to Microsoft.  



## How to collect

See [Collect logs from azure local using powershell](https://learn.microsoft.com/en-us/azure/azure-local/manage/collect-logs?view=azloc-2509&tabs=powershell)

From any host node of the azure local cluster, run the powershell command `Send-DiagnosticData`. This will collect and parse logs from multiple etl providers, run diagnostic scripts, collect other log files in the stamp and (optionally) send them to Microsoft to be analyzed. 

## What to collect
The `Send-DiagnosticData` commandlet supports multiple parameters to choose what to collect. If no parameter is specified, then it will collect all available logs.
These log collections take anywhere from a couple of minutes to more than half an hour (depending on the amount of data collected). Run the command with no parameters if you are unsure of which data you need, or use the parameters to filter only the relevant data if you can.

### roles
See [Send diagnostic data for specified roles](https://learn.microsoft.com/en-us/azure/azure-local/manage/collect-logs?view=azloc-2509&tabs=powershell#send-diagnostic-data-for-specified-roles)

You may specify the roles using the `-FilterByRole` parameter. Use the role **HostNetwork** for networking data, or **SDN** for any SDN related issue (NEtwork controller, Software load balancers or Gateway).

**Example**

*Sending only Host network and SDN logs*
```powershell
Send-DiagnosticData -FilterByRole SDN,HostNetwork
```


**Example**

*Sending only SDN logs*
```powershell
Send-DiagnosticData -FilterByRole SDN
```

### Save logs locally
You may save the log collection in a local folder to analyze them without sending them to microsoft. Use the parameter `-SaveToPath`.

**Example**
*Collecting only hostNetwork logs and saving them locally in the path \<outout path>*

```powershell
Send-DiagnosticData -FilterByRole HostNetwork -SaveToPath <output path> 

```

