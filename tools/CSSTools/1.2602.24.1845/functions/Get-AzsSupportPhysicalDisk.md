# Get-AzsSupportPhysicalDisk

## SYNOPSIS
Gets physical disks connected to the specified ComputerName.

## SYNTAX

```
Get-AzsSupportPhysicalDisk [[-CimSession] <CimSession>] [[-SerialNumber] <String>] [[-PD] <String>]
 [-UnhealthyDisks] [-LocalOnly] [[-UniqueId] <String>] [[-StorageSubSystem] <CimInstance>]
 [[-StoragePool] <CimInstance>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves physical disks connected to the specified ComputerName.
If no node is provided, all nodes are queried.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportPhysicalDisk
```

### EXAMPLE 2
```
Get-AzsSupportPhysicalDisk -CimSession contoso-n02 | Format-Table
```

### EXAMPLE 3
```
Get-AzsSupportPhysicalDisk -SerialNumber ABC1_0000_0000_0001.
```

### EXAMPLE 4
```
Get-AzsSupportPhysicalDisk -PD {aea78659-0c86-f12a-159e-8c6f799c79f7}
```

### EXAMPLE 5
```
Get-AzsSupportPhysicalDisk -CimSession contoso-n02 -UnhealthyDisks | Format-Table
```

### EXAMPLE 6
```
Get-AzsSupportPhysicalDisk -StorageSubSystem $StorageSubSystem
```

### EXAMPLE 7
```
Get-AzsSupportPhysicalDisk -StoragePool $StoragePool | sort-object DeviceId
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

### -SerialNumber
The SerialNumber of the disk drive.

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

### -PD

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UnhealthyDisks
Will filter out all healthy disks and display only unhealthy disks.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -LocalOnly

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -UniqueId

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -StorageSubSystem

```yaml
Type: CimInstance
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -StoragePool

```yaml
Type: CimInstance
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
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

### Array of PSObject representing the physical disks
### Number FriendlyName                   SerialNumber         MediaType CanPool OperationalStatus HealthStatus Usage          Size
### ------ ------------                   ------------         --------- ------- ----------------- ------------ -----          ----
### 1000   Dell NVMe PE8110 RI M.2 3.84TB ABC1_0000_0000_0001. SSD       False   OK                Healthy      Auto-Select 3.49 TB
### 1001   Dell NVMe PE8110 RI M.2 3.84TB ABC1_0000_0000_0002. SSD       False   OK                Healthy      Auto-Select 3.49 TB
### 1002   Dell NVMe PE8110 RI M.2 3.84TB ABC1_0000_0000_0003. SSD       False   OK                Healthy      Auto-Select 3.49 TB
### 1003   Dell NVMe PE8110 RI M.2 3.84TB ABC1_0000_0000_0004. SSD       False   OK                Healthy      Auto-Select 3.49 TB
### 2000   Dell NVMe PE8110 RI M.2 3.84TB ABC1_0000_0000_0005. SSD       False   OK                Healthy      Auto-Select 3.49 TB
### 2001   Dell NVMe PE8110 RI M.2 3.84TB ABC1_0000_0000_0006. SSD       False   OK                Healthy      Auto-Select 3.49 TB
### 2002   Dell NVMe PE8110 RI M.2 3.84TB ABC1_0000_0000_0007. SSD       False   OK                Healthy      Auto-Select 3.49 TB
### 2003   Dell NVMe PE8110 RI M.2 3.84TB ABC1_0000_0000_0008. SSD       False   OK                Healthy      Auto-Select 3.49 TB
