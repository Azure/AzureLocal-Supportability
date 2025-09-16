# Symptoms
Customers may receive an error during the pre-update validation indicating there are missing resource providers (RPs).  This issue has been seen especially with the `Microsoft.Attestation` RP.

Example error output shown below.

```
HealthCheckSource  : PreUpdate\Standard\Medium\ArcIntegration\579cf687
Name               : AzStackHci_ArcIntegration_MandatoryRPRegistration_Check
DisplayName        : Test RP registrations are present in the subscription
Tags               : {}
Title              : Test RP registrations are present in the subscription
Status             : FAILURE
Severity           : CRITICAL
Description        : Check if all Resource Providers are registered in the subscription
Remediation        : https://aka.ms/hci-envch
TargetResourceID   : guid_removed
TargetResourceName : AzureStackHCI
TargetResourceType : Azure Subscription
Timestamp          : X/X/2025 XX:XX:XX PM
```

# Issue Validation
To confirm if the specific resource providers are not registered within the subscription, run the following commands from any machine that have the `Az.Accounts` and `Az.Resources` PowerShell modules installed.  

````
#Define the following variables
$Subscription = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
$Tenant = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

#Connect to your Azure account and Subscription
Connect-AzAccount -SubscriptionId $Subscription -TenantId $Tenant -DeviceCode

#Run the command below replacing the RP in the -ProviderNamespace parameter with the RP from the error.  "Microsoft.Attestation" is used in the example below.
Get-AzResourceProvider -ProviderNamespace "Microsoft.Attestation"
````

> :ledger: **NOTE**
>
> Running the command `Get-AzResourceProvider` with no parameters returns all providers registered in the subscription.

An example output from the `Get-AzResourceProvider` command

```
PS C:\> Get-AzResourceProvider -ProviderNamespace "Microsoft.Attestation"


ProviderNamespace : Microsoft.Attestation
RegistrationState : NotRegistered
ResourceTypes     : {attestationProviders}
Locations         : {East US 2, Central US, UK South, East US...}

ProviderNamespace : Microsoft.Attestation
RegistrationState : NotRegistered
ResourceTypes     : {defaultProviders}
Locations         : {East US 2, Central US, UK South, East US...}

ProviderNamespace : Microsoft.Attestation
RegistrationState : NotRegistered
ResourceTypes     : {locations}
Locations         : {}

ProviderNamespace : Microsoft.Attestation
RegistrationState : NotRegistered
ResourceTypes     : {locations/defaultProvider}
Locations         : {East US 2, Central US, UK South, East US...}

ProviderNamespace : Microsoft.Attestation
RegistrationState : NotRegistered
ResourceTypes     : {operations}
Locations         : {}
```

# Cause
Specific resource providers (documented in [Register your Azure Local machines with Azure Arc and assign permissions for deployment - Azure Local | Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-arc-register-server-permissions?view=azloc-2507#azure-prerequisites)) have always been required for Azure Local deployments.  However, the `Microsoft.Attestation` RP may not be registered for older clusters or clusters that were upgraded from 22H2.

A change was recently made to the Environment Checker that ensures the `Microsoft.Attestation` RP is registered to the subscription.

# Mitigation Details

To resolve this issue, register the missing providers to the subscription.

> :ledger: **NOTE**
>
> To register resource providers, the account must be an owner or contributor on the subscription. You can also ask an administrator to register.

```
Register-AzResourceProvider -ProviderNamespace "Microsoft.Attestation"
```