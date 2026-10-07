# Reset Stale iSCSI State Before Retrying Node Configuration

## Section 1 - Metadata

| Field | Value |
|---|---|
| TSG_ID | TSG-7f3a9c1d0b |
| Title | Reset Stale iSCSI State Before Retrying Node Configuration |
| Description | Clear stale sessions, stored logins, and target portals on a node before retrying node configuration. Check reachability and target access first; those failures do not by themselves call for a reset. |
| Status | New |
| LastUpdated | 2026-10-02 |
| FoundInBuild | N/A |
| FixedInBuild | N/A |
| Region | N/A |
| AppliesTo.OS | 24H2 |
| AppliesTo.Service | Azure Local HCI |
| AuthoringSource | AI-Generated, Human-Reviewed |
| SourceIncidentIDs | N/A |
| SourceArtifacts | _Command sources include Microsoft Learn and iscsicli built-in help._ |
| RevisionHistory | 2026-09-04, v1.0, Initial creation; 2026-09-24, v1.1, Commands verified on hardware; 2026-09-28, v1.2, Clarified reset safety and recovery checks; 2026-09-29, v1.3, Focused title and error triage; 2026-10-02, v1.4, Added TCP source diagnostics and explicit removal-error handling |
| ConfidenceScore | 80 |
| CSS_PG_Author | N/A |
| PG_Reviewer | N/A |
| ReviewDate | N/A |

## Section 2 - Error Codes

| ID | Error / State | Description (one sentence) | Triggering Component |
|---|---|---|---|
| Error #1 | `iSCSI target <address>:3260 is unreachable - recheck the iSCSI network configuration.` | The node could not open a TCP connection to that storage target portal on the iSCSI port. | Azure Local deployment - node configuration |
| Error #2 | `No iSCSI targets were discovered after registering the fabric portals - verify SAN LUN zoning to this node's initiator IQN and the target portal configuration.` | The node discovered no targets after refreshing the configured portals. | Azure Local deployment - node configuration |

## Section 3 - Symptoms

**What you will see:**

1. **Symptom #1 - Node configuration fails** - it stops while bringing up iSCSI storage on one node.
2. **Symptom #2 - A re-run may fail at the same step** - the same failure can recur without the node's iSCSI state being corrected.
3. **Symptom #3 - Storage paths reappear or look wrong after a reboot** - sessions the node was not expected to have are present, or expected paths are missing.

| Symptom | Related Error | Cause | Mitigation (short) |
|---|---|---|---|
| Node configuration stops on one node at the iSCSI step | `iSCSI target <address>:3260 is unreachable - recheck the iSCSI network configuration.` | Target portal not reachable on TCP 3260 from this node | [Check reachability; do not reset](#powershell-validation-steps) |
| Node configuration stops on one node at the iSCSI step | `No iSCSI targets were discovered after registering the fabric portals - verify SAN LUN zoning to this node's initiator IQN and the target portal configuration.` | No targets discovered; portal binding or target access may be wrong | [Check binding and target access first](#powershell-validation-steps) |
| Re-run fails at the same iSCSI step | Either error above | Repetition alone does not establish stale state | [Check reachability and configured paths](#powershell-validation-steps) |
| Unexpected sessions return after reboot | N/A | Stored logins replay at boot | [Reset iSCSI state, then re-run](#mitigation-step-1-record-the-current-state) |

## Section 4 - Issue Validation

**Confirm this is your issue:**

### Failure / Errors Seen on Portal / CLI

Node configuration fails on a single node at the iSCSI step. The failure detail contains either `iSCSI target <address>:3260 is unreachable - recheck the iSCSI network configuration.` or `No iSCSI targets were discovered after registering the fabric portals - verify SAN LUN zoning to this node's initiator IQN and the target portal configuration.`

Run the following on the **failing node**, elevated.

### PowerShell Validation Steps

```powershell
#StartRunCommand
# Diagnoses: Error #1 / Symptom #1 - can this node reach every configured target portal?
# Source: https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection
# Source: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host
$targetPortals = @((Read-Host 'Enter all target portal addresses from this node configuration, comma-separated') -split ',' |
    ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($targetPortals.Count -eq 0) { throw 'No target portal addresses entered. Stop before reset.' }
$reachability = foreach ($portal in $targetPortals) {
    $test = Test-NetConnection -ComputerName $portal -Port 3260 -InformationLevel Detailed
    [pscustomobject]@{
        TargetPortalAddress = $portal
        SourceAddress = $test.SourceAddress.IPAddress
        InterfaceAlias = $test.InterfaceAlias
        TcpTestSucceeded = [bool]$test.TcpTestSucceeded
    }
}
$reachability
if ($reachability | Where-Object { -not $_.TcpTestSucceeded }) {
    throw 'A configured target portal is unreachable. Stop before reset.'
}
#EndRunCommand
```

```powershell
#StartRunCommand
# Diagnoses: Symptom #2 / Cause #1 - portals left over from a previous run
# Source: https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsitargetportal
Get-IscsiTargetPortal | Select-Object TargetPortalAddress, TargetPortalPortNumber, InitiatorPortalAddress
#EndRunCommand
```

```powershell
#StartRunCommand
# Diagnoses: Symptom #3 / Cause #2 - current sessions
# Source: https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsisession
Get-IscsiSession | Select-Object TargetNodeAddress, SessionIdentifier, IsConnected, IsPersistent
#EndRunCommand
```

```powershell
#StartRunCommand
# Diagnoses: Symptom #2 / Cause #2 - initiator and target address for each session path
# Source: https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsiconnection
Get-IscsiSession | ForEach-Object {
    $session = $_
    Get-IscsiConnection -IscsiSession $session |
        Select-Object @{Name='TargetNodeAddress';Expression={$session.TargetNodeAddress}}, InitiatorAddress, TargetAddress
}
#EndRunCommand
```

Use every target portal address from this node's current configuration, not only those in the previous portal listing.

`SourceAddress` and `InterfaceAlias` identify the TCP test's selected path, not an iSCSI session's binding. A different source address warrants network investigation; it does not by itself justify a reset. Use `Get-IscsiConnection` above to check actual iSCSI paths.

- **Error #1:** If any `TcpTestSucceeded` value is `False`, stop. A reset cannot fix reachability; give the failed address to the storage network owner.
- **Error #2:** Compare portal bindings and session connection addresses with the configured initiator-address/target-portal pairs. Reset only if you find stale state. Otherwise, have the storage administrator check target access for this node's initiator IQN; the error alone does not justify a reset.

### Command-to-Symptom Mapping (required)

| Command | Diagnoses | Source |
|---|---|---|
| `Test-NetConnection` | Error #1 / Symptom #1 | https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection |
| `Read-Host` | Error #1 / Symptom #1 | https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host |
| `Get-IscsiTargetPortal` | Symptom #2 / Cause #1 | https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsitargetportal |
| `Get-IscsiSession` | Symptom #3 / Cause #2 | https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsisession |
| `Get-IscsiConnection` | Symptom #2 / Cause #2 | https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsiconnection |

## Section 5 - Cause

Node configuration adds iSCSI state but does not remove obsolete portals or sessions. A retry can reuse existing paths without correcting a wrong portal binding.

- **Cause #1 - A leftover target portal is skipped as already present.** Its binding is not corrected, which can affect discovery (Error #2). Error #1 is different: reachability is tested before portal state is read, so clearing state cannot fix it.
- **Cause #2 - Obsolete session paths are not removed.** An existing connected, persistent path with matching authentication is skipped on retry; a missing path is added, but a stale or mismatched session can remain.
- **Cause #3 - Stored logins survive independently of live sessions.** A stored login is a record replayed at boot. It does not appear in a live-session listing, so it stays invisible until a reboot recreates the path (Symptom #3).

## Section 6 - Preconditions Check

> **This removes every iSCSI path on the node, including any iSCSI usage unrelated to this configuration.** Run it only at the node configuration stage, while the SAN LUNs are still RAW. **Never on a node carrying live storage I/O or in an in-service cluster.**

Confirm all of the following on the failing node:

- **Elevated PowerShell session**, on that node. One node at a time.
- **`Get-Service MSiSCSI`** shows `Running`. If stopped, every listing below returns nothing even when state is present. ([source](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-service))
- Identify all iSCSI disks, including any reached through the current sessions:

  ```powershell
  #StartRunCommand
  # Diagnoses: Symptom #1 / Cause #2 - disks affected by the reset
  # Source: https://learn.microsoft.com/en-us/powershell/module/storage/get-disk
  # Source: https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsisession
  Get-Disk | Where-Object BusType -eq 'iSCSI' | Select-Object Number, UniqueId, PartitionStyle
  Get-IscsiSession | ForEach-Object {
      $session = $_
      Get-Disk -iSCSISession $session |
          Select-Object @{Name='SessionIdentifier';Expression={$session.SessionIdentifier}}, Number, UniqueId, PartitionStyle
  }
  #EndRunCommand
  ```

Confirm that every affected iSCSI LUN is RAW and that **no workload has live I/O over any iSCSI path**. If a cluster exists, a LUN is not RAW, or any disk/path ownership or I/O status is uncertain, **stop and escalate before Step 2**.

## Section 7 - Mitigation Details

**Steps to fix:**

### Mitigation Step 1: Record the current state

```powershell
#StartRunCommand
# Source: https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsiconnection
# Source: https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsisession
# Source: https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsitargetportal
# Source: iscsicli.exe built-in usage text (run: iscsicli /?)
$log = "C:\MASLogs\iscsi-state-before-reset.txt"
Get-IscsiSession      | Format-List * | Out-File $log
Get-IscsiTargetPortal | Format-List * | Out-File $log -Append
Get-IscsiSession | ForEach-Object { Get-IscsiConnection -IscsiSession $_ | Format-List * } | Out-File $log -Append
iscsicli ListPersistentTargets | Out-File $log -Append
iscsicli ListTargetPortals | Out-File $log -Append
#EndRunCommand
```

**Verify**: the file includes both `iscsicli` listings, even if they are empty. If either listing fails, stop before Step 2; keep this file for escalation.

### Mitigation Step 2: Reset the iSCSI state

Run 2a, 2b and 2c in order. Confirm that stored logins are gone before disconnecting sessions.

Judge each sub-step by its listing; stop and escalate if an entry remains after the documented retry.

If a cmdlet fails in 2b or 2c, save the error text with the Step 1 evidence. A failure can occur after some state has changed. Run that sub-step's listing commands separately, even if the error stopped the block before them, and use the fallback only for entries still present. If a listing fails, stop and escalate; do not treat it as empty or advance to the next sub-step.

#### 2a. Remove the stored logins

```powershell
#StartRunCommand
# Diagnoses: Symptom #3 / Cause #3 - removes every stored iSCSI login
# Source: https://learn.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance
# Source: iscsicli.exe built-in usage text (run: iscsicli /?)
Get-CimInstance -Namespace root\wmi -ClassName MSiSCSIInitiator_PersistentLoginClass -ErrorAction Stop |
    ForEach-Object {
        & iscsicli.exe RemovePersistentTarget $_.InitiatorInstance $_.TargetName `
                       $_.InitiatorPortNumber $_.TargetPortal.Address $_.TargetPortal.Port
        if ($LASTEXITCODE -ne 0) { throw "Stored login removal failed. Stop before disconnecting sessions." }
    }
iscsicli ListPersistentTargets
if ($LASTEXITCODE -ne 0) { throw "Stored login verification failed. Stop before disconnecting sessions." }
#EndRunCommand
```

**Verify**: Total of 0 persistent targets.
**Fallback**: If not zero, retry 2a once. If removal fails or the listing still shows entries, stop and escalate.

#### 2b. Remove the sessions

```powershell
#StartRunCommand
# Diagnoses: Symptom #3 / Cause #2 - removes every iSCSI session
# Source: https://learn.microsoft.com/en-us/powershell/module/iscsi/disconnect-iscsitarget
Get-IscsiSession -ErrorAction Stop | ForEach-Object {
    Disconnect-IscsiTarget -SessionIdentifier $_.SessionIdentifier -Confirm:$false -ErrorAction Stop
}
Get-IscsiSession -ErrorAction Stop
#EndRunCommand
```

**Verify**: no output.
**Fallback**: If a session is still listed, log it out by identifier:

```powershell
#StartRunCommand
# Diagnoses: Symptom #3 / Cause #2 - remove the remaining session by its current identifier
# Source: iscsicli.exe built-in usage text (run: iscsicli /?)
# Source: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host
# Source: https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsisession
$sessionId = Read-Host 'Enter SessionIdentifier from the remaining Get-IscsiSession entry'
& iscsicli.exe LogoutTarget $sessionId
if ($LASTEXITCODE -ne 0) { throw 'Session logout failed. Stop before removing portals.' }
Get-IscsiSession
#EndRunCommand
```

Re-read `Get-IscsiSession` after each logout and repeat for any other listed session. If a session remains after retrying its current identifier, stop and escalate before 2c.

#### 2c. Remove the target portals

```powershell
#StartRunCommand
# Diagnoses: Symptom #2 / Cause #1 - removes every iSCSI target portal
# Source: https://learn.microsoft.com/en-us/powershell/module/iscsi/remove-iscsitargetportal
Get-IscsiTargetPortal -ErrorAction Stop | ForEach-Object {
    Remove-IscsiTargetPortal -TargetPortalAddress $_.TargetPortalAddress `
                             -InitiatorPortalAddress $_.InitiatorPortalAddress `
                             -Confirm:$false -ErrorAction Stop
}
Get-IscsiTargetPortal -ErrorAction Stop
iscsicli ListTargetPortals
#EndRunCommand
```

**Verify**: no output from `Get-IscsiTargetPortal`, and no portals listed by `iscsicli ListTargetPortals`.
**Fallback**: If either listing still shows a portal, choose the command matching its current `iscsicli ListTargetPortals` entry. For an entry with an Initiator Name and numeric Port Number:

```powershell
#StartRunCommand
# Diagnoses: Symptom #2 / Cause #1 - remove a portal bound to an initiator
# Source: iscsicli.exe built-in usage text (run: iscsicli /?)
# Source: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host
$address = Read-Host 'Address'
$socket = Read-Host 'Socket'
$initiatorName = Read-Host 'Initiator Name'
$portNumber = Read-Host 'Port Number'
& iscsicli.exe RemoveTargetPortal $address $socket $initiatorName $portNumber
if ($LASTEXITCODE -ne 0) { throw 'Portal removal failed. Stop before retrying node configuration.' }
#EndRunCommand
```

For an entry with a blank Initiator Name and Port Number of `<Any Port>`, use only its Address and Socket:

```powershell
#StartRunCommand
# Diagnoses: Symptom #2 / Cause #1 - remove a portal with no initiator binding
# Source: iscsicli.exe built-in usage text (run: iscsicli /?)
# Source: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host
$address = Read-Host 'Address'
$socket = Read-Host 'Socket'
& iscsicli.exe RemoveTargetPortal $address $socket
if ($LASTEXITCODE -ne 0) { throw 'Portal removal failed. Stop before retrying node configuration.' }
#EndRunCommand
```

Read the listing immediately before you use it; the port index is system-assigned and a value copied from earlier output can silently fail to match. After each removal, re-list both views:

```powershell
#StartRunCommand
# Diagnoses: Symptom #2 / Cause #1 - verify portal removal before proceeding
# Source: https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsitargetportal
# Source: iscsicli.exe built-in usage text (run: iscsicli /?)
Get-IscsiTargetPortal
iscsicli ListTargetPortals
#EndRunCommand
```

Repeat for any other listed portal using its current values. If the same portal remains after one retry, stop and escalate; do not re-run node configuration until both listings are empty.

### Mitigation Step 3: Verify clean, then re-run node configuration

All four listings must be empty. The last two are not visible to the cmdlets above them.

```powershell
#StartRunCommand
# Source: https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsisession
Get-IscsiSession
Get-IscsiTargetPortal
iscsicli ListPersistentTargets
iscsicli ListTargetPortals
#EndRunCommand
```

**Verify**: the two cmdlets return nothing, `ListPersistentTargets` reports 0 targets, and `ListTargetPortals` lists no portals.

Then re-run node configuration on this node through the same path that ran it before.

Success: node configuration proceeds past the iSCSI step. Re-run the session and connection checks in Section 4: for every discovered target, each configured initiator-address/target-portal pair has one connected, persistent session on that path, with no unexpected paths. If a path is missing or extra, do not declare recovery.

### If the above doesn't work

| What you see | Do this |
|---|---|
| Error #1 still occurs | Portal genuinely unreachable; the reset does not affect this. Check the storage network path and portal address with the storage administrator. |
| Error #2 persists after a clean reset | The node discovered no targets. Have the storage administrator check target access for this node's initiator IQN and configured portals; verify host portal-to-initiator bindings before assigning a cause. |
| A session or portal is still listed after removal | Use current listing values for each remaining entry. If the same entry remains after one retry, stop and escalate with the file from Step 1. If a stored login remains, stop at 2a instead. |
| Paths or portals return after a reboot | Capture the four listings from Step 3 and escalate with the file from Step 1; do not repeat the reset or node configuration without rechecking the safety gates. |
| `The session cannot be logged out since a device on that session is currently being used` | Something is holding the LUNs. Re-check Section 6, wait for the storage stack to settle, run 2b again. Do not force it on a node serving storage. |

### Command-to-Symptom Mapping (required)

| Step | Command | Resolves | Source |
|---|---|---|---|
| Precheck | `Get-Disk` / `Get-IscsiSession` | Symptom #1 / Cause #2 | https://learn.microsoft.com/en-us/powershell/module/storage/get-disk; https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsisession |
| 1 | `Get-IscsiSession` / `Get-IscsiTargetPortal` | Symptom #2 / Cause #1 | https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsisession; https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsitargetportal |
| 1 | `Get-IscsiConnection` | Symptom #2 / Cause #2 | https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsiconnection |
| 1 | `iscsicli ListPersistentTargets` / `ListTargetPortals` | Symptom #3 / Cause #3 | iscsicli.exe built-in usage text |
| 2a | `Get-CimInstance` | Symptom #3 / Cause #3 | https://learn.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance |
| 2a | `iscsicli RemovePersistentTarget` | Symptom #3 / Cause #3 | iscsicli.exe built-in usage text |
| 2a | `iscsicli ListPersistentTargets` | Symptom #3 / Cause #3 | iscsicli.exe built-in usage text |
| 2b | `Disconnect-IscsiTarget` | Symptom #3 / Cause #2 | https://learn.microsoft.com/en-us/powershell/module/iscsi/disconnect-iscsitarget |
| 2b | `iscsicli LogoutTarget` | Symptom #3 / Cause #2 | iscsicli.exe built-in usage text |
| 2b/2c | `Read-Host` | Symptom #3 / Cause #2; Symptom #2 / Cause #1 | https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host |
| 2c | `Remove-IscsiTargetPortal` | Symptom #2 / Cause #1 | https://learn.microsoft.com/en-us/powershell/module/iscsi/remove-iscsitargetportal |
| 2c | `iscsicli ListTargetPortals` | Symptom #2 / Cause #1 | iscsicli.exe built-in usage text |
| 2c | `iscsicli RemoveTargetPortal` | Symptom #2 / Cause #1 | iscsicli.exe built-in usage text |
| 3 | `Get-IscsiSession` | Symptom #1 / Symptom #2 | https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsisession |
| 3 | `Get-IscsiTargetPortal` / `iscsicli ListPersistentTargets` / `ListTargetPortals` | Symptom #2 / Symptom #3 | https://learn.microsoft.com/en-us/powershell/module/iscsi/get-iscsitargetportal; iscsicli.exe built-in usage text |