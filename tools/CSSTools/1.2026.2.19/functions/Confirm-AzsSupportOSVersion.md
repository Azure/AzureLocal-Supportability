# Confirm-AzsSupportOSVersion

## SYNOPSIS
Validates the OS version against a specified version or minimum version.

## SYNTAX

### ConfirmOSVersion
```
Confirm-AzsSupportOSVersion -Version <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ConfirmMinimumOSVersion
```
Confirm-AzsSupportOSVersion -MinimumVersion <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function checks the current OS version against a specified version or minimum version.
It throws an error if the current OS version does not match the specified version or is below the minimum version.

# This will throw a terminating exception if the current OS version is not "23H2".
```

### EXAMPLE 2
```
Confirm-AzsSupportOSVersion -MinimumVersion "22H2"
# This will throw a terminating exception if the current OS version is below "22H2".
```

## PARAMETERS


### EXAMPLE 1
```
Confirm-AzsSupportOSVersion -Version "23H2"
### -Version
The exact OS version to confirm against the current OS version.

```yaml
Type: String
Parameter Sets: ConfirmOSVersion
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MinimumVersion
The minimum OS version that the current OS version must meet or exceed.

```yaml
Type: String
Parameter Sets: ConfirmMinimumOSVersion
Aliases:

Required: True
Position: Named
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

