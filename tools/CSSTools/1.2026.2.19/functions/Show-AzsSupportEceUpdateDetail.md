# Show-AzsSupportEceUpdateDetail

## SYNOPSIS
Show ECE update action plan details for the current Azure Stack HCI cluster.

## SYNTAX

```
Show-AzsSupportEceUpdateDetail [[-MaxUpdateRuns] <Object>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
This function retrieves and displays detailed information about ECE update action plans, including all steps and their statuses.
It lists the most recent update action plans and allows the user to select one for detailed viewing.

## EXAMPLES

### EXAMPLE 1
```
Show-AzsSupportEceUpdateDetail
```

## PARAMETERS

### -MaxUpdateRuns
The maximum number of recent update action plans to display for selection.
Defaults to 20.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: 20
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

