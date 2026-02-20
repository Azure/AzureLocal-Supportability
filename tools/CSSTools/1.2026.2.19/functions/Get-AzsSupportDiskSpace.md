# Get-AzsSupportDiskSpace

## SYNOPSIS
Get available disk space on target computers.

## SYNTAX

```
Get-AzsSupportDiskSpace [[-ComputerName] <String[]>] [-DriveLetter] <Char> [[-Credential] <PSCredential>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Utilizes Get-PSDrive via Invoke-Command to remote computers to get available disk space information.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportDiskSpace -ComputerName $Nodes.Name -DriveLetter C | format-table -AutoSize
```

### EXAMPLE 2
```
Get-AzsSupportDiskSpace -ComputerName $Nodes.Name -DriveLetter C -Credential (Get-Credential) | format-table -AutoSize
```

## PARAMETERS

### -ComputerName
The computer(s) that you want to get disk space information from.

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

### -DriveLetter
The drive letter you want to get data from.

```yaml
Type: Char
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
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
Position: 3
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

### Array of PSObject representing the disk space
### ComputerName    Name         Used         Free Provider                             Root
### ------------    ----         ----         ---- --------                             ----
### contoso-n01     C    101630009344 492767858688 Microsoft.PowerShell.Core\FileSystem C:\
### contoso-n02     C    104016150528 490381717504 Microsoft.PowerShell.Core\FileSystem C:\
