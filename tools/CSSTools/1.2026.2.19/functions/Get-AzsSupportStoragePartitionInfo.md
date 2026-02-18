# Get-AzsSupportStoragePartitionInfo

## SYNOPSIS
Outputs the partition information for disks in a cluster node.

## SYNTAX

```
Get-AzsSupportStoragePartitionInfo [[-ComputerName] <Array>] [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves and outputs the partition information for disks in a cluster node, including physical and virtual disks.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStoragePartitionInfo
```

### EXAMPLE 2
```
Get-AzsSupportStoragePartitionInfo -ComputerName con-s1-n01, con-s1-n02
```

### EXAMPLE 3
```
Get-AzsSupportStoragePartitionInfo -ComputerName con-s1-n01 -Credential (Get-Credential)
```

## PARAMETERS

### -ComputerName
The computer names you want to get partition information from.

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

### Returns partition information for disks in the cluster node including alignment status, device ID, serial number, and partition details.
## NOTES

## RELATED LINKS
