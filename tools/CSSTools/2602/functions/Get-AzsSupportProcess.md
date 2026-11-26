# Get-AzsSupportProcess

## SYNOPSIS
Gets processes on a remote computer

## SYNTAX

### Default (Default)
```
Get-AzsSupportProcess [-ComputerName <String>] [-UseWinRM] [-Top <Int32>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### Tasklist_SVC
```
Get-AzsSupportProcess [-ComputerName <String>] [-UseTasklist] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### PID
```
Get-AzsSupportProcess [-ComputerName <String>] [-ProcessId <Int32>] [-UseWinRM]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Named
```
Get-AzsSupportProcess [-ComputerName <String>] [-Name <String>] [-UseWinRM]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets processes on a remote computer.
Supports WMI, WinRM, and Tasklist /SVC

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportProcess -ComputerName "contoso-n01"
```

### EXAMPLE 2
```
Get-AzsSupportProcess -ComputerName "contoso-n01" -Name "svchost"
```

### EXAMPLE 3
```
Get-AzsSupportProcess -ComputerName "contoso-n01" -Name "svchost" -UseWinRM
```

### EXAMPLE 4
```
Get-AzsSupportProcess -ComputerName "contoso-n01" -ProcessId 1234
```

### EXAMPLE 5
```
Get-AzsSupportProcess -ComputerName "contoso-n01" -ProcessId 1234 -UseWinRM
```

### EXAMPLE 6
```
Get-AzsSupportProcess -ComputerName "contoso-n01" -UseTasklist
```

## PARAMETERS

### -ComputerName
The remote computer you want to list processes on.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name

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

### -ProcessId
Process ID (PID) for a known process on the remote computer.

```yaml
Type: Int32
Parameter Sets: PID
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -UseWinRM
If specified, uses WinRM to get the processes.

```yaml
Type: SwitchParameter
Parameter Sets: Default, PID, Named
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -UseTasklist
If specified, uses Tasklist /SVC to get the processes.

```yaml
Type: SwitchParameter
Parameter Sets: Tasklist_SVC
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Top

```yaml
Type: Int32
Parameter Sets: Default
Aliases:

Required: False
Position: Named
Default value: 0
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

### Get-AzsSupportProcess -ComputerName "contoso-n01" -Name "HealthPIH.exe" | Select-Object Name, ProcessId, StartTime, WorkingSetMB, HandleCount | Format-Table -AutoSize
### Name          ProcessId StartTime             WorkingSetMB HandleCount
### ----          --------- ---------             ------------ -----------
### HealthPIH.exe     11692 2/21/2025 10:34:14 AM 49 MB               2319
