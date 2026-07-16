# HostStorage

This script checks the state of the Host Storage.

## Windows.Cluster.ClusterSharedVolume

Checks the health of the Cluster Shared Volumes

| Rule | Synopsis |
| --- | --- |
| Windows.Cluster.CSV.State | Checks the state of the Cluster Shared Volumes |
| Windows.Cluster.CSV.FreeSpace | Checks the Percent free space of the Cluster Shared Volumes |
| Windows.Cluster.CSV.BlockRedirect | Checks for Cluster Shared Volume block redirect scenarios |

## Windows.Cluster.PhysicalDisk

Checks for modified CSV DiskRunChkDsk settings

| Rule | Synopsis |
| --- | --- |
| Windows.Cluster.PhysicalDisk.DiskRunChkDsk | Checks the DiskRunChkDsk setting of Cluster Physical Disk |

## Windows.Cluster.StoragePoolResource

This script checks the operational state of the Cluster

| Rule | Synopsis |
| --- | --- |
| Windows.Cluster.RdmaEnabled | Validates that RDMA is enabled for cluster storage traffic. |

## Windows.Storage.Process

This script checks the HealthPIH process state

| Rule | Synopsis |
| --- | --- |
| Windows.System.Process.State | This script checks if a process is running on the system. |

## Windows.SDDC.Resources

This script checks the SDDC Group Resources State

| Rule | Synopsis |
| --- | --- |
| Windows.Cluster.Resource.State | Checks the state of the Cluster Resource |

## Windows.Storage.Enclosure

Checks the state of the Virtual Disks

| Rule | Synopsis |
| --- | --- |
| Windows.Storage.Enclosure.State | Checks the state of the Storage Enclosures |

## Windows.Storage.HealthService

Consolidated storage Health Service analyzer.

| Rule | Synopsis |
| --- | --- |
| Windows.Storage.HealthAction.Check | Checks for Health Actions from Storage Spaces |
| Windows.Storage.HealthFault.Check | Checks for any faults that affect the overall Storage Spaces Direct cluster. |
| Windows.Storage.SupportedComponents.Missing | Checks for missing Supported Components from Storage Spaces |

## Windows.Storage.PhysicalDisk

Consolidated physical disk analyzer.

| Rule | Synopsis |
| --- | --- |
| Windows.Storage.PhysicalDisk.OperationalStatus | Checks the Health Status of the Physical Disk |
| Windows.Storage.PhysicalDisk.Poolcheck | Checks the Pool status of the Physical Disk |
| Windows.Storage.PhysicalDisk.PartitionCheck | Checks the of the Physical Disk Partitions |
| Windows.Storage.Missing.Disks | Checks for missing disks from Storage Spaces |
| Windows.Storage.PhysicalDisk.Blocklisted | Checks for blocklisted disks in Storage Spaces |
| Windows.Storage.PhysicalDisk.FirmwareDriftCheck | Checks for Firmware Drift of the Physical Disks |
| Windows.Storage.ServerNodeView.Check | Checks for mismatched Server Node Views in Storage Spaces |

## Windows.Storage.Service

Consolidated Storage Spaces SMPHost service analyzer.

| Rule | Synopsis |
| --- | --- |
| Windows.System.Service.State | This script checks the state of a service on the system. |
| Windows.Storage.SmpHost.ServiceHang | Checks if Smphost service on storage nodes is reporting incorrect virtual disk status |

## Windows.Storage.StorageJob

Checks the state of the Virtual Disks

| Rule | Synopsis |
| --- | --- |
| Windows.Storage.Job.Check | Checks Storage Job State |

## Windows.Storage.StoragePool

Checks for running Storage Jobs

| Rule | Synopsis |
| --- | --- |
| Windows.Storage.Pool.OperationalStatus | Checks the state of the Storage Pool |

## Windows.Storage.VirtualDisk

Consolidated virtual disk analyzer.

| Rule | Synopsis |
| --- | --- |
| Windows.Storage.VirtualDisk.OperationalState | Checks the state of the Virtual Disks |
| Windows.Storage.DirtyRegionTracking.ThresholdCheck | Checks the Dirty Region Tracking Threshold has not been exceeded |

## Windows.Storage.Volume

Consolidated storage volume analyzer.

| Rule | Synopsis |
| --- | --- |
| Windows.Storage.Volume | Checks Storage Volume Health and Status |
| Windows.System.ScheduledTask.State | Checks Scheduled Task state. |
| Windows.Storage.VolumeRecommendations.MaxVolumesPerCluster | Checks that the number of volumes in the cluster does not exceed the recommended maximum. |
| Windows.Storage.VolumeRecommendations.MinVolumesPerNode | Checks that the cluster has at least one volume per node. |
| Windows.Storage.VolumeRecommendations.VolumeSize | Checks that a volume does not exceed the recommended maximum size. |
| Windows.Storage.VolumeRecommendations.ReserveCapacity | Checks that the storage pool has enough reserve capacity for in-place repairs. |


