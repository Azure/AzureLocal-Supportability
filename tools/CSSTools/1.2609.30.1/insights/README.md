# Insights

This folder documents the AzStack.Insights component reference for the `Microsoft.AzLocal.CSSTools`
module. Insights use a hierarchical **Component → Analyzer → Rule** architecture: each page below
documents one top-level component and the analyzers and rules it runs.

## Running insights

Install and import the module, then run insights locally or remotely with `Invoke-AzsSupportInsight`:

```powershell
Install-Module -Name Microsoft.AzLocal.CSSTools -Force
Import-Module -Name Microsoft.AzLocal.CSSTools -Force

# Run all components
Invoke-AzsSupportInsight

# Run a single component
Invoke-AzsSupportInsight -Component HostStorage
```

When an insight reports a failure with remediation guidance, run the associated remediation via
`Invoke-AzsSupportInsightRemediation` (see the [remediations reference](../remediations/README.md)).

## Components

| Component | Synopsis |
|-----------|----------|
| [ControlPlaneOperations](./ControlPlaneOperations.md) | Checks the state of the Azure Local control plane services (Microsoft Onprem Cloud, Azure Resource Bridge, Arc services, AKS Arc, MOC/ARB). |
| [HostCompute](./HostCompute.md) | Checks the state of host compute, including cluster node and system service state. |
| [HostNetwork](./HostNetwork.md) | Checks the state of the host network, including NetworkATC intent configuration and provisioning. |
| [HostStorage](./HostStorage.md) | Checks the state of host storage, including Cluster Shared Volume state and free space. |
| [KnownIssues](./KnownIssues.md) | Checks for common known issues on the Azure Local environment. |
| [LifecycleOrchestration](./LifecycleOrchestration.md) | Checks the state of Azure lifecycle and orchestration services such as ECE, LCM, and Update. |
| [OperatingSystem](./OperatingSystem.md) | Checks the operational state of the operating system, including bugcheck and unexpected-reboot events. |
| [VirtualMachines](./VirtualMachines.md) | Checks the state of virtual machines and their VM network adapters. |
