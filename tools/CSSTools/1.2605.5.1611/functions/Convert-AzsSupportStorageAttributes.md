# Convert-AzsSupportStorageAttributes

## SYNOPSIS
Translates the array passed value provided for SBLAttribute, SBLDiskCacheState, SBLCacheUsageCurrent and SBLCacheUsageDesired.

## SYNTAX

```
Convert-AzsSupportStorageAttributes [-DiskHealth] <Object> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Turns array passed value into readable text for quick analysis and comparision.

## EXAMPLES

### EXAMPLE 1
```
Convert-AzsSupportStorageAttributes -DiskHealth $DiskHealth
```

## PARAMETERS

### -DiskHealth
Output from the Get-AzsSupportStorageDiskSBLState function.

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

