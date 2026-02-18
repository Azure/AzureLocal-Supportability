# New-AzsSupportDataBundle

## SYNOPSIS
Creates a support data bundle for Azure Stack HCI.

## SYNTAX

### DataCollectAuto
```
New-AzsSupportDataBundle [-Component <Component>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### DataCollectManual
```
New-AzsSupportDataBundle [-ClusterCommands <Array>] [-NodeCommands <Array>] [-NodeEvents <Array>]
 [-NodeRegistry <Array>] [-NodeFolders <Array>] [-ComputerName <Array>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
This function collects various types of diagnostic data from an Azure Stack HCI cluster and compiles it into a support data bundle.
The data collected can include cluster commands, node commands, events, registry information, and specific folders.
The function supports both automatic data collection based on predefined components and manual data collection based on user-specified parameters.

## EXAMPLES

### EXAMPLE 1
```
New-AzsSupportDataBundle -Component "OS"
Automatically collects a predefined set of diagnostic data related to the operating system component of Azure Stack HCI and compiles it into a support data bundle.
```

### EXAMPLE 2
```
New-AzsSupportDataBundle -NodeCommands @("Get-Process", "Get-Service") -ComputerName @("Node01", "Node02")
Collects the output of "Get-Process" and "Get-Service" commands from Node01 and Node02 and includes it in the support data bundle.
```

## PARAMETERS

### -Component
Specifies the Azure Stack HCI component for which to automatically collect data.
Valid values are defined in the Component enum.

```yaml
Type: Component
Parameter Sets: DataCollectAuto
Aliases:
Accepted values: OS, AzureArcResourceBridge

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClusterCommands
An array of cluster-level commands to run and include in the data bundle.

```yaml
Type: Array
Parameter Sets: DataCollectManual
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NodeCommands
An array of node-level commands to run on each cluster node and include in the data bundle.

```yaml
Type: Array
Parameter Sets: DataCollectManual
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NodeEvents
An array of event log queries to run on each cluster node and include in the data bundle.

```yaml
Type: Array
Parameter Sets: DataCollectManual
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NodeRegistry
An array of registry paths to query on each cluster node and include in the data bundle.

```yaml
Type: Array
Parameter Sets: DataCollectManual
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NodeFolders
An array of folder paths to collect from each cluster node and include in the data bundle.

```yaml
Type: Array
Parameter Sets: DataCollectManual
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ComputerName
An array of computer names (cluster nodes) on which to run the specified commands and collect data.
If not specified, defaults to all cluster nodes.

```yaml
Type: Array
Parameter Sets: DataCollectManual
Aliases:

Required: False
Position: Named
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

## NOTES
This function requires administrative privileges to run.
The collected data may contain sensitive information, so ensure that the support data bundle is handled securely and shared only with authorized personnel.

## RELATED LINKS
