# Get-AzsSupportStorageDirtyCount

## SYNOPSIS
Check Dirty Count for Cluster Shared Volumes and if threshold is exceeded.

## SYNTAX

```
Get-AzsSupportStorageDirtyCount [[-ComputerName] <String[]>] [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Early indicator check known issue - Virtual Disk is in Detached state with Unknown health status due to DRT full

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageDirtyCount -ComputerName contoso-n01
```

### EXAMPLE 2
```
Get-AzsSupportStorageDirtyCount -ComputerName @("contoso-n01", "contoso-n02") -Credential (Get-Credential)
```

## PARAMETERS

### -ComputerName
The computer(s) that you want to get dirty counts from that host virtual disks.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
PSCredential object for authenticating to remote computers.
If not provided, uses current user context.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: [System.Management.Automation.PSCredential]::Empty
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

### ComputerName Disk                    Dirty Count Threshold
### ------------ ----                    ----------- ---------
### contoso-n01  userstorage_2 - disk 19        1000       255
## NOTES

## RELATED LINKS
