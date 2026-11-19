# Invoke-AzsSupportInsightRemediation

## SYNOPSIS
Executes a specified remediation script for Azure Stack Insights.

## SYNTAX

```
Invoke-AzsSupportInsightRemediation [-ScriptName] <String> [[-Parameters] <Hashtable>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function takes the name of a remediation script and an optional hashtable of arguments, executes the script,
and handles the result.
It also includes error handling and logs the remediation process.
The remediation scripts
should be located in the "remediations" subfolder of the module directory and must return a standardized result object.

## EXAMPLES

### EXAMPLE 1
```
Invoke-AzsSupportInsightRemediation -ScriptName "FixExampleIssue" -Parameters @{ Force = $true }
```

### EXAMPLE 2
```
Invoke-AzsSupportInsightRemediation -ScriptName "FixExampleIssue" -Parameters @{ SkipEnvironmentCheck = $true }
```

## PARAMETERS

### -ScriptName
The name of the remediation script to execute (without the .ps1 extension).
The script must be located in the "remediations" subfolder of the module directory.

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

### -Parameters
An optional hashtable of arguments to pass to the remediation script.
The keys of the hashtable should match the parameter names expected by the remediation script.
By default, all scripts support Force and SkipEnvironmentCheck parameters, which can be included in this hashtable if needed.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
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

