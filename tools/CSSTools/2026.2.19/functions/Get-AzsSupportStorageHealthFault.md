# Get-AzsSupportStorageHealthFault

## SYNOPSIS
Runs Get-HealthFault against the cluster.

## SYNTAX

```
Get-AzsSupportStorageHealthFault [[-CimSession] <CimSession>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
See https://learn.microsoft.com/en-us/azure/azure-local/manage/health-service-faults?view=azloc-24112.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageHealthFault
```

### EXAMPLE 2
```
Get-AzsSupportStorageHealthFault -CimSession "Contoso-cl"
```

## PARAMETERS

### -CimSession
The Computer or CimSession you want to check for health faults.

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

### Current Health Faults
### Get-AzsSupportStorageHealthFault -CimSession Contoso-cl
### Severity: Degraded/Warning
### Reason         : Parts of the virtual disk have one available copy of data. Failure of a disk, enclosure, node or rack will cause the volume to become unavailable and could lead to data loss. To see a list of physical disks that holding the last copy of data, please use Get-PhysicalDisk -NoRedundancy command.
### Recommendation : Bring online nodes and disks as soon as possible to bring back redundancy.
### Location       : Not available
### Description    : Virtual disk 'UserStorage_1'
### PSComputerName : Contoso-cl"
## NOTES

## RELATED LINKS
