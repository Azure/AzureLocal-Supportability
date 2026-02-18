# Get-AzsSupportStoragePool

## SYNOPSIS
Gets specified Storage Pool or all pools if none are provided.

## SYNTAX

```
Get-AzsSupportStoragePool [[-FriendlyName] <String>] [[-CimSession] <CimSession>] [[-IsPrimordial] <Boolean>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves storage pools using specified FriendlyName or IsPrimordial params and CimSession.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStoragePool
```

### EXAMPLE 2
```
Get-AzsSupportStoragePool -FriendlyName S2D_Pool
```

### EXAMPLE 3
```
Get-AzsSupportStoragePool -IsPrimordial $False
```

### EXAMPLE 4
```
Get-AzsSupportStoragePool -Cimsession Contoso-cl
```

## PARAMETERS

### -FriendlyName
Friendly name of Storage Pool.

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
Computer name or CimSession to target.

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

### -IsPrimordial
If set to $true, will return only primordial pools.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: False
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

### PS> Get-AzsSupportStoragePool -FriendlyName S2D_Pool -CimSession Contoso-cl
### Array of Storage Pools based on filters selected
### FriendlyName OperationalStatus HealthStatus IsPrimordial IsReadOnly     Size AllocatedSize PSComputerName
### ------------ ----------------- ------------ ------------ ----------     ---- ------------- --------------
### S2D_Pool     OK                Healthy      False        False      27.94 TB       1.79 TB Contoso-cl
## NOTES

## RELATED LINKS
