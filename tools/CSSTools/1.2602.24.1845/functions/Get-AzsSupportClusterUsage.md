# Get-AzsSupportClusterUsage

## SYNOPSIS
Calculate storage usage and capacity for the cluster

## SYNTAX

```
Get-AzsSupportClusterUsage [[-ClusterName] <String>] [[-CimSession] <CimSession>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Allows quick understanding of the current environment and capacity

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportClusterUsage -ClusterName "Contoso-cl"
```

### EXAMPLE 2
```
Get-AzsSupportClusterUsage -CimSession $CimSession
```

## PARAMETERS

### -ClusterName
The Cluster you want to run against

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CimSession
The CimSession to use for remote operations.
If not provided, a new session will be created using ClusterName.

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

### Write Cache Size         : 20.95
### SupportedComponents      : <Components><Disks><Disk><Manufacturer /><Model /><AllowedFirmware><Version /></AllowedFirmware></Disk></Disks><Cache /></Components>
### Used                     : 2.26
### Physical Disk Redundancy : 1
### Capacity Disk Size       : 10.69
### Total Size               : 256.61
### Total Drives             : 36
### Drive Models             : {@{Count=12; Model=KPM6WVUG1T92; Size (TB)=2}, @{Count=24; Model=MG07SCA12TEY; Size (TB)=11}}
### Reserve                  : 21.38
### Available                : 254.35
