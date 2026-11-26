<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "overview",
  "products": ["Azure Local"],
  "detector": {
    "type": "none",
    "signal": null
  },
  "validation": {
    "fidelity_level": "L0",
    "technical_grade": null,
    "reproduction_substrate": "none",
    "automation_status": "not-assessed",
    "last_validated": "2026-11-02",
    "spec_ref": ""
  }
}
-->

# Azure Local Support Diagnostic Tool (CSSTools)

The Azure Local Support Diagnostic Tool is a PowerShell module,
`Microsoft.AzLocal.CSSTools`, that helps administrators and Microsoft Customer Service
and Support (CSS) investigate Azure Local issues. It provides diagnostic checks,
support data collection, and troubleshooting commands.

This folder organizes release notes and supporting reference documentation by
four-digit release train (for example, `2609`). Release notes retain the exact module
versions documented within each train.
Install the module using the public instructions below; downloading this folder does
not install the tool.

> [!IMPORTANT]
> The public guidance applies to **hyperconverged deployments of Azure Local**.
> Consult the public documentation and the release-specific references for applicability
> before running a command. The tool does not replace expert investigation or Microsoft Support.

## Table of contents

- [Install and update](#install-and-update)
- [Basic commands](#basic-commands)
- [Release notes and references](#release-notes-and-references)
- [Support and feedback](#support-and-feedback)
- [Documentation status](#documentation-status)

## Install and update

Follow the [public installation and update instructions](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools#install-or-update-the-azure-local-support-diagnostic-tool)
for installing `Microsoft.AzLocal.CSSTools`, updating an existing installation, and
loading the updated module into the current PowerShell session.

Before you begin:

- Review the [prerequisites](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools#prerequisites).
  Use an account with administrative access and run PowerShell as an administrator.
- Ensure PowerShell remoting is configured on the target machines. Treat changes to
  remoting configuration as a separate administrative change.
- Keep the same module version on every Azure Local node.
- After updating, reload the module as documented and remove existing remote
  PowerShell sessions so subsequent connections use the updated version. Do not
  remove sessions that are running active work.

**[READ-ONLY] Verify installation.** Risk: not applicable. This lists installed
versions without importing or updating the module:

```powershell
Get-Module -ListAvailable -Name Microsoft.AzLocal.CSSTools |
    Select-Object Name, Version, ModuleBase
```

Expected result: the installed module version and location. Check each node; if the
module is missing or versions differ, stop and complete installation or updates before
running cluster-wide diagnostics.

> [!NOTE]
> The public documentation states that importing the module attempts an automatic
> update from PowerShell Gallery. Do not treat module import as a read-only operation.

## Basic commands

The examples below assume the module is installed and loaded according to the public
instructions. Run one example at a time. If a command reports an error, stop, retain
the error details, and investigate before continuing.

### Discover commands and help

**[READ-ONLY]** Risk: not applicable.

```powershell
Get-Command -Module Microsoft.AzLocal.CSSTools
Get-Help Invoke-AzsSupportInsight -Full
Get-Help New-AzsSupportDataBundle -Full
```

Expected result: exported commands and help describing their parameters and examples.
If commands or help are unavailable, stop and verify the loaded module version.
Command availability can differ between releases.

### Run diagnostic checks

**[LOW RISK]** This runs checks and writes diagnostic artifacts; it is not a
remediation step. Before running, confirm that the intended nodes are reachable,
module versions match, and sufficient disk space is available for the output.
Collection uses CPU, disk, and network resources; schedule it appropriately for
busy systems.

From an Azure Local cluster node, check the target list first:

```powershell
Get-ClusterNode | Select-Object Name, State
```

This pre-check is **[READ-ONLY]**; risk is not applicable. Expected result: the
intended cluster nodes and their states. Stop if the list is unexpected or a node
is unavailable. Then run:

```powershell
Invoke-AzsSupportInsight -ComputerName (Get-ClusterNode).Name -ErrorAction Stop
```

Expected result: a diagnostic summary and an output location containing reports and
collected data. Open the HTML report and review warnings, failures, and node coverage.
Do not interpret an incomplete run as a healthy cluster.

Rollback: no configuration rollback is expected for these diagnostic checks. Retain
the output for investigation; remove only the generated artifacts when they are no
longer required, following your organization's retention policy.

See [perform diagnostic checks](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools#perform-diagnostic-checks)
for public usage guidance and sample output.

### Collect a support data bundle

**[LOW RISK]** Collection writes files and consumes CPU, disk, and network resources.
Before running, confirm the required collection scope with Microsoft Support and
ensure sufficient disk space is available. For an operating-system collection:

```powershell
New-AzsSupportDataBundle -Component OS -ErrorAction Stop
```

Expected result: a support data bundle at the output location reported by the tool.
Verify that the bundle was created and that collection completed without errors.
Stop if collection fails or the output is missing.

Rollback: no configuration rollback is expected. Retain the bundle until the support
investigation is complete, then remove only the generated artifacts according to your
retention policy.

See [collect data for support](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools#collect-data-for-support)
for predefined collection sets and custom collection instructions. Use parameter
completion or the installed command's help to discover supported components.

> [!WARNING]
> Reports and bundles can contain environment-specific or sensitive information.
> Do not attach them to public GitHub issues. Share them only through approved,
> secure support channels.

## Release notes and references

Use the documentation for your installed module version. The newest version
documented in this folder is not necessarily the newest version available for installation.

| Release train | Documented module versions | Release notes |
| --- | --- | --- |
| 2609 | 1.2609.30.2, 1.2609.30.1 | [Release notes](./2609/README.md) |
| 2608 | 1.2608.31.1 | [Release notes](./2608/README.md) |
| 2607 | 1.2607.16.2249 | [Release notes](./2607/README.md) |
| 2605 | 1.2605.5.1611 | [Release notes](./2605/README.md) |
| 2602 | 1.2602.24.1845 | [Release notes](./2602/README.md) |
| 2512 | 1.2512.1.2240 | [Release notes](./2512/README.md) |

Reference documentation for the **2609 release train**, through revision **1.2609.30.2**:

- [Functions](./2609/functions/README.md): public commands, parameters, and examples.
- [Insights](./2609/insights/README.md): diagnostic components, analyzers, and rules.
- [Remediations](./2609/remediations/README.md): signed remediation scripts and prerequisites.
- [Scripts](./2609/scripts/README.md): support scripts for CSS or Engineering-led scenarios.

Do not run remediation or support scripts as part of the basic diagnostic workflow.
Review each script's applicability, prerequisites, workload impact, risk, and rollback
guidance, and involve Microsoft Support where required.

## Support and feedback

- [Public tool documentation](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools)
- [Tool questions or feedback](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools#questions-or-feedback)
- [Get support for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/manage/get-support)

## Documentation status

Command examples were checked against public Microsoft Learn guidance and the
version 1.2609.30.1 command references. Validation is static only (L0); no commands
were exercised against an Azure Local environment, and no technical grade has been established.

| Article | Type | Applicable products | Owner | Validation grade | Automation readiness | Last validation |
| --- | --- | --- | --- | --- | --- | --- |
| This README | Overview | Azure Local (hyperconverged) | Repository maintainers | Not graded | Not assessed | 2026-11-02 (L0) |
