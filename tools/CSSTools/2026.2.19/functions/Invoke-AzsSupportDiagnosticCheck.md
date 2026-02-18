# Invoke-AzsSupportDiagnosticCheck

## SYNOPSIS
Runs a diagnostic check on the health and functionality of the specified Azure Stack HCI product.

## SYNTAX

```
Invoke-AzsSupportDiagnosticCheck [-Component] <Component> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
The Invoke-AzsSupportDiagnosticCheck cmdlet runs a diagnostic check on the health and functionality of the specified Azure Stack HCI product.
The cmdlet checks for common issues and provides detailed information about any errors or warnings encountered during the check.

## EXAMPLES

### EXAMPLE 1
```
Invoke-AzsSupportDiagnosticCheck -Component "Network"
```

Runs a diagnostic check on the health and functionality of the Azure Stack HCI product.

## PARAMETERS

### -Component
Specifies the Azure Stack HCI component to check.
Valid values are: \[insert list of valid components here\].

```yaml
Type: Component
Parameter Sets: (All)
Aliases:
Accepted values: Network, Update

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

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

## INPUTS

## OUTPUTS

## NOTES
This cmdlet requires administrative privileges to run.
It does not modify any system settings or configurations.

## RELATED LINKS
