Azure Stack HCI cluster updates may fail pre-checks due to an invalid or inactive subscription/registration status.

# Symptoms

*   Portal or Windows Admin Center Update UI shows an error:
    > **The update identified 1 error(s) that you are required to address before restarting the update**
    
*   Precheck error indicates / Cluster update failure: 
    > **Failed precheck: HCI cluster and node registration validity failed due to Azure Stack HCI Subscription Status not in expected status Active**
    
    

# Issue Validation

To confirm this scenario, check for any of these:

1. **Run:**

   ```powershell
   Get-AzureStackHCI
   ```

   Verify **ConnectionStatus** = `RepairRegistrationRequired`.

2. **Check Admin Events:**

   ```powershell
   Get-WinEvent "Microsoft-AzureStack-Hci/Admin"
   ```

   Look for **Error Event ID 591**.

3.  **Check Azure Portal Status**: Review your cluster resource in the Azure Portal or Windows Admin Center. Look for any errors or warning banners indicating the cluster is disconnected or its `subscription status` is inactive.

4. **Azure Stack HCI Registration Status Check**
    ```powershell
    $status   = (Get-AzureStackHCI).ConnectionStatus
    $event591 = Get-WinEvent -LogName 'Microsoft-AzureStack-Hci/Admin' -Oldest | Where-Object Id -eq 591

    if ($status -eq 'RepairRegistrationRequired' -and $event591) {
        Write-Output "Status: $status; event 591 found. Repair registration is required - follow the mitigation steps."
    } elseif ($status -eq 'Connected') {
        Write-Output "Status: $status; cluster connected - no action needed."
    } else {
        Write-Output "Status: $status; event 591 not found. Try repair registration; if that fails, further investigation is required."
    }
    ```

# Cause

Updates or BIOS FW affecting SecureBoot or VBS encryption keys, the connection to Azure must be repaired.

# Mitigation Details

1. **Repair registration:**

   ```powershell
   Register-AzStackHCI -SubscriptionId "<subscription_ID>" -TenantId "<tenant_ID>" -RepairRegistration
   ```
2. **Authenticate** using the device-code or browser flow. Ensure you have **HciDeployment**/**HciRegistration** permissions.
3. **Confirm:**

   ```powershell
   Get-AzureStackHCI
   ```

   **ConnectionStatus** should now be **Connected**.
4. **Force portal sync (optional):**

   ```powershell
   Sync-AzureStackHCI
   ```
