# Get-AzsSupportStorageSNV

## SYNOPSIS
Checks the Storage Node views for non healthy disks.

## SYNTAX

```
Get-AzsSupportStorageSNV [[-CimSession] <CimSession>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Checks the view of Storage Nodes for Storage Node views for non healthy disks.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageSNV -CimSession contoso-cl
```

## PARAMETERS

### -CimSession
The Computer or CimSession you want to check if not provided with only check for local disks.

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

### Checks for any abnormalities with the Storage Node views for non healthy disks
### Get-AzsSupportStorageSNV -CimSession contoso-cl | Format-Table -AutoSize
### SerialNumber         OperationalStatus   Node              Connected DiskNumber HealthStatus
### ------------         -----------------   ----              --------- ---------- ------------
### A1B0C2D4EFGH         OK                  N:Contoso-N01      True           1003 Healthy
### A1B0C2D4EFGH         In Maintenance Mode N:contoso-n02      False          1003 Warning
