# Get-AzsSupportVolumeUtilization

## SYNOPSIS
Reports the utilization for all Object Stores.

## SYNTAX

```
Get-AzsSupportVolumeUtilization [[-Filter] <String>] [[-CimSession] <CimSession>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Utilizes Get-Volume to get the utilization for all Object Stores.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportVolumeUtilization.
```

### EXAMPLE 2
```
Get-AzsSupportVolumeUtilization -Filter User* -CimSession "Contoso-cl"
```

### EXAMPLE 3
```
Get-AzsSupportVolumeUtilization -CimSession "Contoso-cl"
```

## PARAMETERS

### -Filter
Wildcard filter for FileSystemLabel.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: [String]::Empty
Accept pipeline input: False
Accept wildcard characters: False
```

### -CimSession
Computer name or CimSession to target.

```yaml
Type: CimSession
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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

### Array representing the volume utilization
### Get-AzsSupportVolumeUtilization -CimSession "Contoso-cl" -Filter User* | Format-Table -AutoSize
### OperationalStatus FileSystemLabel SizeGB SizeRemainingGB UtilizationPercent HealthStatus
### ----------------- --------------- ------ --------------- ------------------ ------------
### OK                UserStorage_1    65536           65038 0.76%              Healthy
### OK                UserStorage_2    65536           65179 0.55%              Healthy
## NOTES

## RELATED LINKS
