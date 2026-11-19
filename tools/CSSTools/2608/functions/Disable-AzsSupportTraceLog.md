# Disable-AzsSupportTraceLog

## SYNOPSIS
Disables trace logging to file for AzStack Support.

## SYNTAX

```
Disable-AzsSupportTraceLog [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function removes or clears the AZS_SUPPORT_TRACE_ENABLED machine environment variable.
When disabled, Write-AzsSupportLog events will only use ETW tracing. Because
the underlying ETW logger is a single instance shared for the lifetime of the PowerShell
process, this setting only takes effect for new sessions started after it is changed.

## EXAMPLES

### EXAMPLE 1
```
Disable-AzsSupportTraceLog
```

## PARAMETERS

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

