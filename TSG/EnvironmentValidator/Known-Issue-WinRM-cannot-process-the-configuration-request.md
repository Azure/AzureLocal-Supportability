# Symptoms

Cluster Validation fails with the following error:

```
Type 'ValidateCluster' of Role 'EnvironmentValidator' raised an exception:

{
    "ExceptionType":  "text",
    "ErrorMessage":  "WinRM cannot process the configuration request. The hostname pattern is invalid: \"*\" Hostname patterns must contain one or more patterns. A pattern can contain at most one wildcard (\"*\"). The special pattern \"\u003clocal\u003e\" can be used to indicate all hostnames that do not have a \u0027.\u0027. To trust all hosts use \"*\" as the only pattern. ",
    "ExceptionStackTrace":  "at \u003cScriptBlock\u003e, \u003cNo file\u003e: line 8"
}
```

# Issue Validation

To confirm the scenario that you are encountering is the issue documented in this article, please run this script on the first node of the cluster:
```PowerShell
(Get-Item WSMan:\localhost\Client\TrustedHosts).Value;
```
If it returns a '*' you are impacted by this issue. 

# Mitigation Details

Clear the trustedHost entries on each node of the cluster, run the following script:

```PowerShell
Write-Host "Clearing TrustedHosts setting on $ENV:COMPUTERNAME";
Clear-Item -Path WSMan:\localhost\Client\TrustedHosts;
# Accept the prompt;
```

Verify the setting 
```
$trustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value;
Write-Host "TrustedHosts setting on $ENV:COMPUTERNAME is '$trustedHosts'";
```

This should output `TrustedHosts setting on node1 is ''`

# Cause

Cluster validation must update the TrustedHosts entries with IP, NodeName and cluster name in order to perform cluster validation. If '*' is present already in the TrustedHosts list, WSMAN does not allow updating the list with IP as it considers the '.' as a special pattern.

# Next action

Rerun validation from the portal.