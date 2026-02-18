# Get-AzsSupportStorageDiskLatency

## SYNOPSIS
Checks for disk latency over x seconds

## SYNTAX

```
Get-AzsSupportStorageDiskLatency [-ClusterName] <String> [[-Latency] <String>] [-StartTime] <DateTime>
 [-EndTime] <DateTime> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Checks for disk latency over x seconds for a given time period for each IO operation.
Restricted to above 2 seconds to control output

## EXAMPLES

### EXAMPLE 1
```
$LatencyBreach = "10s"
$StartTime = (Get-Date).AddDays(-2)
$EndTime = (Get-Date).AddDays(-1)
Get-AzsSupportStorageDiskLatency -ClusterName contoso-cl -Latency $LatencyBreach -StartTime $StartTime -EndTime $EndTime | Sort-Object OccurrenceTime | format-table  MachineName, Serial, OccurrenceTime, Vendor, 128us, 256us, 512us, 1ms, 4ms, 16ms, 64ms, 128ms, 256ms, 512ms, 1s, 2s, 10s, '>10s' -AutoSize
```

## PARAMETERS

### -ClusterName
Name of the cluster you want to run against

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

### -Latency
The value you would like to check if breached, accepted values "1s", "2s", "10s", "\>20s"

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -StartTime
When you would like to start looking from

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

### -EndTime
When you would like to end looking to

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
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

### Lists all disks that meet latency criteria set.
### MachineName   Serial               OccurrenceTime       Vendor        128us    256us    512us      1ms       4ms      16ms     64ms 128ms 256ms 512ms 1s 2s 10s >10s
### -----------   ------               --------------       ------        -----    -----    -----      ---       ---      ----     ---- ----- ----- ----- -- -- --- ----
### contoso-n02   A1B0C2D4EFGH         2/20/2025 6:10:14 PM stornvme 1515611416 55388554 34211624 46012467 180113753 170337635 28330296     0     0     0  0  0   1    0
## NOTES

## RELATED LINKS
