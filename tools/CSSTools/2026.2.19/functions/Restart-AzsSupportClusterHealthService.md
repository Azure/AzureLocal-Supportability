# Restart-AzsSupportClusterHealthService

## SYNOPSIS
Restarts the cluster health service.

## SYNTAX

```
Restart-AzsSupportClusterHealthService [[-Cluster] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Restarts the cluster health service using appropriate methods and ensures resource correctly started.

## EXAMPLES

### EXAMPLE 1
```
Restart-AzsSupportClusterHealthService
```

### EXAMPLE 2
```
Restart-AzsSupportClusterHealthService -Cluster "Contoso-cl"
```

## PARAMETERS

### -Cluster
Defaults to management cluster returned from Get-AzsSupportClusterName.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: (Get-AzsSupportClusterName )
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

### Confirmation on restarting the cluster health service
### PS> Restart-AzsSupportClusterHealthService -Cluster "Contoso-cl"
### [Stopping health cluster resource]
### [Starting all resources in SDDC Group]
## NOTES

## RELATED LINKS
