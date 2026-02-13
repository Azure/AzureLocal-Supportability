## Symptoms
Admin operations (including Deployment, Upgrade, Update, AddNode, RepairNode) fails with the following messages. This indicates that the settings on Credssp are incorrect, which causes "Invoke-Command -ComputerName $nodeNameOrIP -Credential $cred -Authentication Credssp" to fail.

Message 1
> The WinRM client cannot process the request. A computer policy does not allow the delegation of the user credentials to the target computer. Use gpedit.msc and look at the following policy: Computer Configuration -> Administrative Templates -> System -> Credentials Delegation -> Allow Delegating Fresh Credentials. Verify that it is enabled and configured with an SPN appropriate for the target computer. For example, for a target computer name "myserver.domain.com", the SPN can be one of the following: WSMAN/myserver.domain.com or WSMAN/*.domain.com. For more information, see the about_Remote_Troubleshooting Help topic. 

Message 2
> The WinRM client cannot process the request. A computer policy does not allow the delegation of the user credentials to the target computer because the computer is not trusted. The identity of the target computer can be verified if you configure the WSMAN service to use a valid certificate using the following command: winrm set winrm/config/service '@{CertificateThumbprint="<thumbprint>"}' Or you can check the Event Viewer for an event that specifies that the following SPN could not be created: WSMAN/<computerFQDN>. If you find this event, you can manually create the SPN using setspn.exe . If the SPN exists, but CredSSP cannot use Kerberos to validate the identity of the target computer and you still want to allow the delegation of the user credentials to the target computer, use gpedit.msc and look at the following policy: Computer Configuration -> Administrative Templates -> System -> Credentials Delegation -> Allow Fresh Credentials with NTLM-only Server Authentication. Verify that it is enabled and configured with an SPN appropriate for the target computer. For example, for a target computer name "myserver.domain.com", the SPN can be one of the following: WSMAN/myserver.domain.com or WSMAN/*.domain.com.

Message 3
> The WinRM client cannot process the request. The authentication mechanism requested by the client is not supported by the server or unencrypted traffic is disabled in the service configuration. Verify the unencrypted traffic setting in the service configuration or specify one of the authentication mechanisms supported by the server.

Message 4
> The WinRM client cannot process the request. CredSSP authentication is currently disabled in the client configuration. Change the client configuration and try the request again. CredSSP authentication must also be enabled in the server configuration. Also, Group Policy must be edited to allow credential delegation to the target computer.


## Cause
The credssp is set by the Orchestrator, but this might be changed by customers manually or through GPO. Refer to the Section "Group Policy" below for more details.

## Issue Validation
Run the command below **on the Cluster Nodes** to see if it gives the error of Message 1 in Symptoms:
```powershell
Invoke-Command -ComputerName $remoteNodeName -Credential $deploymentUserCred -Authentication Credssp -ScriptBlock {whoami}
```
If it throws Message 1, it means AllowFreshCredentials is not configured correctly.
If it is Message 3, it means CredSSP is not enabled in the Service configuration.
If it is Message 4, it means CredSSP is not enabled in the Client configuration.

Run the command below **on the Cluster Nodes** to see if it gives the error of Message 2 in Symptoms:
```powershell
Invoke-Command -ComputerName $remoteNodeIP -Credential $deploymentUserCred -Authentication Credssp -ScriptBlock {whoami}
```

If it throws Message 2, it means AllowFreshCredentialsWhenNTLMOnly is not configured correctly.

## Mitigation
Run the script below **on the Cluster Nodes** to validate the Credssp Settings:
```powershell
function Test-LocalCredsspSetting
{
    [CmdletBinding()]
    param (
        [switch]$AfterGPUpdate
    )

    $v = $true;

    $r = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\WSMAN\Service" -Name "auth_credssp" -ErrorAction SilentlyContinue
    if (($null -eq $r) -or ($r.auth_credssp -ne 1))
    {
        Write-Warning "CredSSP is not enabled on WinRM Service"
        $v = $false
    }

    $r = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\WSMAN\Client" -Name "auth_credssp" -ErrorAction SilentlyContinue
    if (($null -eq $r) -or ($r.auth_credssp -ne 1))
    {
        Write-Warning "CredSSP is not enabled on WinRM Client"
        $v = $false
    }  

    $r = Get-Item "HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials" -ErrorAction SilentlyContinue
    if (($null -eq $r) -or ($r.Property.Count -ne 1) -or ($r.Property[0] -ne '1'))
    {
        Write-Warning "The setting of AllowFreshCredentials is incorrect: it should contain only one property called '1'"
        $v = $false
    } 

    $r = Get-ItemProperty "HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials" -Name "1" -ErrorAction SilentlyContinue
    if (($null -eq $r) -or ($r.'1' -ne 'WSMAN/*'))
    {
        Write-Warning "The setting of AllowFreshCredentials is incorrect: the value of '1' should be 'WSMAN/*'"
        $v = $false
    }  

    $r = Get-Item "HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -ErrorAction SilentlyContinue
    if (($null -eq $r) -or ($r.Property.Count -ne 1) -or ($r.Property[0] -ne '1'))
    {
        Write-Warning "The setting of AllowFreshCredentialsWhenNTLMOnly is incorrect: it should contain only one property called '1'"
        $v = $false
    }  

    $r = Get-ItemProperty "HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -Name "1" -ErrorAction SilentlyContinue
    if (($null -eq $r) -or ($r.'1' -ne 'WSMAN/*'))
    {
        Write-Warning "The setting of AllowFreshCredentialsWhenNTLMOnly is incorrect: the value of '1' should be 'WSMAN/*'"
        $v = $false
    }  

    $r = Get-ItemProperty "HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation" -Name "ConcatenateDefaults_AllowFresh" -ErrorAction SilentlyContinue
    if (($null -eq $r) -or ($r.ConcatenateDefaults_AllowFresh -ne 1))
    {
        Write-Warning "The setting of ConcatenateDefaults_AllowFresh is incorrect"
        $v = $false
    }  

    $r = Get-ItemProperty "HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation" -Name "ConcatenateDefaults_AllowFreshNTLMOnly" -ErrorAction SilentlyContinue
    if (($null -eq $r) -or ($r.ConcatenateDefaults_AllowFreshNTLMOnly -ne 1))
    {
        Write-Warning "The setting of ConcatenateDefaults_AllowFreshNTLMOnly is incorrect"
        $v = $false
    }

    if (!$v -and $AfterGPUpdate)
    {
        Write-Warning "Please refer to the section below to check domain group policy or local group policy which reverts the settings for Credssp."
    }

    if ($v)
    {
        Write-Verbose -Message "The settings for Credssp are correct" -Verbose
    }

    return $v
}

$r = Test-LocalCredsspSetting
if ($r)
{
    Write-Verbose -Message "Running gpupdate ..." -Verbose
    gpupdate /force | Out-Null
    Test-LocalCredsspSetting -AfterGPUpdate
}
```

Run the script below **on the Cluster Nodes** to reset the registry keys for Credssp:
```powershell
# Enable CredSSP in the Service configuration
Set-Item 'wsman:\localhost\Service\Auth\CredSSP' $true -Force

# Enable CredSSP in the Client configuration
Set-Item 'wsman:\localhost\Client\Auth\CredSSP' $true -Force

# Set properties of CredentialsDelegation key

Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentials -Value 1 -Type DWORD -Force

Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentialsWhenNTLMOnly -Value 1 -Type DWORD -Force

Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name ConcatenateDefaults_AllowFresh -Value 1 -Type DWORD -Force

Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name ConcatenateDefaults_AllowFreshNTLMOnly -Value 1 -Type DWORD -Force

  

# Create CredentialsDelegation sub-keys, if needed

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials" -ItemType Directory -Force

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -ItemType Directory -Force

  

# Set properties of CredentialsDelegation sub-keys

Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials" -Name "1" -Value "wsman/*" -Type String -Force

Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -Name "1" -Value "wsman/*" -Type String -Force
```



## Group Policy
The value of the registry keys listed above might be reverted by Group Policy, including Domain Group Policy and Local Group Policy.

If you apply the script above and then learn that the values of some registry keys are reverted back after running **"gpupdate.exe"** or restarting the node, most likely the culprit is Group Policy.


In domain‑joined environments, Domain Group Policy can override locally applied registry settings. One common mitigation is to ensure that the Organizational Unit (OU) containing the node is configured so that unintended Domain Group Policies are not applied. If Group Policy inheritance is enabled on the OU, collect the Resultant Set of Policy for the node (for example, by running `gpresult /r` or `gpresult /h` on the node, using `rsop.msc`, or `Get-GPResultantSetOfPolicy`) and/or review the GPO links and security filtering in Group Policy Management for the specific OU/computer account to confirm that none are enforcing these registry values.

To check Local Group Policy on the cluster node, run **"gpedit.msc /gpcomputer: $nodeName"** on the jumpbox using a credential that has access to the node. If there is a group policy configured for these settings it will be in Computer Configuration -> Administrative Templates -> System -> Credentials Delegation

![items.png](Items.png)

To reset Local Group Policy, there are 2 options:
1. Keep the setting as "Enabled" and update the value to the correct one based on the mitigation script. Run **"gpupdate.exe"** to make it take effect.
2. Change the setting to "Not Configured". Run **"gpupdate.exe"** which will delete the registry key. Reset the registry key using the mitigation script and run **"gpupdate.exe"** again. 
