# ECEAgent Causing Slowness during Update

# Symptoms

The slowness can cause the update to take significantly longer than expected and possibly timeout. The exact symptom of this issue is that the step with name 'Failover ECE Service to new Node' takes a long time to complete. If this step takes longer than 15 minutes to complete the cluster  is likely experiencing this issue. The portal will look like the screenshot below and get stuck for a long time.
![alt text](ECESlownessPortalExample.png)

# Issue Validation
This detection script can be used to detect if ECE is experiencing the issue while an update is running. If the update is not currently running but the previous update got stuck and the portal looked like the screen shot above apply the remediation and then retry the update. If the update gets stuck again while it is in progress run the detection script again and follows its recommendations.

``` Powershell

function CheckForAgentUpdateSlowness()
{

    Import-Module ECEClient

    $ErrorActionPreference = "Stop"

    $eceClient = Create-ECEClusterServiceClient
    try
    {
        $plans = $eceClient.GetActionPlanInstances().GetAwaiter().GetResult()

    }
    catch
    {
        $ErrorMsg = "There was an error retrieving action plan information from the ECE service. Please try again in a few minutes"
        throw $ErrorMsg
    }

    $masUpdate = $plans | Where-Object { ($null -ne $_.ActionPlanName ) -and (($_.ActionPlanName -match "MAS Update")) }

    $sortedMASUpdate = @( $masUpdate | Sort-Object LastModifiedDateTime )

    $mostRecentMASUpdate = $sortedMASUpdate[-1]

    if ($mostRecentMASUpdate -ne $null )
    {
        $xml = $mostRecentMASUpdate.ProgressAsXml

        $task = Select-Xml -XPath "//Step[@Name='Failover ECE Service to new Node']" -Content $xml | Select-Object -ExpandProperty Node | Select-Object -exp Task

        if (@($task).Count -ne 1 -or -not $task.StartTimeUtc)
        {
            Write-Host "Cannot tell: the most recent update does not have exactly one started 'Failover ECE Service to new Node' step"
            return
        }

        $startTime = Get-Date $task.StartTimeUtc

        $endTime = $task.EndTimeUtc

        if ($mostRecentMASUpdate.Status -eq "Running" -or $mostRecentMASUpdate.Status -eq "Waiting" -or $mostRecentMASUpdate.Status -eq "Pending" )
        {
            if  ((-not $endTime) -and $startTime.AddMinutes(15) -lt $(Get-Date))
            {
                Write-Host "ECE slowness issue detected. Please run the agent restart remediation from the ECEAgent Causing Slowness during Update TSG"
                return
            }
        }
    }

    Write-Host "An update is not running or the slowness issue was not detected"
}

CheckForAgentUpdateSlowness

```


# Mitigation Details  

Running the below command from one of the cluster nodes while the agent is stuck should clear up the slowness and the update should auto remediate its state. The script forces a restart of the ECEAgent on all of the nodes in the cluster. The ECEAgent service is configured to restart itself a few seconds after its process stops, so the script's `Start-Service` call only makes sure the service is running; do not replace it with starting the program file directly, which runs a second copy outside the service.

Run it only when the detection script above reports "ECE slowness issue detected", or when a previous update got stuck at the 'Failover ECE Service to new Node' step as described in Issue Validation.

**Changes:** On every cluster node, the script force-stops the ECEAgent process and then makes sure the `ECEAgent` service is running again. Any work the agent is doing on that node at that moment is interrupted. It does not restart the nodes or any virtual machines, and it does not change the update or the cluster configuration.

``` Powershell 
 $scriptBlock = {
            try {
                Write-Host "Running ECEAgent service restart on $(hostname)"
                $eceagent = Get-WmiObject -Class Win32_Service -Filter "Name='ECEAgent'"
                Stop-Process $eceagent.ProcessId -Force
                Start-Sleep -Seconds 5
                $eceagent = Get-WmiObject -Class Win32_Service -Filter "Name='ECEAgent'"
                
                $retry = 0
                while ($eceagent.State -ne "Running")
                {
                    Start-Service -Name ECEAgent
                    $eceagent = Get-WmiObject -Class Win32_Service -Filter "Name='ECEAgent'"
                    if(++$retry -ge 5)
                    {
                        throw "Failed to start ECEAgent during agent restart on $(hostname)"
                    }
                    Start-Sleep -Seconds 1
                }
                Write-Host "ECE Agent service was restarted on $(hostname)"
            }
            catch {
                throw "Failed to restart ECEAgent on $(hostname): $($_.Exception.Message)"
            }
        }
    $nodes = Get-Clusternode | select -expandproperty Name

    
    
    Invoke-Command -ComputerName $nodes -ScriptBlock $scriptBlock -Verbose -ErrorAction 'Stop'
```