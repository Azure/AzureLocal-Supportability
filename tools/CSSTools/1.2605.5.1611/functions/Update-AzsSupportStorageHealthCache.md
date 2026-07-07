# Update-AzsSupportStorageHealthCache

## SYNOPSIS
Refreshes the storage cache and health cluster resources.

## SYNTAX

```
Update-AzsSupportStorageHealthCache [[-Cluster] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Updates the cache instance and health cluster resources.

## EXAMPLES

### EXAMPLE 1
```
Update-AzsSupportStorageHealthCache
```

### EXAMPLE 2
```
Update-AzsSupportStorageHealthCache -Cluster "Contoso-cl"
```

## PARAMETERS

### -Cluster
The cluster to perform the operation against.

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

### Confirmation on updating the storage cache
### PS> Update-AzsSupportStorageHealthCache -Cluster "Contoso-cl"
### [Stopping health cluster resource]
### [Starting all resources in SDDC Group]
### [Updating Storage Provider Cache]
