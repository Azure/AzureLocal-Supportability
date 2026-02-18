# Get-AzsSupportDataIntegrityScanState

## SYNOPSIS
Gets "Data Integrity Check And Scan" scheduled task's state on all reachable nodes from the failover cluster.

## SYNTAX

```
Get-AzsSupportDataIntegrityScanState [[-ComputerName] <Array>] [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets detailed information on scheduled task "Data Integrity Check And Scan" on provided cluster nodes.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportDataIntegrityScanState
```

### EXAMPLE 2
```
Get-AzsSupportDataIntegrityScanState -ComputerName con-s1-n01
```

### EXAMPLE 3
```
Get-AzsSupportDataIntegrityScanState -ComputerName con-s1-n01 -Credential (Get-Credential)
```

## PARAMETERS

### -ComputerName
The computer names you want to check for scheduled tasks.

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

### Returns the state of the "Data Integrity Check And Scan" scheduled task on all reachable nodes from the failover cluster
### Get-AzsSupportDataIntegrityScanState -ComputerName con-s1-n01 | Select PSComputerName,State,TaskName
### PSComputerName               State TaskName
### --------------               ----- --------
### contoso-n01.contoso.lab           3 Data Integrity Check And Scan
### contoso-n02.contoso.lab           3 Data Integrity Check And Scan
