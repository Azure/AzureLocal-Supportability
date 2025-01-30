# Facing "Access Denied" For the LCM User

### Description 

### Identifying the Issue

### Mitigating the Issue ( For 2411 and later builds)
To mitigate the issue, please follow the steps below:

### Step 1: Update the CACert Credentials in the ECE Store
To update the CACert user credentials in the ECE store, run the below script.
```
$containerName = "CACertificateCred"
$certPasswordString = [System.Web.Security.Membership]::GeneratePassword(64, 16)
$secureCertPassword = ConvertTo-SecureString -String $certPasswordString -AsPlainText -Force
$caCertificateUserCredential = (New-Object PSCredential -ArgumentList "CACertUser", $secureCertPassword)
Set-ECEServiceSecret -ContainerName $containerName -Credential $caCertificateUserCredential
```

### Step 2: Start secret rotation
```
Run "Start-SecretRotaion" from any of the host nodes.
```

### Mitigating the Issue ( For 2408 and earlier builds)
To mitigate the issue, please follow the steps below:


### Step 1: Update the FCA certificates on all nodes

Run the below on all nodes:
```
$cert = Get-ChildItem -Recurse cert:\LocalMachine\My | Where-Object { $_.Subject -like "CN=FileCopyAgentKeyIdentifier*" } 
$cert | Remove-Item 

# Restart FCA on each host: 
Restart-Service "AzureStack File Copy Agent*" 
```

### Step 2: Update the CACert Credentials in the ECE Store
To update the CACert user credentials in the ECE store, run the below script.
```
$containerName = "CACertificateCred"
$certPasswordString = [System.Web.Security.Membership]::GeneratePassword(64, 16)
$secureCertPassword = ConvertTo-SecureString -String $certPasswordString -AsPlainText -Force
$caCertificateUserCredential = (New-Object PSCredential -ArgumentList "CACertUser", $secureCertPassword)
Set-ECEServiceSecret -ContainerName $containerName -Credential $caCertificateUserCredential
```

### Step 3: Start secret rotation
```
Run "Start-SecretRotaion" from any of the host nodes.
```