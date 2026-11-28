<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v2",
  "document_type": "troubleshoot",
  "products": ["Azure Local", "Azure Local VMs", "AKS enabled by Azure Arc"],
  "detector": {"type": "command", "signal": "Test-SupportAksArcKnownIssues"}
}
-->

# Support.AksArc Module Troubleshooting Guide

The Support.AksArc PowerShell module provides diagnostic and remediation capabilities for Azure Kubernetes Service on Azure Arc environments.

It checks the infrastructure that Azure Local VMs and AKS enabled by Azure Arc run on, mostly Microsoft On-Premises Cloud (MOC). MOC is the Azure Local service layer that creates and manages those VMs and their disks, networks, and images. The module can fix many of the known issues it finds.

## Table of contents

- [Symptoms](#symptoms)
- [Where these problems appear](#where-these-problems-appear)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Commands](#commands)
- [Support](#support)

## Symptoms

Use this guide on Azure Local 2311.2 or later when you see any of these problems:

- Azure Local VM or AKS Arc operations fail, for example creating, changing, or deleting a VM.
- A solution update fails in the MOC binaries stage or in the Azure Arc resource bridge stage.
- The MOC service doesn't stay online.
- Azure Arc resource bridge, the appliance that lets Azure manage your VMs, is offline.

**Severity:** depends on the failing test. A failed test can block Azure Local VM and AKS Arc operations or a solution update. The module checks the MOC infrastructure only; it doesn't check hardware, storage, or network faults.

**Who runs it:** an Azure Local administrator. If the module doesn't fix the problem, contact Microsoft Support.

## Where these problems appear

| Admin surface | Status | What you see |
| --- | --- | --- |
| PowerShell on an Azure Local machine | Shown | `Test-SupportAksArcKnownIssues` lists each test with its status and a message. This is the only place the module reports its results. |
| Azure portal | Not evident | The module's results don't appear in the portal, and the system health check on the **Updates** page doesn't run these tests, so a passing health check doesn't rule out these problems. You may only see their effects, such as a failed solution update or an Azure Arc resource bridge whose status is **Offline**. |
| Windows Failover Cluster Manager | Shown | For one test only: `Validate MOC Cloud Agent Running` fails when the `MOC Cloud Agent Service` resource in the MOC cloud agent role isn't **Online**, which Failover Cluster Manager shows under **Roles**. Other test results don't appear there. |
| Windows event logs | Not evident | The module doesn't write its results to any Windows event log. |
| Cluster logs (Get-ClusterLog) | Not evident | The module doesn't write its results to the cluster log. |
| Windows Admin Center (standalone host) | Not evident | Windows Admin Center doesn't run these tests or show their results. The problems don't raise a Health Service fault, so its alerts don't list them. |
| Windows Admin Center in the Azure portal | Not evident | Windows Admin Center in the Azure portal doesn't run these tests or show their results. The problems don't raise a Health Service fault, so its alerts don't list them. |
| Component / tool log files (on disk) | Not evident | The module doesn't write a log file. To keep a record, start a transcript as shown in [Support](#support). |

## Prerequisites

- Azure Local 2311.2 or later, with the Moc PowerShell module that Azure Local installs on every machine.
- Sign in directly to one machine of your Azure Local instance, at the console or with Remote Desktop, using your deployment user account or another account that is an administrator on every machine. Open Windows PowerShell as Administrator.
- Run every command in this guide in Windows PowerShell 5.1 (`powershell.exe`), not in PowerShell 7 (`pwsh.exe`), which newer Azure Local machines also have. The module doesn't work correctly in PowerShell 7: the test reports a Failover Cluster service failure that isn't real. To check which one you're in, run `$PSVersionTable.PSEdition`. It must return `Desktop`; `Core` means PowerShell 7.
- Don't run the module in a remote PowerShell session, such as `Enter-PSSession` or `Invoke-Command`. The test uses PowerShell remoting from the machine you're signed in to, to reach every machine in the instance that is Up. In a remote session, that machine usually can't pass your sign-in on to the other machines, so the test can't reach them and doesn't run.
- PowerShell remoting (WinRM) must work from that machine to every machine in the instance that is Up. `Get-ClusterNode` shows the state of each machine.
- Access to the PowerShell Gallery, directly or through your proxy. You need it to install the module, and each time the module loads it checks the gallery for a newer version.
- Paste or run each block whole, not line by line. Text that arrives as keystrokes, for example from a right-click paste in the console window or a paste over SSH, can run one statement at a time, so a check that fails doesn't stop the statements after it. Each block that has more than one statement is wrapped in `. { ... }` so that it runs as one unit, and the values it saves stay in the window for the next step.

## Installation

**Changes:** installs the Support.AksArc module from the PowerShell Gallery and loads it into the current PowerShell session. It doesn't change Azure Local, MOC, or your workloads.

```powershell
. {
    Install-Module -Name Support.AksArc
    Import-Module Support.AksArc
}
```

`Install-Module` asks you to confirm installing from the PSGallery repository, which isn't trusted by default, and to accept the module license. Answer Yes to both. When the module loads, it shows a disclaimer that starts with `THE SOFTWARE IS PROVIDED "AS IS"` and then prints `Checking if you are on the latest version`. It can also show a warning that some commands from the module `Common` use unapproved verbs. These are expected.

If the module was already installed, update it before you use it, so that you run the current tests:

**Changes:** replaces the installed Support.AksArc module with the newest version from the PowerShell Gallery and reloads it.

```powershell
. {
    Remove-Module -Name Support.AksArc -ErrorAction SilentlyContinue
    Update-Module -Name Support.AksArc
    Import-Module -Name Support.AksArc
}
```

## Commands 

### Test for known issues

Run this command to check if your cluster is running into any of the known issues.

```powershell
Test-SupportAksArcKnownIssues

```

The test takes about a minute on a three-machine instance. Version 1.3.164 of the module runs 23 tests. They check, on every machine that is Up:

- the Failover Cluster and Hyper-V Virtual Machine Management services;
- the MOC cloud agent, node agent, and host agent services, and whether MOC is on the latest patch of its version;
- MOC certificates and tokens, MOC PowerShell settings, and the cloud agent placement rule;
- whether the MOC machines match the cluster machines and are active;
- VMs and gallery images that failed to delete, and the user storage containers;
- the Windows Event Log service.

It only reports what it finds. It doesn't fix anything. Most tests skip machines that are Down or Paused. The Failover Cluster and Hyper-V Virtual Machine Management service tests check every machine in the cluster, so a machine that is Down makes the Failover Cluster test fail and stops the run with the `Critical Test` error. Bring that machine back Up, or find out why it's Down, before you act on the results. While it runs, it also prints many `VERBOSE:` progress lines. They're expected.

The output ends with a summary line, followed by a table that lists each test with its `TestName`, its `Status`, and a `Message`. For example output, see [Use the Support tool to troubleshoot and fix Azure Local infrastructure problems](https://learn.microsoft.com/azure/azure-local/manage/remediate-support-tool-infrastructure). Use this table to decide what to do next:

| What you see | What it means | What to do |
| --- | --- | --- |
| The summary `All tests passed successfully.`, and every test in the table shows `Passed` | The module found no known issue. | Don't run the remediation command. If you still have a problem, see [Support](#support). |
| The summary `Some tests failed. Run Invoke-SupportAksArcRemediation to remediate issues.`, and one or more tests in the table show `Failed` or `Error` | The module found a known issue, or a test couldn't finish. | Run the remediation command in the next section. |
| No table, and the error `Critical Test Failover Cluster service not responsive or not running failed: Failover Cluster service is not running on node: <machine>. Exception: A parameter cannot be found that matches parameter name 'ComputerName'.` | You ran the test in PowerShell 7. The result isn't valid. | Don't run the remediation command. Open Windows PowerShell 5.1 as described in [Prerequisites](#prerequisites), and run the test again. |
| No table, and any other error `Critical Test <test name> failed: <message>` | A critical check failed. The module stops, because the later results can't be trusted. | Run the remediation command in the next section. |
| The error `Please ensure you are running this script directly on the host and not over remote powershell` | The module couldn't reach every machine that is Up over PowerShell remoting. It ran no tests. | Don't run the remediation command. Sign in directly to a machine as described in [Prerequisites](#prerequisites). If you already did, fix PowerShell remoting to the machine named in the error `Remote PowerShell is not available on node: <machine>`, and then run the test again. |
| The summary `Tests completed with warnings. Review warning details before remediation.`, and the tests in the table show only `Passed` or `Warning` | The module found a condition to review, such as no isolated user storage container. | Read the `Message` of each `Warning` test and follow it. The remediation command doesn't change anything for a warning. |

### Test for issues with remediation

Run this only when the test above reported a `Failed` or `Error` test, or the `Critical Test` error. Don't run it while a solution update is in progress, or when one is scheduled to start before you finish. First check the solution updates, then check whether the module's fix would remove VMs, and then run the block that fixes the failed tests. The block never removes VMs. On a three-machine instance with one failed test, it took about 75 seconds; the time depends on the fixes it applies.

**Changes:** depending on the failing test, the fix can:

- update MOC to the latest patch of its current version;
- stop and start the MOC cloud agent role and the MOC node agent and host agent services on every machine, and renew MOC identities and certificates;
- delete stale MOC working folders, and reset MOC PowerShell settings to the standard Azure Local values;
- re-create the MOC PowerShell registry setting or the cloud agent cluster affinity rule `Cloud Agent-CNO`;
- start the Windows Event Log service;
- remove gallery images that failed to delete.

It doesn't restart the Failover Cluster service or the Hyper-V Virtual Machine Management service. The module's fix for the test `Validate Virtual Machine Stuck In Deleting Due To OS Disk Lock` stops and removes VMs. The block below never runs it; it runs only from [If the fix would remove VMs](#if-the-fix-would-remove-vms), after the owner of the VMs approves.

**Plan for:** Azure Local VM and AKS Arc management operations, such as creating, changing, or deleting a VM, can fail while MOC agents restart or MOC updates. The fixes work on the MOC infrastructure, not on running VMs. Machines that are Down or Paused aren't fixed. Run the block in a maintenance window.

> [!WARNING]
> **[HIGH RISK]** The module doesn't undo its fixes, and there is no rollback. An MOC update, renewed MOC identities and certificates, and deleted MOC working folders stay as they are. If you aren't sure the failed tests are the problem you're troubleshooting, contact Microsoft Support before you run the block.

First, check that no solution update is in progress or scheduled to start while you work. A solution update also updates MOC, and while that runs, the module's test `Validate MOC Powershell Not Stuck in Updating` reports MOC as stuck. Its fix deletes MOC working folders and marks the MOC update as failed, and the fix for `Validate MOC is on Latest Patch Version` starts an MOC update of its own. This check reads the state of each solution update and each update schedule, and changes nothing:

```powershell
try {
    $updates = @(Get-SolutionUpdate -ErrorAction Stop)
    $running = @($updates | Where-Object { [string]$_.State -in 'Downloading', 'Preparing', 'HealthChecking', 'Installing' })
    $scheduled = @($updates | Where-Object { [string]$_.State -eq 'ScheduledToInstall' })
    $schedules = @()
    if (Get-Command Get-SolutionUpdateSchedule -ErrorAction SilentlyContinue) {
        $schedules = @(Get-SolutionUpdateSchedule -ErrorAction Stop | Where-Object { [string]$_.State -in 'Pending', 'Triggering' })
    }
    $starting = @($schedules | Where-Object { [string]$_.State -eq 'Triggering' })
    if ($running.Count -gt 0 -or $starting.Count -gt 0) {
        'UPDATE-IN-PROGRESS'
        $running | ForEach-Object { "Update $($_.DisplayName) $($_.Version) is $($_.State)" }
        $starting | ForEach-Object { "Update $($_.Target.UpdateName) is starting from its schedule" }
    }
    elseif ($scheduled.Count -gt 0 -or $schedules.Count -gt 0) {
        'UPDATE-SCHEDULED'
        $scheduled | ForEach-Object { "Update $($_.DisplayName) $($_.Version) is $($_.State)" }
        $schedules | ForEach-Object {
            $startUtc = [DateTime]$_.StartTimeUtc
            if ($startUtc.Kind -eq 'Local') { $startUtc = $startUtc.ToUniversalTime() } else { $startUtc = [DateTime]::SpecifyKind($startUtc, 'Utc') }
            "Update $($_.Target.UpdateName) starts at $($startUtc.ToString('yyyy-MM-dd HH:mm')) UTC ($($startUtc.ToLocalTime().ToString('yyyy-MM-dd HH:mm')) local time)"
        }
    }
    else { 'NO-UPDATE-IN-PROGRESS' }
} catch { "UPDATE-CHECK-ERROR: $($_.Exception.Message)" }
```

- `NO-UPDATE-IN-PROGRESS`: no solution update is running or scheduled. Continue with the next check.
- `UPDATE-SCHEDULED`: a solution update is scheduled, and it starts by itself at its start time without anyone running a command. The lines after it name the update and its start time. If it would start before you finish everything in this section, including the owner's review and the command in [If the fix would remove VMs](#if-the-fix-would-remove-vms), don't run anything else in this section. Wait until the update finishes or fails, and then run the test in [Test for known issues](#test-for-known-issues) again. Continue with the next check only if the start time leaves enough time to finish.
- `UPDATE-IN-PROGRESS`: the lines after it name the update and its state. Don't run anything else in this section. Wait until the update finishes or fails, and then run the test in [Test for known issues](#test-for-known-issues) again: a result from while the update ran, such as `Validate MOC Powershell Not Stuck in Updating` failing, can be wrong.
- `UPDATE-CHECK-ERROR`: the state of the solution updates or their schedules couldn't be read. Don't run anything else in this section. Run this check again in a few minutes. If it keeps failing, contact Microsoft Support.

Then check whether the module's fix would remove VMs. This check runs only that test and changes nothing:

```powershell
. {
    $vmTest = @(Test-SupportAksArcKnownIssues -TestId MOC-0017)
    if ($vmTest.Count -eq 0) { 'TEST-DID-NOT-RUN' }
    elseif (@($vmTest | Where-Object { $_.Status -in 'Failed', 'Error' }).Count -gt 0) { 'VM-REMOVAL-PENDING'; $vmTest | Format-List TestName, Status, Message }
    else { 'NO-VM-REMOVAL' }
}
```

- `NO-VM-REMOVAL`: the fix would remove no VMs. Run the block below.
- `VM-REMOVAL-PENDING`: the module's fix would stop and remove the VMs that the message lists, and any other VM whose name contains one of those names. Run the block below, which fixes every other failed test and never removes VMs, and follow [If the fix would remove VMs](#if-the-fix-would-remove-vms) for the VM removal.
- `TEST-DID-NOT-RUN`: the test ran no checks. Use the results table above to find out why.

Run this block after the solution update check printed `NO-UPDATE-IN-PROGRESS`, or `UPDATE-SCHEDULED` with a start time after the block will finish, whatever the VM removal check printed. It fixes every failed test except `Validate Virtual Machine Stuck In Deleting Due To OS Disk Lock`, which removes VMs and is left to [If the fix would remove VMs](#if-the-fix-would-remove-vms). It runs the test and reads each test's ID from its `Running test: <test name> with ID: <ID>` line. Then it runs the remediation for each test that failed, had an error, or stopped the run as a critical test, except `MOC-0017`. A critical test that fails stops the test run, so the tests after it don't run. After the block fixes that test, it runs the test again, for at most 4 passes. While it runs, it prints:

- `REMEDIATION-PASS <n>` at the start of each pass;
- `CRITICAL-STOP <ID>` if a critical test stopped that pass;
- `REMEDIATE <ID>` before each fix;
- `SKIPPED MOC-0017` if it left that test alone;
- `NO-FAILED-TESTS` if the pass found no test to fix.

For each fix, the module prints either `No remediation required for <test>.`, or `Remediation for <test> is required.` and then `Remediation for <test> succeeded.` or the warning `Remediation for <test> failed.` Two tests have no automatic fix; see [If a test has no automatic fix](#if-a-test-has-no-automatic-fix).

Its last line is one of these results:

- `REMEDIATION-PASSES-DONE Passes=<n>`: the last pass ran every test, and the block ran the fixes. Continue with [If a test has no automatic fix](#if-a-test-has-no-automatic-fix).
- `CRITICAL-STOP-NO-AUTOFIX FC-0011`: the Failover Cluster test stopped the run. It has no automatic fix, so the block fixed nothing. Continue with [If a test has no automatic fix](#if-a-test-has-no-automatic-fix) to bring the machine back first, and then run this block again.
- `CRITICAL-STOP-REPEATED <ID>`: the same critical test stopped two passes in a row, so its fix didn't work. Don't run the block again. Contact Microsoft Support.
- `REMEDIATION-PASS-LIMIT <ID>`: a critical test still stopped the run after 4 passes. Contact Microsoft Support.
- `TEST-DID-NOT-RUN`: the test ran no checks. Use the results table above to find out why.
- `REMEDIATION-ERROR`: the test or a fix stopped with the error shown. Fix the reason shown, and run the block again. If the same error comes back, contact Microsoft Support.

**Changes:** applies the fixes listed above for the failed tests only, one test at a time. It never runs the fix that removes VMs, but it can still update MOC and restart MOC agents.

**Paste or run the whole block at once, not line by line.** It runs as one unit, so if the window isn't Windows PowerShell 5.1, the block stops before it fixes anything.

```powershell
. {
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run this command in Windows PowerShell 5.1 (powershell.exe), not PowerShell 7.' }
    $final = $null; $lastStop = $null; $pass = 0
    try {
        while (-not $final) {
            if ($pass -ge 4) { $final = "REMEDIATION-PASS-LIMIT $lastStop"; break }
            $pass++
            "REMEDIATION-PASS $pass"
            $info = $null
            $results = @(Test-SupportAksArcKnownIssues -InformationVariable info)
            $ids = @($info | ForEach-Object { [regex]::Match([string]$_.MessageData, '^Running test: .+ with ID: ((MOC|FC|VMMS)-\d{4})$') } | Where-Object { $_.Success } | ForEach-Object { $_.Groups[1].Value })
            if ($ids.Count -eq 0) { $final = 'TEST-DID-NOT-RUN'; break }
            $stop = $null
            if ($results.Count -lt $ids.Count) { $stop = $ids[$ids.Count - 1]; "CRITICAL-STOP $stop" }
            if ($stop -eq 'FC-0011') { $final = 'CRITICAL-STOP-NO-AUTOFIX FC-0011'; break }
            if ($stop -and $stop -eq $lastStop) { $final = "CRITICAL-STOP-REPEATED $stop"; break }
            $failed = @(for ($i = 0; $i -lt $ids.Count; $i++) { if ($i -ge $results.Count -or $results[$i].Status -in 'Failed', 'Error') { $ids[$i] } })
            if ($failed.Count -eq 0) { 'NO-FAILED-TESTS' }
            foreach ($id in $failed) {
                if ($id -eq 'MOC-0017') { 'SKIPPED MOC-0017'; continue }
                "REMEDIATE $id"
                Invoke-SupportAksArcRemediation -TestId $id
            }
            if ($stop) { $lastStop = $stop } else { $final = "REMEDIATION-PASSES-DONE Passes=$pass" }
        }
    } catch { $final = "REMEDIATION-ERROR: $($_.Exception.Message)" }
    $final
}
```

#### If the fix would remove VMs

Run this when the VM removal check in [Test for issues with remediation](#test-for-issues-with-remediation) printed `VM-REMOVAL-PENDING`. It runs that test again and lists every cluster role and Hyper-V VM that the fix would stop and remove, matched the same way the fix matches them. It changes nothing. Its last line is `VM-LIST-COMPLETE` only if it checked every machine that is `Up`. Keep this PowerShell window open; the steps after it use the list it keeps.

```powershell
. {
    $getVmRemovalList = {
        $lines = @(); $complete = $true
        try {
            $vmTest = @(Test-SupportAksArcKnownIssues -TestId MOC-0017)
            $pending = @($vmTest | Where-Object { $_.Status -in 'Failed', 'Error' })
            $names = @($pending | ForEach-Object { $_.AffectedVMs } | ForEach-Object { $_.VMName })
            if ($vmTest.Count -eq 0) { $complete = $false; $lines += 'VM-LIST-ERROR: the test ran no checks.' }
            elseif ($pending.Count -gt 0 -and $names.Count -eq 0) { $complete = $false; $lines += 'VM-LIST-ERROR: the test result lists no VM names.' }
            foreach ($name in $names) {
                $groups = @(Get-ClusterGroup -ErrorAction Stop | Where-Object { $_.Name.Contains($name) })
                if ($groups.Count -gt 0) { $lines += @($groups | ForEach-Object { "MOC VM $name -> cluster role $($_.Name)" }) }
                else {
                    $found = 0; $notChecked = 0
                    foreach ($node in @(Get-ClusterNode -ErrorAction Stop | Where-Object { $_.State -eq 'Up' } | ForEach-Object { $_.Name })) {
                        try {
                            $vms = @(Get-VM -ComputerName $node -ErrorAction Stop | Where-Object { $_.Name -like "*$name*" })
                            $found += $vms.Count
                            $lines += @($vms | ForEach-Object { "MOC VM $name -> Hyper-V VM $($_.Name) on $node" })
                        } catch { $notChecked++; $complete = $false; $lines += "VM-LIST-ERROR: MOC VM $name -> NOT CHECKED on ${node}: $($_.Exception.Message)" }
                    }
                    if ($found -eq 0 -and $notChecked -eq 0) { $lines += "MOC VM $name -> no matching cluster role or Hyper-V VM found" }
                }
            }
        } catch { $complete = $false; $lines += "VM-LIST-ERROR: $($_.Exception.Message)" }
        [pscustomobject]@{ Complete = $complete; Lines = @($lines | Sort-Object -Unique) }
    }
    $shownVmList = & $getVmRemovalList
    $shownVmList.Lines
    if ($shownVmList.Complete -and $shownVmList.Lines.Count -eq 0) { 'NO-VM-REMOVAL-PENDING' }
    if ($shownVmList.Complete) { 'VM-LIST-COMPLETE' } else { 'VM-LIST-INCOMPLETE' }
}
```

- If it prints `NO-VM-REMOVAL-PENDING` and then `VM-LIST-COMPLETE`, the fix would now remove no VMs, and there is nothing for the owner to confirm. Continue with [Run the fix after the owner approves](#run-the-fix-after-the-owner-approves), which saves the empty list and checks it again just before the command.
- If the last line is `VM-LIST-COMPLETE` and it lists VMs, the owner reviews the list as described below.
- If the last line is `VM-LIST-INCOMPLETE`, the list is missing at least one machine: a `NOT CHECKED` line names the machine it couldn't query, or another `VM-LIST-ERROR` line shows why the check stopped. Don't run the command in [Run the fix after the owner approves](#run-the-fix-after-the-owner-approves), and don't approve removing any VM, until every machine is checked. Fix the reason shown, for example Hyper-V access to that machine, and run this check again.
- If any VM it lists isn't one you intend to remove, or you aren't sure, stop. Don't run the command in [Run the fix after the owner approves](#run-the-fix-after-the-owner-approves). Contact Microsoft Support before you remove any VM. The block in [Test for issues with remediation](#test-for-issues-with-remediation) fixes the other failed tests without removing VMs.

**Stop here and confirm.** Before anyone runs the command in [Run the fix after the owner approves](#run-the-fix-after-the-owner-approves), the owner of the VMs reviews the list this check printed and decides whether every VM on it can be removed. Done looks like: the last line is `VM-LIST-COMPLETE`, and the owner has confirmed by name that each listed VM can be removed. Then continue with [Run the fix after the owner approves](#run-the-fix-after-the-owner-approves).

##### Run the fix after the owner approves

The command matches VMs by name when it runs, so a VM created, renamed, or moved after the owner approved the list can be removed too. Save the approved list now, in the same window as the list. It saves exactly the list the owner reviewed, and changes nothing:

```powershell
. {
    $approvedVmList = $null; $vmListUnchanged = $false
    if ($null -eq $shownVmList -or $null -eq $getVmRemovalList) { 'VM-LIST-NOT-SAVED: there is no list in this window.' }
    elseif (-not $shownVmList.Complete) { 'VM-LIST-NOT-SAVED: the list is incomplete.' }
    else {
        $approvedVmList = @($shownVmList.Lines)
        $approvedVmList
        if ($approvedVmList.Count -eq 0) { 'NO-VM-REMOVAL-PENDING' }
        'VM-LIST-SAVED'
    }
}
```

- `VM-LIST-SAVED`: the lines above it are the saved list, one line per VM the command would remove. They're the list the owner approved. With `NO-VM-REMOVAL-PENDING`, the command would remove no VMs.
- `VM-LIST-NOT-SAVED`: this window has no complete list. Don't run the command. Run the check in [If the fix would remove VMs](#if-the-fix-would-remove-vms) again in this window, and get the owner's confirmation for the list it prints.

**Plan for:** between the owner's approval and the command below, don't create, rename, or migrate VMs on the instance, don't start a solution update, and don't let anyone else do so. A scheduled solution update starts by itself, so before you ask the owner, check that none would start in that time. Any of these can change which VMs the command matches or what its fixes do.

Immediately before you run the command, run the solution update check in [Test for issues with remediation](#test-for-issues-with-remediation) again. Continue only if it prints `NO-UPDATE-IN-PROGRESS`, or `UPDATE-SCHEDULED` with a start time after the command and its fixes will finish. Then run this check in the same window. It compares the VMs the command would remove now with the saved list, and changes nothing:

```powershell
. {
    $vmListUnchanged = $false
    try {
        if ($null -eq $getVmRemovalList -or $null -eq $approvedVmList) { throw 'no saved list in this window. Run the block that saves the list first.' }
        $now = & $getVmRemovalList
        $added = @($now.Lines | Where-Object { $approvedVmList -notcontains $_ })
        $gone = @($approvedVmList | Where-Object { $now.Lines -notcontains $_ })
        if (-not $now.Complete) { 'VM-LIST-RECHECK-ERROR'; $now.Lines | Where-Object { $_ -like 'VM-LIST-ERROR:*' } }
        elseif ($added.Count -gt 0 -or $gone.Count -gt 0) { 'VM-LIST-CHANGED'; $added | ForEach-Object { "NEW: $_" }; $gone | ForEach-Object { "GONE: $_" } }
        else { $vmListUnchanged = $true; 'VM-LIST-UNCHANGED' }
    } catch { "VM-LIST-RECHECK-ERROR: $($_.Exception.Message)" }
}
```

- `VM-LIST-UNCHANGED`: the command would remove exactly the approved VMs. Run the command below now, in the same window.
- `VM-LIST-CHANGED`: a `NEW` line is a VM the command would now remove that the owner didn't approve, and a `GONE` line is an approved VM it no longer matches. Don't run the command below. Run the check in [If the fix would remove VMs](#if-the-fix-would-remove-vms) again, and get a new approval.
- `VM-LIST-RECHECK-ERROR`: the check couldn't list every VM. Don't run the command below. Fix the reason shown, and run this check again.

If you don't get a new approval, don't run the command. The block in [Test for issues with remediation](#test-for-issues-with-remediation) fixes the other failed tests without removing VMs.

The command runs only right after this check printed `VM-LIST-UNCHANGED` in the same window; otherwise it stops with an error and changes nothing.

**Paste or run the whole block at once, not line by line.** It runs as one unit, so a failed check stops it before the command runs:

```powershell
. {
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run this command in Windows PowerShell 5.1 (powershell.exe), not PowerShell 7.' }
    $listChecked = $vmListUnchanged; $vmListUnchanged = $false
    if (-not $listChecked) { throw 'Run the check above first, in this window. Run this command only right after it prints VM-LIST-UNCHANGED.' }
    Invoke-SupportAksArcRemediation
}
```

It prints the results described in [Test for issues with remediation](#test-for-issues-with-remediation). Then continue with [If a test has no automatic fix](#if-a-test-has-no-automatic-fix).

### If a test has no automatic fix

The tests `Failover Cluster service not responsive or not running` (`FC-0011`) and `Virtual Machine Management service not responsive or not running` (`VMMS-0012`) have no automatic fix. For them, the remediation command prints `Auto Remediation not available. Please Restart the Node manually, which has the issue` and still reports success, but it changes nothing.

After any remediation, run this check. It runs only those two tests and changes nothing:

```powershell
. {
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run this command in Windows PowerShell 5.1 (powershell.exe), not PowerShell 7.' }
    $fcErrors = $null; $vmmsErrors = $null
    $fcRows = @(Test-SupportAksArcKnownIssues -TestId FC-0011 -ErrorVariable fcErrors)
    $vmmsRows = @(Test-SupportAksArcKnownIssues -TestId VMMS-0012 -ErrorVariable vmmsErrors)
    $critical = @(@($fcErrors) + @($vmmsErrors) | Where-Object { "$_" -match '^Critical Test ' })
    $failed = @(@($fcRows) + @($vmmsRows) | Where-Object { $_.Status -in 'Failed', 'Error' })
    if ($critical.Count -gt 0 -or $failed.Count -gt 0) { 'MANUAL-RESTART-NEEDED'; $critical | ForEach-Object { "$_" }; $failed | Format-List TestName, Status, Message }
    elseif ($fcRows.Count -eq 0 -or $vmmsRows.Count -eq 0) { 'TEST-DID-NOT-RUN' }
    else { 'NO-MANUAL-RESTART' }
}
```

- `NO-MANUAL-RESTART`: continue with [Verify the fix](#verify-the-fix).
- `MANUAL-RESTART-NEEDED`: the message names the machine. Run `Get-ClusterNode` to see its state:
  - If the machine is `Up` or `Paused`, follow [If the machine is Up or Paused](#if-the-machine-is-up-or-paused).
  - If the machine is `Down`, follow [If the machine is Down](#if-the-machine-is-down).

  Then run this check again. If it still prints `MANUAL-RESTART-NEEDED`, contact Microsoft Support.
- `TEST-DID-NOT-RUN`: at least one of the two tests ran no checks, so the check can't say that no restart is needed. Use the results table above to find out why, and then run this check again.

#### If the machine is Up or Paused

**Operator action.** An administrator restarts the machine as described in [Suspend and resume Azure Local machines for maintenance](https://learn.microsoft.com/azure/azure-local/manage/suspend-resume-cluster-maintenance): suspend and drain it, restart it, and resume it. Done looks like: `Get-ClusterNode` shows the machine `Up`, and the check above prints `NO-MANUAL-RESTART`.

**Changes:** the restart moves the machine's workloads to other machines, restarts it, and returns it to the instance. On a single-machine instance there is no other machine, so its VMs stop until the restart finishes.

**Plan for:** the instance runs with one machine fewer until the restart finishes. Restart in a maintenance window.

#### If the machine is Down

`Down` means the instance can't reach the machine's Cluster service. The machine can still be powered on and running VMs, for example when only its Cluster service stopped or it lost network communication with the other machines. Find out which before you restart anything.

1. Check whether the machine is reachable and what runs on it. Run this on any machine that is `Up` (on a single-machine instance, on that machine). It finds the machine that is `Down` itself, and stops with `CHECK-ERROR` unless exactly one machine is `Down`. It changes nothing:

   ```powershell
   try {
       $machine = $null
       try { $machine = @(Get-ClusterNode -ErrorAction Stop | Where-Object { [string]$_.State -eq 'Down' } | ForEach-Object { $_.Name }) }
       catch {
           if ([string](Get-Service -Name ClusSvc -ErrorAction Stop).Status -eq 'Running') { throw }
           $machine = @($env:COMPUTERNAME)
       }
       if ($machine.Count -ne 1) { throw "expected exactly one machine that is Down, found $($machine.Count)." }
       $machine = [string]$machine[0]
       $state = $null
       try {
           $state = Invoke-Command -ComputerName $machine -ErrorAction Stop -ScriptBlock {
               $svc = $null; $svcError = $null; $vms = $null; $vmError = $null
               try { $svc = [string](Get-Service -Name ClusSvc -ErrorAction Stop).Status } catch { $svcError = $_.Exception.Message }
               try { $vms = @(Get-VM -ErrorAction Stop | Where-Object { $_.State -ne 'Off' } | ForEach-Object { "$($_.Name) ($($_.State))" }) } catch { $vmError = $_.Exception.Message }
               [pscustomobject]@{ ClusSvc = $svc; ClusSvcError = $svcError; VMs = $vms; VMError = $vmError }
           }
       } catch { "MACHINE-NOT-REACHABLE Machine=${machine}: $($_.Exception.Message)" }
       if ($state -and ($state.ClusSvcError -or $state.VMError)) {
           "MACHINE-CHECK-INCOMPLETE Machine=$machine ClusSvc=$($state.ClusSvc) $($state.ClusSvcError) $($state.VMError)"
       }
       elseif ($state) {
           "MACHINE-REACHABLE Machine=$machine ClusSvc=$($state.ClusSvc) VMsNotOff=$(@($state.VMs).Count)"
           @($state.VMs) | ForEach-Object { "  VM: $_" }
       }
   } catch { "CHECK-ERROR: $($_.Exception.Message)" }
   ```

   - `MACHINE-REACHABLE` with `ClusSvc` other than `Running`: the machine is on, and only its Cluster service stopped. Don't restart the machine. Start the service instead, which doesn't stop its VMs: `Invoke-Command -ComputerName $machine -ScriptBlock { Start-Service -Name ClusSvc }`. Then go to step 4.
   - `MACHINE-REACHABLE` with `ClusSvc=Running`: the machine is on, but the instance can't communicate with it. Don't restart it; a restart would stop the VMs it lists. Contact Microsoft Support.
   - `MACHINE-CHECK-INCOMPLETE`: the machine is on, but its Cluster service state or its VMs couldn't be read. Don't restart it. Contact Microsoft Support.
   - `MACHINE-NOT-REACHABLE`: go to step 2.
   - `CHECK-ERROR`: the check didn't find exactly one machine that is `Down`, or the instance couldn't be queried. If no machine is `Down` now, run the check in [If a test has no automatic fix](#if-a-test-has-no-automatic-fix) again. If more than one machine is `Down`, don't restart any of them; contact Microsoft Support.

   Each result names the machine it checked in `Machine=`. Keep this PowerShell window open: the command that starts the Cluster service uses that machine.

2. Check the machine from its baseboard management controller (BMC) or at the machine. Restart it only if it's powered off or doesn't respond at all, from its console or on the network. If it's powered on and responds, don't restart it; contact Microsoft Support.

   On an instance with more than one machine, run this on a machine that is `Up` to confirm that the clustered VMs of the machine that is `Down` moved to other machines. It finds that machine the same way as step 1, and changes nothing:

   ```powershell
   try {
       $down = @(Get-ClusterNode -ErrorAction Stop | Where-Object { [string]$_.State -eq 'Down' } | ForEach-Object { [string]$_.Name })
       if ($down.Count -ne 1) { throw "expected exactly one machine that is Down, found $($down.Count)." }
       $left = @(Get-ClusterGroup -ErrorAction Stop | Where-Object { $_.OwnerNode.Name -eq $down[0] })
       if ($left.Count -eq 0) { "ROLES-MOVED Machine=$($down[0])" } else { "ROLES-NOT-MOVED Machine=$($down[0])"; $left | Format-Table Name, State }
   } catch { "FAILOVER-CHECK-ERROR: $($_.Exception.Message)" }
   ```

   Restart the machine only if this prints `ROLES-MOVED` for the machine that step 1 checked. `ROLES-NOT-MOVED` lists the roles that didn't move, and `FAILOVER-CHECK-ERROR` means the check didn't find exactly one machine that is `Down` or the instance couldn't be queried, so the check couldn't confirm that the VMs moved. In both cases, don't restart the machine. Contact Microsoft Support.

3. **Operator action.** An administrator turns on or restarts the machine from its BMC or at the machine, only after step 2 shows that it's off or unresponsive and, on an instance with more than one machine, that its VMs moved. Done looks like: step 4 prints `MACHINE-UP-OR-PAUSED`.

4. Run this on any machine that is `Up` (on a single-machine instance, on that machine), until it prints `MACHINE-UP-OR-PAUSED`. Step 1 found exactly one machine that is `Down`, so when every machine is `Up` or `Paused`, that machine is back. It changes nothing:

   ```powershell
   try {
       $nodes = @(Get-ClusterNode -ErrorAction Stop)
       if ($nodes.Count -eq 0) { throw 'the instance returned no machines.' }
       $notBack = @($nodes | Where-Object { [string]$_.State -notin 'Up', 'Paused' })
       if ($notBack.Count -eq 0) { 'MACHINE-UP-OR-PAUSED'; $nodes | Where-Object { [string]$_.State -eq 'Paused' } | ForEach-Object { "Paused: $($_.Name)" } }
       else { 'MACHINE-NOT-YET-UP'; $notBack | ForEach-Object { "$($_.State): $($_.Name)" } }
   } catch { "NODE-CHECK-ERROR: $($_.Exception.Message)" }
   ```

   - `MACHINE-UP-OR-PAUSED`: no machine is `Down`, so the machine is back in the instance. A `Paused:` line names each machine that is `Paused`. Go to step 5.
   - `MACHINE-NOT-YET-UP`: the lines after it name each machine that isn't `Up` or `Paused` yet, with its state. Wait a few minutes and run the check again. If it stays in this state, contact Microsoft Support.
   - `NODE-CHECK-ERROR`: the instance couldn't be queried yet, for example while the only machine of a single-machine instance starts. Wait a few minutes and run the check again.

5. If step 4 printed a `Paused:` line for the machine that step 1 checked, resume it with `Resume-ClusterNode -Name` followed by that machine's name.
6. Run the check in [If a test has no automatic fix](#if-a-test-has-no-automatic-fix) again.

**Changes:** starting the Cluster service returns the machine to the instance without stopping its VMs. Turning on or restarting the machine from its BMC stops anything still running on it, which is why you check first that it's off or unresponsive. On a single-machine instance, that restart stops every VM on the machine. Clustered VMs normally start again when the instance brings its roles back online; check that the VMs you need are running.

### Verify the fix

Run the test again, and list any test that failed:

```powershell
. {
    $results = @(Test-SupportAksArcKnownIssues)
    $failed = @($results | Where-Object { $_.Status -in 'Failed', 'Error' })
    $failed | Format-List TestName, Status, Message
    "Tests run: $($results.Count). Failed or error: $($failed.Count)."
}
```

The fix worked when no test is listed, no error is shown, and the last line shows `Failed or error: 0` with a test count above 0, for example `Tests run: 23. Failed or error: 0.` `Tests run: 0` means an error stopped the run. A `Warning` test isn't listed; handle it as described in the results table. If any test is listed, or an error remains, go back to [Test for issues with remediation](#test-for-issues-with-remediation) once, starting with the check for a solution update. If a test is still listed after that, see [Support](#support).


## Support
Review Azure Local  documentation or contact Microsoft Support for unresolved issues.

When you contact Microsoft Support, include the Support.AksArc module version, your Azure Local version, and the output of a new test run. This block saves all three to a file on your Desktop. If you ran the remediation command, also copy its console output into the case.

**Changes:** writes a transcript file to your Desktop. It doesn't change Azure Local.

```powershell
. {
    Start-Transcript -Path "$env:USERPROFILE\Desktop\Support-AksArc-$(Get-Date -Format yyyyMMdd-HHmmss).txt"
    Import-Module -Name Support.AksArc
    Get-Module -Name Support.AksArc | Select-Object Name, Version | Out-Host
    Get-SolutionUpdateEnvironment | Select-Object CurrentVersion | Out-Host
    Test-SupportAksArcKnownIssues | Format-List TestName, Status, Message | Out-Host
    Stop-Transcript
}
```
