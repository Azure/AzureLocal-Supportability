# Invoke-AzsSupportInsight

## SYNOPSIS
This function executes the support insight for a specific component or all components, locally or remotely.

## SYNTAX

### AllComponents (Default)
```
Invoke-AzsSupportInsight [-OutputDirectory <String>] [-ComputerName <String[]>] [-Credential <PSCredential>]
 [-NoSummary] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### SingleComponent
```
Invoke-AzsSupportInsight -Component <String> [-OutputDirectory <String>] [-ComputerName <String[]>]
 [-Credential <PSCredential>] [-NoSummary] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
{{ Fill in the Description }}

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Component
The name of the component to generate insights for.

```yaml
Type: String
Parameter Sets: SingleComponent
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputDirectory
The directory where the output HTML report will be saved.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: "$(Get-AzsSupportWorkingDirectory)\InsightReport"
Accept pipeline input: False
Accept wildcard characters: False
```

### -ComputerName
One or more remote computers to run the cmdlet on.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
Credential to use for remote session.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: [System.Management.Automation.PSCredential]::Empty
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoSummary
If specified, a summary of the insight run will not be written to the console.

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

## NOTES

## RELATED LINKS
