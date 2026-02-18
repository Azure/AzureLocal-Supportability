# Get-AzsSupportStoragePhysicalExtent

## SYNOPSIS
Gets physical allocations for a virtual disk that is unhealty.

## SYNTAX

```
Get-AzsSupportStoragePhysicalExtent [-Friendlyname] <Object> [-CimSession] <CimSession>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The "extent" (also known as "allocation" or "slab") is the area on a pooled disk containing one fragment of data for storage space.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStoragePhysicalExtent -CimSession contoso-cl -Friendlyname UserStorage_1
```

## PARAMETERS

### -Friendlyname
The Friendly name of the Virtual Disk that you want to get non active extents for.

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

### -CimSession
The Computername or CimSession you want to check for firmware drift

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

### Outputs key information for troubleshooting unhealthy Virtual Disk extents, providing VirtualDisk, Extents, UniqueDisks and Disks
### (Get-AzsSupportStoragePhysicalExtent -CimSession contoso-cl -Friendlyname Infrastructure_1).Extents
### PhysicalDiskUniqueId OperationalStatus OperationalDetails
### --------             ------------      -----------------
### eui.ABC52D0055692058 Stale Metadata    {IO Error}
### (Get-AzsSupportStoragePhysicalExtent -CimSession contoso-cl -Friendlyname Infrastructure_1).UniqueDisks
### ColumnNumber          : 1
### CopyNumber            : 2
### Flags                 : 0x0000000000000000
### OperationalDetails    : {IO Error}
### OperationalStatus     : Stale Metadata
### PhysicalDiskOffset    : 82141249536
### PhysicalDiskUniqueId  : eui.ABC52D0055692058
### ReplacementCopyNumber :
### Size                  : 1073741824
### StorageTierUniqueId   :
### VirtualDiskOffset     : 154618822656
### VirtualDiskUniqueId   : 66C74EBBE4A8954FB33F362DCBED4BA6
## NOTES

## RELATED LINKS
