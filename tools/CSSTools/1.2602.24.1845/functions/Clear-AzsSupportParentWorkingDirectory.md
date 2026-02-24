# Clear-AzsSupportParentWorkingDirectory

## SYNOPSIS
Clears stale Azs.Support working directory contents across all infrastructure nodes.

## SYNTAX

```
Clear-AzsSupportParentWorkingDirectory [[-LastWriteTime] <DateTime>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
This function iterates through the parent working directory of Azs.Support and removes any directories
that are older than the specified LastWriteTime, except for the current working directory.

## EXAMPLES

### EXAMPLE 1
```
Clear-AzsSupportParentWorkingDirectory -LastWriteTime (Get-Date).AddDays(-10)
```

## PARAMETERS

### -LastWriteTime
Optional parameter to define the age of folders to retain within the parent working directory.
Defaults to (Get-Date).AddDays(-5)

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: (Get-Date).AddDays(-5)
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

### Returns nothing. This function performs a cleanup operation and does not produce output.
