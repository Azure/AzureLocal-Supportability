# Get-AzsSupportStorageCacheDetails

## SYNOPSIS
Get detailed information on Cache drives for usage and errors".

## SYNTAX

```
Get-AzsSupportStorageCacheDetails [[-ComputerName] <Array>] [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves values for  Write Errors Total, Write Errors Timeout, Read Errors Total, Read Errors Timeout, Disk Transfers/sec for Cache Stores and Hybrid Disks.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageCacheDetails -ComputerName $nodes
```

### EXAMPLE 2
```
Get-AzsSupportStorageCacheDetails -ComputerName $nodes -Credential (Get-Credential)
```

## PARAMETERS

### -ComputerName
The computer(s) that you want to get cache details information from.

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

### List of cache disk usage and errors for given computer(s) as a hashtable
### Name                           Value
### ----                           -----
### contoso-n01                    {11, _total, 12, 7:3...}
### contoso-n02                    {11, _total, 12, 10...}
### ..... etc
