# Set-AzsSupportPhysicalDiskIndicator

## SYNOPSIS
To Enable or Disable physical disk indicator for spcific disk based on its serial number.

## SYNTAX

### Enable
```
Set-AzsSupportPhysicalDiskIndicator [-Enable] -SerialNumber <String> -CimSession <CimSession>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Disable
```
Set-AzsSupportPhysicalDiskIndicator [-Disable] -SerialNumber <String> -CimSession <CimSession>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enable physical disk indicator for specific disk based on its serial number to be marked for attention or disable.

## EXAMPLES

### EXAMPLE 1
```
Set-AzsSupportPhysicalDiskIndicator -CimSession contoso-n01
```

### EXAMPLE 2
```
Set-AzsSupportPhysicalDiskIndicator -SerialNumber A1B0C2D4EFGH -Enable -CimSession contoso-cl
```

## PARAMETERS

### -Enable
Enable physical disk indicator light.

```yaml
Type: SwitchParameter
Parameter Sets: Enable
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Disable
Disable physical disk indicator light.

```yaml
Type: SwitchParameter
Parameter Sets: Disable
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -SerialNumber
Physical disk serial number.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CimSession
The Computer name or CimSession to target.

```yaml
Type: CimSession
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
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

### Enable physical disk indicator light :
### Set-AzsSupportPhysicalDiskIndicator -SerialNumber A1B0C2D4EFGH -Enable -CimSession contoso-cl
### [Enabling indicator light for physical disk with serial number A1B0C2D4EFGH]
### [Physical disk with serial number A1B0C2D4EFGH indicator light has been enabled]
### [Light indicator is enabled for some disks]
### SerialNumber IsIndicationEnabled HealthStatus OperationalStatus
### ------------ ------------------- ------------ -----------------
### A1B0C2D4EFGH                True Healthy      OK
