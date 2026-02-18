# Get-AzsSupportService

## SYNOPSIS
Gets services on a specified ComputerName, and sorts them by State, Name.
Supports WMI, and WinRM.

## SYNTAX

### Default (Default)
```
Get-AzsSupportService [-ComputerName <Array>] [-UseWinRM] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### Named
```
Get-AzsSupportService [-ComputerName <Array>] [-Name <String>] [-UseWinRM] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Gets services on a specified ComputerName, and sorts them by State, Name.
Supports WMI, and WinRM.
When using WinRM, wildcard search is only supported for the service name, not display name or description.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportService -ComputerName "Azs-XRP01"
```

### EXAMPLE 2
```
Get-AzsSupportService -ComputerName "Azs-XRP01" -Name "WinRM"
```

### EXAMPLE 3
```
Get-AzsSupportService -ComputerName "Azs-Node01" -Name "smphost" -UseWinRM
```

## PARAMETERS

### -ComputerName
The remote computer you want to list services on

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name
Wildcard search for the provided name

```yaml
Type: String
Parameter Sets: Named
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UseWinRM
{{ Fill UseWinRM Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
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

### System.Management.Automation.PSCustomObject[]
### Returns one or more service objects sorted by service state/status and name.
### WMI mode (`-UseWinRM:$false`) includes:
### - State
### - Status
### - Name
### - ProcessId
### - DisplayName
### - ComputerName
### WinRM mode (`-UseWinRM`) includes:
### - Status
### - Name
### - DisplayName
### - ComputerName
## NOTES

## RELATED LINKS
