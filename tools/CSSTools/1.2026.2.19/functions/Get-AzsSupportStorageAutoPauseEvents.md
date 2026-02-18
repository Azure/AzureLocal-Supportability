# Get-AzsSupportStorageAutoPauseEvents

## SYNOPSIS
Checks for volume autopause events

## SYNTAX

```
Get-AzsSupportStorageAutoPauseEvents [-StartTime] <DateTime> [-EndTime] <DateTime> [-Nodes] <Array[]>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Checks for volume autopause events over a specified time period on specified nodes

## EXAMPLES

### EXAMPLE 1
```
$StartTime = (Get-Date).AddDays(-2)
$EndTime = (Get-Date).AddDays(-1)
$Nodes = Get-AzsSupportClusterNode
Get-AzsSupportStorageAutoPauseEvents -StartTime $StartTime -EndTime $EndTime -Nodes $Nodes | Select-Object TimeCreated, Node, Id, CSVFsEventIdName, VolumeName, FromDirectIo, Irp, Parameter1, Parameter2, LastUptime, CurrentDowntime, TimeSinceLastStateTransition, Lifetime, SourceName, StatusName | sort-Object TimeCreated | Format-Table -AutoSize
```

## PARAMETERS

### -StartTime
When you would like to start looking from

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EndTime
When you would like to end looking to

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

### -Nodes
Nodes you want to run the check on

```yaml
Type: Array[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
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

### AutoPause errors over time period specified
### TimeCreated           Node              Id CSVFsEventIdName VolumeName       FromDirectIo Irp Parameter1 Parameter2 LastUptime
### -----------           ----              -- ---------------- ----------       ------------ --- ---------- ---------- ----------
### 12/5/2024 12:21:16 AM contoso-n01     9296 VolumeAutopause  Infrastructure_1        False   0          0          0 5922968750
### 12/5/2024 12:21:16 AM contoso-n01     9296 VolumeAutopause  UserStorage_1           False   0          0          0 5922968750
## NOTES

## RELATED LINKS
