# Get-AzsSupportStorageSupportedComponents

## SYNOPSIS
Checks for supported firmware and hardware in Storage Spaces

## SYNTAX

```
Get-AzsSupportStorageSupportedComponents [[-CimSession] <CimSession>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Gets supported componants on storage spaces

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageSupportedComponents -CimSession contoso-cl
```

## PARAMETERS

### -CimSession
The Computer or CimSession you want to check for supported components

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

### Outputs supported components for the cluster
### (Get-AzsSupportStorageSupportedComponents -CimSession contoso-cl).OrigSupportedComponents
### Manufacturer    : .*
### Model           : Dell NVMe PE8010 RI M.2 1.92TB
### AllowedFirmware :
### TargetFirmware  : 1.3.0
### Path            : D:\CloudContent\Microsoft_Reserved\DriveFirmware\Hynix\1.3.0.bin
### ... etc
## NOTES

## RELATED LINKS
