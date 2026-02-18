# Get-AzsSupportStorageDiskSBLState

## SYNOPSIS
Gets SBL state for disks on given computer(s).

## SYNTAX

```
Get-AzsSupportStorageDiskSBLState [[-ComputerName] <Array>] [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets SBL state from registry for disks on given computer(s), SBLAttributes , SBLDiskCacheState, SBLCacheUsageCurrent and SBLCacheUsageDesired.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageDiskSBLState -ComputerName $Nodes
```

### EXAMPLE 2
```
Get-AzsSupportStorageDiskSBLState -ComputerName $Nodes -Credential (Get-Credential)
```

## PARAMETERS

### -ComputerName
The computer(s) that you want to get SBL State information from.

```yaml
Type: Array
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

### List of SBL state for given computer(s), filtered in example below for a specific disk
### $PD=(Get-AzsSupportPhysicalDisk -ComputerName contoso-cl | Where-Object {$_.SerialNumber -like "A1B0C2D4EFGH"} ).PD
### # ComputerName is the name of the computer hosting the disk
### (Get-AzsSupportStorageDiskSBLState -ComputerName contoso-n01)."contoso-n01".$PD
### Name                           Value
### ----                           -----
### SBLDiskCacheState              3
### SBLCacheUsageCurrent           2
### SBLCacheUsageDesired
### SBLAttributes                  0
## NOTES

## RELATED LINKS
