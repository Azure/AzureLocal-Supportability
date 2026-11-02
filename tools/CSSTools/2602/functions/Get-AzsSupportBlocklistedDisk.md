# Get-AzsSupportBlocklistedDisk

## SYNOPSIS
Gets all blocklisted physical disks from the cluster filter service.

## SYNTAX

```
Get-AzsSupportBlocklistedDisk [[-ComputerName] <String>] [[-Credential] <PSCredential>]
 [[-SerialNumber] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves blocklisted physical disks from the ClusBFlt service registry parameters.
This function examines the cluster block filter service to identify disks that have been blocklisted due to various reasons.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportBlocklistedDisk
```

### EXAMPLE 2
```
Get-AzsSupportBlocklistedDisk -ComputerName "Node01"
```

### EXAMPLE 3
```
Get-AzsSupportBlocklistedDisk -ComputerName "Node01" -Credential (Get-Credential)
Gets blocklisted disks from Node01 using specified credentials.
```

### EXAMPLE 4
```
Get-AzsSupportBlocklistedDisk -SerialNumber "ABC123"
```

## PARAMETERS

### -ComputerName
Computer name to target.
If not specified, uses the local computer.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: $ENV:ComputerName
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

### -SerialNumber
SerialNumber of the specific disk you want to retrieve.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
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

### Array of blocklisted disks with their properties
### SerialNumber         Node    PhysicaldiskGUID                      Attribute Status       LastIgnoredReason LastIgnoredTimeStamp
### ------------         ----    ----------------                      --------- ------       ----------------- --------------------
### WD-ABC123            Node01  {12345678-1234-1234-1234-123456789012}        16 Blocklisted                 5              1234567890
