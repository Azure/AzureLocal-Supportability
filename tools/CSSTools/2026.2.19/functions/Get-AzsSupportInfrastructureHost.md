# Get-AzsSupportInfrastructureHost

## SYNOPSIS
Gets physical host node information from FailoverClustering.

## SYNTAX

```
Get-AzsSupportInfrastructureHost [[-Name] <String>] [[-Cluster] <String>] [[-State] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets physical host node information from FailoverClustering.
If no Cluster is provided, it will attempt to find Nodes.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportInfrastructureHost
```

### EXAMPLE 2
```
Get-AzsSupportInfrastructureHost -Cluster "contoso-cl"
```

### EXAMPLE 3
```
Get-AzsSupportInfrastructureHost -Node "contoso-n01" -Cluster "contoso-cl"
```

### EXAMPLE 4
```
Get-AzsSupportInfrastructureHost -Cluster $Cluster -State:Up
```

## PARAMETERS

### -Name
A node name, such as contoso-n01 to filter the results.

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

### -Cluster
Cluster to connect to, such as contoso-cl

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

### -State
A node state, such as Up, Down, Paused, or Unknown to filter the results.

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

### Get-AzsSupportInfrastructureHost -cluster contoso-cl
### Name            State Type
### ----            ----- ----
### contoso-n01     Up    Node
### contoso-n02     Up    Node
