# Get-AzsSupportStorageDiskLatency

## SYNOPSIS
Checks for disk latency over specified thresholds using version-safe property access from live cluster event logs

## SYNTAX

```
Get-AzsSupportStorageDiskLatency [[-Latency] <String>] [[-StartTime] <DateTime>] [[-EndTime] <DateTime>]
 [-Nodes] <Array> [[-Credential] <PSCredential>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

# Basic cluster analysis with default settings - bucket names are dynamic based on StorPort event schema
PS> $Nodes = Get-ClusterNode -Cluster "MyCluster"
PS> Get-AzsSupportStorageDiskLatency -Nodes $Nodes | Sort-Object MachineName, Serial | Format-Table -AutoSize
```

### EXAMPLE 2
```
# Custom time range and latency threshold - accepts any format that matches StorPort event buckets
PS> $Nodes = Get-ClusterNode -Cluster "MyCluster"
PS> $StartTime = (Get-Date).AddDays(-1)
PS> $EndTime = (Get-Date)
PS> Get-AzsSupportStorageDiskLatency -Nodes $Nodes -Latency "500ms" -StartTime $StartTime -EndTime $EndTime | Sort-Object MachineName, Serial | Format-List
```

### EXAMPLE 3
```
# Advanced filtering - works with any Windows version's StorPort schema
PS> $Nodes = Get-ClusterNode -Cluster "MyCluster"
PS> $Results = Get-AzsSupportStorageDiskLatency -Nodes $Nodes -Latency "1000ms" -StartTime (Get-Date).AddHours(-6)
PS> # Filter for events with high latency values (bucket names are determined dynamically)
PS> $Results | Where-Object {
>>     $currentObject = $_
>>     $latencyProperties = $_.PSObject.Properties.Name | Where-Object { $_ -notmatch '^(MachineName|Serial|OccurrenceTime|Vendor)$' }
>>     ($latencyProperties | ForEach-Object {
>>         $propValue = $currentObject.$_
>>         if ($propValue -ne "error" -and $propValue -gt 0) { $true }
>>     }) -contains $true
>> } | Format-Table -AutoSize
```

## PARAMETERS

### -Latency
The latency threshold to check for breaches (default: 10000ms).
Accepts formats like: 16ms, 500ms, 2000ms, 10s, 20000+ms.
Value must match an actual latency bucket in the StorPort events (validated at runtime against dynamic bucket schema).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: 10000ms
Accept pipeline input: False
Accept wildcard characters: False
```

### -StartTime
When you would like to start looking from (default: 24 hours ago)

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: (Get-Date).AddDays(-1)
Accept pipeline input: False
Accept wildcard characters: False
```

### -EndTime
When you would like to end looking to (default: current time)

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: (Get-Date)
Accept pipeline input: False
Accept wildcard characters: False
```

### -Nodes
Array of cluster nodes to check

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
PSCredential object for authenticating to remote computers.
If not provided, uses current user context.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
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

### Lists all disks that meet latency criteria with comprehensive latency bucket analysis from Node event logs.
### Note: Latency bucket property names are dynamically determined from StorPort events and vary between Windows versions.
### Schema Detection: Automatically handles RS1 (combined count) vs RS5+ (separate success/failed counts) schemas.
