# Test-Cluster Administrative Privileges Failure During Deployment

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr><th style="text-align:left; width: 180px;">Component</th><td><strong>EnvironmentValidator - ValidateCluster</strong></td></tr>
  <tr><th style="text-align:left; width: 180px;">Severity</th><td><strong>Critical - blocks deployment</strong></td></tr>
  <tr><th style="text-align:left;">Applicable Scenarios</th><td><strong>Deployment</strong></td></tr>
</table>

## Overview

During deployment, cluster validation may fail with an "administrative privileges" error when running `Test-Cluster` against one or more nodes. Despite the error message, this is not a permissions problem. The affected nodes were not properly rebooted after joining the domain, leaving their authentication in an incomplete state.

## Symptoms

The deployment fails during cluster validation with one of these error messages:

```
Failed to execute Test-Cluster: You do not have administrative privileges on the server <NodeName>
```

```
Access is denied
```

```
An error occurred opening cluster <NodeName>
```

## Root Cause

During the domain join phase of deployment, nodes must be rebooted for their Kerberos credentials to be fully registered in Active Directory. In some deployments, one or more nodes are not rebooted after domain join. When cluster validation later runs `Test-Cluster`, it cannot authenticate to those nodes using Kerberos, producing the "administrative privileges" error.

## Resolution

### Step 1: Reboot the affected node(s)

Reboot each node mentioned in the error message. Since the node's authentication state may be incomplete, remote PowerShell commands may not succeed—use the **primary path** if remoting is available, or the **fallback path** if it is not.

**Primary path (remote PowerShell):**

> [!NOTE]
> This requires that WinRM/PowerShell remoting is functional to the failing node. If the remote command fails, use the fallback path below.

```powershell
Restart-Computer -ComputerName <FailingNodeName>
```

**Fallback path (local or out-of-band):**

If remote commands fail (e.g., `Access is denied` or connection errors), reboot the node using one of these alternatives:

- **Locally on the node:** Log in to the node directly (console or RDP) and run:
  ```powershell
  Restart-Computer
  ```
- **Out-of-band management:** Use the node's hardware management interface (iLO, iDRAC, or Hyper-V console) to initiate a graceful reboot.

Wait 2-3 minutes for the reboot to complete.

### Step 2: Confirm the reboot resolved the issue

From another node, verify you can connect to the rebooted node:

```powershell
Invoke-Command -ComputerName <FailingNodeName> -ScriptBlock { whoami }
```

If this returns a username successfully, the issue is resolved. If this command fails, the node may still be rebooting—wait an additional 1-2 minutes and retry.

### Step 3: Resume deployment

Resume the deployment from the Azure portal by navigating to the deployment and selecting **Resume** or **Retry**.

You can also verify cluster validation manually before resuming:

```powershell
Test-Cluster -Node <Node1>, <Node2>
```

This should now succeed without "administrative privileges" errors.

## Prevention

This issue is being addressed in an upcoming release.
