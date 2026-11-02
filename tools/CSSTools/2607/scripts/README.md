# Support Scripts

This folder documents the signed support scripts shipped inside the `Microsoft.AzLocal.CSSTools`
module. These scripts live in [src/scripts](../../src/scripts) and are packaged into the module's
`scripts` directory at build time. They are executed through the exported
[`Invoke-AzsSupportScript`](../functions/Invoke-AzsSupportScript.md) function.

> [!WARNING]
> **Anything invoked using `Invoke-AzsSupportScript` must only be performed by Microsoft CSS or
> Engineering.** These scripts perform low-level, high-impact operations against Azure Local systems
> (deleting Arc guest-configuration assignments, erasing Health Service data records, and similar).
> Running them without a full understanding of the current system state, or outside of a Microsoft-led
> support engagement, can leave a cluster in an unrecoverable state and cause data loss. Do not run
> these scripts based on symptom-matching alone — confirm every precondition first, and prefer the
> read-only preview (`-WhatIf`) before making changes.

## How to run a support script

1. Install and import the module on the target Azure Local system (or from a management machine with
   connectivity to it):

   ```powershell
   Install-Module -Name Microsoft.AzLocal.CSSTools -Force
   Import-Module -Name Microsoft.AzLocal.CSSTools -Force
   ```

2. Invoke the script by its base file name (without the `.ps1` extension). Pass the script's parameters
   as a hashtable to `-Parameters`:

   ```powershell
   Invoke-AzsSupportScript -ScriptName "<ScriptName>" -Parameters @{ Param1 = "Value1"; Param2 = "Value2" }
   ```

   `-ScriptName` supports tab completion — press <kbd>Tab</kbd> to enumerate the scripts available in
   the installed module.

3. If the script takes no parameters, omit `-Parameters`:

   ```powershell
   Invoke-AzsSupportScript -ScriptName "<ScriptName>"
   ```

`Invoke-AzsSupportScript` locates the script under the module's `scripts` folder, logs the invocation
(via `Trace-Output`), splats the supplied `-Parameters` hashtable to the script, and rethrows any
error after tracing it.

## Available scripts

| Script | Synopsis | Runs where |
|--------|----------|------------|
| [ClearStorageHealthData](./ClearStorageHealthData.md) | Clear Health Service data entries for storage components. | On a cluster node (uses `healthapi.dll`) |
| [Remove-SetSecuredCoreGuestConfig](./Remove-SetSecuredCoreGuestConfig.md) | Removes the `SetSecuredCore` guest configuration assignment from every Arc-for-Server node of a cluster. | Anywhere with an authenticated `Az` context |
