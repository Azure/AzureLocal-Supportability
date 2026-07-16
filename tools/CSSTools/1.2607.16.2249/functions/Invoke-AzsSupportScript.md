# Invoke-AzsSupportScript

## SYNOPSIS
Invokes an AzsSupport script.

## SYNTAX

```
Invoke-AzsSupportScript [-ScriptName] <String> [[-Parameters] <Hashtable>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
This function is used to execute a script located in the scripts directory of the AzsSupport module.

## EXAMPLES

### EXAMPLE 1
```
Invoke-AzsSupportScript -ScriptName "MyScript" -Parameters @{Param1 = "Value1"; Param2 = "Value2"}
```

## PARAMETERS

### -ScriptName
The name of the script to execute.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameters
A hashtable of parameters to pass to the script.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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

