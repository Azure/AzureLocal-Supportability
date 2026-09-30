# Show-AzsSupportEnvironmentValidatorSummary

## SYNOPSIS
Retrieves and displays a comprehensive summary of environment validator results from the event log.

## SYNTAX

```
Show-AzsSupportEnvironmentValidatorSummary [-Concise] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function queries the AzStackHciEnvironmentChecker event log for validation results,
filters to get the latest run results, and displays a summary of succeeded, warning, and failed validators.
It shows color-coded counts for each status category and detailed information for failed and warning validators,
including descriptions, remediation steps, and additional diagnostic data.

## EXAMPLES

### EXAMPLE 1
```
Show-AzsSupportEnvironmentValidatorSummary
```
Displays a comprehensive summary of the most recent environment validator run results, including:
- Color-coded count summary (succeeded in green, warnings in yellow, failed in red)
- Detailed information for each failed validator with description, remediation, and additional data
- Detailed information for each warning validator with description, remediation, and additional data
- Success message if all validators passed

### EXAMPLE 2
```
Show-AzsSupportEnvironmentValidatorSummary -Concise
```
Displays only the summary counts without detailed validator information:
- \[SUCCEEDED\] 25
- \[WARNING\] 2  
- \[FAILED\] 1

## PARAMETERS

### -Concise
Optional switch parameter.
When specified, displays only the summary counts without detailed information
for individual validators.
Useful for quick status checks.

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

### None. This function displays formatted output to the console with color-coded information.
## NOTES
- Queries event ID 17205 from the AzStackHciEnvironmentChecker event log
- Automatically filters to show only the most recent validation run results
- Uses validator name and target resource ID combination to identify unique validators
- Displays results in a color-coded format for easy visual assessment
- Failed validators are displayed with red headers and separators
- Warning validators are displayed with yellow headers and separators  
- Remediation steps are highlighted in cyan for easy identification
- Additional data objects are formatted as readable key-value pairs

