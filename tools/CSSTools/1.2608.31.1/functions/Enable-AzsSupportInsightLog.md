# Enable-AzsSupportInsightLog

## SYNOPSIS
Deprecated.
Use Enable-AzsSupportTraceLog instead.

## SYNTAX

```
Enable-AzsSupportInsightLog [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function has been renamed to Enable-AzsSupportTraceLog as part of the AzStack.Observability
consolidation.
This shim forwards the call to the new function so existing scripts continue to
work, and prints a deprecation notice via plain Write-Information so it is always visible
regardless of the caller's InformationPreference.

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

