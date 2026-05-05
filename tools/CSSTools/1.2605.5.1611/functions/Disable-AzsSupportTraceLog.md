# Disable-AzsSupportTraceLog

## SYNOPSIS
Disables trace logging to file for AzStack Support.

## SYNTAX

```
Disable-AzsSupportTraceLog [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function removes or clears the AZS_SUPPORT_TRACE_ENABLED environment variable to disable
trace logging to file for AzStack Support.
When disabled, support logs will only use ETW tracing.

## EXAMPLES

### EXAMPLE 1
```
Disable-AzsSupportInsightLog
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

