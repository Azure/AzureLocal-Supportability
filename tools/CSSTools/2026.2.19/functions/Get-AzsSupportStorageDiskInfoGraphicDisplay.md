# Get-AzsSupportStorageDiskInfoGraphicDisplay

## SYNOPSIS
Outputs threshold based graphic for easy identification of disk space issues on CSVs

## SYNTAX

```
Get-AzsSupportStorageDiskInfoGraphicDisplay [[-ClusterName] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Allows quick ability to visualise an issue with disk space using pre-defined thresholds

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageDiskInfoGraphicDisplay -ClusterName contoso-cl
```

## PARAMETERS

### -ClusterName
The Cluster you want to run against

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

### Graphical display of disk space usage
### Used Space < 80%    Used Space > 80%    Used Space > 90%
### Infrastructure_1                                              67.26% Free
### UserStorage_1                                                 99.24% Free
### UserStorage_2                                                 99.45% Free
## NOTES

## RELATED LINKS
