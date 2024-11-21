This troubleshooting guide will assist engineers with the basics of troubleshooting for SBE during bootstrap, deployment, and update.

# Introduction
Starting with Azure Stack HCI 23H2, HCI introduced the Lifecycle Manager (LCM) to orchestrate deployment and updates of the full solution using a **solution update** composed of the following components to implement a recipe to consistently deploy and update the solution:
* [Solution Builder Extension (SBE)](https://learn.microsoft.com/en-us/azure-stack/hci/update/solution-builder-extension) – A special type of solution extension provided by the server hardware vendor or system integrator (aka the Solution Builder) to provide updates for firmware, drivers, and other Hardware vendor specific tools.  See https://learn.microsoft.com/en-us/azure-stack/hci/update/solution-builder-extension for details.
* Platform Updates – OS and Security Updates
* Services Updates – Agents and services updates including LCM component updates

For general details on how solution extensions fits in with the other components as part of solution updates, see [About Updates 23H2](
https://learn.microsoft.com/en-us/azure-stack/hci/update/about-updates-23h2#whats-in-the-update-package) for details.

## SBE Related Term Definitions
* **Solution Extension** - A package consisting of 2 XML files (manifest and metadata) and a zip payload file. Used to provide constent way for partners to extend the HCI solution.
* **Solution Extension Discovery Manifest XML** - A signed multi-entry manifest that describes each partner solution extension release to date.  Used by LCM to establish trust for the zip file (XML is signed and has packageHash for zip file) and applicability rules used to discover which extension is a match for a specific model system and a specific solution update version.
* **Solution Extension metadata XML** - A signed metadata file that tracks expected contents of the zip file including a software BOM. Used to perform file integrity checks after extension zip file is expanded.
* **Solution Extension ZIP** - The zip file containing the extension content from the partner. See Solution Extension Zip Contents section below.
* **LCM** - The "Orchestrator" or Lifecycle Manager that orchestrates extension installation and updates as well as performs solution extension discovery to assure the correct extensions are included in deploymentents and updates.
* **CAU** - [Cluster Aware Updating or CAU](https://learn.microsoft.com/en-us/windows-server/failover-clustering/cluster-aware-updating) is leveraged by solution extensions to perform rolling updates using hardware vendor provided **CAU plugins** in the update use case; however, for deployment CAU is only used to perform a scan to determine if an update is needed (without actually performing the update).
* **WDAC Policy** - It is mandatory for solution extensions to contain the extension publisher's supplemental Windows Defender Application Control (WDAC) policy. This is the mechanism by which the content within the extension is allowed to execute. Gaps in the supplemental policy may result in extension operations being blocked by WDAC.

# Scoping Questions
When troubleshooting issues with a solution extension the following questions may be helpful to better understand the situation or identify common issues.

* Who is the system manufacturer and publisher of the solution extension?
* What is server model (solution builder extensions only supports specific models defined by partner)?
* Which solution version is being deployed/updated?
* Is your issue with bootstrap, pre-deployment (e.g. environment validation), cloud deployment, or update?
* If for deployment, which solution builder extension version and family version is staged at `C:\SBE\*.zip`
* If for update
  * What version of SBE is currently installed (per `Get-SolutionUpdateEnvironment`)?
  * What type of update is being installed? Does `Get-SolutionUpdate` list the `PackageType` as "SBE" (a "SBE-only" update) or "Solution" (a Platform + Services + SBE) update?
See this [discovery doc](https://learn.microsoft.com/en-us/azure-stack/hci/update/solution-builder-extension#discover-solution-builder-extension-updates-via-powershell) for how to tell which.
* How were the solution extension files obtained (e.g. preloaded by partner vs downloaded and placed by customer)?
* What InterfaceType task failed in the action plan?
  * If it starts with **SBEPartner** it likely failed executing partner code or installing partner files.
  * If it contains **CAU** it may still be partner code, but it may be need to Microsoft support assistance for deeper triage if the guidance is in this document is insufficient.
  * Other interfaces are less likely to be an issue caused by the solution extension and the [known issues](https://learn.microsoft.com/en-us/azure-stack/hci/release-information-23h2) for solution update version that is installed (or being installed) should be consulted.
 
# Getting information on solution extension failures
Solution extensions are directly integrated into the LCM Orchestration processes for deployment and update and thus the top level progress details can viewed direclty in the portal and PowerShell. This means that the first pass analysis for solution extension issues can be obtained using 
## Standardized solution builder extension logs
Solution extensions always create *.etl based log files at `C:\Observability\OEMDiagnostics` on the server that is currently executing the LCM Orchestrator (which will rotate based on node reboots).  ETL logs can be converted to text files using the `Get-ASEvent` cmdlet which is always installed on the 1st server in the cluster or with other utilities such as [WPA](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/opening-and-analyzing-etl-files-in-wpa).  If using Get-ASEvent to view the logs, copy the logs to a location accessible on the 1st node and use syntax similar to the following if the file had been copied to c:\temp:
```
Get-ASEvent -Path c:\temp\example.etl > example.txt
notepad.exe example.txt
```

Microsoft understands that dealing with with ETL logs is not always convenient so text based versions of the logs may also be available. Starting with solution version 10.2411.0.x, text-based solution builder extension standardized log files will be created at one of the 2 locations as outlined below:
* `D:\CloudContent\MASLogs\SBELogs **(if D:\ drive exists)**
* `C:\CloudContent\MASLogs\SBELogs **(when there is no D:\ drive)**

Prior to solution version 10.2411.0.x, text-based solution builder extension logs may have been created at `C:\SBELogs`; however, logs at this location may be incomplete and the ETL based logs may need to be consulted.

## Extension-specific logs
As each solution extension is executing partner authored logic, the extension may create additional log files at other locations.  Consult the release notes and other documentation provided by the extension publisher for details where to find addition log files that could assist in troubleshooting.

# Solution Builder Extension workflows

## SBE Bootstrap Flow
If there is a failure with SBE in the bootstrap process see the below diagram for the high level flow.

![SBE-bootstrap-flow.png](./images/sbe-bootstrap-flow.png)

## SBE Deployment Flow
See the detailed [Solution builder extension deploy scenarios guide](./Solution-builder-extension-deploy-scenarios.md)

## SBE Update Flow
See the detailed [Solution builder extension update scenarios guide](./Solution-builder-extension-update-scenarios.md)