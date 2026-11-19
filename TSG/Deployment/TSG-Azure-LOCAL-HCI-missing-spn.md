# TSG | 23H2 | 10.2411.3.2 | Missing SPN during deployment


# Symptoms

The portal or response from the ARM request contains the error when trying to run a deployment or a validate command.

  

```

Type 'DeployArb' of Role 'MocArb' raised an exception: [DeployArb:Fetching SP in CloudDeployment Scenario] Exception calling 'GetCredential' with '1' argument(s): 'Exception of type 'CloudEngine.Configurations.SecretNotFoundException' was thrown.' at at Get-CloudDeploymentServicePrincipal,

```

# Mitigation Details    

## Generating the SPN in Azure


  
1.  Sign in to Azure Portal

### Navigate to "App Registrations"

  
![image.png](./images/image-2061e9e1-98c1-4997-9d8d-b4214c7d3ba5.png)

### Register a New Application

    1.  Name: Choose a name like `HCI-SPN` or `HCI-Deployment-App`. 
    2.  Supported account types: Select "Accounts in this organizational directory only".
    3.  Leave Redirect URI blank for now.
    4.  Click "Register".

  
![image.png](./images/image-c0d37109-e1f4-465c-b904-d76cd89a0bc4.png)

  

### Create a Client Secret

1.  After registration, go to the HCI-SPN overview to copy the Application id.
2.  Then, go to Certificates & secrets in the left pane. 
3.  Under Client secrets, click "New client secret". 
4.  Add a description (e.g., "HCI secret") and expiry (e.g., 1 year or 2 years).
5.  Click "Add". 
6.  Copy the secret value now – you won’t see it again.

![image.png](./images/image-14e604ab-b367-49cb-986c-73b9f4457bc4.png)

![image.png](./images/image-bab52f81-8d5d-4064-a445-c1a5c727d7ac.png)

![image.png](./images/image-36ccec4b-ca9a-4a35-802d-b0d85f0cbc72.png)

  

### Assign Permissions

*   Navigate to Subscriptions in the Azure portal. 
*   Select your subscription.
*   Click Access Control (IAM). 
*   Click Add > Add role assignment.

![image.png](./images/image-4035e151-7ab1-4626-bd7f-d2dc78ab9017.png)
  
  
*   Role: Select "Azure Resource Bridge Deployment Role"
*   Assign access to: `User, group, or service principal`. 
*   Search for your app name (e.g., `HCI-SPN`) and select it. 
*   Click Save.

![image.png](./images/image-aa6e789a-6337-41f1-9040-d2e2f8d97aca.png)

![image.png](./images/image-c5fd46ca-9dd8-4a74-83db-74e311d901b1.png)

  
  

## Setting the SPN on the host

The instructions below are to set the SPN in the ECEStore. The below commands must be run on the **seed node** running deployment. The seed node can be identified by examining which host has the C:\ECEStore folder. This is usually the first host in the node list of the arm template or portal node list but not always.

``` Powershell
Import-Module C:\CloudDeployment\ECEngine\EnterpriseCloudEngine.psd1
Import-Module ECEClient


$appId = "<application (client) Id>"  
$secret = "<hci secret value (not secret Id)>"

$password = ConvertTo-SecureString  $secret -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($appId, $password)


Set-ECESecret -ContainerName "DefaultARBApplication" -Credential $cred | Out-Null
Set-ECEServiceSecret -ContainerName "DefaultARBApplication" -Credential $cred | Out-Null

```

After running the above code resume the deployment through the portal or resubmit the arm template
