# Get-AzsSupportDiskSpaceReport

## SYNOPSIS
Get available disk space report for all infra Hosts.

## SYNTAX

```
Get-AzsSupportDiskSpaceReport [[-Cluster] <String>] [-DriveLetter] <Char> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Utilizes Get-AzsSupportDiskSpace command to get available disk space information for all infra hosts, return with a report for better summary view.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportDiskSpaceReport -DriveLetter C -Cluster contoso-cl | sort-object ComputerName
```

### EXAMPLE 2
```
Get-AzsSupportDiskSpaceReport -DriveLetter C | sort-object ComputerName
```

## PARAMETERS

### -Cluster
The Cluster you want to run against.

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

### -DriveLetter
The drive letters you want to get data from.

```yaml
Type: Char
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

### Array of PSObject representing the disk space report
### infraHostDiskResults
### --------------------
### @{ComputerName=CONTOSO-N01; Name=C; Used=104021139456; Free=490376728576; Provider=Microsoft.PowerShell.Core\FileSystem; Root=C:\}
### @{ComputerName=CONTOSO-N02; Name=C; Used=101640761344; Free=492757106688; Provider=Microsoft.PowerShell.Core\FileSystem; Root=C:\}
