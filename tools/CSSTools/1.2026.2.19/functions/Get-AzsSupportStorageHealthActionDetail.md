# Get-AzsSupportStorageHealthActionDetail

## SYNOPSIS
Gets storage health actions with enhanced object information and filtering options.

## SYNTAX

```
Get-AzsSupportStorageHealthActionDetail [[-ComputerName] <String>] [[-Credential] <PSCredential>]
 [-FilterNotSucceeded] [-ShowFailedOnly] [-ShowRunningOnly] [[-TimeFilterHours] <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves storage health actions from a remote cluster and enriches them with
storage object details (Virtual Disks, Physical Disks, Storage Pools, etc.).
Provides filtering options to show only non-succeeded, failed, or running actions.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportStorageHealthActionDetail -ComputerName "contoso-node01"
Gets all storage health actions from contoso-node01.
```

### EXAMPLE 2
```
Get-AzsSupportStorageHealthActionDetail -ComputerName "localhost"
Gets all storage health actions from the local computer.
```

### EXAMPLE 3
```
Get-AzsSupportStorageHealthActionDetail -ComputerName "RemoteCluster" -Credential (Get-Credential)
Gets all storage health actions from RemoteCluster using specified credentials.
```

### EXAMPLE 4
```
Get-AzsSupportStorageHealthActionDetail -ComputerName "MyCluster" -FilterNotSucceeded
Gets only non-succeeded storage health actions from MyCluster.
```

### EXAMPLE 5
```
Get-AzsSupportStorageHealthActionDetail -ComputerName "contoso-node01" -ShowFailedOnly
Gets only failed storage health actions from contoso-node01.
```

### EXAMPLE 6
```
Get-AzsSupportStorageHealthActionDetail -ComputerName "RemoteCluster" -ShowRunningOnly
Gets only currently running storage health actions from RemoteCluster.
```

### EXAMPLE 7
```
Get-AzsSupportStorageHealthActionDetail -ComputerName "localhost" -TimeFilterHours 24
Gets storage health actions from the last 24 hours from the local computer.
```

### EXAMPLE 8
```
Get-AzsSupportStorageHealthActionDetail -ComputerName "MyCluster" -TimeFilterHours 1 -ShowFailedOnly
Gets only failed storage health actions from the last hour from MyCluster.
```

## PARAMETERS

### -ComputerName
The name of the cluster or computer to query.
Defaults to "contoso-node01".

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

### -FilterNotSucceeded
Show only actions that are not in "Succeeded" state.

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

### -ShowFailedOnly
Show only actions that are in "Failed" state.

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

### -ShowRunningOnly
Show only actions that are in "Running" state.

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

### -TimeFilterHours
Filter health actions to show only those that started within the specified number of hours ago.
If not specified or set to 0, all health actions are returned regardless of age.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 0
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

## NOTES

## RELATED LINKS
