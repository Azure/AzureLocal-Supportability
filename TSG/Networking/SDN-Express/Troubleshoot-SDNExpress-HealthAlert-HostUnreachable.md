# Symptoms
From Azure Portal, you received Health Alert about **HostUnreachable**.

The **HostUnreachable** issue is a generic error that occurs when communication from the Network Controller VSwitchService or FirewallService to SDN Hosts fails. This can happen due to failures in NcHostAgent service on the Host.

# Issue Validation

To confirm the scenario that you are encountering is the issue documented in this article, you can follow the validation steps below:

## Step1: Validate if agents are running
From any Cluster node, run the following commands to check if your NC Host Agents are running on each cluster node:

```Powershell
foreach($node in Get-ClusterNode){  
     Invoke-Command -ComputerName $node.Name -ScriptBlock{Get-Service -Name NcHostAgent}  
}
```

### Mitigation Details

If the NcHostAgent service is in Status `Stopped` on any of the node. Run command below to start the service

```Powershell
Invoke-Command -ComputerName <node_name> -ScriptBlock {Start-Service -Name NcHostAgent}
```
If the service fails to be started, create a support ticket to get further help.

## Step2: Validate if agents are listening
Find the OVSDB passive connection listening port used by NcHostAgent by command below from registry key:
```Powershell
# Get the pssl connection string and extract the port
$nchaParams = Get-ItemProperty HKLM:System\CurrentControlSet\Services\NcHostAgent\Parameters
$psslConnection = $nchaParams.Connections | Where { $_ -like "pssl*" }
$psslPort = ($psslConnection -split ":")[1]
$psslPort
``` 
      
The Network Controller VSwitchService and FirewallService communicate with the NcHostAgent via port 443 and passive connection port. From any Cluster Node, you can check if the agents are LISTENING on that ports:
```Powershell
foreach($node in Get-ClusterNode){  
         Invoke-Command -ComputerName $node.Name -ArgumentList $psslPort -ScriptBlock{  
              param($psslPort)
              Get-NetTCPConnection | where {  
                  $_.State -eq "Listen" -and ($_.LocalPort -eq 443 -or $_.LocalPort -eq $psslPort)} | ft
        }  
}  
```
      
> Note: 
> - The owning process for Port 443 should be PID 4, which is the system process. If the owning process of Port 443 is not PID 4 that indicates another process is using the port and that will cause an issue.
> - The owning process for Port `$psslPort` should be the PID of NcHostAgent Service

Check if the HostAgent URL successfully registered at Port 443 with the following command, run from issue cluster node:
```Powershell
netsh http show servicestate
```
Review the output and confirm if [HTTPS://+:443/HOSTAGENT/VSWITCH/](HTTPS://+:443/HOSTAGENT/VSWITCH/) URL is registered by NcHostAgent Service, sample output:
```Powershell
Request queue name: Request queue is unnamed.
        Version: 2.0
        State: Active
        Request queue 503 verbosity level: Basic
        Max requests: 1000
        Active requests: 0
        Queued requests: 0
        Max queued request age: 0s
        Requests arrived: 6
        Requests rejected: 0
        Cache hits: 0
        Number of active processes attached: 1
        Processes:
            ID: 2688, image: C:\Windows\System32\svchost.exe
            Services: NcHostAgent
            Tagged Service: NcHostAgent
        Registered URLs:
            HTTPS://+:443/HOSTAGENT/VSWITCH/
```

### Mitigation Details
If the agents are not listening, create a support ticket to get further help.

## Step3: Check line of sight connectivity to your host machines
Find the node running VSwitchService and FirewallService.
      
### For Failover Cluster based Network Controller. 
Run command below and find the OwnerNode of VSwitchService and FirewallService

```Powershell
Get-ClusterGroup | ft
```
      
### For Service Fabric based Network Controller.
Run from any Network Controller VM and find the node running VSwitchService and FirewallService

```Powershell
Get-NetworkControllerReplica
```
      
Test the network connection from VSwitchService and FirewallService node by running command below:
```Powershell
# Set Issue Host's HostName or FQDN that report this issue
$issueHost = "HostName Or HostFQDN"
Test-NetConnection -ComputerName $issueHost -Port 443

# Replace the `$psslPort` port you get from registry key configuration in Step2 for service fabric based Network Controller.
Test-NetConnection –ComputerName $issueHost -Port $psslPort
```

### Mitigation Details
* Review 
If the line-of-sight connectivity is not present, create a support ticket to get further help.

## Step4: Check certificate binding
From the cluster node, run below command to confirm the port 443 has right certificate binding set:
```Powershell
netsh http show sslcert
```
Sample output:

```Powershell
    IP:port                      : 0.0.0.0:443
    Certificate Hash             : 411fb4637cc223c876a300d26b814e086634c35c
    Application ID               : {28f7fb0f-eab3-4960-9693-9289ca768dea}
```
      
Review the output and find section match for application ID `28f7fb0f-eab3-4960-9693-9289ca768dea` and ensure there is a certificate hash configured. Confirm if that is the right certificate:

```Powershell
Get-ChildItem Cert:\LocalMachine\My\411FB4637CC223C876A300D26B814E086634C35C | fl *
```
### Mitigation Details

If the certificate binding does not exist or incorrect. Ensure there is a valid certificate exist and meet requirements per document [Manage certificates for Software Defined Networking - Azure Local | Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-local/manage/sdn-manage-certs#certificate-configuration-requirements) . Then restart the NcHostAgent service to mitigate the issue:

```Powershell
Restart-Service NcHostAgent
```

# Cause
This can happen due to failures on Host's NcHostAgent Service:
*   Inability to communicate with SDN Hosts from Network Controller.
*   Failure of the NcHostAgent service to run or listen on required ports (443 and Port of OVSDB Passive Connection).
*   Incorrect process ownership of Port 443 or Port of OVSDB Passive Connection.
*   Unsuccessful registration of the HostAgent URL at Port 443.
*   Network connection issues between VSwitchService and FirewallService nodes and the host machines.
*   Incorrect or missing certificate binding for Port 443

