# Get-AzsSupportHostNetworkDiagnosticData

## SYNOPSIS
Collects comprehensive network diagnostic data from the local host.

## SYNTAX

```
Get-AzsSupportHostNetworkDiagnosticData [[-FilePrefix] <String>] [[-OutputDirectory] <String>]
 [-SkipCompression] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function gathers extensive network diagnostic information including Network ATC configuration,
Windows Event Logs, cluster configuration, network adapter settings, and host configuration.
The collected data is saved to JSON files and optionally compressed into a ZIP archive.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportHostNetworkDiagnosticData
Collects diagnostic data to the default Network folder and creates a ZIP archive.
```

### EXAMPLE 2
```
Get-AzsSupportHostNetworkDiagnosticData -FilePrefix "Issue123" -OutputDirectory "C:\Diagnostics"
Collects diagnostic data with "Issue123" prefix to C:\Diagnostics and creates a ZIP archive.
```

### EXAMPLE 3
```
Get-AzsSupportHostNetworkDiagnosticData -SkipCompression
Collects diagnostic data without creating a ZIP archive.
```

## PARAMETERS

### -FilePrefix
Optional.
A prefix to add to the diagnostic data folder name for easier identification.

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

### -OutputDirectory
Optional.
The directory where diagnostic data will be saved.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: "$(Get-AzsSupportWorkingDirectory)\HostNetwork"
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipCompression
Optional.
If specified, the diagnostic data will not be compressed into a ZIP file.
By default, a ZIP archive is created for easier transport.

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

