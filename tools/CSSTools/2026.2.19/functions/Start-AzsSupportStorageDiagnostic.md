# Start-AzsSupportStorageDiagnostic

## SYNOPSIS
Runs a series of storage specific diagnostic tests and generates a storage report.

## SYNTAX

```
Start-AzsSupportStorageDiagnostic [[-ClusterName] <String>] [[-Credential] <PSCredential>]
 [[-PhysicalExtentCheck] <String>] [[-Include] <String[]>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
The script checks storage against known issues

## EXAMPLES

### EXAMPLE 1
```
Start-AzsSupportStorageDiagnostic
```

### EXAMPLE 2
```
Start-AzsSupportStorageDiagnostic -PhysicalExtentCheck
```

### EXAMPLE 3
```
Start-AzsSupportStorageDiagnostic -ClusterName "MyCluster" -Credential (Get-Credential)
Runs storage diagnostics on MyCluster using specified credentials.
```

## PARAMETERS

### -ClusterName
ClusterName you wish to run the Storage Diagnostics on.
If not provided, the script will attempt to get the cluster name.

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

### -PhysicalExtentCheck
Enables checking of the Virtual disks physical extents.

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

### -Include
Allows user to specify which tests to run.
By default all tests are run.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
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

### Outputs a storage report with the results of the tests run.
## NOTES

## RELATED LINKS
