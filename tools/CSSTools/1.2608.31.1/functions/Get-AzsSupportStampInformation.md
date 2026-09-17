# Get-AzsSupportStampInformation

## SYNOPSIS
Gets common stamp information

## SYNTAX

```
Get-AzsSupportStampInformation [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Queries for common stamp information properties such as DeploymentID, OEMVersion and CloudID.
On plain HCI OS, where the Azure Local solution is not installed, an equivalent view is
synthesized from operating-system, computer, and cluster data instead.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStampInformation
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

## OUTPUTS

### Outputs the Stamp Information
