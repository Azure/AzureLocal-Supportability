# Symptoms

A solution update fails at **RegisterCloudManagementClusterExtensions** with a connection error to
port 42545. Virtual machines and storage are unaffected, but the update does not continue.

```text
Type 'RegisterCloudManagementClusterExtensions' of Role 'CloudManagementConfig' raised an exception:
Exception occurred in Get-ClusterExtension: System.Net.WebException: Unable to connect to the remote server
 ---> System.Net.Sockets.SocketException: No connection could be made because the target machine
      actively refused it <node-ip-address>:42545
```

The same failure sometimes appears as a timeout instead:

```text
System.Net.Sockets.SocketException: A connection attempt failed because the connected party did not
properly respond after a period of time <node-ip-address>:42545
```

The Azure Local host service (HciSvc) has crashed on at least one node. Its Application log records:

* **Event ID 1026** from `.NET Runtime` — `HciSvc.exe` terminated by an unhandled `System.AccessViolationException`
* **Event ID 1000** from `Application Error` — `HciSvc.exe` faulted with exception code `0xc0000005`

# Issue Validation

Run this from any node. It checks every node for HciSvc crashes since that node last restarted.

```powershell
Invoke-Command (Get-ClusterNode) {
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000,1026; StartTime=$boot} -ErrorAction SilentlyContinue |
        Where-Object Message -match 'HciSvc' | Select-Object -First 2
} | Format-List PSComputerName, TimeCreated, Id, Message
```

An affected node returns entries like these:

```text
PSComputerName : NODE01
TimeCreated    : 9/2/2026 8:58:08 PM
Id             : 1026
Message        : Application: HciSvc.exe
                 Framework Version: v4.0.30319
                 Description: The process was terminated due to an unhandled exception.
                 Exception Info: System.AccessViolationException
                    at Microsoft.AzureStack.HCI.Interop.En.ID(IntPtr, UInt32 ByRef, IntPtr, UInt32 ByRef, UInt32, UInt32)
                    at Microsoft.AzureStack.HCI.Enclave.HciEnclave+EnclaveClient.EnclaveImdsOp(EnclaveImdsFunction, Byte[], Byte[])
                    at Microsoft.AzureStack.HCI.Enclave.HciEnclave.ImdsSign(Byte[], Byte[])
                    at Microsoft.AzureStack.HCI.Imds.ImdsAttestationCommon.SignAttestedData(Microsoft.AzureStack.HCI.Imds.AttestedData)

PSComputerName : NODE01
TimeCreated    : 9/2/2026 8:58:09 PM
Id             : 1000
Message        : Faulting application name: HciSvc.exe, version: 10.0.26100.33296, time stamp: 0x90103505
                 Faulting module name: ucrtbase.dll, version: 10.0.26100.33158, time stamp: 0x32c000ad
                 Exception code: 0xc0000005
                 Fault offset: 0x00000000000edb0b
                 Faulting application path: C:\Windows\system32\azshci\HciSvc.exe
```

Any entries returned confirm this issue. Nothing returned on any node means the update failed for
another reason.

If the update error says **BadRequest** rather than a connection failure to port 42545, this article
does not apply.

# Cause

A virtualization-based security (VBS) key rotation leaves HciSvc holding a stale key. HciSvc fails
when it next uses that key, and the service crashes. The Cloud Management service depends on HciSvc,
so it cannot start, and the extension registration step has nothing to connect to.

Restarting the service on its own does not clear it. The key is renewed when the cluster
registration is re-synced.

Azure Local 2609 detects and recovers this automatically during the solution update. On earlier
versions, use the steps below.

# Mitigation Details

Run from one node in an elevated PowerShell session.

```powershell
# 1. Start HciSvc wherever it is stopped.
Invoke-Command (Get-ClusterNode) {
    if ((Get-Service HciSvc).Status -ne 'Running') { Start-Service HciSvc }
}

# 2. Re-sync the cluster registration. This renews the key.
$before = (Get-AzureStackHCI).LastConnected
Sync-AzureStackHCI

# Sync-AzureStackHCI returns nothing and does not wait, so watch LastConnected instead.
# Allow longer than 5 minutes on large clusters, roughly 16 nodes or more.
$deadline = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 20
    $now = (Get-AzureStackHCI).LastConnected
    if ($now -and (-not $before -or $now -gt $before)) { "Sync completed at $now"; break }
    "Waiting for sync to complete..."
}

# 3. Bring the Cloud Management role back online if it did not recover on its own.
$group = Get-ClusterGroup -Name 'Cloud Management' -ErrorAction SilentlyContinue
if ($group -and $group.State -ne 'Online') {
    Stop-ClusterGroup  -Name 'Cloud Management' -Wait 60
    Start-ClusterGroup -Name 'Cloud Management' -Wait 60
}
```

Confirm every node can sign again without crashing:

```powershell
Invoke-Command (Get-ClusterNode) {
    $uri = "http://127.0.0.1:42542/metadata/attested/document?api-version=2021-02-01&nonce=$(Get-Random)"
    [pscustomobject]@{
        Node   = $env:COMPUTERNAME
        Status = (Invoke-WebRequest -Uri $uri -Headers @{Metadata='true'} -UseBasicParsing -TimeoutSec 60).StatusCode
    }
} | Format-Table Node, Status -AutoSize
```

```text
Node   Status
----   ------
NODE01    200
NODE02    200
NODE03    200
```

A status of `200` from every node means the signing path works. If HciSvc were still failing there
would be no response at all.

Then retry the update or other operation you were running.

If HciSvc is still crashing, run the steps above once more. A second pass sometimes clears the
remaining nodes. If the operation still fails after that, collect diagnostic data with
`Send-DiagnosticData` and open a support case.
