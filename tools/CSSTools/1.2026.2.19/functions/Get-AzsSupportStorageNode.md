# Get-AzsSupportStorageNode

## SYNOPSIS
Gets specified storage node or all nodes if none are provided.

## SYNTAX

```
Get-AzsSupportStorageNode [[-Name] <String>] [[-CimSession] <CimSession>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Retrieves storage nodes connected to the specified ComputerName.
If no node is provided, all nodes are queried.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageNode
```

### EXAMPLE 2
```
Get-AzsSupportStorageNode -Name contoso-n01
```

### EXAMPLE 3
```
Get-AzsSupportStorageNode -CimSession contoso-n01
```

## PARAMETERS

### -Name
Name of Physical Node.

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

### -CimSession
Computer name or CimSession to target.

```yaml
Type: CimSession
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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

### Array of storage nodes based on name filter
### PS> Get-AzsSupportStorageNode -Name contoso-n01* -CimSession contoso-n01
### Name                         Manufacturer Model    SerialNumber OperationalStatus PSComputerName
### ----                         ------------ -----    ------------ ----------------- --------------
### contoso-n01.contoso.lab      Dell Inc.    AX-740xd 10000001     Up                contoso-n01
### contoso-n02.contoso.lab      Dell Inc.    AX-740xd 10000002     Up                contoso-n01
## NOTES

## RELATED LINKS
