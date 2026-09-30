# Test-AzsSupportSolutionInstalled

## SYNOPSIS
Determines whether the Azure Local solution is present on the current system.

## SYNTAX

```
Test-AzsSupportSolutionInstalled [-Terminating] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Returns the cached platform state recorded on the CSSTools_AzsSupport global during module
import: $false when running on plain HCI OS, $true when the Azure Local solution is also
installed.
When the global has not yet been populated - for example when this function is
called in isolation before the main module has finished loading - it falls back to a live
probe for the solution-provided cmdlets so the result is still correct.

## EXAMPLES

### EXAMPLE 1
```
Test-AzsSupportSolutionInstalled
True
```

## PARAMETERS

### -Terminating
If specified, the function will throw a terminating error if the solution is not installed.

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

## OUTPUTS

### System.Boolean. $true when the Azure Local solution is installed; otherwise $false.
