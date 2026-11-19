# Set-AzsSupportNetworkATCIntentApplyWithTracing

## SYNOPSIS
Applies a Network ATC intent with tracing enabled to capture diagnostic information.

## SYNTAX

```
Set-AzsSupportNetworkATCIntentApplyWithTracing [-IntentName] <String> [[-OutputDirectory] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function enables Network ATC tracing, applies a retry state to a specified network intent,
waits for the intent to complete, and then captures the trace data.
If the intent fails to apply
successfully, it optionally collects additional diagnostic data.

## EXAMPLES

### EXAMPLE 1
```
Set-AzsSupportNetworkATCIntentApplyWithTracing -IntentName "Compute_Management"
Applies the "Compute_Management" intent with tracing enabled and saves output to default directory.
```

### EXAMPLE 2
```
Set-AzsSupportNetworkATCIntentApplyWithTracing -IntentName "Storage" -OutputDirectory "C:\Traces"
Applies the "Storage" intent with tracing enabled and saves output to C:\Traces.
```

## PARAMETERS

### -IntentName
The name of the Network ATC intent to apply.
This intent must already exist.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputDirectory
Optional.
The directory where trace files and diagnostic data will be saved.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: "$(Get-AzsSupportWorkingDirectory)\HostNetwork"
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

