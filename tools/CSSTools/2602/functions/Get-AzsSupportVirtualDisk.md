# Get-AzsSupportVirtualDisk

## SYNOPSIS
Gets all virtual disks and their health states.

## SYNTAX

```
Get-AzsSupportVirtualDisk [[-CimSession] <CimSession>] [[-FriendlyName] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves virtual disks connected to the specified ComputerName.
If no Cluster is provided, it will query all nonprimordial pools found.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportVirtualDisk
```

### EXAMPLE 2
```
Get-AzsSupportVirtualDisk -CimSession "Contoso-cl"
```

### EXAMPLE 3
```
Get-AzsSupportVirtualDisk -FriendlyName "UserStorage_1"
```

## PARAMETERS

### -CimSession
Computer name or CimSession to target.

```yaml
Type: CimSession
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FriendlyName
FriendlyName of VirtualDisk you want to retrieve.

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

### Array of virtual disks based on filters selected
### FriendlyName  ResiliencySettingName FaultDomainRedundancy OperationalStatus HealthStatus  Size FootprintOnPool StorageEfficiency PSComputerName
### ------------  --------------------- --------------------- ----------------- ------------  ---- --------------- ----------------- --------------
### UserStorage_1 Mirror                1                     OK                Healthy       64 TB        1017 GB            49.95% Contoso-cl
