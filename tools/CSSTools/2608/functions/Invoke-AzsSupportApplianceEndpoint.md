# Invoke-AzsSupportApplianceEndpoint

## SYNOPSIS
Invokes a REST API call against a specified Azure Stack HCI support appliance endpoint using the provided URL and client certificate.

## SYNTAX

```
Invoke-AzsSupportApplianceEndpoint [[-Url] <Uri>] [[-Certificate] <X509Certificate2>] [-Endpoint] <String>
 [-ConvertToJson] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function constructs the full REST API endpoint URL by formatting the endpoint template
from the module configuration with the base URL provided, and then invokes the REST API
call using the specified client certificate.
It handles retries and error reporting for
failed requests.

## EXAMPLES

### EXAMPLE 1
```
Invoke-AzsSupportApplianceEndpoint -Url https://10.0.0.50 -Certificate (Get-DisconnectedOperationsClientContext).ManagementEndpointClientCert -Endpoint SystemConfiguration
```

## PARAMETERS

### -Url
The base URL of the Azure Stack HCI support appliance to which the REST API call will be made.

```yaml
Type: Uri
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Certificate
The client certificate to use for authenticating the REST API call.

```yaml
Type: X509Certificate2
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Endpoint
The key of the endpoint template in the module configuration to invoke.
The template will be formatted
with the base URL provided in -Url to construct the full REST API endpoint URI.
Available endpoint keys are defined in the module configuration under $Global:CSSTools_AzStack_Disconnected.Config.Endpoints.sysconfig.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConvertToJson
Convert the output to JSON format.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

