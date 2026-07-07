# Get-AzsSupportPhysicalDiskIndicator

## SYNOPSIS
To get the physical disks with light indicator on.

## SYNTAX

```
Get-AzsSupportPhysicalDiskIndicator [[-SerialNumber] <String>] [-CimSession] <CimSession>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves physical disks with light indicator on that have been marked for attention.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportPhysicalDiskIndicator -CimSession contoso-cl -SerialNumber "ABC1_0000_0000_0001."
```

### EXAMPLE 2
```
Get-AzsSupportPhysicalDiskIndicator -CimSession contoso-cl
```

## PARAMETERS

### -SerialNumber
Physical disk serial number.

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

Required: True
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

### Array of PSObject representing the physical disks with light indicator on
### SerialNumber IsIndicationEnabled HealthStatus OperationalStatus
### ------------ ------------------- ------------ -----------------
### A1B0C2D4EFGH                True Healthy      OK
