# Get-AzsSupportStorageSubsystem

## SYNOPSIS
Gets specified Storage Subsystem or all subsystems if none are provided.

## SYNTAX

```
Get-AzsSupportStorageSubsystem [[-FriendlyName] <String>] [[-CimSession] <CimSession>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves storage subsystems connected to the specified ComputerName.
If no node is provided, all nodes are queried.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageSubsystem
```

### EXAMPLE 2
```
Get-AzsSupportStorageSubsystem -FriendlyName Cluster* -Cimsession Contoso-cl
```

## PARAMETERS

### -FriendlyName
Name of Storage Pool.

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

### Array of Storage Subsystems based on filters selected
### Get-AzsSupportStorageSubsystem -FriendlyName Cluster* -Cimsession Contoso-cl
### FriendlyName                            HealthStatus OperationalStatus PSComputerName
### ------------                            ------------ ----------------- --------------
### Clustered Windows Storage on Contoso-cl Healthy      OK                Contoso-cl
