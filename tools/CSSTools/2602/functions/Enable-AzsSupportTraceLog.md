# Enable-AzsSupportTraceLog

## SYNOPSIS
Enables trace logging to file for AzStack Support.

## SYNTAX

```
Enable-AzsSupportTraceLog [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function sets the AZS_SUPPORT_TRACE_ENABLED environment variable to enable
trace logging to file for AzStack Support.
When enabled, support logs will be written
to a file in addition to ETW tracing.

## EXAMPLES

### EXAMPLE 1
```
Enable-AzsSupportInsightLog
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

