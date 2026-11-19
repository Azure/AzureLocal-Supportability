# Symptoms
When trying to Arc Register the new node, user sees the error code 42.

# Error: 
Bootstrap reported error: A ArcAgentConnectionException error occurred with the message: 'AZCMAgent command failed with error:  >> exitcode: 42. Additional Info: See https://aka.ms/arc/azcmerror'

# Potential causes
1. Az.Accounts version on the system is incorrect.
2. ARM access token is expired.
3. ARM access token is passed incorrectly.

# 1. Az.Accounts version on the system is incorrect

## Issue Validation
Run this cmdlet on each node to see what powershell module versions are present
`Get-InstalledModule Az.Accounts`

If 5.0.0 version is seen, this is expected because of a breaking change -
Changed the default output access token of 'Get-AzAccessToken' from plain text to 'SecureString'.

| Version | Name        | Repository | Description                                         |
|---------|-------------|------------|-----------------------------------------------------|
| 5.0.0   | Az.Accounts | PSGallery  | Microsoft Azure PowerShell - Accounts credential...  |


Release until 2505 expects Az.Accounts version to be 4.0.2, any higher version is not supported.
If there are any versions besides expected version, they need to be removed.


 ## Resolution
 
 To remove unsupported Az.Accounts module versions (any version other than 4.0.2), follow these steps on each node:
 
 1. **List all installed versions of Az.Accounts:**
    ```powershell
    Get-InstalledModule -Name Az.Accounts -AllVersions
    ```
 
 2. **Uninstall all versions except 4.0.2:**
    ```powershell
    Get-InstalledModule -Name Az.Accounts -AllVersions | Where-Object { $_.Version -ne '4.0.2' } | ForEach-Object { Uninstall-Module -Name Az.Accounts -RequiredVersion $_.Version -Force }
    ```
 
 3. **(Optional) Reinstall the required 4.0.2 version if needed:**
    ```powershell
    Install-Module -Name Az.Accounts -RequiredVersion 4.0.2 -Force
    ```
 
 4. **Verify only 4.0.2 is present:**
    ```powershell

    Get-InstalledModule -Name Az.Accounts -AllVersions
    ```
 
  Note: You may need to run PowerShell as Administrator.


  # 2. ARM Access token is expired

  ## Issue validation

  If the token was created more than 1h before using it for registration, this could be a likely cause for the error.

  ## Resolution
  
  Create a new ARM access token and trigger bootstrap again to see if the error resolves.

  **Creating an ARM Access Token**
    
    $token = (Get-AzAccessToken).token

# 3. ARM access token is passed incorrectly

  ## Issue Validation
  Sometimes, AZCMAGENT Error 42 is seen when the ARM Access token is not passed correctly. One reason for this could be that the token is being passed as an object instead of a string.

  ## Resolution

  Pass only the 'token' property of the ARM access token object
      
    $token = (Get-AzAccessToken).token
    
