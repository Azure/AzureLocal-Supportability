# Get-AzsSupportWinEvent

## SYNOPSIS
Get eventlog entries from a cluster or its node in filtered format

## SYNTAX

```
Get-AzsSupportWinEvent [-LogName] <String> [[-Cluster] <String>] [[-ClusterNodes] <String>]
 [[-Message] <String>] [[-EventId] <Array>] [[-FilterInformation] <Boolean>] [[-ProviderName] <Array>]
 [[-Backwards] <Boolean>] [[-Date] <String>] [[-Duration] <String>] [[-Detailed] <Boolean>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Get-AzsSupportWinEvent read various windows eventlogs (which can be read with get-winevent) from a cluster or remote computers

## EXAMPLES

### EXAMPLE 1
```
Checking 2 clusterNodes's logs contains the word "smbclient" on 01/10/2024 between 17:00 and 20:00
Get-AzsSupportWinEvent -clusterNodes strhci03,strhci02 -Logname *smbclient* -FilterInformation 0 -Date 01/10/2024 -time 17:00:00 -Duration 3
```

## PARAMETERS

### -LogName
Name of the log, wildcards can be used ("*")

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

### -Cluster
Name of the cluster

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: (Get-Cluster)
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClusterNodes
Name of the clusterNodes.
Use "," as separator

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Message
Filter for event message, wildcards can be used ("*")

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EventId
EventID filtering.
Use "," as separator

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FilterInformation
Filter out informational events, disabled by default.
(1 or 0)

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProviderName
Event provider name filter.

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Backwards
Go back in time.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

### -Date
Date of start.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: (Get-Date)
Accept pipeline input: False
Accept wildcard characters: False
```

### -Duration
Time window of the events, can be hours (single digit) or specified time (hh:mm:ss)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -Detailed
Output will be in format-list format, disabled by default

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: False
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

