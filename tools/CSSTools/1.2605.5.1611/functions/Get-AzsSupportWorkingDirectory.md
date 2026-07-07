# Get-AzsSupportWorkingDirectory

## SYNOPSIS
Gets the current working directory for AzsSupport tools

## SYNTAX

```
Get-AzsSupportWorkingDirectory
```

## DESCRIPTION
Gets the current working directory for AzsSupport tools.
This is the directory where all the tools will write their output to by default.
The working directory is created under the ParentWorkingDirectory defined in the configuration file with a timestamp.
If the working directory does not exist, it will be created.

## EXAMPLES

### EXAMPLE 1
```
Get-AzsSupportWorkingDirectory
```

## OUTPUTS

### System.String
### Returns the full path to the active AzsSupport working directory.
### If a working directory has not yet been initialized, one is created under the configured ParentWorkingDirectory using a UTC timestamp.
### If the directory does not exist on disk, it is created.
## NOTES
This function is a public wrapper over Get-WorkingDirectory.

