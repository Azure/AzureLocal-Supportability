# Enable-AzsSupportTraceLog

## SYNOPSIS
Enables trace logging to file for AzStack Support.

## SYNTAX

```
Enable-AzsSupportTraceLog [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function sets the AZS_SUPPORT_TRACE_ENABLED machine environment variable. When set,
the shared ETW dispatcher (Write-EtwTrace in AzStack.Observability) additionally writes
Write-AzsSupportLog events to a shared log file, in addition to ETW tracing.
Because the underlying ETW logger is a single instance shared for the lifetime of the
PowerShell process, this setting only takes effect for new sessions started after it is
changed.

## EXAMPLES

### EXAMPLE 1
```
Enable-AzsSupportTraceLog
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

