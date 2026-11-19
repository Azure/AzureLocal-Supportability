# Overview
Update of the Azure Local cluster may fail due to ARB VM goes offline unexpected by the orchestration sequence. The following update error message may be used to identify and match the issue. 

You may also use this TSG to preemptively detect and mitigate the issue before starting an update. 

**Example error message:**

 (The following example applies to all versions of Azure Local, note the part "[ResourceBridge Status = Offline]")
```
Type 'UpdateArbAndExtensions' of Role 'MocArb' raised an exception:

[UpgradeArbAndExtensions :VMSS extension upgrade] Get-ArcHciMgmt returned components that are in failure state before upgrading VMSS extension. Failed component status checks [ResourceBridge Status  = Offline]
```
(The following example applies to Update version 2510 and later)
```
Type 'EnsureArbVmResourceState' of Role 'MocArb' raised an exception:
 
A positional parameter cannot be found that accepts argument '...'.
```
---

# Cause
The ARB may go Offline for many reasons, including a known issue related to CAU orchestration. Except when during the actual ARB VM update, we expect the ARB VM resource to usually always be available. 

---

# Validation
Validate that the ARB VM resource is indeed Offline by running the following script:
```powershell
Get-ClusterGroup -Name "*control-plan*"
```
If the resource state is Offline, you may attempt the following mitigation. Otherwise, please contact Microsoft support. 

---

# Mitigation Steps 
The mitigation will simply try to start the ARB VM resource.

```powershell
Get-ClusterGroup -Name "*control-plan*" | Start-ClusterGroup
# Check the resource state again
Get-ClusterGroup -Name "*control-plan*"
```

Then retry the update.

---

If the update failure persists after mitigation attempt, please contact Microsoft support.

---
