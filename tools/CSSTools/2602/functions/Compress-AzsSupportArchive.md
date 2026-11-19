# Compress-AzsSupportArchive

## SYNOPSIS
Creates a zip archive that contains the files and directories from the specified directory

## SYNTAX

```
Compress-AzsSupportArchive [-Path] <DirectoryInfo> [[-Destination] <FileInfo>] [[-CompressionLevel] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Creates a zip archive using the System.IO.Compression namespace that contains the files and directories from the specified directory.
This is used to compress the collected data into an archive that can be easily shared for support purposes and enables compression of files up to 8GB in size.

## EXAMPLES

### EXAMPLE 1
```
Compress-AzsSupportArchive -Path C:\Example\Logs -Destination "$(Get-AzsSupportWorkingDirectory)\Logs.zip"
```

### EXAMPLE 2
```
Compress-AzsSupportArchive -Path C:\Example\Logs -Destination "$(Get-AzsSupportWorkingDirectory)\Logs.zip" -CompressionLevel Optimal
```

## PARAMETERS

### -Path
Specifies the path to the directory that you wish to compress.
All files and subfolders in a directory are added to your archive file by default.

```yaml
Type: DirectoryInfo
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Destination
Specifies the output location of the archive directory.
Path defined should contain the absolute path including the .zip extension.
If this parameter is not specified, the archive will be created in the working directory.

```yaml
Type: FileInfo
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CompressionLevel
Specifies how much compression to apply when you're creating the archive file.
Faster compression requires less time to create the file, but can result in larger file sizes.
If this parameter isn't specified, the command uses the default value, Optimal.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Optimal
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

### System.IO.FileInfo
### Returns a FileInfo object representing the created zip archive file.
### PS> Compress-AzsSupportArchive -Path C:\Example\Logs -Destination "$(Get-AzsSupportWorkingDirectory)\Logs.zip"
### Mode                 LastWriteTime         Length Name
### ----                 -------------         ------ ----
### -a---          02/18/2026  9:30 PM      104857600 contoso-n01_Logs.zip
