# Get-AzsSupportStorPortOpEvents

## SYNOPSIS
Checks for Storport Operational Events.

## SYNTAX

```
Get-AzsSupportStorPortOpEvents [-ClusterName] <String> [-StartTime] <DateTime> [-EndTime] <DateTime>
 [[-Credential] <PSCredential>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Checks for Storport Operational Events over a specified time period on specified nodes.

## EXAMPLES

### EXAMPLE 1
```
$StartTime = (Get-Date).AddDays(-2)
$EndTime = (Get-Date).AddDays(-1)
Get-AzsSupportStorPortOpEvents -ClusterName contoso-cl -StartTime $StartTime -EndTime $EndTime | Sort-Object TimeCreated  | Format-Table  | Format-Table -AutoSize
```
```

## PARAMETERS

### -ClusterName
Name of the cluster you want to run against.

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

### -StartTime
When you would like to start looking from .

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EndTime
When you would like to end looking to.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: [System.Management.Automation.PSCredential]::Empty
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

### Lists specific errors from Storport drive resets and Storage Spaces Driver report disk errors.
