# Get-AzsSupportStorageMissingDisks

## SYNOPSIS
Checks for Missing Disks in Storage Spaces

## SYNTAX

```
Get-AzsSupportStorageMissingDisks [[-Cluster] <String>] [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Checks for any disks that are in PNP that are eligible for Storage Spaces but not added

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageMissingDisks -Cluster contoso-cl
```

### EXAMPLE 2
```
Get-AzsSupportStorageMissingDisks -Cluster contoso-cl -Credential (Get-Credential)
```

## PARAMETERS

### -Cluster
The Cluster you want to check for Missing Disks

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

### Returns a detailed object showing the comparison of disks in PNP and Storage Spaces with working information:
### - ComputerName: Target system name
### - NodeId: Infrastructure host ID
### - IsCluster: Boolean indicating if this is cluster-wide results
### - PNPDisksFound: Count of PNP disks found
### - PoolDisksFound: Count of pool disks found
### - CountsMatch: Boolean indicating if counts match
### - MissingDisksMessage: Summary message if there's a mismatch
### - PNPDisks: Detailed list of PNP disks found
### - PoolDisks: Detailed list of pool disks found
