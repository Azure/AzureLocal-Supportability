# Type 'UpdateArbAndExtensions' of Role 'MocArb' raised an exception. ERROR: (ApplianceResourceScopeLocked)

# Issue Summary

During Azure Local solution updates, the ARB upgrade may fail if the appliance is locked with either a `ReadOnly` or `CanNotDelete` lock. This lock prevents the update process from proceeding, triggering a `ScopeLocked` error during the `UpgradeArbAndExtensions` step.

This behavior is **distinct from previous scope lock errors**, where mitigation required complex extension handling. In the current scenario, the failure is immediate and clearly attributed to the lock, and the mitigation is straightforward: **remove the lock and retry the update**.

The error message returned during failure is:

```Powershell
[UpgradeArbAndExtensions :arcappliance upgrade] Failed with Error C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin\az.cmd arcappliance upgrade hci --config-file "C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\MocArb\WorkingDirectory\Appliance\hci-appliance.yaml" --only-show-errors returned a non empty error stream [ERROR: (ApplianceResourceScopeLocked) A ReadOnly or CanNotDelete lock exists on Microsoft.ResourceConnector/appliances/s-cluster-arcbridge, please refer to documentation on how to remove the lock before proceeding with upgrade. Documentation found here: https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/lock-resources?tabs=json#lock-inheritance]
```

# Issue Validation

To confirm that the failure you're encountering is due to a scope lock on the ARB resource, validate the following:

### Expected Behavior
- The ARB is in a `Running` state.
- The update fails during the `UpgradeArbAndExtensions` step.
- The error message includes `ApplianceResourceScopeLocked` and references a `ReadOnly` or `CanNotDelete` lock.

### Validation via Azure Portal
1. Navigate to the ARB resource in the Azure Portal.
2. Under **Settings**, select **Locks**.
3. Confirm that a lock of type `ReadOnly` or `CanNotDelete` is present.


# Cause

The failure occurs due to a scope lock applied to the ARB resource in Azure. Specifically, if a `ReadOnly` or `CanNotDelete` lock exists on the ARB, the update process is blocked during the `UpgradeArbAndExtensions` step. The ARB upgrade implementation includes a pre-check that immediately halts the update and surfaces a clear error message (`ApplianceResourceScopeLocked`). This behavior is intentional and designed to prevent partial updates or inconsistent states when locked resources cannot be modified. The lock must be removed before the update can proceed successfully.


# Mitigation Details

To resolve this issue, any lock on the ARB resource must be removed. Once the lock is cleared, the update process can be retried and will proceed successfully.

#### **1. Remove Lock via Azure Portal**
1. Navigate to the ARB resource in the Azure Portal.
2. Under **Settings**, select **Locks**.
3. Identify any `ReadOnly` or `CanNotDelete` locks.
4. To remove a lock, click the delete (trash) icon next to the lock, or select the lock and click **Delete** at the top of the page.


#### **2. Retry the update**
After removing the lock, retry the Azure Local solution update using either the Azure Portal or CLI. This will allow the update to proceed past the scope lock validation.