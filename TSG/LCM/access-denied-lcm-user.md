# Symptoms
During deployment, update, or add-node you may encounter 'Access Denied'. Some examples include:

During deployment you might see the following error message(s)

```
Exception: Connecting to remote server <hostname/IP> failed with the following error message: Access is denied
```

```
Exception : Type 'ValidateConnectivity' of Role 'EnvironmentValidator' raised an exception: Unable to create a valid session to <ip>: [<ip>] 
Connecting to remote server <ip> failed with the following error message : Access is denied. 
```

During update download stage, you may see:

```
update package download failure with details similar to "Action plan GetCauDeviceInfo ID xxx failed with state: Failed".
```

During any action plan, if you see the following, go to "Known Causes" #6
```
Connecting to remote server <ClusterName> failed with the following error message : An unknown security error occured
```
# Known Causes
1. The LCM (deployment user) credentials were not updated properly using the [Set-AzureStackLCMUserPassword](https://learn.microsoft.com/en-us/azure/azure-local/manage/manage-secrets-rotation?view=azloc-24112#run-set-azurestacklcmuserpassword-cmdlet) cmdlet. This cmdlet is responsible for updating the password in Active Directory as well as updating it in the ECE Store. Both of these should be in sync, otherwise there will be access denied issues.
2. The LCM user does not have sufficient permissions on the Organization Unit (OU) in Active Directory (AD).
3. The NTLM policy, configured via Group Policy, may be blocking remote operations such as Invoke-Command. This can occur if NTLM is restricted either at the OU level or on the individual nodes or the domain controller via applied Group Policy Objects (GPOs).
4. The WinRM trusted hosts configuration is set up incorrectly.
5. The LCM user is part of the "Protected Users" group (See Protected Users heading below).
6. Cluster's SPN is misconfigured (See Unknown Security Error heading below)

# Issue Validation

Before running the following steps, please log into a node with the LCM user credential to ensure the credential works. If you do not know your LCM username, please view the [Retrieving your LCM (user deployment) username section](#retrieving-your-lcm-deployment-user-username). If you do not know your LCM user credentials, then you will need to recreate the LCM user and follow this document to ensure the LCM user is set up properly.

### Step 1: Check if LCM user is in the Local Administrators Group on all cluster nodes
Run the script below on all cluster nodes. Replace the `$lcmUser` variable with your LCM (deployment) user, and fill in `$groupsContainingLCMUser` if not logged in as lcmUser. 

```Powershell
# Set your LCM user
$lcmUser = 'DOMAIN\LCMUser'
# If logged in as LCMUser, run script at this point. Otherwise go to next comment
$groupsContainingLCMUser = (whoami /groups) |
    Select-Object -Skip 6 |
    ForEach-Object {
        ($_ -split '\s{2,}')[0]
    } |
    Where-Object { $_ -and $_ -ne "===" }

# If not logged in as lcmUser, manually populate groups lcmUser belongs to, and uncomment below
<#$groupsContainingLCMUser = @(
    'DOMAIN\Group1',
    'DOMAIN\Group2',
    'DOMAIN\Group3'
)#>

Write-Output "Checking if the LCM user or any of the specified groups are in the local Administrators group..."

try {
    $adminGroupMembers = Get-LocalGroupMember -Group 'Administrators'
} catch {
    Write-Error "Failed to retrieve Administrators group members. Error: $_"
    return
}

$found = $false

# Check if any of the groups are in the Administrators group
foreach ($group in $groupsContainingLCMUser) {
    if ($adminGroupMembers.Name -contains $group) {
        Write-Output "Group '$group' is in the Administrators group."
        $found = $true
    }
}

# Check if LCM user is directly in the Administrators group
if ($adminGroupMembers.Name -contains $lcmUser) {
    Write-Output "User '$lcmUser' is directly in the Administrators group."
    $found = $true
}

if ($found) {
    Write-Output "$lcmUser has administrative rights either directly or via one of the specified groups."
} else {
    Write-Output "$lcmUser does NOT have administrative rights via the specified groups or directly."
}
```

If the script shows that the `lcmUser` is not in the local Administrators group, then run the mitigation below:

```Powershell
# Replace 'DOMAIN\LCMUser' with your actual LCM username
$lcmUser = 'DOMAIN\LCMUser'

Write-Output "Attempting to add $lcmUser to the local Administrators group..."
try {
    Add-LocalGroupMember -Group 'Administrators' -Member $lcmUser
    Write-Output "$lcmUser was successfully added to the local Administrators group."
} catch {
    Write-Error "Failed to add $lcmUser to the Administrators group. Error: $_"
}
```

### Step 2: Check the LCM user credentials work on all nodes
Verify the LCM user credentials work with all iterations of Invoke-Command with and without CredSSP and using the hostname or the IP as the target:

```PowerShell
$credential = Get-Credential # Input your LCM (deployment user) credentials

$targetHostname = "<target_hostname>" # Replace with your target host
$targetIp = "<target_ip>" # Replace with your target IP address

Invoke-Command -computername $targetHostname -credential $credential -scriptblock {hostname}
Invoke-Command -ComputerName $targetHostname -Credential $credential -Authentication Credssp -ScriptBlock {whoami}

Invoke-Command -computername $targetIp -credential $credential -scriptblock {hostname}
Invoke-Command -ComputerName $targetIp -Credential $credential -Authentication Credssp -ScriptBlock {whoami}
```

If there are no issues running the previous script, then proceed to **Step 3**, otherwise:

1. If no Invoke-Command works (with or without CredSSP), double check you have entered the right LCM user credentials. If you are certain they are correct, then check the [WinRM Trusted Hosts configuration](#winrm-trusted-hosts-configuration) is set up properly to include all hostnames, FQDNs and IPs of all nodes in your cluster.
2. If Invoke-Command without CredSSP works, but CredSSP does not work, please review the [CredSsp-Authentication-Issues Doc](../Security/CredSsp-Authentication-Issues.md).
3. If Invoke-Command with hostname works, but using the IP does not work, ensure the [WinRM Trusted Hosts configuration](#winrm-trusted-hosts-configuration) is set up properly to include all IPs of all nodes in your cluster and that a Group Policy Object (GPO) [is not blocking NTLM](#check-ntlm-is-not-blocked-by-gpo).
 
### Step 3: Verify the LCM credential in AD matches ECE Store
If Invoke-Command works, then validate the credential exists in ECE store by running the script in the [Validating LCM (user deployment) credentials match the ECE Store](#validating-lcm-user-deployment-credentials-match-the-ece-store) section. If this script returns that they do not match, run the mitigation script from the same section.

### Step 4: Check LCM user permissions on the OU
Verify the Active Directory permissions are set properly for the LCM user. Log into the domain controller node using the LCM user credentials and run the following to get the Access Control List (ACL) for the user on the OU. Replace the LCM username in the script with your LCM username and the sample OU with your environment OU. You can get the OU by running `Get-ADOrganizationalUnit -Filter *` on the domain controller (DC) node. You should also check the permissions of any groups that the LCM user belongs to, since they are inherited by the LCM user.

```Powershell
# Define the target OU (update to match your environment)
$ou = "OU=MyOU,DC=domain,DC=com"

# Get the ACL of the OU
$acl = Get-Acl "AD:$ou"

# Define the LCM username (without domain prefix)
$lcmUsername = "<lcm_username>"

# Get the domain name in short form
$domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
$shortDomain = $domain.Split('.')[0]
$user = "$shortDomain\$lcmUsername"

$userAcl = $acl.Access | Where-Object { $_.IdentityReference -like "*$user*" }
$userAcl | Select-Object IdentityReference, ActiveDirectoryRights, AccessControlType
```

You should see output like the following:
```
IdentityReference           ActiveDirectoryRights AccessControlType
-----------------           --------------------- -----------------
<domain>\<LCM Username>              ReadProperty             Allow
<domain>\<LCM Username>                GenericAll             Allow
<domain>\<LCM Username>  CreateChild, DeleteChild             Allow
```

The user should have the following permissions on the OU:
* ReadProperty 
* GenericAll 
* CreateChild 
* DeleteChild 
 
If you do not see all of these ActiveDirectoryRights listed for this user, please follow [instructions to prepare active directory](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-prep-active-directory?view=azloc-2503), including running the `AsHciADArtifactsPreCreationTool` listed in the wiki to ensure all permissions are set appropriately for the user. Ensure these same permissions are applied to all OU objects and their descendents.

### WinRM Trusted Hosts Configuration

```Powershell
Get-Item WSMan:\localhost\Client\TrustedHosts
```

This file should contain the ips or hostnames of each of the nodes in your cluster. To set this file, use this command and specify all hostnames and ip-addresses in your cluster delimited by commas.

```Powershell
Set-Item WSMan:\localhost\Client\TrustedHosts -Value hostname1,hostname2,192.168.0.1,192.168.0.2
```

# Scripts
### Validating LCM (User Deployment) Credentials Match the ECE Store

### Prerequisites
Ensure the certificate with subject name CN=RuntimeParameterEncryptionCert, or CN=DscEncryptionCert is not missing or expired. If so, please run [Start-SecretRotation](https://learn.microsoft.com/en-us/azure/azure-local/manage/manage-secrets-rotation?view=azloc-24113) to rotate certificates.

Please input your LCM user credentials when prompted. **DO NOT include the domain as part of the username in the credential**.

```PowerShell
$credential = Get-Credential

# Validate credentials
try {
    # Attempt to invoke a simple command (Get-Process) on the local machine to validate credentials
    Invoke-Command -ScriptBlock { whoami } -Credential $credential -ErrorAction Stop -ComputerName localhost

    Write-Host "Credential validation successful." -ForegroundColor Green
}
catch {
    Write-Host "Credential validation failed. Please check the username and password." -ForegroundColor Red
    return
}

# Import necessary modules
Import-Module "ECEClient" 3>$null 4>$null
Import-Module "C:\Program Files\WindowsPowerShell\Modules\Microsoft.AS.Infra.Security.SecretRotation\Microsoft.AS.Infra.Security.ActionPlanExecution.psm1" -DisableNameChecking
Import-Module "C:\Program Files\WindowsPowerShell\Modules\Microsoft.AS.Infra.Security.SecretRotation\PasswordUtilities.psm1" -DisableNameChecking

# Print the User Name
Write-Host "Username provided: $($credential.UserName)" -ForegroundColor Cyan

# Validate that the username provided is of the correct format. Username should be provided without domain and not contain any special characters.
if ($credential.UserName -match '^[^\\]+(?=\\)|(?<=@).+$') {
    throw "Please provide user name without domain."
}

# Create ECE client and get the stamp version
$eceClient = Create-ECEClusterServiceClient
$stampVersion = $eceClient.GetStampVersion().GetAwaiter().GetResult()

# Define certificate path
$certPath = "Cert:\LocalMachine\My"  # Change this path if the cert is located elsewhere

# Check if RuntimeParameterEncryptionCert exists
$certName = "RuntimeParameterEncryptionCert"
$certificate = Get-ChildItem -Path $certPath | Where-Object { $_.Subject -like "*$certName*" }

# If RuntimeParameterEncryptionCert is not found, check for DscEncryptionCert
if (-not $certificate) {
    Write-AzsSecurityVerbose -Message "RuntimeParameterEncryptionCert not found. Checking for DscEncryptionCert." -Verbose
    $certName = "DscEncryptionCert"
    $certificate = Get-ChildItem -Path $certPath | Where-Object { $_.Subject -like "*$certName*" }

    # If DscEncryptionCert is also not found, throw an error
    if (-not $certificate) {
        throw "Neither RuntimeParameterEncryptionCert nor DscEncryptionCert found in the certificate store."
    }
} else {
    Write-AzsSecurityVerbose -Message "Found RuntimeParameterEncryptionCert." -Verbose
}

# Convert the SecureString password to an encrypted standard string using the selected certificate
$encryptedPassword = $credential.GetNetworkCredential().Password | Protect-CmsMessage -To "CN=$certName"

# Validate credentials in ECE
$ValidateParams = @{
    TimeoutInSecs = 10 * 60
    RetryCount = "2"
    ExclusiveLock = $true
    RolePath = "SecretRotation"
    ActionType = "ValidateCredentials"
    ActionPlanInstanceId = [Guid]::NewGuid()
}
$ValidateParams['RuntimeParameters'] = @{
    UserName = $credential.GetNetworkCredential().UserName
    Password = $encryptedPassword
}

Write-AzsSecurityVerbose -Message "Validating credentials in ECE.`r`nStarting action plan with Instance ID: $($ValidateParams.ActionPlanInstanceId)" -Verbose
$ValidateActionPlanInstance = Start-ActionPlan @ValidateParams 3>$null 4>$null

if ($ValidateActionPlanInstance -eq $null) {
    Write-AzsSecurityWarning -Message "There was an issue running the action plan. Please reach out to Microsoft support for help" -Verbose
}
elseif ($ValidateActionPlanInstance.Status -eq 'Failed') {
    Write-AzsSecurityWarning -Message "Could not find matching credentials in ECE store." -Verbose
}
elseif ($ValidateActionPlanInstance.Status -eq 'Completed') {
    Write-AzsSecurityVerbose -Message "Found matching credentials in ECE store." -Verbose
}
```

### Mitigation
Please input your LCM user credentials when prompted. **DO NOT include the domain as part of the username in the credential**.

```PowerShell
# Prompt for credentials
$credential = Get-Credential

# Validate credentials
try {
    # Attempt to invoke a simple command (Get-Process) on the local machine to validate credentials
    Invoke-Command -ScriptBlock { whoami } -Credential $credential -ErrorAction Stop -ComputerName localhost

    Write-Host "Credential validation successful." -ForegroundColor Green
}
catch {
    Write-Host "Credential validation failed. Please check the username and password." -ForegroundColor Red
    return
}

# Import the necessary module
Import-Module "C:\Program Files\WindowsPowerShell\Modules\Microsoft.AS.Infra.Security.SecretRotation\PasswordUtilities.psm1" -DisableNameChecking

# Print the User Name
Write-Host "Username provided: $($credential.UserName)" -ForegroundColor Cyan

# Validate that the username provided is of the correct format. Username should be provided without domain and not contain any special characters.
if($credential.UserName -match '^[^\\]+(?=\\)|(?<=@).+$')
{
    throw "Please provide user name without domain."
}

# Check the status of the ECE cluster group
$eceClusterGroup = Get-ClusterGroup | Where-Object { $_.Name -eq "Azure Stack HCI Orchestrator Service Cluster Group" }
if ($eceClusterGroup.State -ne "Online") {
    Write-AzsSecurityError -Message "ECE cluster group is not in an Online state. Cannot continue with password rotation." -ErrRecord $_
}

# Update ECE with the new password
Write-AzsSecurityVerbose -Message "Updating password in ECE" -Verbose

$ECEContainersToUpdate = @(
    "DomainAdmin",
    "DeploymentDomainAdmin",
    "SecondaryDomainAdmin",
    "TemporaryDomainAdmin",
    "BareMetalAdmin",
    "FabricAdmin",
    "SecondaryFabric",
    "CloudAdmin"
)

foreach ($containerName in $ECEContainersToUpdate) {
    Set-ECEServiceSecret -ContainerName $containerName -Credential $credential 3>$null 4>$null
}

Write-AzsSecurityVerbose -Message "Finished updating credentials in ECE." -Verbose
```

### Retrieving Your LCM (deployment user) Username
Run the following script on your HCI node to retrieve the LCM username:

```Powershell
# Retrieve the latest ECEWinService NuGet Version
$eceWinService = Get-ChildItem "C:\Agents" -Directory |
    Where-Object { $_.Name -match 'Microsoft\.AzureStack\.Solution\.ECEWinService\.(\d+\.\d+\.\d+\.\d+)' } |
    ForEach-Object {
        [PSCustomObject]@{
            Path = $_.FullName
            Version = [version]$matches[1]
        }
    } |
    Sort-Object Version -Descending |
    Select-Object -First 1

$eceWinServiceVersion = $eceWinService.Version.ToString()
$eceWinServicePath = $eceWinService.Path

# Load Assemblies
[System.Reflection.Assembly]::LoadFile("$eceWinServicePath\content\ECEWinService\CloudEngine.dll") | Out-Null
[System.Reflection.Assembly]::LoadFile("$eceWinServicePath\content\ECEWinService\Microsoft.AzureStack.Orchestration.Common.Packaging.Contract.dll") | Out-Null
[System.Reflection.Assembly]::LoadFile("$eceWinServicePath\content\ECEWinService\Microsoft.AzureStack.Orchestration.Common.Packaging.dll") | Out-Null
[System.Reflection.Assembly]::LoadFile("$eceWinServicePath\content\ECEWinService\Microsoft.Diagnostics.Tracing.EventSource.dll") | Out-Null

# Load MetricTelemetry.dll if it exists, otherwise fallback to Telemetry.dll
$metricTelemetryPath = "$eceWinServicePath\content\ECEWinService\Microsoft.AzureStack.Solution.MetricTelemetry.dll"
$telemetryPath = "$eceWinServicePath\content\ECEWinService\Microsoft.AzureStack.Solution.Telemetry.dll"

if (Test-Path $metricTelemetryPath) {
    [System.Reflection.Assembly]::LoadFile($metricTelemetryPath) | Out-Null
} elseif (Test-Path $telemetryPath) {
    [System.Reflection.Assembly]::LoadFile($telemetryPath) | Out-Null
} else {
    Write-Warning "Neither MetricTelemetry.dll nor Telemetry.dll found in $eceWinServicePath"
}

#Retrieve LCM User Username
Import-Module ECEClient 3>$null 4>$null
$eceClient = Create-ECEClusterServiceClient
$cloudDefinitionAsXmlString = (Get-CloudDefinition -EceClient $eceClient).CloudDefinitionAsXmlString
$cloudDefElements = [System.Xml.Linq.XElement]::Parse($cloudDefinitionAsXmlString)
 
$customerConfigurationObject = New-Object -TypeName 'CloudEngine.Configurations.CustomerConfiguration' -ArgumentList $cloudDefElements
$cloudRoleObject = [CloudEngine.Configurations.ConfigurationPathExtensions]::Find($customerConfigurationObject, 'Cloud')
[CloudEngine.Configurations.IInterface] $interface = $cloudRoleObject.Interface('Build')
$eceParams = $interface.GetInterfaceParameters()
 
$securityInfo = $ECEParams.Roles["Cloud"].PublicConfiguration.PublicInfo.SecurityInfo
$DAdmin = $securityInfo.DomainUsers.User | Where Role -eq "DomainAdmin"
Write-Output "Your LCM username is: $($DAdmin.Credential.Credential.UserName)"
```

### Check NTLM is not Blocked by GPO
Verify that you do not have policies in your domain controller that are restricting NTLM access. Please review [Network security: Restrict NTLM: NTLM authentication in this domain](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/security-policy-settings/network-security-restrict-ntlm-ntlm-authentication-in-this-domain).

## Access Denied because LCM is part of "Protected User" Group
### Symptoms
Deployment fails with `access denied` when doing invoke-command or new-pssession from node1 -> node1

The following variations of invoke-command or new-pssession from node1 -> node1 fail
- new-pssession \<node1 hostname\>
- new-pssession localhost
- new-pssession \<loopback IP\>

The following variations of invoke-command or new-pssession succeed
- new-pssession \<node1 hostname\> -EnableNetworkAccess
- new-pssession \<node1 hostname.fqdn>
- new-pssession \<node2 hostname\>

### Issue Validation
#### Validation Step 1
Repro the issue by running the following from node1:
```Powershell
new-pssession <node1 hostname>
$event = Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=4625)]]" | Select-Object -First 1
$event.message
```
If you see the following error code in the message, this is an indication of the problem
```
Failure Information:

              Failure Reason:                  Unknown user name or bad password.
              Status:                          0xC000006E
              Sub Status:                      0xC000006E
```
#### Validation Step 2
From the DC, run the following:
```Powershell
Get-ADUser -Identity <LCMUser> -Properties MemberOf | Select-Object -ExpandProperty MemberOf # Use LCM username without domain prefix
```
If the output has something similar to `CN="...protectedusers..."` the LCM user is part of the "Protected Users" group. If both validations passed, follow the mitigation below.
### Mitigation
The LCM user must be removed from the "Protected Users" group.


## Invoke-Command fails with with Unknown Security Error
`Note this section applies to errors with Invoke-Command to the <ClusterName> only, not to the <HostName>`
### Symptoms
Invoke-Command from any host node to the \<ClusterName\> fails with:
```
Connecting to remote server <ClusterName> failed with the following error message : An unknown security error occured
```
The issue can be manually repro'd with the following:
```
Invoke-Command -ComputerName <ClusterName> -Credential <LCMUserCreds> -Authentication Credssp -ScriptBlock { hostname }
```
The following scenarios still work:
- Invoke-Command to \<ClusterName\> without Credssp
- Invoke-Command to \<HostName\> with Credssp
### Issue Validation
From the jumpbox / DC check ClusterName's SPN for WSMAN/\<ClusterName\>
```
setspn -L <ClusterName>
```
You should see a bunch of entries including HOST/\<Clustername\> and HOST/\<ClusterName\>.\<FQDN\>

If you see entries for either wsman/\<ClusterName\> or wsman/\<ClusterName\>.\<FQDN\> follow the mitigation

`Note - this issue is only for the Cluster's SPN. Nodes with SPN's of HOST\<HostName> is expected`
### Mitigation
Remove the entries for wsman/\<ClusterName\> and wsman/\<ClusterName\>.\<FQDN\>
```
setspn -D wsman/<ClusterName> <ClusterName>
setspn -D wsman/<ClusterName><FQDN> <ClusterName>
```