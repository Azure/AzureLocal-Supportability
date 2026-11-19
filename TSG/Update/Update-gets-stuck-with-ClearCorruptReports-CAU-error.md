# Overview
In the course of updating a Azure Local cluster running you may run into the following error: 

`"A parameter cannot be found that matches parameter name 'ClearCorruptReports'"`. 

Note that this error may be encountered while running pre-update health checks (i.e. during `'CauPreHealthCheck'` step) or after the completion of update run while validating the end result (during the `'EvalCauRetryApplicability'` step). 

As long as the error string indicates a failure to find parameter called ClearCorruptReports, this document is applicable.

# Symptoms
While attempting to update your cluster, you may run into this issue and fail with an error message similar to the one described in this documentation. Once you hit this issue, the subsequent retry attempts will all result in the same error and update may get stuck in either of `CauPreHealthCheck` or `EvalCauRetryApplicability` steps since both of these steps will try to use the `Invoke-CauRun ForceRecovery` cmdlet with the `ClearCorruptReports` option and that will keep failing. The error string in either of the cases will be as follows:

- `Type 'CauPreHealthCheck' of Role 'CAU' raised an exception: A parameter cannot be found that matches parameter name 'ClearCorruptReports'. at CauPreHealthCheck, C:\NugetStore\Microsoft.AS.CAU.10.2506.1.2\content\Classes\CAU\CAU.psm1: line 195 at , C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2506.0.989\content\ECEWinService\InvokeInterfaceInternal.psm1: line 163` 

- `Type 'EvalCauRetryApplicability' of Role 'CAU' raised an exception: EvalCauRetryApplicability action plan failure. A parameter cannot be found that matches parameter name 'ClearCorruptReports'. Stack Trace: at EvalCauRetryApplicability, C:\NugetStore\Microsoft.AS.CAU.10.2506.1.2\content\Classes\CAU\CAU.psm1: line 1301 at <ScriptBlock>, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2505.0.953\content\ECEWinService\InvokeInterfaceInternal.psm1: line 157`

# Issue Validation
Any indication about the ClearCorruptReports not being present is enough signal to safely confirm that it is the same issue and the following mitigation can be applied.

# Cause
In ECE CAU action plan, the CauPreHealthCheck and EvalCauRetryApplicability interfaces check if currently there is any state that needs to be cleared. We do this by running `Get-CauRun` cmdlet, and if it returns RunFailed then action plan will try to run the ForceRecovery. We have recently shipped an improvement in this step which utilizes a newly added parameter, ClearCorruptReports for additional cleanup.

However, the parameter ClearCorruptReports is available in the CAU engine only on 24H2+ OS builds, and the fix mentioned above does not check for OS version. So, a system which is running OS version 23H2 or below trying to run the ForceRecovery with ClearCorruptReports option will always hit this error.

# Mitigation Details
The only mitigation is to manually reset the CAU state by running the force recovery in powershell.
1. Confirm all the nodes are UP, and then run the following cmdlet from any of the cluster nodes `Invoke-CauRun -ForceRecovery -Force`
2. Once this cmdlet completes successfully, confirm the state was reset by running `Get-CauRun` and ensure the return value is `RunNotInProgress`
3. Retry the update.
