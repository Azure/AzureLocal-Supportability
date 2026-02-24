# Get-AzsSupportClusterName

## SYNOPSIS
Gets the failover cluster name.

## SYNTAX

```
Get-AzsSupportClusterName [[-Name] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets the failover cluster name.
If no cluster name is provided, it will attempt to get the cluster name.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportClusterName -Name "contoso-cl"
```

### EXAMPLE 2
```
Get-AzsSupportClusterName
```

## PARAMETERS

### -Name
Filter the results by the provided cluster name.

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

### Output the Cluster name
### contoso-cl
