After installing certain updates (including BIOS), Azure Stack HCI clusters may report `RepairRegistrationRequired` and show a stale connection state.

# Symptoms

* `Get-AzureStackHCI` returns **RepairRegistrationRequired**
* Azure Portal shows **Connection status** as “Not recently connected” (>48 hrs)
* **Admin Channel Event ID 591** in the HciSvc Admin log:
  > *Azure Stack HCI failed to connect with Azure. If you continue to see this error, try running `Register-AzStackHCI` again with the `-RepairRegistration` parameter.*
* Attempting to create a new clustered role or resource fails with:
  > *Failed to create the clustered role `<ClusteredRole>` because Azure Stack HCI is out of policy. Azure Stack HCI requires an Azure subscription and needs to regularly connect to the cloud. Register now or troubleshoot your connection. See aka.ms/register-hci for more information.*

  > *Failed to create the clustered resource `<ResourceName>` because Azure Stack HCI is out of policy. Azure Stack HCI requires an Azure subscription and needs to regularly connect to the cloud. Register now or troubleshoot your connection. See aka.ms/register-hci for more information.*

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

3. **Portal Verification:** HCI Cluster resource connection status in Azure is stale (>48 hrs last connected time).

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
