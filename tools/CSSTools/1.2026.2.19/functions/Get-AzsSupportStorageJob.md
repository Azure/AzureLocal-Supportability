# Get-AzsSupportStorageJob

## SYNOPSIS
Gets all active storage jobs from the storage pool and virtual disks.

## SYNTAX

```
Get-AzsSupportStorageJob [-CimSession <CimSession>] [-Wait] [-IncludeStoragePoolOptimizationJob]
 [-RefreshInSeconds <Int32>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves all active storage jobs from the storage pool.
If no node is provided, all nodes are queried.
The optimisation job is excluded by default.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageJob
```

### EXAMPLE 2
```
Get-AzsSupportStorageJob -CimSession contoso-cl
```

### EXAMPLE 3
```
Get-AzsSupportStorageJob -Wait
```

### EXAMPLE 4
```
Get-AzsSupportStorageJob -Wait -RefreshInSeconds 90
```

### EXAMPLE 5
```
Get-AzsSupportStorageJob -CimSession contoso-cl -IncludeStoragePoolOptimizationJob
```

## PARAMETERS

### -CimSession
Computer name or CimSession to target.

```yaml
Type: CimSession
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Wait
Timed refresh for updating the output of any running storage jobs.

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

### -IncludeStoragePoolOptimizationJob

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

### -RefreshInSeconds
How many seconds to wait before refreshing the output again.
Defaults to 60 seconds.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 60
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

### Array of Storage Jobs based on selected filters
### PS> Get-AzsSupportStorageJob -CimSession Contoso-cl -IncludeStoragePoolOptimizationJob
### Name                             IsBackgroundTask ElapsedTime JobState  PercentComplete BytesProcessed BytesTotal PSComputerName
### ----                             ---------------- ----------- --------  --------------- -------------- ---------- --------------
### ClusterPerformanceHistory-Repair True             00:00:28    Suspended 0                          0 B       1    Contoso-cl
### Infrastructure_1-Repair          True             00:00:52    Suspended 0                          0 B       9 GB Contoso-cl
### UserStorage_1-Repair             True             00:00:52    Suspended 0                          0 B     768 MB Contoso-cl
