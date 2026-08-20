<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "command",
    "signal": "Get-ChildItem"
  },
  "validation": {
    "fidelity_level": "L3",
    "technical_grade": null,
    "reproduction_substrate": "either",
    "automation_status": "ready",
    "last_validated": "2026-08-18",
    "spec_ref": "AzLocal_Storage_GhostCsvMountPoints"
  }
}
-->

# Troubleshoot ghost CSV mount points (`C:\ClusterStorage.000`, `.001`, `.00X`)

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Storage</strong> (Cluster Shared Volumes)</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Medium</strong> (see <a href="#at-a-glance">At a glance</a>; rises to
    <strong>High</strong> when any object still references a ghost path)</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Day 2 Operations</strong>: solution update readiness, Arc Resource
    Bridge (ARB) operations, clustered Hyper-V VM management</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td><strong>All Azure Local releases</strong> (and Windows Server failover
    clusters using Cluster Shared Volumes)</td>
  </tr>
</table>

> **In plain terms:** you have found one or more extra folders next to the normal
> `C:\ClusterStorage` folder, named `C:\ClusterStorage.000`, `C:\ClusterStorage.001`
> and so on. These are leftovers, usually called *ghost folders*. Most of the time
> they are harmless clutter. They become a real problem when a virtual machine, a
> cluster resource, or an Azure Local platform component is still pointed at one of
> them, because that reference can break a solution update or stop a VM from
> starting, with an error that says nothing about folder names.
>
> **The single most important rule on this page: do not delete these folders until
> you have proved nothing references them.** Deleting first is how a tidy-up turns
> into an outage.

## At a glance

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Business impact</th>
    <td><strong>Usually low.</strong> A ghost folder that nothing references is
    cosmetic. <strong>High if anything still references it</strong>: solution
    updates can fail mid-flight, ARB VMs can fail to start or redeploy, and
    checkpoint merges can break because a virtual disk's parent is resolved through
    the wrong mount point.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Who owns this</th>
    <td>The customer's <strong>cluster administrator</strong>. This is not a
    networking issue, and <strong>no OEM, BIOS, or firmware action is ever
    required</strong>. If the only references are under
    <code>Infrastructure_1</code> (ARB or platform-managed content), stop and
    engage Microsoft Support rather than self-remediating.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical time to resolve</th>
    <td>Detection: minutes, and read-only. Repointing a workload VM: tens of
    minutes, and it moves data. Cleanup after verification: minutes.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Downtime / maintenance window</th>
    <td>All detection in this guide is <strong>read-only and online</strong>.
    Repointing VM storage moves data and should be scheduled; depending on the VM
    and the amount of data it may require the VM to be offline.</td>
  </tr>
</table>

## Terms used on this page

If you are new to failover clustering, read this first. The safety decisions later
on depend on these words.

| Term | What it means here |
| --- | --- |
| **CSV** (Cluster Shared Volume) | Shared cluster storage that every node can access at the same time. Each CSV appears as a folder under `C:\ClusterStorage`. |
| **CSV root** | The folder `C:\ClusterStorage` itself. The Cluster service owns it and puts one folder inside it per CSV. |
| **Ghost root / ghost folder** | A leftover copy of the CSV root that the Cluster service renamed to a numbered name such as `C:\ClusterStorage.000`. |
| **Mount point** | A folder that is really a doorway into a whole disk volume. Opening it shows that volume's contents. Deleting it can affect real data. |
| **Junction / reparse point** | The Windows mechanism behind a mount point: a folder that redirects somewhere else. A `-Recurse` delete can follow one into live data. |
| **Open handle** | A file or folder currently held open by a running program. Windows will not let you rename or move something while a handle is open on it. |
| **SMB** | The Windows file-sharing protocol. `Get-SmbOpenFile` shows which files **other machines** currently have open over SMB. It does NOT show handles held by software running locally on the node, such as antivirus, backup, or a filter driver, which is the kind of handle that creates a ghost root in the first place. See [2G](#2g-open-handles-on-a-ghost-path). |
| **Fan-out** | Running one command against every cluster node at once, with `Invoke-Command -ComputerName`, instead of logging on to each node. |
| **Canonical** | The correct, expected location: `C:\ClusterStorage\<CsvName>`. A ghost path is the same content reached through a numbered root instead. |
| **Parent chain / differencing disk** | A checkpoint creates a small child disk that points at a larger parent disk. The child is unusable without its parent, so the whole chain matters, not just the disk attached to the VM. |
| **VHD-Set (`.vhds`) / `.vhdpmem`** | Other virtual disk formats: a shared disk usable by several VMs, and a persistent-memory disk. Both are live data, exactly like `.vhdx`. |
| **Solution update** | The Azure Local platform update that moves the whole cluster to a new version. Not the same as Windows Update. Ghost roots typically appear during one. |
| **ARB** (Arc Resource Bridge) | An Azure Local platform component that runs as a VM on the cluster. Managed by the platform, not by you. |
| **MOC / MocArb** | Microsoft On-premises Cloud, the platform layer underneath ARB. Its working files live on the infrastructure volume. Platform-managed, not customer-managed. |
| **`Infrastructure_1`** | The reserved Azure Local infrastructure volume. It holds platform configuration and working data, is not for customer workloads, and the platform blocks you from placing storage on it. |

## Before you start

### What you need

- **An elevated PowerShell session** (Run as Administrator) **on one of the cluster
  nodes**. Every command on this page assumes that.
- **Cluster administrator rights** on the cluster.
- The **FailoverClusters** and **Hyper-V** PowerShell modules, present by default on
  Azure Local nodes.
- **PowerShell remoting working between nodes**, because the cluster-wide checks use
  `Invoke-Command`.

Confirm all of that before going further:

```powershell
# Every value below must be True before you continue. This block STOPS if any is False,
# rather than printing a table a reader can walk past: a preflight that only prints is not
# a gate, and every later step assumes all four already hold.
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$preflight = [ordered]@{
    RunningAsAdmin        = ([Security.Principal.WindowsPrincipal]$id).IsInRole(
                                [Security.Principal.WindowsBuiltInRole]::Administrator)
    FailoverClustersAvail = [bool](Get-Module -ListAvailable FailoverClusters)
    HyperVAvail           = [bool](Get-Module -ListAvailable Hyper-V)
    ClusterReachable      = [bool](Get-Cluster -ErrorAction SilentlyContinue)
}

# Remoting is a stated prerequisite, so TEST it rather than assuming it. The cluster-wide
# checks all use Invoke-Command, and a remoting failure part-way through Step 2 looks like
# a clean result on the nodes that did not answer.
$remotingOk = $true
try {
    $peers = @((Get-ClusterNode -ErrorAction Stop | Where-Object State -eq 'Up').Name)
    if ($peers.Count) {
        $reached = @(Invoke-Command -ComputerName $peers -ScriptBlock { $env:COMPUTERNAME } -ErrorAction SilentlyContinue)
        $remotingOk = ($reached.Count -eq $peers.Count)
        if (-not $remotingOk) {
            Write-Warning ("Remoting reached {0} of {1} node(s). Unreachable: {2}" -f $reached.Count, $peers.Count,
                (@($peers | Where-Object { ($_ -split '\.')[0] -notin @($reached | ForEach-Object { ($_ -split '\.')[0] }) }) -join ', '))
        }
    }
}
catch { $remotingOk = $false; Write-Warning "Could not enumerate cluster nodes: $($_.Exception.Message)" }
$preflight['RemotingToAllUpNodes'] = $remotingOk

[pscustomobject]$preflight | Format-List
$failed = @($preflight.GetEnumerator() | Where-Object { -not $_.Value } | Select-Object -ExpandProperty Key)
if ($failed.Count) {
    throw "Preflight failed: $($failed -join ', '). Resolve these before running any step in this guide."
}
'Preflight passed.'
```

### Safety rules

> [!WARNING]
> **Never delete a `C:\ClusterStorage.00X` folder until every check in
> [Step 3](#step-3-classify-what-you-found) reports no references.**
> A ghost folder can still contain, or still redirect to, live data. Deleting it
> while something points at it can take virtual machines or Arc Resource Bridge
> offline, and the resulting failure will not obviously point back at the deletion.

> [!IMPORTANT]
> [Step 1](#step-1-find-the-ghost-roots) and
> [Step 2](#step-2-prove-whether-anything-references-them) are **read-only**. Run the
> whole detection pass first and decide afterwards. Do not scroll ahead and run a
> cleanup block on its own: the cleanup in
> [Path A](#path-a-no-references-found-safe-to-clean-up) assumes you have completed
> Steps 1 to 3 in order.

## Quick triage (start here)

> [!IMPORTANT]
> This is a fast first look, **not a clearance**. It covers the per-node checks
> only. Zero references here does **not** mean the cluster is clear, because the
> cluster-wide resource check and the mount-point check have not run yet. Treat a
> clean result as "keep going", never as "safe to delete".

Run this on **any one node**. It fans out to every running node.

```powershell
# The canonical ghost-path pattern used throughout this guide.
# It matches a literal dot followed by one or more digits after "ClusterStorage",
# for example C:\ClusterStorage.000\... or C:\ClusterStorage.001\...
# It deliberately does NOT match the real root C:\ClusterStorage\...
$GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)'

$nodes = (Get-ClusterNode | Where-Object State -eq 'Up').Name

Invoke-Command -ComputerName $nodes -ArgumentList $GhostPathPattern -ScriptBlock {
    param($Pattern)

    $findings = New-Object System.Collections.Generic.List[string]

    $ghostRoots = Get-ChildItem -Path "$($env:SystemDrive)\" -Directory -Filter 'ClusterStorage.*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^ClusterStorage\.\d+$' } |
        Select-Object -ExpandProperty FullName

    foreach ($vm in (Get-VM -ErrorAction SilentlyContinue)) {
        foreach ($d in ($vm | Get-VMHardDiskDrive -ErrorAction SilentlyContinue)) {
            if ($d.Path -match $Pattern) { $findings.Add("VMHardDisk: $($vm.Name) -> $($d.Path)") }
        }
        foreach ($prop in 'ConfigurationLocation', 'SnapshotFileLocation', 'SmartPagingFilePath') {
            $v = $vm.$prop
            if ($v -and ($v -match $Pattern)) { $findings.Add("VMConfig: $($vm.Name).$prop -> $v") }
        }
    }

    foreach ($f in (Get-SmbOpenFile -ErrorAction SilentlyContinue)) {
        if ($f.Path -match $Pattern) {
            $findings.Add("SmbOpenFile: $($f.ClientUserName)@$($f.ClientComputerName) -> $($f.Path)")
        }
    }

    [pscustomobject]@{
        Node           = $env:COMPUTERNAME
        GhostRoots     = if ($ghostRoots) { $ghostRoots -join '; ' } else { '<none>' }
        ReferenceCount = $findings.Count
        Findings       = if ($findings.Count) { $findings -join ' || ' } else { '<none>' }
    }
} | Select-Object Node, GhostRoots, ReferenceCount, Findings | Format-List
```

| What you see | What it means | Where to go |
| --- | --- | --- |
| `GhostRoots = <none>` on every node | No ghost folders anywhere. Nothing to do. | Stop here. |
| Ghost roots exist, `ReferenceCount = 0` | Possible cleanup candidate, **not yet cleared**. | [Step 1](#step-1-find-the-ghost-roots) |
| `ReferenceCount` above 0 on any node | Something is actively pointed at a ghost path. | [Step 1](#step-1-find-the-ghost-roots) |

> [!NOTE]
> `Get-VM` on a node lists only the VMs currently **resident on that node**. A
> clustered VM owned by another node, or one that is powered off, can still hold a
> ghost reference these per-node passes do not see. The cluster-wide check in
> [Step 2C](#2c-cluster-resource-parameters-run-once-for-the-whole-cluster) is what
> catches those, which is why the quick triage alone is never a clearance.

## Symptoms

**Observable behaviors:**

- One or more folders named `C:\ClusterStorage.000`, `C:\ClusterStorage.001`,
  `C:\ClusterStorage.00X` exist alongside the normal `C:\ClusterStorage` folder.
- New numbered folders appear after every solution update, or after a node restart.
- **Several numbered folders have accumulated over many months**, one per update,
  each holding only a small `Infrastructure_1` breadcrumb of a few hundred bytes.
  This is the most common shape in the field, and on its own it is benign; the
  checks below are what tell you whether it is still benign on your cluster.
- A solution update fails part-way through, and the failure references a path
  containing a numbered root.
- An Arc Resource Bridge VM fails to start, or ARB redeployment fails, after an
  update.
- A checkpoint (snapshot) merge fails, or a VM reports a missing or broken parent
  disk.
- A clustered VM role fails to come online on one node but works on another.

**Common error messages:**

Errors caused by this condition usually name the *path*, not the cause. Look for a
numbered root anywhere in the message:

```
... C:\ClusterStorage.000\Infrastructure_1\...
```

## Contributing factors and evidence

### The namespace

Cluster Shared Volumes are surfaced to every node through a single common namespace
on the system drive. Microsoft documents this:

> Disks in CSVs are accessed using a path that appears as a numbered volume under
> the `\ClusterStorage` folder on the system drive. This path is consistent across
> all nodes in the cluster.
>
> Source: [Cluster Shared Volumes overview](https://learn.microsoft.com/windows-server/failover-clustering/failover-cluster-csvs#requirements-and-considerations-for-using-csv-in-a-failover-cluster)

So `C:\ClusterStorage` is an ordinary directory on the system drive that the Cluster
service owns and fills with one mount point per CSV.

### Why the numbered folders appear

When a CSV is brought online on its owner node, the Cluster service initializes the
CSV namespace under that root. If that initialization fails, because another process
is holding an open handle on the directory at that moment, the Cluster service does
not fail the operation. As a recovery action it renames the failed directory out of
the way to the next free numbered name (`ClusterStorage.000`, then `.001`, and so
on) and creates a fresh `C:\ClusterStorage`.

This failure mode is what Microsoft's own guidance addresses. Microsoft documents that
security, backup, and filter-driver products holding a handle on the CSV path cause access
failures under `C:\ClusterStorage`, and publishes the exclusions that prevent them (see
[Recommended antivirus exclusions for Hyper-V hosts](https://learn.microsoft.com/troubleshoot/windows-server/virtualization/antivirus-exclusions-for-hyper-v-hosts)).
Excluding `C:\ClusterStorage` from antivirus scanning on every node is the practical
prevention for this condition. See [Prevention](#prevention).

A Microsoft Windows Support Team blog post describes the specific recovery behavior (the
rename to the next numbered name) in more detail. It is a helpful secondary write-up, not a
normative source:

> Additional reading (non-normative): [Break chain on multi mount points](https://jpwinsup.github.io/blog/2025/01/13/Hyper-V/Break-chain-on-multi-mount-points/),
> Microsoft Windows Support Team blog, 13 January 2025.

The result is:

- The cluster keeps working, so nothing obviously breaks at the time.
- The **old** directory survives on disk under the numbered name.
- Anything that recorded an absolute path while the old directory was the live root
  is now pointing at a stale location.

### Why a referenced ghost path is dangerous, not just untidy

Having more than one mount point for what should be a single CSV can break virtual
disk parent and child differencing chains during a checkpoint merge, because a
virtual disk's parent locator can resolve through the wrong numbered mount point.
That hazard is documented in the same Microsoft Windows Support Team article.

On Azure Local the stakes are higher again, because the platform stores its own
content on the reserved infrastructure volume, conventionally `Infrastructure_1`.
That volume holds platform configuration and working data and is explicitly not
intended for customer workloads. A stale reference there can break a platform
operation such as a solution update or an ARB lifecycle action rather than a single
VM, which is why
[Path C](#path-c-references-under-infrastructure_1-or-arb-engage-support) routes
those cases to Microsoft Support instead of self-service repair.

## Where this shows up

Knowing where the problem is **not** visible saves as much time as knowing where it
is.

- **PowerShell on a cluster node**: the primary surface. `Get-ChildItem C:\` shows
  the numbered folders, and the audit in
  [Step 2](#step-2-prove-whether-anything-references-them) shows what references
  them.
- **Component and tool log files on disk**: solution update and deployment logs under
  `C:\CloudDeployment\Logs` and `C:\MASLogs` contain the numbered path when an update
  failure is caused by a stale reference. See
  [Step 2E](#2e-optional-search-logs-and-configuration-for-stale-references).
- **Cluster logs**: `Get-ClusterLog` output records the Cluster service's handling of
  the CSV root, so it is the best place to establish *when* a ghost root appeared.
  See [Step 2F](#2f-optional-establish-when-the-ghost-root-appeared).
- **Windows event logs**: there is no dedicated event that announces this rename.
  Failover Clustering events appear under the `Microsoft-Windows-FailoverClustering`
  provider, and CSV trouble often shows Events **5120** and **5142**, but those are
  I/O availability events and are **not** the rename record. Do not treat a 5120 or
  5142 as proof of a ghost root, and do not treat their absence as proof there is
  none. Use the on-disk check in [Step 1](#step-1-find-the-ghost-roots), which is
  definitive.
- **Windows Failover Cluster Manager**: the ghost folders do not appear here. The
  console shows CSVs by friendly name and current state, not the filesystem layout of
  the system drive.
- **Azure portal**: the ghost folders do not appear here. The only indirect signal is
  a failed solution update on the cluster's Updates blade, which does not name the
  folder.
- **Windows Admin Center on a standalone host**: the ghost folders do not appear
  here.
- **Windows Admin Center in the Azure portal**: the ghost folders do not appear here.

> [!NOTE]
> Fleet telemetry does not carry this condition either. Ghost CSV roots are
> filesystem state on each node's system drive and are not shipped to Azure Local
> observability pipelines, so detection has to be run on the cluster using this
> guide rather than looked up centrally.

## Step 1: find the ghost roots

### 1A. List the numbered roots

```powershell
Get-ChildItem -Path "$($env:SystemDrive)\" -Directory -Filter 'ClusterStorage.*' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^ClusterStorage\.\d+$' } |
    Select-Object FullName, CreationTime, LastWriteTime |
    Sort-Object CreationTime
```

> [!WARNING]
> The `Where-Object` guard is not optional. Windows `-Filter 'ClusterStorage.*'`
> also matches the **real** CSV root `C:\ClusterStorage`, because the filter treats
> the part after the dot as an optional extension. Every block on this page pairs the
> filter with `^ClusterStorage\.\d+$` for that reason. If you simplify the filter and
> then feed the result into a delete command, you will target the live CSV root.

`CreationTime` usually lines up with the update or restart that created the ghost
root.

### 1B. Confirm which mount points are the real ones

This is what tells ghost apart from real. Active CSV mount points must be under
`C:\ClusterStorage`, never under a numbered root.

```powershell
Get-ClusterSharedVolume | ForEach-Object {
    [pscustomobject]@{
        CSVName = $_.Name
        Path    = $_.SharedVolumeInfo.FriendlyVolumeName
        State   = $_.State
    }
} | Format-Table -AutoSize
```

Expected output shows paths such as `C:\ClusterStorage\UserStorage_1` or
`C:\ClusterStorage\Infrastructure_1`. **Write down a destination volume from this
list**, because [Path B](#path-b-a-workload-vm-references-a-ghost-path) requires a
real path taken from here.

> [!WARNING]
> If any **active** CSV reports a `FriendlyVolumeName` under a numbered root such as
> `C:\ClusterStorage.000\...`, that numbered root is **not** a ghost, it is the live
> namespace. Do not treat it as cleanup. Stop and engage Microsoft Support.

### 1C. Check whether the ghost root still redirects to live data

A ghost root can contain leftover mount points that still resolve to a real volume.
That is the difference between deleting an empty shell and detaching live storage.

Check the **`ReparsePoint` file attribute**, which is the authoritative signal.

> [!IMPORTANT]
> Do not rely on the `LinkType` or `Target` properties for this decision. They do not
> reliably populate for volume mount points, so a folder that really does redirect to
> a live volume can show a blank `LinkType` and be mistaken for ordinary leftover
> files. The attribute check below does not have that failure mode.

> [!IMPORTANT]
> The scan below is **recursive** on purpose. A volume mount point does not have to sit at
> the top of the ghost root: it can be nested inside an ordinary-looking leftover folder.
> A top-level-only check would classify that as "ordinary leftover files" and send you to
> Path A, and the cleanup would then be deleting live storage.

```powershell
Get-ChildItem -Path "$($env:SystemDrive)\" -Directory -Filter 'ClusterStorage.*' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^ClusterStorage\.\d+$' } |
    ForEach-Object {
        $root = $_.FullName

        # Test the ROOT ITSELF first. Only the children were checked before, so a numbered
        # root that is ITSELF a volume mount point reported IsReparsePoint = False and
        # classified as safe, which is the worst possible miss: the whole root is live storage.
        $rootIsReparse = [bool]($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
        [pscustomobject]@{
            GhostRoot      = $root
            Child          = '<the root itself>'
            IsReparsePoint = $rootIsReparse
            Detail         = if ($rootIsReparse) { (fsutil reparsepoint query "$root" 2>&1 | Out-String).Trim() } else { '' }
        }

        # An enumeration that FAILED is not an empty root. Reading errors explicitly so an
        # access-denied subtree cannot hide a nested reparse point behind an empty result.
        $enumErrors = @()
        $children = Get-ChildItem -LiteralPath $root -Force -Recurse -ErrorAction SilentlyContinue -ErrorVariable +enumErrors
        if ($enumErrors.Count) {
            [pscustomobject]@{
                GhostRoot      = $root
                Child          = '<ENUMERATION INCOMPLETE>'
                IsReparsePoint = $null
                Detail         = "$($enumErrors.Count) path(s) could not be read; treat this root as UNVERIFIED, not clean."
            }
        }
        # elseif, NOT a separate if: a root whose enumeration FAILED must not also emit the
        # '<empty>' row, because the results table calls empty the lowest-risk outcome and an
        # incomplete scan would then read as both unverified and safe at the same time.
        elseif (-not $children) {
            [pscustomobject]@{ GhostRoot = $root; Child = '<empty>'; IsReparsePoint = $false; Detail = '' }
        }
        else {
            foreach ($c in $children) {
                $isReparse = [bool]($c.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
                $detail = ''
                if ($isReparse) {
                    $detail = (fsutil reparsepoint query "$($c.FullName)" 2>&1 | Out-String).Trim()
                    if ($detail.Length -gt 200) { $detail = $detail.Substring(0, 200) }
                }
                [pscustomobject]@{
                    GhostRoot      = $root
                    Child          = $c.Name
                    IsReparsePoint = $isReparse
                    Detail         = $detail
                }
            }
        }
    } | Format-Table -AutoSize
```

| Result | Meaning |
| --- | --- |
| `Child = <empty>` | Empty shell. Lowest risk. |
| `IsReparsePoint = False` with files present | Ordinary leftover files. Inventory them in [Step 2D](#2d-inventory-what-is-actually-inside). |
| `IsReparsePoint = True` on the root itself or any child | The ghost root **still redirects to a volume**. Treat it as live storage. Do not delete. Go to [Path C](#path-c-references-under-infrastructure_1-or-arb-engage-support). |

## Step 2: prove whether anything references them

Each check answers "is something pointed at a ghost path?" from a different angle.
Run all of them. A single miss is what turns a cleanup into an incident.

**Where to run each check:**

| Check | Run it |
| --- | --- |
| 2A, 2B, 2D, 2E | On **every node**. Use the quick-triage fan-out, or repeat per node. |
| 2C, 2F | **Once**, from any one node. These are cluster-wide. |

Define the pattern once in every session where you run these:

```powershell
$GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)'

# Safety guard. PowerShell -match against an EMPTY or unset variable matches EVERY path,
# so a step run without this pattern set reports every VM on the node as referencing a
# ghost root. Fail loudly here instead of silently reporting a false positive on all of them.
if ([string]::IsNullOrWhiteSpace($GhostPathPattern)) {
    throw 'GhostPathPattern is not set. Re-run this block before running any step below.'
}
```

> [!WARNING]
> Every step in this section depends on `$GhostPathPattern`. If you open a **new**
> PowerShell session, reconnect, or paste a single step on its own, re-run the block
> above first. Each paste-ready block below re-defines the pattern if it is missing, but
> only for the session it runs in.

> [!NOTE]
> Use this exact pattern. A simpler filter such as `ClusterStorage.` also matches the
> healthy root `C:\ClusterStorage\...`, because `.` is a regular-expression wildcard,
> which produces a false positive on every cluster. This pattern requires a literal
> dot followed by digits, so it also correctly ignores unrelated names such as
> `ClusterStorage.backup`.

### 2A. Virtual machine disk paths

```powershell
# Self-sufficient: re-defines the pattern if this block is pasted into a fresh session.
# Without it, -match against an unset variable matches EVERY path.
if ([string]::IsNullOrWhiteSpace($GhostPathPattern)) { $GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)' }
Get-VM | Get-VMHardDiskDrive |
    Where-Object { $_.Path -match $GhostPathPattern } |
    Select-Object VMName, ControllerType, ControllerNumber, ControllerLocation, Path |
    Format-Table -AutoSize
```

> [!IMPORTANT]
> The command above reads only the **attached** disk path. If a VM has checkpoints or
> differencing disks, the attached disk can sit on a healthy CSV while one of its
> **parent** disks is still on a ghost root. That is the exact hazard described in
> [Contributing factors and evidence](#why-a-referenced-ghost-path-is-dangerous-not-just-untidy), and it is
> invisible to the command above. Deleting a ghost root that still holds a parent disk
> breaks the chain and the child disk becomes unusable. Walk the parent chain too.

```powershell
# Self-sufficient: re-defines the pattern if this block is pasted into a fresh session.
# Without it, -match against an unset variable matches EVERY path.
if ([string]::IsNullOrWhiteSpace($GhostPathPattern)) { $GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)' }
# Walk every attached disk's FULL parent chain (checkpoints / differencing disks).
Get-VM | Get-VMHardDiskDrive | ForEach-Object {
    $vmName = $_.VMName
    $path   = $_.Path
    $depth  = 0
    while ($path -and $depth -lt 50) {
        if ($path -match $GhostPathPattern) {
            [pscustomobject]@{ VMName = $vmName; Depth = $depth; Reference = $path }
        }
        $vhd = Get-VHD -Path $path -ErrorAction SilentlyContinue
        if (-not $vhd) {
            [pscustomobject]@{ VMName = $vmName; Depth = $depth; Reference = "UNREADABLE: $path" }
            break
        }
        $path = $vhd.ParentPath
        $depth++
    }
} | Format-Table -AutoSize
```

Any row returned is a reference and blocks cleanup. A row beginning `UNREADABLE:` means
the chain could not be followed, so coverage is incomplete: treat it as a reference
until you can read that disk.

A hard disk is not the only file a VM can hold on a ghost root. An **ISO mounted in a
virtual DVD drive** is a live reference too, and deleting it breaks the VM's optical media
(and can block a VM that boots or installs from it).

```powershell
# Self-sufficient: re-defines the pattern if this block is pasted into a fresh session.
# Without it, -match against an unset variable matches EVERY path.
if ([string]::IsNullOrWhiteSpace($GhostPathPattern)) { $GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)' }

Get-VM | Get-VMDvdDrive |
    Where-Object { $_.Path -match $GhostPathPattern } |
    Select-Object VMName, ControllerNumber, ControllerLocation, Path |
    Format-Table -AutoSize
```

Treat any row here exactly like a 2A row: it is a reference, and the root is not safe to
delete.

### 2B. Virtual machine configuration, checkpoint, and paging paths

A VM can have healthy disks and still be anchored to a ghost root by one of these
three properties.

```powershell
# Self-sufficient: re-defines the pattern if this block is pasted into a fresh session.
# Without it, -match against an unset variable matches EVERY path.
if ([string]::IsNullOrWhiteSpace($GhostPathPattern)) { $GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)' }
Get-VM | Select-Object Name, ConfigurationLocation, SnapshotFileLocation, SmartPagingFilePath |
    Where-Object {
        $_.ConfigurationLocation -match $GhostPathPattern -or
        $_.SnapshotFileLocation  -match $GhostPathPattern -or
        $_.SmartPagingFilePath   -match $GhostPathPattern
    } | Format-Table -AutoSize
```

### 2C. Cluster resource parameters (run once for the whole cluster)

This is the check that catches clustered VMs owned by another node, powered-off
roles, platform-managed resources, and anything that is not a Hyper-V VM on the node
you happen to be sitting on. Run it **once** from any node.

```powershell
# Self-sufficient: re-defines the pattern if this block is pasted into a fresh session.
# Without it, -match against an unset variable matches EVERY path.
if ([string]::IsNullOrWhiteSpace($GhostPathPattern)) { $GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)' }
$paramErrors = New-Object System.Collections.Generic.List[string]
Get-ClusterResource | ForEach-Object {
    $r = $_
    try {
        Get-ClusterParameter -InputObject $r -ErrorAction Stop | ForEach-Object {
            # Match strings AND string arrays: a multi-valued parameter holding a ghost path
            # was skipped entirely by a bare -is [string] test.
            if (($_.Value -is [string] -or $_.Value -is [string[]]) -and
                (@($_.Value) -match $GhostPathPattern)) {
                [pscustomobject]@{ Resource = $r.Name; Parameter = $_.Name; Value = $_.Value }
            }
        }
    }
    catch {
        # Most resource types that throw here simply do not expose parameters, which is
        # benign. Record the resource so a genuine query failure stays visible instead of
        # silently reducing coverage.
        $paramErrors.Add($r.Name)
    }
} | Sort-Object Resource, Parameter | Format-Table -AutoSize

if ($paramErrors.Count) {
    Write-Warning ("VERIFICATION INCOMPLETE: {0} cluster resource(s) did not return parameters and were NOT inspected: {1}. Uninspected coverage is not clean coverage, and Get-GhostCsvAudit fails closed on exactly this condition, so resolve these and re-run before calling the issue resolved." -f `
        $paramErrors.Count, ($paramErrors -join ', '))
}
```

### 2D. Inventory what is actually inside

If the ghost roots are empty, that alone is strong evidence nothing is using them.

```powershell
Get-ChildItem -Path "$($env:SystemDrive)\" -Directory -Filter 'ClusterStorage.*' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^ClusterStorage\.\d+$' } |
    ForEach-Object {
        $root = $_.FullName
        Write-Host "`n==== $root ====" -ForegroundColor Cyan
        $items = Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        if (-not $items) {
            Write-Host '   (empty)'
        }
        else {
            $items | Sort-Object LastWriteTime -Descending |
                Select-Object -First 25 Mode, LastWriteTime, Length, FullName |
                Format-Table -AutoSize | Out-String | Write-Host
            Write-Host ("   total items: {0}" -f @($items).Count)
        }
    }
```

> [!IMPORTANT]
> Look at **what** the content is, not just where it sits.
>
> - Content that is **still referenced** by anything in Step 2, or that contains
>   ARB or MOC working data (any virtual hard disk, or a `MocArb`, `ImageStore`, or
>   `WorkingDirectory` folder), is platform data in use. Go to
>   [Path C](#path-c-references-under-infrastructure_1-or-arb-engage-support).
> - Small, stale breadcrumb content left behind by past orchestration, for example
>   a few files under
>   `Infrastructure_1\Shares\SU1_Infrastructure_1\Orchestration\AgentLifecycleManagement\FCARotation\SuccessFiles`,
>   with **no** references from Step 2, is an ordinary leftover. It stays on the
>   normal path and is handled by
>   [Path A](#path-a-no-references-found-safe-to-clean-up).
>
> The presence of an `Infrastructure_1` folder inside a ghost root is expected and
> is **not** on its own a reason to open a support case. A cluster that has taken
> several updates commonly accumulates one such folder per numbered root, each only
> a few hundred bytes. Treating every one of those as a support case creates noise
> and trains people to ignore the check.

### 2E. Optional: search logs and configuration for stale references

Useful when an update or ARB operation already failed and you want to confirm the
ghost path is implicated.

```powershell
$SearchRoots = @('C:\CloudDeployment\Logs', 'C:\MASLogs', 'C:\Windows\Cluster')

foreach ($root in $SearchRoots) {
    if (Test-Path -LiteralPath $root) {
        Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { if ($_.Length -ge 200MB) { Write-Warning "SKIPPED (over 200MB, search it manually): $($_.FullName)"; $false } else { $true } } |
            Select-String -Pattern 'ClusterStorage\.\d+' -ErrorAction SilentlyContinue |
            Select-Object -First 50 @{N='File';E={$_.Path}}, @{N='Match';E={$_.Matches[0].Value}}
    }
}
```

> [!NOTE]
> This can take several minutes on a node with large log directories. It is read-only
> and safe to interrupt.

### 2F. Optional: establish when the ghost root appeared

```powershell
# Generates cluster logs covering the last 3 days into a DEDICATED folder, not the current
# directory: an elevated shell starts in System32, and $env:TEMP mixes in unrelated logs.
$logDir = Join-Path $env:TEMP ("GhostCsvClusterLogs-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
Get-ClusterLog -Destination $logDir -TimeSpan 4320

Select-String -Path (Join-Path $logDir '*.log') -Pattern 'ClusterStorage\.\d+' |
    Select-Object -First 40 Filename, LineNumber, Line
```

Correlate the timestamps with your update and restart history. That tells you which
operation created the ghost root, which is what you need to stop it recurring.

> [!WARNING]
> Use the cluster log for this, not the folder's `CreationTime`. A ghost root is produced by
> RENAMING the existing CSV root, and an NTFS rename PRESERVES `CreationTime`, so the ghost
> root's `CreationTime` is when the original `C:\ClusterStorage` was first created, not when
> it was ghosted. The `CreationTime` column shown in Step 1A is useful for telling several
> ghost roots apart, not for dating the incident.

> [!NOTE]
> Search for the numbered path itself, as above. Do not search for a specific
> sentence of cluster-log text: the exact wording is not a documented, stable string,
> so a phrase search can return nothing on a cluster that genuinely has the problem.

### 2G. Open handles on a ghost path

Step 3 requires this check, and it is the one that most directly matches the cause: a
ghost root exists because something held a handle open on the CSV root. Run it on
**every** node.

Two different things are being looked for, and neither alone is sufficient:

- **Remote SMB opens** (`Get-SmbOpenFile`). Another machine holding a file open.
- **Local handles.** Antivirus, a backup agent, or a filter driver running ON the node.
  `Get-SmbOpenFile` cannot see these, and this is the handle class that creates the ghost
  root in the first place, so a clean SMB result is not a clean handle result.

```powershell
# Self-sufficient: re-defines the pattern if this block is pasted into a fresh session.
# Without it, -match against an unset variable matches EVERY path.
if ([string]::IsNullOrWhiteSpace($GhostPathPattern)) { $GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)' }

$nodes = (Get-ClusterNode | Where-Object State -eq 'Up').Name
Invoke-Command -ComputerName $nodes -ArgumentList $GhostPathPattern -ScriptBlock {
    param($Pattern)
    $hits   = New-Object System.Collections.Generic.List[string]
    $errors = New-Object System.Collections.Generic.List[string]

    # Remote SMB opens. TERMINATING: a failed query must not read as "no open files".
    try {
        foreach ($f in (Get-SmbOpenFile -ErrorAction Stop)) {
            if ($f.Path -match $Pattern) { $hits.Add("SMB open: $($f.Path) (by $($f.ClientUserName) from $($f.ClientComputerName))") }
        }
    }
    catch { $errors.Add("Get-SmbOpenFile failed -> $($_.Exception.Message)") }

    # Local handles. There is no built-in cmdlet for this, so report what CAN be
    # established and be explicit that the check is partial rather than implying it is clean.
    $sysRoot = "$($env:SystemDrive)\"
    $roots = @(Get-ChildItem -Path $sysRoot -Directory -Filter 'ClusterStorage.*' -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '^ClusterStorage\.\d+$' })
    foreach ($r in $roots) {
        try {
            # A rename that the OS refuses is direct evidence of an open handle, but it is a
            # MUTATION, so it is not attempted here. Instead, report the root as
            # handle-unverified so the operator uses handle.exe or Process Explorer.
            $errors.Add("LOCAL HANDLES NOT PROVEN for $($r.FullName): run 'handle.exe -a -u $($r.FullName)' (Sysinternals) or Process Explorer's Find Handle on this node.")
        }
        catch { $errors.Add("Local handle probe failed for $($r.FullName) -> $($_.Exception.Message)") }
    }

    [pscustomobject]@{
        Node          = $env:COMPUTERNAME
        SmbHits       = @($hits)
        SmbHitCount   = $hits.Count
        Notes         = @($errors)
    }
} | Select-Object Node, SmbHitCount, SmbHits, Notes | Format-List
```

> [!IMPORTANT]
> A zero `SmbHitCount` means no REMOTE opens. It does not prove no local handle exists.
> Before Path A, confirm on each node with `handle.exe -a -u C:\ClusterStorage.00X` from
> [Sysinternals](https://learn.microsoft.com/sysinternals/downloads/handle), or Process
> Explorer's Find Handle. If a local handle is found, identify and stop the owning process
> (commonly antivirus or a backup agent) and re-run Step 2. Do not delete a root whose
> handle state is unknown.

## Step 3: classify what you found

Classify **each ghost root separately**, then act on the most severe classification present.

A node can hold an empty `C:\ClusterStorage.000` and a referenced `C:\ClusterStorage.001`
at the same time. Those are two different answers on one node, and forcing a single verdict
would let the safe root's answer justify deleting the referenced one. Path A's cleanup is
cluster-wide and only proceeds when NO root anywhere is referenced, so if any root lands in
Path B or Path C, resolve that first and re-run Steps 1 to 3 before any cleanup.

Evaluate the rows **in the order listed**: Path C first, then Path B, then Path A. A root can
satisfy more than one row, and the most severe match wins.

| Classification | Criteria (all must hold, per root) | Action |
| --- | --- | --- |
| **Safe to clean up** | Ghost roots exist; 2A, 2B, 2C and 2G return nothing on **every** node, and every node actually ANSWERED (a node that was skipped, unreachable, or whose scan reported `<ENUMERATION INCOMPLETE>` is UNVERIFIED, which blocks Path A); 1C shows `IsReparsePoint = False` everywhere; 2D shows the roots are empty or contain only stale files with no references | [Path A](#path-a-no-references-found-safe-to-clean-up) |
| **Unsafe, active references found** | Any of 2A, 2B, 2C returns a row, or 2G shows an open handle under a ghost path, and the referencing object is a **customer workload VM** | [Path B](#path-b-a-workload-vm-references-a-ghost-path) |
| **Unsafe, platform references found** | Any reference from 2A, 2B or 2C points under `Infrastructure_1`, or the ghost root holds ARB / MOC working data (any virtual hard disk, or a `MocArb`, `ImageStore`, or `WorkingDirectory` folder), or 1C shows `IsReparsePoint = True`, or an active CSV is mounted under a numbered root | [Path C](#path-c-references-under-infrastructure_1-or-arb-engage-support) |
| **Unsafe, reference is not a VM** | Any 2C cluster-resource parameter or 2G open handle references a ghost path and the owner is NOT a Hyper-V VM (a file share, a generic service or script resource, or an unidentified process) | [Path C](#path-c-references-under-infrastructure_1-or-arb-engage-support): there is no self-service repoint for these |

> [!WARNING]
> If you are unsure which category applies, treat it as **Path C** and engage
> Microsoft Support. The cost of asking is minutes. The cost of deleting a referenced
> ghost root is an outage.

## Path A: no references found, safe to clean up

### Prerequisites

- Steps 1, 2 and 3 completed **in order**, on **every** node, with no findings.
- Step 1C shows `IsReparsePoint = False` for every ghost root ITSELF and for every child of it.
- If the ghost roots contain any files at all, you have either copied them somewhere
  safe or confirmed with the data owner that they are disposable. An inventory export
  is a record, not a backup.

### Steps

1. **Paste the shared audit function.**
   Every gate below calls this one function, so the final safety check is as strict as
   the Step 3 classification (references, reparse points, active CSV, platform working
   data, and any query or remoting failure), not a narrower subset of it. Paste it
   once into your elevated session.

   ```powershell
   function Get-GhostCsvAudit {
       [CmdletBinding()]
       param()

       $pattern  = '[\\/]ClusterStorage\.\d+([\\/]|$)'
       $blockers = New-Object System.Collections.Generic.List[string]

       # This gate is FAIL-CLOSED. Any discovery, query, or remoting error is recorded as a
       # blocker, so an incomplete audit can never report SafeToDelete = True. Deletion is
       # allowed only when every expected check ran to completion AND found nothing.

       # (1) An active CSV mounted under a numbered root means this is not a ghost.
       try {
           foreach ($csv in (Get-ClusterSharedVolume -ErrorAction Stop)) {
               if ($csv.SharedVolumeInfo.FriendlyVolumeName -match $pattern) {
                   $blockers.Add("ActiveCsvUnderNumberedRoot: $($csv.Name) -> $($csv.SharedVolumeInfo.FriendlyVolumeName)")
               }
           }
       } catch {
           $blockers.Add("QueryError: Get-ClusterSharedVolume failed -> $($_.Exception.Message)")
       }

       # (2) Cluster-wide resource parameters: catches VMs owned by other nodes.
       try {
           foreach ($r in (Get-ClusterResource -ErrorAction Stop)) {
               try {
                   foreach ($p in (Get-ClusterParameter -InputObject $r -ErrorAction Stop)) {
                       if (($p.Value -is [string]) -and ($p.Value -match $pattern)) {
                           $blockers.Add("ClusterResource: $($r.Name).$($p.Name) -> $($p.Value)")
                       }
                   }
               } catch {
                   $blockers.Add("QueryError: Get-ClusterParameter on '$($r.Name)' failed -> $($_.Exception.Message)")
               }
           }
       } catch {
           $blockers.Add("QueryError: Get-ClusterResource failed -> $($_.Exception.Message)")
       }

       # (3) Per-node checks across every running node. Cluster-node discovery MUST succeed:
       # without the node list we cannot prove cluster-wide clearance, so a failure here is a
       # blocker, NOT a silent fall back to the local machine.
       $nodes = $null
       try {
           $nodes = @(Get-ClusterNode -ErrorAction Stop | Where-Object State -eq 'Up' |
                      Select-Object -ExpandProperty Name)
       } catch {
           $blockers.Add("DiscoveryError: Get-ClusterNode failed; cannot confirm cluster-wide clearance -> $($_.Exception.Message)")
       }
       if (($null -ne $nodes) -and ($nodes.Count -eq 0)) {
           $blockers.Add("DiscoveryError: no cluster node reported 'Up'; cannot confirm cluster-wide clearance")
       }

       if ($nodes -and $nodes.Count -gt 0) {
           # -ErrorAction SilentlyContinue keeps one unreachable node from aborting the whole
           # sweep; the reported-vs-expected check below turns any missing node into a blocker.
           $perNode = Invoke-Command -ComputerName $nodes -ArgumentList $pattern `
               -ErrorAction SilentlyContinue -ScriptBlock {
               param($Pattern)
               $hits   = New-Object System.Collections.Generic.List[string]
               $errors = New-Object System.Collections.Generic.List[string]

               try {
                   foreach ($vm in (Get-VM -ErrorAction Stop)) {
                       # A mounted ISO is a live reference just like a disk.
                       foreach ($dvd in ($vm | Get-VMDvdDrive -ErrorAction Stop)) {
                           if ($dvd.Path -match $pattern) { $hits.Add("VMDvdDrive: $($vm.Name) -> $($dvd.Path)") }
                       }
                       foreach ($d in ($vm | Get-VMHardDiskDrive -ErrorAction SilentlyContinue)) {
                           if ($d.Path -match $Pattern) { $hits.Add("VMHardDisk: $($vm.Name) -> $($d.Path)") }

                           # Walk the parent chain. A checkpoint / differencing PARENT can still
                           # live on a ghost root while the attached child sits on a healthy CSV,
                           # and deleting that parent breaks the chain. An unreadable link is
                           # recorded as an error (a blocker), never skipped.
                           $p = $d.Path
                           $depth = 0
                           while ($p -and $depth -lt 50) {
                               $vhd = Get-VHD -Path $p -ErrorAction SilentlyContinue
                               if (-not $vhd) {
                                   # FAIL CLOSED at every depth, including the attached leaf.
                                   # An unreadable disk means we cannot prove its parent chain is
                                   # clean, so it is a blocker, not a pass.
                                   $errors.Add("Get-VHD could not read '$p' (chain of $($vm.Name), depth $depth); parent-chain coverage incomplete")
                                   break
                               }
                               $p = $vhd.ParentPath
                               if ($p -and ($p -match $Pattern)) { $hits.Add("VMDiskParent: $($vm.Name) -> $p") }
                               $depth++
                           }
                           if ($depth -ge 50) {
                               $errors.Add("Parent chain of $($vm.Name) exceeded 50 links; not fully walked")
                           }
                       }
                       foreach ($prop in 'ConfigurationLocation','SnapshotFileLocation','SmartPagingFilePath') {
                           $v = $vm.$prop
                           if ($v -and ($v -match $Pattern)) { $hits.Add("VMConfig: $($vm.Name).$prop -> $v") }
                       }
                   }
               } catch {
                   $errors.Add("Get-VM enumeration failed -> $($_.Exception.Message)")
               }

               try {
                   foreach ($f in (Get-SmbOpenFile -ErrorAction Stop)) {
                       if ($f.Path -match $Pattern) { $hits.Add("SmbOpenFile: $($f.Path)") }
                   }
               } catch {
                   $errors.Add("Get-SmbOpenFile failed -> $($_.Exception.Message)")
               }

               # One recursive, fail-closed pass over each ghost root. A reparse point at
               # ANY depth still redirects to a volume, so the scan must recurse rather than
               # check only immediate children. A read that cannot complete throws and is
               # recorded as a blocker below, so an unreadable root is never reported safe.
               try {
                   foreach ($g in (Get-ChildItem -Path "$($env:SystemDrive)\" -Directory -Filter 'ClusterStorage.*' -ErrorAction Stop |
                                   Where-Object { $_.Name -match '^ClusterStorage\.\d+$' })) {
                       # The ROOT ITSELF can be the mount point. Scanning only descendants let a
                       # numbered root that IS a volume mount point pass this gate entirely.
                       if ($g.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                           $hits.Add("ReparsePointOnRoot: $($g.FullName)")
                       }
                       foreach ($item in (Get-ChildItem -LiteralPath $g.FullName -Recurse -Force -ErrorAction Stop)) {
                           if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                               $hits.Add("ReparsePoint: $($item.FullName)")
                           }
                           # Platform content is a Path C blocker regardless of references: a
                           # MocArb, ImageStore, or WorkingDirectory folder, or ANY virtual hard
                           # disk (base .vhd/.vhdx, checkpoint .avhd/.avhdx, VHD-Set .vhds, or
                           # .vhdpmem). This is the same pattern the companion CSSTools remediation
                           # uses. A bare Infrastructure_1 breadcrumb is NOT platform content and
                           # stays on Path A.
                           if ($item.Name -match '^(MocArb|ImageStore|WorkingDirectory)$|\.a?vhd(x|s|pmem)?$') {
                               $hits.Add("PlatformContent: $($item.FullName)")
                           }
                       }
                   }
               } catch {
                   $errors.Add("Ghost-root enumeration failed -> $($_.Exception.Message)")
               }

               [pscustomobject]@{ Node = $env:COMPUTERNAME; Hits = @($hits); Errors = @($errors) }
           }

           foreach ($n in $perNode) {
               foreach ($h in $n.Hits)   { $blockers.Add("[$($n.Node)] $h") }
               foreach ($e in $n.Errors) { $blockers.Add("[$($n.Node)] QueryError: $e") }
           }

           # Every expected node MUST return a result. A node that never reported (unreachable,
           # WinRM down, remoting refused) is a blocker: we cannot clear what we could not inspect.
           $reported = @($perNode | ForEach-Object { $_.PSComputerName })
           foreach ($expected in $nodes) {
               if ($reported -notcontains $expected) {
                   $blockers.Add("[$expected] RemotingError: node did not return an audit result (unreachable or WinRM unavailable)")
               }
           }
       }

       [pscustomobject]@{
           SafeToDelete = ($blockers.Count -eq 0)
           BlockerCount = $blockers.Count
           Blockers     = @($blockers)
       }
   }
   ```

2. **Re-confirm immediately before acting.**
   State can change between investigation and cleanup, especially if an update ran in
   between.

   ```powershell
   $audit = Get-GhostCsvAudit
   $audit | Format-List
   if (-not $audit.SafeToDelete) { $audit.Blockers }
   ```

   **`SafeToDelete` must be `True`.** If it is not, stop and return to
   [Step 3](#step-3-classify-what-you-found).

3. **Record what is there before removing it.**

   ```powershell
   $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
   $backup = "C:\Temp\GhostCsvBackup-$stamp"
   New-Item -ItemType Directory -Path $backup -Force | Out-Null

   Get-ChildItem -Path "$($env:SystemDrive)\" -Directory -Filter 'ClusterStorage.*' -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -match '^ClusterStorage\.\d+$' } |
       ForEach-Object {
           Get-ChildItem -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
               Select-Object FullName, Length, LastWriteTime |
               Export-Csv -Path (Join-Path $backup "$($_.Name)-inventory.csv") -NoTypeInformation
       }
   Write-Host "Inventory written to $backup"
   ```

   > [!IMPORTANT]
   > This writes an **inventory only**. It does not copy file contents, so it does
   > not make the deletion reversible. If the ghost roots contain any file you are
   > not certain is disposable, copy it somewhere safe before continuing, or treat
   > the situation as
   > [Path C](#path-c-references-under-infrastructure_1-or-arb-engage-support).

4. **Remove the ghost roots, one node at a time. [HIGH RISK]**
   This permanently deletes the numbered roots. The block re-runs the full audit,
   refuses to touch anything that is a reparse
   point, and requires you to type a confirmation. Run it on a single node, confirm
   the cluster is healthy, then move to the next.

   ```powershell
   $audit = Get-GhostCsvAudit
   if (-not $audit.SafeToDelete) {
       Write-Warning "Refusing to delete. Blockers:"
       $audit.Blockers
   }
   else {
       $targets = Get-ChildItem -Path "$($env:SystemDrive)\" -Directory -Filter 'ClusterStorage.*' -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -match '^ClusterStorage\.\d+$' }

       # Never recurse into a reparse point: that can delete the target volume's data.
       # This scan uses -ErrorAction Stop on purpose. Suppressing enumeration errors here
       # would let an unreadable subtree hide the very reparse point this gate exists to
       # find, so an enumeration failure is treated as unsafe rather than as "nothing found".
       $unsafe    = @()
       $scanError = $null
       foreach ($t in $targets) {
           try {
               # The root itself first: deleting a root that IS a mount point deletes into live storage.
               if ($t.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { $unsafe += $t }
               $unsafe += Get-ChildItem -LiteralPath $t.FullName -Force -Recurse -ErrorAction Stop |
                   Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint }
           }
           catch {
               $scanError = "Could not fully enumerate $($t.FullName): $($_.Exception.Message)"
               break
           }
       }

       if ($scanError) {
           Write-Warning "Refusing to delete. The safety scan could not complete:"
           Write-Warning $scanError
       }
       elseif ($unsafe) {
           Write-Warning "Reparse points found inside ghost roots. Refusing to delete:"
           $unsafe | Select-Object FullName
       }
       elseif (-not $targets) {
           Write-Host "No ghost roots on $env:COMPUTERNAME."
       }
       else {
           Write-Host "About to permanently delete on $($env:COMPUTERNAME):" -ForegroundColor Yellow
           $targets | ForEach-Object { Write-Host "   $($_.FullName)" -ForegroundColor Yellow }
           Write-Host "Type DELETE (uppercase) to confirm. Anything else cancels." -ForegroundColor Yellow
           $answer = Read-Host "Confirm"
           if ($answer -ceq 'DELETE') {
               foreach ($t in $targets) {
                   # Re-check this specific root immediately before removing it, so a reparse
                   # point created between the scan above and this moment cannot be followed.
                   $lateCheck = @(
                       @($t | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint }) +
                       @(Get-ChildItem -LiteralPath $t.FullName -Force -Recurse -ErrorAction Stop |
                         Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint })
                   )
                   if ($lateCheck.Count -gt 0) {
                       Write-Warning "Skipping $($t.FullName): a reparse point appeared since the scan."
                       continue
                   }
                   # [System.IO.Directory]::Delete removes a reparse point as a LINK rather
                   # than following it into the target. It does NOT clear the read-only
                   # attribute, so clear it first: otherwise the call throws part-way and
                   # leaves the root partially deleted.
                   try {
                       Get-ChildItem -LiteralPath $t.FullName -Force -Recurse -ErrorAction Stop |
                           Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReadOnly } |
                           ForEach-Object { $_.Attributes = $_.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly) }
                       [System.IO.Directory]::Delete($t.FullName, $true)
                       Write-Host "Removed $($t.FullName)"
                   }
                   catch {
                       # Stop the whole batch on the first failure. Continuing would leave some
                       # roots deleted and one half-deleted with no record of where it stopped.
                       Write-Warning "FAILED to remove $($t.FullName): $($_.Exception.Message)"
                       Write-Warning "Stopping. $($t.FullName) may be PARTIALLY deleted. Re-run Get-GhostCsvAudit before touching any remaining root."
                       break
                   }
               }
           }
           else {
               Write-Host "Cancelled. Nothing was deleted."
           }
       }
   }
   ```

5. **Verify.** Go to [Verify the fix](#verify-the-fix).

## Path B: a workload VM references a ghost path

The fix is to move the VM's storage back onto the canonical CSV path, then confirm
nothing points at the ghost root any more. The supported primitive is
[`Move-VMStorage`](https://learn.microsoft.com/powershell/module/hyper-v/move-vmstorage),
which moves disks, configuration, checkpoints, and the smart paging file.

### Prerequisites

- A destination path taken from your
  [Step 1B](#1b-confirm-which-mount-points-are-the-real-ones) output. Do not invent
  one.
- A maintenance window, since this moves data.
- The VM is a **customer workload** VM. If it is an ARB or platform VM, or its files
  are under `Infrastructure_1`, go to
  [Path C](#path-c-references-under-infrastructure_1-or-arb-engage-support).

### Steps

1. **Set your variables and validate the destination.**
   Replace both placeholder values. The validation refuses to continue unless the
   destination is a real, active CSV mount point on this cluster, which prevents
   moving VM storage onto the non-clustered system drive by accident.

   ```powershell
   # ---- replace both of these ----
   $VMName      = 'REPLACE-WITH-VM-NAME'
   $CsvRootPath = 'REPLACE-WITH-CSV-PATH-FROM-STEP-1B'   # for example C:\ClusterStorage\UserStorage_1
   # -------------------------------

   $GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)'

   if ($VMName -like 'REPLACE-*' -or $CsvRootPath -like 'REPLACE-*') {
       throw "Set the VM name and CSV path variables before running this block."
   }
   if (-not (Get-VM -Name $VMName -ErrorAction SilentlyContinue)) {
       throw "VM '$VMName' not found on $env:COMPUTERNAME. Get-VM and Move-VMStorage are node-local, so for a clustered VM you must run Path B from the node that currently owns it. Find the owner with 'Get-ClusterGroup | Where-Object GroupType -eq ''VirtualMachine''' (its OwnerNode column), move to that node, and re-run."
   }

   # Get-VM -Name accepts WILDCARDS, so a pasted value such as 'web*' or a partial name can
   # match several VMs and silently feed all of them into the move. Require exactly one, and
   # require the name to be literal.
   if ($VMName -match '[\*\?\[\]]') {
       throw "VMName '$VMName' contains a wildcard character. Supply one exact VM name; Path B moves storage and must never act on a set."
   }
   $matchedVms = @(Get-VM -Name $VMName -ErrorAction SilentlyContinue)
   if ($matchedVms.Count -ne 1) {
       throw "VMName '$VMName' matched $($matchedVms.Count) VM(s): $(($matchedVms.Name) -join ', '). Supply one exact VM name."
   }

   # Path C content must never be repointed by the customer. The classification in Step 3
   # covers the ghost ROOT, but nothing here previously checked the VM ITSELF, so an ARB or
   # platform VM name copied out of Step 2A would be moved onto a customer CSV.
   $platformVmPattern = '^(AzureStackHCI|ARB-|arcbridge|.*-arcbridge|moc-|.*_MocArb.*|ClusterPerformanceHistory)'
   if ($matchedVms[0].Name -match $platformVmPattern) {
       throw "VM '$VMName' looks like an Azure Local platform or Arc Resource Bridge VM. That is Path C: stop and engage Microsoft Support rather than repointing it yourself."
   }
   # The infrastructure test must cover EVERY storage location, not just attached disks: a
   # config, checkpoint, or paging path under Infrastructure_<n> is equally Path C.
   $infraHits = @()
   $infraHits += @($matchedVms[0] | Get-VMHardDiskDrive -ErrorAction SilentlyContinue |
                   Where-Object { $_.Path -match '[\\/]Infrastructure(_\d+)?[\\/]' } |
                   Select-Object -ExpandProperty Path)
   $infraHits += @($matchedVms[0].ConfigurationLocation, $matchedVms[0].SnapshotFileLocation,
                   $matchedVms[0].SmartPagingFilePath) |
                 Where-Object { $_ -and ($_ -match '[\\/]Infrastructure(_\d+)?[\\/]') }
   if ($infraHits.Count) {
       throw "VM '$VMName' has storage on the reserved infrastructure volume ($($infraHits -join '; ')). That is Path C: stop and engage Microsoft Support."
   }

   # A disk attached to MORE THAN ONE VM (a shared .vhdx or a VHD Set) must never be moved
   # here: Move-VMStorage relocates the file, and the peer VM's path would still point at the
   # old location, breaking a VM this guide was never asked to touch.
   $myDiskPaths = @($matchedVms[0] | Get-VMHardDiskDrive -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty Path)
   $sharedWith = @()
   foreach ($other in (Get-VM -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $matchedVms[0].Name })) {
       foreach ($od in ($other | Get-VMHardDiskDrive -ErrorAction SilentlyContinue)) {
           if ($od.Path -and ($myDiskPaths -contains $od.Path)) { $sharedWith += "$($other.Name) -> $($od.Path)" }
       }
   }
   if ($sharedWith.Count) {
       throw "One or more disks on '$VMName' are ALSO attached to another VM ($($sharedWith -join '; ')). Moving shared storage would break the other VM. That is Path C: stop and engage Microsoft Support."
   }

   # The destination must be an ACTIVE CSV mount point from Step 1B, and it must be a
   # CUSTOMER workload volume. Get-ClusterSharedVolume also returns the reserved
   # infrastructure volume, so membership of that list is NOT on its own a safe test.
   $InfraPathPattern = '[\\/]Infrastructure(_\d+)?([\\/]|$)'

   # Only ONLINE CSVs are valid destinations. An Offline CSV still appears in this
   # list but cannot host VM storage, so it is excluded here as well.
   $allCsv   = @(Get-ClusterSharedVolume | Where-Object { $_.State -eq 'Online' } |
                     ForEach-Object { $_.SharedVolumeInfo.FriendlyVolumeName })
   $validCsv = @($allCsv | Where-Object { $_ -notmatch $InfraPathPattern })

   # Checked FIRST so the reserved volume produces its own specific error rather than
   # a generic "not in the list" message.
   if ($CsvRootPath -match $InfraPathPattern) {
       throw "'$CsvRootPath' is the reserved Azure Local infrastructure volume. Customer workload storage must never be placed there. Pick a customer volume from Step 1B, or go to Path C."
   }
   if (-not $validCsv) {
       throw "No customer CSV mount point is available on this cluster. Do not use the infrastructure volume. Go to Path C."
   }
   # Normalise before comparing: a pasted path with a trailing slash would not match the
   # Get-ClusterSharedVolume value and would block a legitimate destination.
   $CsvRootPath = $CsvRootPath.TrimEnd('\','/')
   $validCsv    = @($validCsv | ForEach-Object { $_.TrimEnd('\','/') })
   if ($CsvRootPath -notin $validCsv) {
       throw "'$CsvRootPath' is not an active customer CSV mount point. Valid values: $($validCsv -join ', ')"
   }
   if ($CsvRootPath -match $GhostPathPattern) {
       throw "'$CsvRootPath' is itself a ghost path. Pick a canonical CSV from Step 1B."
   }

   $Destination = Join-Path $CsvRootPath $VMName
   Write-Host "Destination validated: $Destination" -ForegroundColor Green
   ```

2. **Record the current state of the affected VM.**
   Keep this output. It is your rollback reference and your evidence of what changed.

   ```powershell
   Get-VM -Name $VMName |
       Select-Object Name, State, ConfigurationLocation, SnapshotFileLocation, SmartPagingFilePath |
       Format-List
   Get-VM -Name $VMName | Get-VMHardDiskDrive |
       Select-Object VMName, ControllerType, ControllerNumber, ControllerLocation, Path |
       Format-Table -AutoSize
   ```

3. **Build the disk mapping and review it.**

   ```powershell
   # Self-sufficient: re-defines the pattern if this block is pasted into a fresh session.
   # Without it, -match against an unset variable matches EVERY path.
   if ([string]::IsNullOrWhiteSpace($GhostPathPattern)) { $GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)' }
   New-Item -ItemType Directory -Path $Destination -Force | Out-Null

   # The [string] casts are REQUIRED, and are the most common reason this step
   # fails. Join-Path returns a PSObject-wrapped string, and Move-VMStorage
   # rejects the wrapper with the misleading error
   #   "Hash tables in the Vhds parameter must contain 'DestinationFilePath' key"
   # even though the key IS present. The wrapper is invisible to normal checks:
   # .GetType() reports String and -is [string] reports True.

   # Give each disk its OWN numbered subdirectory. Two disks can share a leaf filename
   # (attached from different source folders); mapping both to $Destination\<leaf> would
   # produce identical DestinationFilePath values and make Move-VMStorage fail. A unique
   # per-disk subdirectory keeps the mapping one-to-one while preserving each filename.
   $diskIndex = 0
   $vhds = @(
       Get-VM -Name $VMName | Get-VMHardDiskDrive |
           Where-Object { $_.Path -match $GhostPathPattern } |
           ForEach-Object {
               $diskIndex++
               $diskDir = Join-Path $Destination ('Disk{0:D2}' -f $diskIndex)
               New-Item -ItemType Directory -Path $diskDir -Force | Out-Null
               @{
                   SourceFilePath      = [string]$_.Path
                   DestinationFilePath = [string](Join-Path $diskDir (Split-Path $_.Path -Leaf))
               }
           }
   )

   if (-not $vhds) { Write-Host "No ghost-rooted disks on '$VMName'." }
   $vhds | ForEach-Object { "{0}  ->  {1}" -f $_.SourceFilePath, $_.DestinationFilePath }

   # Move-VMStorage -Vhds relocates ATTACHED disks only. A ghost-rooted checkpoint or
   # differencing PARENT is not an attached disk, so it will NOT move here; Step 5 and
   # Path A will keep reporting it (correctly). Detect that case now so it is not a surprise.
   $ghostParents = @(
       Get-VM -Name $VMName | Get-VMHardDiskDrive | ForEach-Object {
           $path = $_.Path; $depth = 0
           while ($path -and $depth -lt 50) {
               $vhd = Get-VHD -Path $path -ErrorAction SilentlyContinue
               if (-not $vhd) { break }
               $path = $vhd.ParentPath; $depth++
               if ($path -and ($path -match $GhostPathPattern)) { $path }
           }
       }
   )
   if ($ghostParents.Count -gt 0) {
       Write-Warning "PARENT disk(s) on a ghost root that Move-VMStorage will NOT relocate:"
       $ghostParents | Sort-Object -Unique | ForEach-Object { Write-Warning "   $_" }
       Write-Warning "Relocating an unattached differencing or checkpoint parent is not a hand procedure. Complete the attached-disk move if there is one, but this VM needs Path C (engage support) to clear the parent before Path A can remove the root."
   }
   ```

   **Stop and read that mapping.** Every destination must be under the path you
   validated in step 1.

4. **Dry-run the move, then perform it. [MEDIUM RISK]**
   `Move-VMStorage` relocates live VM storage. It supports `-WhatIf`. Always run the dry run and read its output
   before the real move.

   The parameter set is built once, below. `-Vhds` is included **only** when there is
   at least one ghost-rooted disk to move, because `Move-VMStorage` rejects an empty
   array. Building it this way means you never have to hand-edit the command, which is
   the step most likely to go wrong under time pressure.

   ```powershell
   $moveParams = @{
       Name                = $VMName
       VirtualMachinePath  = $Destination
       SnapshotFilePath    = $Destination
       SmartPagingFilePath = $Destination
   }
   if ($vhds.Count -gt 0) { $moveParams['Vhds'] = $vhds }

   # Dry run: reports what would happen and changes nothing.
   Move-VMStorage @moveParams -WhatIf
   ```

   When the dry run looks correct, run the same parameter set without `-WhatIf`:

   ```powershell
   Move-VMStorage @moveParams
   ```

   > [!NOTE]
   > Supply only the parameters you actually need to change. If the VM's checkpoint
   > location was already correct in Step 2B, remove `SnapshotFilePath` from
   > `$moveParams` rather than moving it unnecessarily.

5. **Confirm this VM is clean.**

   ```powershell
   # Self-sufficient: re-defines the pattern if this block is pasted into a fresh session.
   # Without it, -match against an unset variable matches EVERY path.
   if ([string]::IsNullOrWhiteSpace($GhostPathPattern)) { $GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)' }
   $vm  = Get-VM -Name $VMName
   $bad = New-Object System.Collections.Generic.List[string]

   # Walk every attached disk's FULL parent chain, exactly as Step 2A does. Checking only
   # attached paths would report success while a checkpoint or differencing PARENT is still
   # on a ghost root, which Path A would then correctly refuse to delete, leaving a green
   # verdict and a blocked cleanup. An UNREADABLE link is treated as a reference.
   foreach ($d in ($vm | Get-VMHardDiskDrive)) {
       $path  = $d.Path
       $depth = 0
       while ($path -and $depth -lt 50) {
           if ($path -match $GhostPathPattern) { $bad.Add("disk chain (depth $depth): $path") }
           $vhd = Get-VHD -Path $path -ErrorAction SilentlyContinue
           if (-not $vhd) { $bad.Add("UNREADABLE (chain not fully walked): $path"); break }
           $path = $vhd.ParentPath
           $depth++
       }
   }
   foreach ($p in @($vm.ConfigurationLocation, $vm.SnapshotFileLocation, $vm.SmartPagingFilePath)) {
       if ($p -and ($p -match $GhostPathPattern)) { $bad.Add("config/checkpoint/paging: $p") }
   }

   if ($bad.Count -gt 0) {
       Write-Warning "$VMName still references a ghost path (parent chains included):"
       $bad
   }
   else {
       Write-Host "$VMName no longer references any ghost path, including parent chains." -ForegroundColor Green
   }
   ```

6. **Repeat for every VM found in Step 2**, then re-run
   [Step 2](#step-2-prove-whether-anything-references-them) in full.

7. **Only once every reference is cleared**, follow
   [Path A](#path-a-no-references-found-safe-to-clean-up) to remove the now-unused
   ghost roots.

## Path C: references under `Infrastructure_1` or ARB, engage support

Stop and open a support case if **any** of the following is true:

- A reference from Step 2 points under `...\Infrastructure_1\...`.
- A ghost root holds ARB or MOC working data: any virtual hard disk (`.vhd`,
  `.vhdx`, `.avhd`, `.avhdx`, `.vhds`, `.vhdpmem`), or a `MocArb`, `ImageStore`, or
  `WorkingDirectory` folder.
- [Step 1C](#1c-check-whether-the-ghost-root-still-redirects-to-live-data) shows
  `IsReparsePoint = True` for the root itself or any child of a ghost root.
- An **active** CSV reports a `FriendlyVolumeName` under a numbered root.

> [!NOTE]
> An `Infrastructure_1` folder inside a ghost root is **not** by itself one of
> these conditions. Clusters routinely accumulate a small, stale `Infrastructure_1`
> breadcrumb per numbered root as updates run. What matters is whether anything
> still references it, or whether it holds real ARB or MOC working data.

These are platform-managed paths. `Infrastructure_1` is reserved for Azure Local
system configuration, the platform deliberately blocks customer storage placement on
it, and relocating its content by hand is outside the customer support boundary. A
wrong move can leave Arc Resource Bridge or the solution update pipeline in a state
that needs a rebuild to recover.

**Collect this before contacting support**, so the case starts with evidence:

```powershell
$out = "C:\Temp\GhostCsvEvidence-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $out -Force | Out-Null
$GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)'

Get-ClusterSharedVolume | ForEach-Object {
    [pscustomobject]@{ CSVName = $_.Name; Path = $_.SharedVolumeInfo.FriendlyVolumeName; State = $_.State }
} | Export-Csv "$out\csv-mountpoints.csv" -NoTypeInformation

Get-ChildItem -Path "$($env:SystemDrive)\" -Directory -Filter 'ClusterStorage.*' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^ClusterStorage\.\d+$' } |
    Select-Object FullName, CreationTime, LastWriteTime,
        @{n='IsReparsePoint';e={[bool]($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)}} |
    Export-Csv "$out\ghost-roots.csv" -NoTypeInformation

# The criteria that TRIGGER Path C are the reference and reparse findings, so export those
# too. Sending only the CSV list and cluster parameters makes support re-run Steps 1 and 2
# before they can start, which is the slowest possible opening to a case.
$nodes = (Get-ClusterNode | Where-Object State -eq 'Up').Name
Invoke-Command -ComputerName $nodes -ArgumentList $GhostPathPattern -ScriptBlock {
    param($Pattern)
    $refs = New-Object System.Collections.Generic.List[object]
    foreach ($vm in (Get-VM -ErrorAction SilentlyContinue)) {
        foreach ($d in ($vm | Get-VMHardDiskDrive -ErrorAction SilentlyContinue)) {
            $path = $d.Path; $depth = 0
            while ($path -and $depth -lt 50) {
                if ($path -match $Pattern) { $refs.Add([pscustomobject]@{ Node=$env:COMPUTERNAME; Kind='VMDiskChain'; Object=$vm.Name; Value=$path; Depth=$depth }) }
                if (-not (Test-Path -LiteralPath $path)) { break }
                $vhd = Get-VHD -Path $path -ErrorAction SilentlyContinue
                if (-not $vhd) { $refs.Add([pscustomobject]@{ Node=$env:COMPUTERNAME; Kind='UnreadableChain'; Object=$vm.Name; Value=$path; Depth=$depth }); break }
                $path = $vhd.ParentPath; $depth++
            }
        }
        foreach ($dvd in ($vm | Get-VMDvdDrive -ErrorAction SilentlyContinue)) {
            if ($dvd.Path -and ($dvd.Path -match $Pattern)) { $refs.Add([pscustomobject]@{ Node=$env:COMPUTERNAME; Kind='VMDvdDrive'; Object=$vm.Name; Value=$dvd.Path; Depth=0 }) }
        }
        foreach ($prop in 'ConfigurationLocation','SnapshotFileLocation','SmartPagingFilePath') {
            $v = $vm.$prop
            if ($v -and ($v -match $Pattern)) { $refs.Add([pscustomobject]@{ Node=$env:COMPUTERNAME; Kind="VMConfig:$prop"; Object=$vm.Name; Value=$v; Depth=0 }) }
        }
    }
    foreach ($f in (Get-SmbOpenFile -ErrorAction SilentlyContinue)) {
        if ($f.Path -match $Pattern) { $refs.Add([pscustomobject]@{ Node=$env:COMPUTERNAME; Kind='SmbOpenFile'; Object=$f.ClientComputerName; Value=$f.Path; Depth=0 }) }
    }
    # Root and descendant reparse points, plus platform content, per ghost root.
    foreach ($g in (Get-ChildItem -Path "$($env:SystemDrive)\" -Directory -Filter 'ClusterStorage.*' -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match '^ClusterStorage\.\d+$' })) {
        if ($g.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $refs.Add([pscustomobject]@{ Node=$env:COMPUTERNAME; Kind='ReparsePointOnRoot'; Object=$g.FullName; Value=$g.FullName; Depth=0 })
        }
        foreach ($item in (Get-ChildItem -LiteralPath $g.FullName -Force -Recurse -ErrorAction SilentlyContinue)) {
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                $refs.Add([pscustomobject]@{ Node=$env:COMPUTERNAME; Kind='ReparsePoint'; Object=$g.Name; Value=$item.FullName; Depth=0 })
            }
            if ($item.Name -match '^(MocArb|ImageStore|WorkingDirectory)$|\.a?vhd(x|s|pmem)?$') {
                $refs.Add([pscustomobject]@{ Node=$env:COMPUTERNAME; Kind='PlatformContent'; Object=$g.Name; Value=$item.FullName; Depth=0 })
            }
        }
    }
    $refs
} | Select-Object Node, Kind, Object, Value, Depth |
    Export-Csv "$out\references-and-content.csv" -NoTypeInformation

$paramErrors = New-Object System.Collections.Generic.List[string]
Get-ClusterResource | ForEach-Object {
    $r = $_
    try {
        Get-ClusterParameter -InputObject $r -ErrorAction Stop | ForEach-Object {
            # Match strings AND string arrays: a multi-valued parameter holding a ghost path
            # was skipped entirely by a bare -is [string] test.
            if (($_.Value -is [string] -or $_.Value -is [string[]]) -and
                (@($_.Value) -match $GhostPathPattern)) {
                [pscustomobject]@{ Resource = $r.Name; Parameter = $_.Name; Value = $_.Value }
            }
        }
    }
    catch {
        # Benign for resource types that expose no parameters; record the rest so the
        # support case shows which resources could not be inspected.
        $paramErrors.Add($r.Name)
    }
} | Export-Csv "$out\cluster-resource-refs.csv" -NoTypeInformation

if ($paramErrors.Count) {
    $paramErrors | Set-Content "$out\cluster-resource-uninspected.txt"
    Write-Host ("Note: {0} cluster resource(s) returned no parameters; listed in cluster-resource-uninspected.txt" -f $paramErrors.Count)
}

Write-Host "Evidence collected in $out"
```

Also attach the output of
[Troubleshooting Storage With Support Diagnostics Tool](./Troubleshooting-Storage-With-Support-Diagnostics-Tool.md).

## Verify the fix

Run all four. The condition is resolved only when all four are clean.

```powershell
$GhostPathPattern = '[\\/]ClusterStorage\.\d+([\\/]|$)'
$nodes = (Get-ClusterNode | Where-Object State -eq 'Up').Name

# Every node must be inspected, not just the reachable ones. A node that is Down, Paused, or
# unreachable is UNVERIFIED, not clean, and ghost roots frequently appear precisely while a
# node is drained for a solution update. Surface the gap instead of silently omitting it.
$allNodes     = (Get-ClusterNode).Name
$missingNodes = @($allNodes | Where-Object { $_ -notin $nodes })
if ($missingNodes.Count) {
    Write-Warning ("{0} node(s) were NOT inspected and remain unverified: {1}. This condition is NOT resolved until every node returns clean." -f `
        $missingNodes.Count, ($missingNodes -join ', '))
}

# 1) No ghost roots, and no VM, PARENT-CHAIN, or SMB reference, on any node.
$remotingErrors = @()
$nodeResults = Invoke-Command -ComputerName $nodes -ArgumentList $GhostPathPattern -ScriptBlock {
    param($Pattern)
    $refs = @()
    $unverifiedChains = @()
    foreach ($vm in (Get-VM -ErrorAction SilentlyContinue)) {
        # A mounted ISO is a reference too.
        foreach ($dvd in ($vm | Get-VMDvdDrive -ErrorAction SilentlyContinue)) {
            if ($dvd.Path -and ($dvd.Path -match $Pattern)) { $refs += $dvd.Path }
        }
        foreach ($d in ($vm | Get-VMHardDiskDrive -ErrorAction SilentlyContinue)) {
            # Walk the FULL parent chain, not just the attached path. Checking only the
            # attached disk lets a differencing/checkpoint PARENT sitting on a ghost root
            # pass verification, which is the exact data-loss case Step 2A warns about.
            $path = $d.Path; $depth = 0
            while ($path -and $depth -lt 50) {
                if ($path -match $Pattern) { $refs += $path }
                # A file that does NOT EXIST ends the chain: an orphaned VM whose disk was
                # already deleted is an ordinary field state and cannot hold a parent link.
                if (-not (Test-Path -LiteralPath $path)) { break }
                # A file that EXISTS but cannot be READ is different: coverage is unknown, so
                # it counts as unverified rather than clean. Step 2A and the Path A audit both
                # treat this as a reference, and verification must not be weaker than they are.
                $vhd = Get-VHD -Path $path -ErrorAction SilentlyContinue
                if (-not $vhd) { $unverifiedChains += "UNREADABLE: $($vm.Name) -> $path"; break }
                $path = $vhd.ParentPath; $depth++
            }
        }
        $refs += @($vm.ConfigurationLocation, $vm.SnapshotFileLocation, $vm.SmartPagingFilePath) |
                 Where-Object { $_ -and ($_ -match $Pattern) }
    }
    $refs += (Get-SmbOpenFile -ErrorAction SilentlyContinue |
              Where-Object { $_.Path -match $Pattern }).Path
    # Probe the SYSTEM drive, not a hardcoded C:, so a node whose system drive is not C:
    # is not silently reported as clean because the wrong volume was inspected.
    $sysRoot = "$($env:SystemDrive)\"
    $roots = @(Get-ChildItem -Path $sysRoot -Directory -Filter 'ClusterStorage.*' -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '^ClusterStorage\.\d+$' })
    # Any surviving root must still be free of reparse points and platform content, which
    # the earlier version of this check omitted entirely.
    $reparse = 0; $platform = 0
    foreach ($r in $roots) {
        $items = @($r) + @(Get-ChildItem -LiteralPath $r.FullName -Force -Recurse -ErrorAction SilentlyContinue)
        $reparse  += @($items | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint }).Count
        $platform += @($items | Where-Object { $_.Name -match '^(MocArb|ImageStore|WorkingDirectory)$|\.a?vhd(x|s|pmem)?$' }).Count
    }
    [pscustomobject]@{
        Node             = $env:COMPUTERNAME
        GhostRoots       = $roots.Count
        References       = @($refs | Where-Object { $_ }).Count
        UnverifiedChains = $unverifiedChains.Count
        ReparsePoints    = $reparse
        PlatformItems    = $platform
    }
} -ErrorAction SilentlyContinue -ErrorVariable +remotingErrors

# A node whose cluster state is Up can still fail Invoke-Command (WinRM down, credentials,
# firewall). That node returns NO ROW, and a missing row is not a clean row. Reconcile the
# nodes that actually ANSWERED against the full cluster membership, so an Up-but-unreachable
# node cannot pass verification by silently producing nothing.
$results   = @($nodeResults)
$answered  = @($results | Select-Object -ExpandProperty Node -ErrorAction SilentlyContinue)
$noAnswer  = @($allNodes | Where-Object {
    $short = ($_ -split '\.')[0]
    $short -notin @($answered | ForEach-Object { ($_ -split '\.')[0] })
})
if ($noAnswer.Count) {
    Write-Warning ("{0} node(s) returned NO RESULT and are UNVERIFIED: {1}. A missing row is not a clean row; this condition is NOT resolved until every node answers clean." -f `
        $noAnswer.Count, ($noAnswer -join ', '))
}
if ($remotingErrors.Count) {
    Write-Warning ("{0} remoting error(s) occurred during verification; resolve them and re-run." -f $remotingErrors.Count)
}

$results | Select-Object Node, GhostRoots, References, UnverifiedChains, ReparsePoints, PlatformItems | Format-Table -AutoSize

# 2) Every CSV is Online and mounted under the canonical root.
Get-ClusterSharedVolume | ForEach-Object {
    [pscustomobject]@{
        CSVName   = $_.Name
        Path      = $_.SharedVolumeInfo.FriendlyVolumeName
        State     = $_.State
        Canonical = ($_.SharedVolumeInfo.FriendlyVolumeName -notmatch $GhostPathPattern)
    }
} | Format-Table -AutoSize

# 3) No cluster resource references a ghost path.
$paramErrors = New-Object System.Collections.Generic.List[string]
Get-ClusterResource | ForEach-Object {
    $r = $_
    try {
        Get-ClusterParameter -InputObject $r -ErrorAction Stop | ForEach-Object {
            # Match strings AND string arrays: a multi-valued parameter holding a ghost path
            # was skipped entirely by a bare -is [string] test.
            if (($_.Value -is [string] -or $_.Value -is [string[]]) -and
                (@($_.Value) -match $GhostPathPattern)) {
                [pscustomobject]@{ Resource = $r.Name; Parameter = $_.Name; Value = $_.Value }
            }
        }
    }
    catch {
        # Benign for resource types that expose no parameters; record the rest so a genuine
        # query failure does not let the verification pass on reduced coverage.
        $paramErrors.Add($r.Name)
    }
} | Format-Table -AutoSize

if ($paramErrors.Count) {
    Write-Warning ("{0} cluster resource(s) did not return parameters and were not inspected: {1}" -f `
        $paramErrors.Count, ($paramErrors -join ', '))
}

# 4) Cluster roles and resources are healthy.
Get-ClusterGroup    | Format-Table Name, OwnerNode, State -AutoSize
Get-ClusterResource | Where-Object State -ne 'Online' | Format-Table Name, State, OwnerGroup -AutoSize
```

Expected: `GhostRoots = 0` and `References = 0` on every node, every CSV `Online`
with `Canonical = True`, no rows from the third command, and no unexpected offline
resources from the fourth.

If you reached this page because a solution update failed, re-run the update
readiness checks before retrying the update.

## Prevention

- **Exclude the CSV path from antivirus and endpoint scanning on every node.** This
  is the single most effective prevention, because a scanner holding a handle on
  `C:\ClusterStorage` is the common trigger for the rename. Microsoft publishes the
  required exclusions, including `%SystemDrive%\ClusterStorage`, in
  [Recommended antivirus exclusions for Hyper-V hosts](https://learn.microsoft.com/troubleshoot/windows-server/virtualization/antivirus-exclusions-for-hyper-v-hosts).
  Use the exact syntax in that document, and apply the same thinking to backup and
  monitoring agents, not only antivirus.
- **Check before and after every solution update.** Running the
  [Quick triage](#quick-triage-start-here) as part of update readiness catches a
  stale reference while it is still cheap to fix.
- **Do not create your own folders next to `C:\ClusterStorage`.** A folder matching
  the numbered pattern is treated as a ghost root by this guide and by tooling.
- **Investigate recurrence rather than repeatedly cleaning up.** If new numbered
  roots keep appearing after each update, something is holding an open handle under
  the CSV root when the Cluster service re-establishes it. Use
  [Step 2F](#2f-optional-establish-when-the-ghost-root-appeared) to identify the
  timing, correlate it with backup, antivirus, monitoring, or third-party storage
  agents running at that moment, and exclude the CSV path from them.
- **Keep VM storage on the canonical path.** When creating or importing a VM, target
  `C:\ClusterStorage\<volume>\...` explicitly rather than accepting a recorded
  absolute path from another system.

## Related Issues

- [Troubleshooting Storage With Support Diagnostics Tool](./Troubleshooting-Storage-With-Support-Diagnostics-Tool.md)
- [Troubleshoot: Storage pool capacity threshold warning (fixed vs thin volumes)](./Troubleshoot-Storage-StoragePoolCapacityThreshold.md)
- [Cluster Shared Volumes overview](https://learn.microsoft.com/windows-server/failover-clustering/failover-cluster-csvs)
- [Manage Cluster Shared Volumes](https://learn.microsoft.com/windows-server/failover-clustering/failover-cluster-manage-cluster-shared-volumes)
- [Recommended antivirus exclusions for Hyper-V hosts](https://learn.microsoft.com/troubleshoot/windows-server/virtualization/antivirus-exclusions-for-hyper-v-hosts)
- [`Move-VMStorage`](https://learn.microsoft.com/powershell/module/hyper-v/move-vmstorage)
- [Events 5120 and 5142 and unable to access the ClusterStorage folder](https://learn.microsoft.com/troubleshoot/windows-server/backup-and-storage/event-5120-5142-access-clusterstorage-folder)

---
