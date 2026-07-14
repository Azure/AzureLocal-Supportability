# TSG | 2505-2604 | Get-SolutionUpdate fails intermittently with NullReferenceException

On Azure Local builds **2505 through 2604**, `Get-SolutionUpdate` (or `Get-SolutionUpdateEnvironment`) can intermittently fail with a `NullReferenceException` during or shortly after a solution update. The failure is transient: retrying the same command usually succeeds. This is fixed in build **2605** and later.

> **Applies to builds 2505-2604 only.** If your cluster is on **2605 or later**, this article does not apply. A persistent `NullReferenceException` on a fixed build is a different problem: collect diagnostics and contact Microsoft Support.

# Symptoms

`Get-SolutionUpdate` or `Get-SolutionUpdateEnvironment` returns:

```
Get-SolutionUpdateEnvironment : Object reference not set to an instance of an object.
    + CategoryInfo          : NotSpecified: (:) [Get-SolutionUpdateEnvironment], NullReferenceException
    + FullyQualifiedErrorId : System.NullReferenceException,Microsoft.AzureStack.Lcm.PowerShell.GetSolutionUpdateEnvironmentCmdlet
```

Characteristics:

- It appears **during or shortly after** a solution update (for example, while checking update status).
- It is **intermittent**: running the same cmdlet again a short time later often returns a normal result.
- The update itself keeps making progress. It is the status cmdlet that fails, not the update.

# Issue Validation

This article applies when **all** of the following are true:

1. The cluster is on a build in the range **2505-2604** (23H2 `11.25xx`-`11.26xx`, or 24H2 `12.25xx`-`12.26xx`). Confirm the current version from the Azure portal (your Azure Local instance -> **Updates**), or from `Get-SolutionUpdate | ft Version, State` once the cmdlet returns.
2. The error above comes from `Get-SolutionUpdate` or `Get-SolutionUpdateEnvironment`.
3. It occurs during or around a solution update.
4. It is **intermittent**: a retry often succeeds.

If the cmdlet instead **hangs or times out** (unresponsive for a long time, eventually a GatewayTimeout) rather than returning the error above, see [Get-SolutionUpdate GatewayTimeout](./Get-SolutionUpdate-GatewayTimeout.md).

# Cause

Under high concurrent request load (for example, frequent update-status polling combined with retrying or failed action plans), an internal timing issue in the Update Service can cause a request to the Orchestrator service to fail momentarily. The Update Service does not handle that failed response gracefully and surfaces a `NullReferenceException`. Because the condition is a transient timing issue, the same command normally succeeds when retried. The issue is resolved in build **2605** and later.

# Mitigation Details

## Step 1 - Retry (resolves most cases)

Re-run the cmdlet. Because the failure is transient, it usually succeeds within a few attempts, and an in-progress update continues normally once the cmdlet returns.

```powershell
Get-SolutionUpdate | ft Version, State, UpdateStateProperties
```

## Step 2 - If it does not clear

If `Get-SolutionUpdate` keeps failing after several retries over a few minutes, or the update appears **stalled** (its state is not advancing), stop retrying. This may be a different issue (for example, an unresponsive Update Service or an unhealthy Orchestrator service), not the transient condition described here.

- If the cmdlet is **hanging or timing out** rather than throwing the error above, follow [Get-SolutionUpdate GatewayTimeout](./Get-SolutionUpdate-GatewayTimeout.md).
- Otherwise, collect diagnostics and contact Microsoft Support. Run `Send-DiagnosticData` from any Azure Local machine to upload logs before opening the case; for the current steps, see [Collect diagnostic logs](https://learn.microsoft.com/azure/azure-local/manage/collect-logs).

```powershell
Send-DiagnosticData
```

## Permanent resolution - update to 2605 or later

The timing issue is fixed in build **2605**. Once 2605 or later is offered on your update train, moving to it removes the condition entirely. You do **not** need to start an update solely to work around this issue: if a retry already unblocked you, the fix will arrive through the normal update path.
