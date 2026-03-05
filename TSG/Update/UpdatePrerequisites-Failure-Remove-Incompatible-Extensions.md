# Update Failure: Incompatible AZ CLI extensions (UpdatePreRequisites / AzCLIKnownIncompatibleExtensions)

## Symptoms

An update fails during **UpdatePreRequisites** or the **pre-update environment validation** phase with one of the following error patterns:

- **Python SyntaxWarning during UpdatePreRequisites:**
  ```
  C:\CloudContent\AzCliExtensions\hybridaks\azext_hybridaks\vendored_sdks\hybridaks\models_models_py3.py:3800: SyntaxWarning: invalid escape sequence '\W'
  C:\CloudContent\AzCliExtensions\connectedmachine\azext_connectedmachine\aaz\latest\connectedmachine_delete.py:54: SyntaxWarning: invalid escape sequence '\.'
  C:\CloudContent\AzCliExtensions\azurestackhci\azext_azurestackhci\generated_validators.py:18: SyntaxWarning: invalid escape sequence '\['
  ```

- **Pre-update health check failure**: the environment validator reports a failed test similar to:
  ```
  Name:        AzStackHci_ARBStack_AzCLIKnownIncompatibleExtensions
  Status:      FAILURE
  Description: Detect known incompatible Azure CLI extensions that should be removed.
  Remediation: Please remove unsupported Azure CLI extensions to ensure compatibility (<extension-name>).
  Detail:      Known incompatible Azure CLI extensions detected: <extension-name>.
               These extensions will cause issues during the update process.
  ```
  > **Note:** The `TargetResourceName` field in the health check result identifies the specific node(s) where the incompatible extension was detected.

Both patterns indicate that AZ CLI extensions **not managed by Azure Local** are present on one or more nodes and may be incompatible with the AZ CLI core version shipped with the target release.

## Root Cause

AZ CLI uses the `AZURE_EXTENSION_DIR` environment variable to locate its extensions directory. Every `az` command automatically loads **all** extensions present in that directory, regardless of whether they are managed by Azure Local or not.

Each Azure Local release ships a ValidatedRecipe that defines the exact set of AZ CLI extensions (and their versions) required for the solution. These **managed extensions** are tested for compatibility with the AZ CLI core version included in each release. During UpdatePreRequisites, MocArb installs or upgrades them.

The problem occurs when **unmanaged extensions** (extensions that are not part of the ValidatedRecipe) are also present in the extensions directory (e.g., manually installed by a user, or left over from other tooling). AZ CLI core frequently introduces breaking changes between versions, particularly in the bundled Python runtime. Because Azure Local does not manage these extensions, they may be incompatible with the newer CLI core shipped in the update. When the CLI loads them:

- **SyntaxWarnings / SyntaxErrors** occur because the newer Python runtime rejects deprecated syntax in older extension code.
- **Action plan failures** occur because CLI commands invoked by MocArb during the update return unexpected errors or crash due to the incompatible extension being loaded.

The pre-update environment validator (`AzStackHci_ARBStack_AzCLIKnownIncompatibleExtensions`) proactively detects known incompatible extensions and blocks the update until they are removed.

## Applies To

All Azure Local releases. This is not specific to any single build version.

## Issue Validation

### Step 1: Get expected extensions from the ValidatedRecipe

On any node, run:
```powershell
# Load the ValidatedRecipe for the target release
$vcNugetPath = Get-ASArtifactPath -NugetName 'Microsoft.AzureStack.VersionControl.Operations'
Import-Module "$vcNugetPath\content\Scripts\VersionControlHelpers.psm1" -Force -DisableNameChecking
$recipePath = Get-ValidatedRecipeJsonFilePath -TagsToInclude @('Azure')
$recipe = Get-Content $recipePath -Raw | ConvertFrom-Json

# Filter to AZ CLI core and CLI extensions only
$cliRecipe = $recipe | Where-Object { $_.Type -in @('AzCli', 'AzCliExtension') }

# Extract short extension names (last segment of nuget name) to match az version output
$cliRecipe | Select-Object @{N='ExtensionName';E={ $_.Name.Split('.')[-1] }}, RequiredVersion, Type | Format-Table -AutoSize
```

Example output:
```
ExtensionName  RequiredVersion Type
-------------  --------------- ----
AzureCLI       2.81.0          AzCli
arcappliance   1.7.0           AzCliExtension
k8s-extension  1.7.0           AzCliExtension
customlocation 0.1.4           AzCliExtension
stack-hci-vm   1.12.0          AzCliExtension
```

### Step 2: Compare with installed extensions on each node

Run the following on **every node** in the cluster (the unmanaged extension may only be present on some nodes):

```powershell
az version --output json --only-show-errors | ConvertFrom-Json | Select-Object -ExpandProperty extensions
```

Example output:
```
arcappliance   : 1.7.0
connectedmachine : 1.1.0
customlocation : 0.1.4
k8s-extension  : 1.7.0
stack-hci-vm   : 1.12.0
```

Compare this against the expected list from Step 1. Any extension present here that is **not** in the ValidatedRecipe (e.g., `connectedmachine`, `azurestackhci` in the example above) is an **unmanaged extension** and should be removed before updating. These can be added back once the Solution Update completes.

## Mitigation

Remove any **unmanaged extension** (not listed in the ValidatedRecipe) from **every node** in the cluster:

```powershell
az extension remove --name "<extension-name>" --only-show-errors
```

Repeat for each unmanaged extension identified in Step 2, on every affected node. Then resume or retry the update. The UpdatePreRequisites step will handle installing the correct managed extensions automatically.
