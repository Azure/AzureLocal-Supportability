# Facing "Access Denied" for the LCM User
## Symptoms
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
## Known Causes
1. The password for the LCM (deployment) user in Active Directory (AD) may differ from the password stored in Enterprise Cloud Engine (ECE). Use [Set-AzureStackLCMUserPassword](https://learn.microsoft.com/en-us/azure/azure-local/manage/manage-secrets-rotation#powershell-cmdlet-and-properties) to set the LCM User Password.
2. The LCM user does not have sufficient permissions on the Organization Unit (OU) in Active Directory (AD).
3. The NTLM policy, configured via Group Policy, may be blocking remote operations such as Invoke-Command. This can occur if NTLM is restricted either at the OU level or on the individual nodes or the domain controller via applied Group Policy Objects (GPOs).
4. The WinRM trusted hosts configuration is set up incorrectly.
5. The LCM user is part of the "Protected Users" group (See Protected Users heading below).
6. Cluster's SPN is misconfigured (See Unknown Security Error heading below)

## Issue Validation

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
 
### Step 3: Synchronize the LCM credential with ECE
If the remote-command checks from Step 2 succeed but the original operation still fails with access denied, follow [Synchronize the LCM password with ECE](#synchronize-the-lcm-password-with-ece). This validates the supplied password against AD and writes it to ECE; it does **not** detect or prove an AD/ECE password mismatch. Retry the failed operation to verify recovery. If access denied persists, continue to **Step 4** and the other applicable diagnostic sections.

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
TrustedHosts should be checked on each node for correct configuration.
```Powershell
Get-Item WSMan:\localhost\Client\TrustedHosts
```

TrustedHosts should include the following:
- Each cluster node's hostname
- Each cluster node's IP address
- Each cluster node's FQDN

To set TrustedHosts, use one of the commands below and replace the placeholder values with your cluster node hostnames, IPs, and FQDNs.

```PowerShell
# Setting and overwriting all values
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "hostname1,hostname2,192.168.0.1,192.168.0.2,hostname1.contoso.local,hostname2.contoso.local" -Force
```
```PowerShell
# Adding missing values to existing TrustedHosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "hostname1.contoso.local,hostname2.contoso.local" -Concatenate -Force
```

## Synchronize the LCM password with ECE

**Applies to:** Azure Local, release **2601 and later**. For releases earlier than 2601, instead contact Microsoft CSS.

Validation of the issue is difficult due to multiple changes across different releases, and different states the cluster may be in. So instead of validating the issue, we will simply fix the issue and retry. Fixing the issue involves setting the LCM user's password in ECE to match what is in AD. No changes to AD or AD password will be made. Once fix is applied, please retry the failed action plan.

### Preconditions

- Confirm the remote-command checks in [Step 2](#step-2-check-the-lcm-user-credentials-work-on-all-nodes) succeed.

### Step 1: Validate the current password against AD [READ-ONLY]

Run this block first. Replace `<lcm_username>` with your LCM username (without domain prefix). LCM password synchronization can be run from any node.

```powershell
$lcmUsername = '<lcm_username>'
$adPasswordValidated = $false
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($lcmUsername) -or $lcmUsername -match '[\\@<>]') {
    throw 'Provide the configured LCM username without the domain prefix.'
}

Get-Command Set-AzureStackLCMUserPassword -ErrorAction Stop | Out-Null
$pw = Read-Host 'Current LCM password in AD' -AsSecureString

Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$computer = Get-CimInstance Win32_ComputerSystem
if (-not $computer.PartOfDomain) {
    throw 'Run this procedure on a domain-joined Azure Local node. For AD-Less deployments contact CSS'
}
$domain = $computer.Domain
$ctx = [System.DirectoryServices.AccountManagement.PrincipalContext]::new('Domain', $domain)
$plain = $null
try {
    $plain = [pscredential]::new($lcmUsername, $pw).GetNetworkCredential().Password
    if (-not $ctx.ValidateCredentials($lcmUsername, $plain)) {
        throw "AD rejected the password for $domain\$lcmUsername. Stop; do not update ECE."
    }
    "AD accepted the password for $domain\$lcmUsername."
}
finally {
    $plain = $null
    $ctx.Dispose()
}
$adPasswordValidated = $true
```

**Expected result:** `AD accepted the password for <domain>\<lcm_username>.`

**Stop condition:** If AD rejects the password, do not run Step 2. Have the AD administrator resolve the credential, account, or domain-connectivity issue first. For any other issues with the script reach out to CSS.

### Step 2: Write the validated password to ECE

Run this block in the **same session**, only after Step 1 succeeds and you confirm the displayed account is the configured deployment account.

**Impact:** Updates the stored LCM credentials used by ECE lifecycle operations. No AD password change, node restart, or VM restart is requested.

```powershell
if ($adPasswordValidated -ne $true) {
    throw 'Complete Step 1 successfully in this session before updating ECE.'
}
Set-AzureStackLCMUserPassword -Identity $lcmUsername -NewPassword $pw -ErrorAction Stop
```

**Expected result:** The cmdlet completes without errors.

### Verify recovery

Retry the originally failed action plan using its normal retry workflow. The previously failing step should complete without the access-denied error.

If the cmdlet succeeds but the original error persists, do not assume a password mismatch was confirmed or repeat synchronization indefinitely. Continue with the OU permissions and other applicable checks in this guide, or contact CSS.

Close the PowerShell session when finished to discard the credential variables.

## Check NTLM is not Blocked by GPO
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
```Powershell
Invoke-Command -ComputerName <ClusterName> -Credential <LCMUserCreds> -Authentication Credssp -ScriptBlock { hostname }
```
The following scenarios still work:
- Invoke-Command to \<ClusterName\> without Credssp
- Invoke-Command to \<HostName\> with Credssp
### Issue Validation
From any host node check ClusterName's SPN for WSMAN/\<ClusterName\>
```Powershell
setspn -L <ClusterName>
```
You should see a bunch of entries including `HOST/<Clustername>` and `HOST/<ClusterName>.<FQDN>`

If you see entries for either `wsman/<ClusterName>` or `wsman/<ClusterName>.<FQDN>` follow the mitigation

`Note - this issue is only for the Cluster's SPN. Nodes with SPN's of wsman/<HostName> is expected`
### Mitigation
Remove the entries for `wsman/<ClusterName>` and `wsman/<ClusterName>.<FQDN>`
```Powershell
setspn -D wsman/<ClusterName> <ClusterName>
setspn -D wsman/<ClusterName>.<FQDN> <ClusterName>
```

## Access Denied because remote logon related GPO policy is applied
### Symptoms
#### Symptom 1
Deployment fails with `Access is Denied` during `AddAsZHostToDomain` step, right after node is joined to domain. An example of error message can be:
```
Type 'AddAsZHostToDomain' of Role 'BareMetal' raised an exception: Unable to connect to the <NODE_IP> using .\Administrator credentials. Please check the .\Administrator credentials.
```


#### Symptom 2
When you recently made Group Policy change and applied to Azure Local clusters, your admin account, either local admin or domain account added to node's local `Administrators` group, fails to remotely logon to a node and gets `Access is Denied` error. 

### Issue Validation
Please run the following script on your node through BMC console, or through another user that can still remotely connect (i.e., via PowerShell session or RDP) to the impacted node.

```powershell
$ErrorActionPreference = 'Stop'

# SIDs to check
$Sid_LocalAdminCapability = 'S-1-5-114'
$Sid_AdministratorsGroup  = 'S-1-5-32-544'
$isBlocked = $false

$TempCfg = Join-Path $env:TEMP 'secpol.cfg'

Write-Host "=== Checking SeDenyNetworkLogonRight ==="

# Export effective user rights
secedit /export /areas USER_RIGHTS /cfg $TempCfg | Out-Null

$denyLine = Select-String -Path $TempCfg `
    -Pattern '^SeDenyNetworkLogonRight\s*=' `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

Remove-Item $TempCfg -Force -ErrorAction SilentlyContinue

if (-not $denyLine) {
    Write-Host "SeDenyNetworkLogonRight: NOT configured"
    Write-Host "Local admins blocked: NO"
}
else {
    Write-Host "SeDenyNetworkLogonRight: CONFIGURED"
    Write-Host "Raw value:"
    Write-Host "  $($denyLine.Line)"

    $assignedSids = (($denyLine.Line -split '=', 2)[1] -split ',') |
        ForEach-Object { $_.Trim().TrimStart('*') }

    Write-Host "Assigned SIDs:"
    foreach ($sid in $assignedSids) {
        Write-Host "  - $sid"
    }

    $blocked114 = $assignedSids -contains $Sid_LocalAdminCapability
    $blocked544 = $assignedSids -contains $Sid_AdministratorsGroup
    $isBlocked = $blocked114 -or $blocked544

    if ($isBlocked) {
        Write-Host "Local admins blocked: YES"
    }
    else {
        Write-Host "Local admins blocked: NO"
    }
}

if ($isBlocked)
{
    Write-Host ""
    Write-Host "=== Identifying applying GPO(s) ==="

    $gpresultText = gpresult /scope computer /Z 2>$null

    $gpos = $gpresultText |
        Select-String 'Policy:\s+DenyNetworkLogonRight' -Context 3,3 |
        ForEach-Object {
            $_.Context.PreContext |
                Select-String 'GPO:' |
                ForEach-Object {
                    ($_ -split 'GPO:\s*')[1].Trim()
                }
        } |
        Select-Object -Unique

    if ($gpos) {
        foreach ($gpo in $gpos) {
            Write-Host "GPO that contains the DenyNetworkLogonRight policy: $gpo"
        }
    }
    else {
        Write-Host "GPO that contains the DenyNetworkLogonRight policy: UNKNOWN (Run gpresult /scope computer /Z manually to confirm, or it may not be applied via Group Policy)"
    }
}
Write-Host "=== Done ==="
```
If you see `Local admins blocked: YES` in the output, that means the issue is validated.

### Mitigation
Here is an example output from the validation script that validated the issue.

```
=== Checking SeDenyNetworkLogonRight ===
SeDenyNetworkLogonRight: CONFIGURED
Raw value:
  SeDenyNetworkLogonRight = *S-1-5-32-544
Assigned SIDs:
  - S-1-5-32-544
Local admins blocked: YES

=== Identifying applying GPO(s) ===
GPO that contains the DenyNetworkLogonRight policy: Test-GPO
=== Done ===
```

Please check the last section and find the GPO name that contains this  `DenyNetworkLogonRight` policy. In Group Policy console it is displayed as `Deny Access to this computer from the network`. Go to the Group Policy management console and find the GPO with that name. Either uncheck the `Define these policy settings` checkbox for this policy, or remove `Administrators` group from the policy value. 

Location where you can find the policy: 
![Image](./images/access-denied-gpo-location.png)

Once finished, run
```powershell
gpupdate /force
```
on each impacted node. This will help mitigate the issue. Once this is done on all impacted nodes, you can then retry the failed action.
