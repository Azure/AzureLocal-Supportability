# Test-AzsSupportDiskPartitionValid

## SYNOPSIS
Determines whether a physical disk's partition configuration is expected.

## SYNTAX

```
Test-AzsSupportDiskPartitionValid [-Disk] <Object> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Storage Spaces disks report a partition layout that varies by role.
Hybrid
(caching) disks pair a Space Protective partition with a Microsoft SBL Cache
Store/Hdd partition, while all-flash (non-hybrid) capacity disks report a single
Space Protective partition.
This helper centralizes the validation logic so the
same rules are applied everywhere and can be unit tested over a set of disks.

It is exported by the Microsoft.AzLocal.CSSTools manifest so the
Windows.Storage.PhysicalDisk.PartitionCheck insight rule and the manual
Complete-AzsSupportStorageChecks path share this single implementation.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportPhysicalDisk | Where-Object { -not (Test-AzsSupportDiskPartitionValid -Disk $_) }
```

## PARAMETERS

### -Disk
The physical disk object.
Must expose Partitions and SBLCacheUsageCurrent members.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
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

### \[bool\] $true when the partition configuration is expected; otherwise $false.
