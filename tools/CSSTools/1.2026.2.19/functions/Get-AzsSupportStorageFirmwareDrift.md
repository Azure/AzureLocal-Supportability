# Get-AzsSupportStorageFirmwareDrift

## SYNOPSIS
Checks for Firmware Drift in Storage Spaces

## SYNTAX

```
Get-AzsSupportStorageFirmwareDrift [[-CimSession] <CimSession>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Checks for models of disk running different firmware

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageFirmwareDrift -CimSession $ClusterName
```

## PARAMETERS

### -CimSession
The ComputerName or CimSession you want to check for firmware drift if not provided it will check the local node only.

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

### Array of disk models with different firmware versions
### Get-AzsSupportStorageFirmwareDrift -CimSession Contoso-cl
###  Count Model        FirmwareVersion
###  ----- -----        ---------------
###  2     MG07SCA12TEY {AB0C, DE48}
## NOTES

## RELATED LINKS
