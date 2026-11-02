# Get-AzsStorageDiskPnpId

## SYNOPSIS
Gets PNP information for disks that should be in Storage Spaces

## SYNTAX

```
Get-AzsStorageDiskPnpId [[-ComputerName] <Object>] [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets Pnp Id for only disks that should be in Storage Spaces

## EXAMPLES

### EXAMPLE 1
```
Get-AzsStorageDiskPnpId -ComputerName $Nodes
```

### EXAMPLE 2
```
Get-AzsStorageDiskPnpId -ComputerName $Nodes -Credential (Get-Credential)
```

## PARAMETERS

### -ComputerName
The computer(s) that you want to get Pnp Id information from

```yaml
Type: Object
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

### Data            : SCSI\Disk&Ven_NVMe&Prod_Dell_NVMe_PE8110\5&115bc00c&0&000000
### HasProblem      : False
### LastArrivalDate : 2/21/2025 10:33:44 AM
### DevNodeStatus   : 25174026
### ComputerName    : contoso-n01
### ProblemCode     : 0
### IsPresent       : True
### PSComputerName  : contoso-n01.contoso.lab
### etc...
