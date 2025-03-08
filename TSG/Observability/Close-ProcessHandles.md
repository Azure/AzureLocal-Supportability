# Close-ProcessHandles

Please copy the contents of the below script block into a file named "Close-ProcessHandles.ps1"
```Powershell
# Close-ProcessHandles.ps1
Param (
    [Parameter(Mandatory = $false)]
    [System.String] $FolderPathToClean = "C:\Packages\Plugins\Microsoft.AzureStack.Observability.TelemetryAndDiagnostics\*\bin"
)

function Get-ExceptionDetails {
    [CmdLetBinding()]
    Param (
        [Parameter(Mandatory=$True, ValueFromPipeline)]
        [System.Management.Automation.ErrorRecord] $ErrorObject
    )

    return @{
        Errormsg = $ErrorObject.ToString()
        Exception = $ErrorObject.Exception.ToString()
        Stacktrace = $ErrorObject.ScriptStackTrace
        Failingline = $ErrorObject.InvocationInfo.Line
        Positionmsg = $ErrorObject.InvocationInfo.PositionMessage
        PScommandpath = $ErrorObject.InvocationInfo.PSCommandPath
        Failinglinenumber = $ErrorObject.InvocationInfo.ScriptLineNumber
        Scriptname = $ErrorObject.InvocationInfo.ScriptName
    } | ConvertTo-Json ## The ConvertTo-Json will return the entire hashtable as string.
}

function Get-FileLockProcess {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [System.String] $FilePath
    )

    $functionName = $MyInvocation.MyCommand.Name

    ##### BEGIN Variable/Parameter Transforms and PreRun Prep #####

    if (! $(Test-Path $FilePath)) {
        Write-Output "[$functionName] The path $FilePath was not found! Halting!"
        return
    }

    ##### END Variable/Parameter Transforms and PreRun Prep #####


    ##### BEGIN Main Body #####

    if ($PSVersionTable.PSEdition -eq "Desktop" -or $PSVersionTable.Platform -eq "Win32NT" -or 
    $($PSVersionTable.PSVersion.Major -le 5 -and $PSVersionTable.PSVersion.Major -ge 3)) {
        $CurrentlyLoadedAssemblies = [System.AppDomain]::CurrentDomain.GetAssemblies()
    
        $AssembliesFullInfo = $CurrentlyLoadedAssemblies | Where-Object {
            $_.GetName().Name -eq "Microsoft.CSharp" -or
            $_.GetName().Name -eq "mscorlib" -or
            $_.GetName().Name -eq "System" -or
            $_.GetName().Name -eq "System.Collections" -or
            $_.GetName().Name -eq "System.Core" -or
            $_.GetName().Name -eq "System.IO" -or
            $_.GetName().Name -eq "System.Linq" -or
            $_.GetName().Name -eq "System.Runtime" -or
            $_.GetName().Name -eq "System.Runtime.Extensions" -or
            $_.GetName().Name -eq "System.Runtime.InteropServices"
        }
        $AssembliesFullInfo = $AssembliesFullInfo | Where-Object {$_.IsDynamic -eq $False}
  
        $ReferencedAssemblies = $AssembliesFullInfo.FullName | Sort-Object | Get-Unique

        $usingStatementsAsString = @"
        using Microsoft.CSharp;
        using System.Collections.Generic;
        using System.Collections;
        using System.IO;
        using System.Linq;
        using System.Runtime.InteropServices;
        using System.Runtime;
        using System;
        using System.Diagnostics;
"@
        
        $TypeDefinition = @"
        $usingStatementsAsString
        
        namespace MyCore.Utils
        {
            static public class FileLockUtil
            {
                [StructLayout(LayoutKind.Sequential)]
                struct RM_UNIQUE_PROCESS
                {
                    public int dwProcessId;
                    public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime;
                }
        
                const int RmRebootReasonNone = 0;
                const int CCH_RM_MAX_APP_NAME = 255;
                const int CCH_RM_MAX_SVC_NAME = 63;
        
                enum RM_APP_TYPE
                {
                    RmUnknownApp = 0,
                    RmMainWindow = 1,
                    RmOtherWindow = 2,
                    RmService = 3,
                    RmExplorer = 4,
                    RmConsole = 5,
                    RmCritical = 1000
                }
        
                [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
                struct RM_PROCESS_INFO
                {
                    public RM_UNIQUE_PROCESS Process;
        
                    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCH_RM_MAX_APP_NAME + 1)]
                    public string strAppName;
        
                    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCH_RM_MAX_SVC_NAME + 1)]
                    public string strServiceShortName;
        
                    public RM_APP_TYPE ApplicationType;
                    public uint AppStatus;
                    public uint TSSessionId;
                    [MarshalAs(UnmanagedType.Bool)]
                    public bool bRestartable;
                }
        
                [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
                static extern int RmRegisterResources(uint pSessionHandle,
                                                    UInt32 nFiles,
                                                    string[] rgsFilenames,
                                                    UInt32 nApplications,
                                                    [In] RM_UNIQUE_PROCESS[] rgApplications,
                                                    UInt32 nServices,
                                                    string[] rgsServiceNames);
        
                [DllImport("rstrtmgr.dll", CharSet = CharSet.Auto)]
                static extern int RmStartSession(out uint pSessionHandle, int dwSessionFlags, string strSessionKey);
        
                [DllImport("rstrtmgr.dll")]
                static extern int RmEndSession(uint pSessionHandle);
        
                [DllImport("rstrtmgr.dll")]
                static extern int RmGetList(uint dwSessionHandle,
                                            out uint pnProcInfoNeeded,
                                            ref uint pnProcInfo,
                                            [In, Out] RM_PROCESS_INFO[] rgAffectedApps,
                                            ref uint lpdwRebootReasons);
        
                /// <summary>
                /// Find out what process(es) have a lock on the specified file.
                /// </summary>
                /// <param name="path">Path of the file.</param>
                /// <returns>Processes locking the file</returns>
                /// <remarks>See also:
                /// http://msdn.microsoft.com/en-us/library/windows/desktop/aa373661(v=vs.85).aspx
                /// http://wyupdate.googlecode.com/svn-history/r401/trunk/frmFilesInUse.cs (no copyright in code at time of viewing)
                /// 
                /// </remarks>
                static public List<Int32> WhoIsLocking(string path)
                {
                    // Console.WriteLine("Looking for process handles for file {0}.", path);
                    uint handle;
                    string key = Guid.NewGuid().ToString();
                    var processes = new List<Int32>();
        
                    int res = RmStartSession(out handle, 0, key);
                    if (res != 0) throw new Exception("Could not begin restart session.  Unable to determine file locker.");
        
                    try
                    {
                        const int ERROR_MORE_DATA = 234;
                        uint pnProcInfoNeeded = 0,
                            pnProcInfo = 0,
                            lpdwRebootReasons = RmRebootReasonNone;
        
                        string[] resources = new string[] { path }; // Just checking on one resource.
        
                        res = RmRegisterResources(handle, (uint)resources.Length, resources, 0, null, 0, null);
        
                        if (res != 0) throw new Exception("Could not register resource.");                                    
        
                        //Note: there's a race condition here -- the first call to RmGetList() returns
                        //      the total number of process. However, when we call RmGetList() again to get
                        //      the actual processes this number may have increased.
                        res = RmGetList(handle, out pnProcInfoNeeded, ref pnProcInfo, null, ref lpdwRebootReasons);
        
                        if (res == ERROR_MORE_DATA)
                        {
                            // Create an array to store the process results
                            RM_PROCESS_INFO[] processInfo = new RM_PROCESS_INFO[pnProcInfoNeeded];
                            pnProcInfo = pnProcInfoNeeded;
        
                            // Get the list
                            res = RmGetList(handle, out pnProcInfoNeeded, ref pnProcInfo, processInfo, ref lpdwRebootReasons);
                            if (res == 0)
                            {
                                processes = new List<Int32>((int)pnProcInfo);
        
                                // Enumerate all of the results and add them to the 
                                // list to be returned
                                for (int i = 0; i < pnProcInfo; i++)
                                {
                                    try
                                    {
                                        processes.Add(processInfo[i].Process.dwProcessId);
                                    }
                                    // catch the error -- in case the process is no longer running
                                    catch (ArgumentException) { }
                                }
                            }
                            else {
                                var exceptionMessage = String.Format("Could not list processes locking file ({0}).", path);
                                throw new Exception(exceptionMessage);
                            }
                        }
                        else if (res != 0) {
                            var exceptionMessage = String.Format("Could not list processes locking file ({0}). Failed to get size of result.", path); 
                            throw new Exception(exceptionMessage);
                        }
                    }
                    finally
                    {
                        RmEndSession(handle);
                    }
        
                    return processes;
                }
            }
        }
"@

            $CheckMyCoreUtilsFileLockUtilLoaded = $CurrentlyLoadedAssemblies | Where-Object {$_.ExportedTypes -like "MyCore.Utils.FileLockUtil*"}
            if ($null -eq $CheckMyCoreUtilsFileLockUtilLoaded) {
                Add-Type -ReferencedAssemblies $ReferencedAssemblies -TypeDefinition $TypeDefinition
            }

            $Result = [MyCore.Utils.FileLockUtil]::WhoIsLocking($FilePath)
        }
        if ($null -ne $PSVersionTable.Platform -and $PSVersionTable.Platform -ne "Win32NT") {
            $lsofOutput = lsof $FilePath

            function Parse-lsofStrings ($lsofOutput, $Index) {
                $($lsofOutput[$Index] -split " " | ForEach-Object {
                    if (![String]::IsNullOrWhiteSpace($_)) {
                        $_
                    }
                }).Trim()
            }

            $lsofOutputHeaders = Parse-lsofStrings -lsofOutput $lsofOutput -Index 0
            $lsofOutputValues = Parse-lsofStrings -lsofOutput $lsofOutput -Index 1

            $Result = [pscustomobject]@{}
            for ($i=0; $i -lt $lsofOutputHeaders.Count; $i++) {
                $Result | Add-Member -MemberType NoteProperty -Name $lsofOutputHeaders[$i] -Value $lsofOutputValues[$i]
            }
        }

        return $Result
    
    ##### END Main Body #####

}

function Close-ProcessHandles {
        Param (
        [Parameter(Mandatory=$True)]
        [System.String] $FolderPathToClean
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Output "[$functionName] Entering."

    $transcriptFileName = "CloseProcessHandles-$(Get-Date -Format 'yyyy-MM-dd').log"
    $transcriptFilePath = Join-Path -Path $PSScriptRoot -ChildPath $transcriptFileName
    Start-Transcript -Path $transcriptFilePath -Append

    ## Get the process handles that are locking files and save the fileName and corresponding ProcessIDs.
    $filesLockedByProcessesDict = @{}
    foreach ($folder in (Get-ChildItem $FolderPathToClean)) {
        Write-Output "[$functionName] Checking process handles inside folder: $($folder.FullName)"
        Get-ChildItem -Path $folder.FullName -Recurse | Where-Object { ! $_.PSIsContainer } | ForEach-Object {
            $filePath = $_.FullName
            try {
                $processHandles = Get-FileLockProcess -FilePath $filePath
                if ($null -ne $processHandles -and $processHandles.Count -gt 0) {
                    $filesLockedByProcessesDict[$filePath] = $processHandles
                }
            }
            catch {
                $excectionDetails = Get-ExceptionDetails -ErrorObject $_
                Write-Output "[$functionName] Exception occurred for file ($filePath). Exception is as follows: $excectionDetails"
            }
        }
    }

    if ($filesLockedByProcessesDict.Keys.Count -eq 0) {
        Write-Output "[$functionName] No files found with locked process handles."
    }
    else {
        Write-Output "[$functionName] Files locked by Processes are as follows = $($filesLockedByProcessesDict | ConvertTo-Json -Compress)."

        $currentPID = [System.Diagnostics.Process]::GetCurrentProcess().Id
        Write-Output "[$functionName] Current PID is $currentPID"

        $returnStatusMessage = [System.String]::Empty

        ## Loop through the ProcessIDs and force stop them accordingly (if needed).
        Write-Output "[$functionName] Looping through locked file processes and force stop them accordingly (if needed)."
        $stoppedPID = [System.Collections.Generic.HashSet[string]]@()
        foreach ($currentFile in $filesLockedByProcessesDict.Keys) {
            foreach ($procId in $filesLockedByProcessesDict[$currentFile]) {
                if ($procId -eq $currentPID) {
                    ## We do not want to stop the current process, so if the file is locked by the current process, we hope that the process will finish successfully and release the handle.
                    Write-Output "[$functionName] Ignoring file $currentFile as it is used by PID ($procId) which is running the current script."
                } 
                elseif ($stoppedPID.Contains($procId)) {
                    ## We do not want to stop the same process again (and get "PID not found" error)
                    Write-Output "[$functionName] Ignoring PID ($procId) as it was already stopped"
                }
                else {
                    $procDetails = gwmi win32_process | Where-Object {$_.ProcessId -eq $procId} | Select-Object ProcessName, ExecutablePath, CommandLine
                    $fileLockingProcDetails = @{
                        FilePath = $currentFile
                        ProcessName = $procDetails.ProcessName
                        ExecutablePath = $procDetails.ExecutablePath
                        CommandLine = $procDetails.CommandLine
                    }
                    Write-Output "[$functionName] Details of file and its locking process = $($fileLockingProcDetails | ConvertTo-Json -Compress)"
                    try {
                        Write-Output "[$functionName] Stopping process $procId = $(Stop-Process -Id $procId -Force -PassThru | Out-String)"
                        $stoppedPID.Add($procId) | Out-Null
                    }
                    catch{
                        $returnStatusMessage += "[$functionName] Cannot stop process $procId due to error $_"
                    }
                }
            }
        }
    }

    Write-Output "[$functionName] Exiting. Return status message = $returnStatusMessage"
    Stop-Transcript
}


## Invoke the main function
$resolvedPath = (Resolve-Path $FolderpathToClean).Path
Close-ProcessHandles -FolderPathToClean $resolvedPath

```