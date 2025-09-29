#
# Usage:
# Export-SRClusterConfiguration -StretchClusterName [Cluster Name] -OutputFolder [Directory Path]
#
# This powershell function captures the Storage Replica groups and partnership information along with their cluster group, cluster resource and owner node information.
# -StretchClusterName parameter specifies the stretch cluster whose Storage Replica information you would like to collect. 
#                     If running from a local stretch cluster node, this parameter can be ignored.
#
# -OutputFolder specifies a local directory where the Storage Replica configuration file will be created.
#

Data SRStringTable {
    # culture="en-US"
    ConvertFrom-StringData -StringData @'
SRPSNotInstalled           = Storage Replica powershell feature (RSAT-Storage-Replica) should be installed to execute this script.
ClusterPSNotInstalled      = Failover Cluster powershell feature (RSAT-Clustering-PowerShell) should be installed to execute this script.
OutputFolderNotFound       = Output Folder specified '{0}' did not exist.
PathIsNotADirectory        = Specify a directory and not a file.
NotClusterNode             = Run the powershell function from a stretch cluster node or pass the cluster name as parameter.
OutputFilePrefix           = SRClusterConfiguration-
OutputFileExtension        = .log
ActivityExportConfig       = Exporting Stretch Cluster Storage Replica configuration
DiscoverPartnerships       = Discovering Storage Replica partnerships 
DiscoverResources          = Discovering Storage Replica cluster resources 
NoSRObjectsFound           = No Storage Replica partnerships nor groups found
ProcessingPartnership      = Processing Storage Replica partnership 
ProcessingGroup            = Processing Storage Replica group 
NoGroupsFound              = No Storage Replica groups were found.
GroupNotFound              = Unable to find group:
ResourceNotFound           = Unable to find Storage Replica resource for group:
GroupsNotInPartnership     = The following groups were not found to be in a replication partnership.
'@                         
}

function Get-SRClusterResources
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String] $Cluster
    )

    $Result = @{}

    $Resources = Get-WmiObject -ComputerName $Cluster -Namespace ROOT\MSCluster -Class MSCluster_Resource -Filter "Type='Storage Replica'"

    foreach ($Resource in $Resources)
    {
        $Result[$Resource.PrivateProperties.ReplicationGroupName] = $Resource    
    }

    return $Result
}

function Get-SRGroupInfo
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Object] $Group,
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Object] $ClusterResource
    )

    $DataVolumes                = @()
    $Replicas                   = $Group.Replicas
    foreach ($Replica in $Replicas)
    {
        $DataVolumes += $Replica.DataVolume
    }

    #
    # Find Data and Log disk PDR info based on dependency chart
    #
    $ClusterName = $Group.ComputerName
    $pdrs = Get-ClusterGroup -Name  $ClusterResource.OwnerGroup -Cluster $ClusterName | Get-ClusterResource | ? {$_.ResourceType -eq "Physical Disk"}

    $LogDiskPdr = ""
    $DataDiskPdrs = @()
    
    foreach ($pdr in $pdrs)
    {
        $DependencyExpr = (Get-ClusterResourceDependency -Resource $pdr.Name -Cluster $ClusterName).DependencyExpression

        if($DependencyExpr -match $ClusterResource.Name)
        {
            $LogDiskPdr = $pdr.Name
        }
        else
        {
            $DataDiskPdrs += $Pdr.Name
        }
    }

        
    $GroupInfo                         = [ordered]@{}
                                       
    $GroupInfo["Name"]                 = $Group.Name
    $GroupInfo["Id"]                   = $Group.Id    
    $GroupInfo["OwnerNode"]            = $ClusterResource.OwnerNode
    $GroupInfo["DataVolumes"]          = $Datavolumes -join ","
    $GroupInfo["LogVolume"]            = $Group.LogVolume
    $GroupInfo["ReplicationMode"]      = $Group.ReplicationMode
    $GroupInfo["ReplicationStatus"]    = $Group.ReplicationStatus
    $GroupInfo["LogSizeInGB"]          = $Group.LogSizeInBytes/1GB

    if ([String]::IsNullOrEmpty($Group.AsyncRPO) -eq $false)
    {                                  
        $GroupInfo["AsyncRPO"]         = $Group.AsyncRPO
    }
                                  
    $GroupInfo["ClusterGroupName"]     = $ClusterResource.OwnerGroup
    $GroupInfo["SRClusterResourceId"]  = $ClusterResource.Name
    $GroupInfo["DataDiskResourceIds"]  = $DataDiskPdrs -join "," 
    $GroupInfo["LogDiskResourceId"]    = $LogDiskPdr

    return $GroupInfo
     
}

function Add-GroupContent
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String] $Path,
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Object] $Value
    )

    foreach ($key in $Value.Keys)
    {
        $spaceCount = 24 - $key.Length
        $formattedString = "`t`t{0}"
        for($i =0; $i -lt $spaceCount; $i++)
        {
            $formattedString += " "
        }
        $formattedString += "= {1}"
        Add-Content -Path $Path -Value ([String]::Format($formattedString, $key, $Value[$key]))
    }
}


function Export-SRClusterConfiguration
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    param
    (
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String] $StretchClusterName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String] $OutputFolder

    )

    #
    # Check if we have the right modules to run the script.
    #

    if((Get-WindowsFeature -Name "RSAT-Storage-Replica").InstallState -ne "Installed")
    {
        throw $SRStringTable.SRPSNotInstalled
    }

    if((Get-WindowsFeature -Name "RSAT-Clustering-PowerShell").InstallState -ne "Installed")
    {
        throw $SRStringTable.ClusterPSNotInstalled
    }

    
    if ((Test-Path -Path $OutputFolder) -eq $false)
    {
        $ErrorMsg = [String]::Format($SRStringTable.OutputFolderNotFound, $OutputFolder)
        throw (New-Object -TypeName System.IO.DirectoryNotFoundException -ArgumentList $ErrorMsg)
    }

    if ((Test-Path -Path $OutputFolder -PathType Container) -eq $false)
    {
        throw (New-Object -TypeName System.IO.IOException -ArgumentList $SRStringTable.PathIsNotADirectory)
    }
   
    $Partnerships         = $null
    $ExportedPartnerships = 0
    $Groups               = @{}
    $ExportedGroups       = 0
    $SRClusterResources   = @{}

    if ([String]::IsNullOrEmpty($StretchClusterName) -eq $true)
    {
        $Cluster = Get-Cluster -ErrorAction Ignore
        
        if($Cluster -eq $null)
        {
            throw $SRStringTable.NotClusterNode
        }

        $StretchClusterName = $Cluster.Name
    }

    [String]$FileName     = $SRStringTable.OutputFilePrefix + (Get-Date -Format "yyyy-MM-dd-HH-mm-ss").ToString() + $SRStringTable.OutputFileExtension
    $File = New-Item -Path $OutputFolder -Name $FileName -ItemType File -Force

    Write-Progress -Activity $SRStringTable.ActivityExportConfig -Status $SRStringTable.DiscoverPartnerships


    $Partnerships = Get-SRPartnership -ComputerName $StretchClusterName -Name * | Select-Object -Unique

    foreach ($group in (Get-SRGroup -ComputerName $StretchClusterName))
    {
        $Groups += @{ $group.Name = $group }
    }
    
    if ($Partnerships -eq $null -or $Groups.Count -eq 0)
    {    
        Add-Content -Path $File.FullName -Value $SRStringTable.NoSRObjectsFound

        return
    }

    Write-Progress -Activity $SRStringTable.ActivityExportConfig -Status $SRStringTable.DiscoverResources

    #
    # Gather SR cluster resource information and its cluster properties
    #
    $SRClusterResources = Get-SRClusterResources -Cluster $StretchClusterName


    #
    # Export groups which are part of an active
    # replication partnership.
    #
    if ($Partnerships -ne $null)
    {
        foreach ($partnership in $Partnerships)
        {
            $partnershipToString = [String]::Format("### {0} --> {1} ###", $partnership.SourceRGName, $partnership.DestinationRGName)

            Write-Progress -Activity $SRStringTable.ActivityExportConfig -Status ($SRStringTable.ProcessingPartnership + $partnershipToString)

            $SourceGroupName             = $partnership.SourceRGName
            $SourceGroupSRResource       = $SRClusterResources[$SourceGroupName]
            $DestinationGroupName        = $partnership.DestinationRGName
            $DestinationGroupSRResource  = $SRClusterResources[$DestinationGroupName]

            if($SourceGroupSRResource -eq $null)
            {
                throw $SRStringTable.ResourceNotFound + " $SourceGroupName"
            }

            if($DestinationGroupSRResource -eq $null)
            {
                throw $SRStringTable.ResourceNotFound + " $DestinationGroupName"
            }

            $SourceRG = Get-SRGroup -ComputerName $partnership.SourceComputerName -Name $SourceGroupName
            if ($SourceRG -eq $null)
            {
                throw $SRStringTable.GroupNotFound + " $SourceGroupName"
            }

            $DestinationRG = Get-SRGroup -ComputerName $partnership.DestinationComputerName -Name $DestinationGroupName
            if ($DestinationRG -eq $null)
            {
                throw $SRStringTable.GroupNotFound + " $DestinationGroupName"
            }

            $ReplicationMode = $DestinationRG.ReplicationMode

            $SourceGroupInfo            = Get-SRGroupInfo -Group $SourceRG -ClusterResource $SourceGroupSRResource
            $DestinationGroupInfo       = Get-SRGroupInfo -Group $DestinationRG -ClusterResource $DestinationGroupSRResource

            Add-Content -Path $File.FullName -Value $partnershipToString
            Add-Content -Path $File.FullName -Value ([String]::Empty)
            Add-Content -Path $File.FullName -Value "`t Source SR Group:"            
            Add-GroupContent -Path $File.FullName -Value $SourceGroupInfo
            Add-Content -Path $File.FullName -Value ([String]::Empty)            
            Add-Content -Path $File.FullName -Value "`t Destination SR Group:" 
            Add-GroupContent -Path $File.FullName -Value $DestinationGroupInfo
            Add-Content -Path $File.FullName -Value ([String]::Empty)
            Add-Content -Path $File.FullName -Value ([String]::Empty)


            if ($Groups.ContainsKey($SourceGroupName))
            {
                $Groups.Remove($SourceGroupName)
            }

            if ($Groups.ContainsKey($DestinationGroupName))
            {
                $Groups.Remove($DestinationGroupName)
            }
        }        
    }

    #
    # Export groups that are not part of a replication partnership.
    #
    if ($Groups.Count -gt 0)
    {
        Add-Content -Path $File.FullName -Value ([String]::Empty)
        Add-Content -Path $File.FullName  -Value "#"
        Add-Content -Path $File.FullName  -Value ("# " + $SRStringTable.GroupsNotInPartnership)
        Add-Content -Path $File.FullName  -Value "#"
        Add-Content -Path $File.FullName  -Value ([String]::Empty)

        foreach ($groupName in $Groups.Keys)
        {
            Write-Progress -Activity $SRStringTable.ActivityExportConfig -Status ($SRStringTable.ProcessingGroup + " $groupName")

            $Group = $Groups[$groupName]

            $SRResource = $SRClusterResources[$groupName]
            $GroupInfo = Get-SRGroupInfo -Group $Group -ClusterResource $SRResource

            Add-Content -Path $File.FullName -Value ("`t SR Group " + $Group.Name + ":")   
            Add-GroupContent -Path $File.FullName -Value $GroupInfo
            Add-Content -Path $File.FullName  -Value ([String]::Empty)

            $ExportedGroups += 1
        }
    }
}

Export-ModuleMember -Function Export-SRClusterConfiguration
