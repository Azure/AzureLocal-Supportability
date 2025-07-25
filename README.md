# Azure Local Supportability Forum
This is a public repository for all of Azure Local Troubleshooting guides (TSGs), known issues and reporting feedback - this repo is intended to provide a central location for community driven supportability content. This is the material that is referenced by Customer Support Services when a ticket is created, by Azure Local engineering responding to an incident, and by users when self discovering resolutions to active system issues.

_Azure Stack HCI is now part of Azure Local. [Learn more](https://aka.ms/azloc-promo)._ 

## Table of Contents
Troubleshooting guides (TSGs) are grouped by categories and stored in relevantly named subdirectories. Each directory contains a README that lists the guides. The following are the categories of guides that are stored in relevantly named directories:

* [Deployment](./TSG/Deployment/README.md) - Prerequisites, AD, Software Download, OS install, Registration, Arc extensions and Deployment (Portal & ARM templates).
* [Update](./TSG/Update/README.md) - Health Check, Sideloading, Update method (Azure Update Manager & PowerShell).
* [Upgrade](./TSG/Upgrade/README.md) - Upgrade from version 22H2 to 23H2.
* [Solution Extension](./TSG/SolutionExtension/README.md) - Solution extension.
* [LCM](./TSG/LCM/README.md) - Lifecycle Manager.
* [Infra Lifecycle Operations](./TSG/Lifecycle/README.md) - Add Server, Repair Server.
* [Arc VMs](./TSG/ArcVMs/README.md) - VM lifecycle management, licensing, extensions, networking and storage.
* [Security](./TSG/Security/README.md) - WDAC, BitLocker, Secret Rotation, Syslog, Defender for Cloud.
* [Networking](./TSG/Networking/README.md) - Arc Gateway, Outbound Connectivity, TOR Configuration.
* [Monitoring](./TSG/Monitoring/README.md) - Insights, Metric and Alerts.
* [Azure Virtual Desktop](./TSG/AVD/README.md) - Azure Virtual Desktop.
* [Azure Kubernetes](./TSG/AKS/README.md) - Deployment, Networking, Update.
* [Storage](./TSG/Storage/README.md) - Storage.
* [Environment Validator](./TSG/EnvironmentValidator/README.md) - Environment Validation during deploy, update, scaleout, upgrade etc.
* [Arc Registration](./TSG/ArcRegistration/README.md) - Arc Registration.

## Bug Reports

> **IMPORTANT**: An inability to meet the below requirements for bug reports are subject to being closed by maintainers and routed to official Azure support channels to provide the proper support experience to resolve user issues.

Bug reports filed on this repository should follow the default issue template that is shown when opening a new issue. Please do not share any personal data. The template contains the following fields:

* Bug Description
* Repro Steps
* Expected Behavior
* Environment
  * Azure Local build (release version)
  * 1-node vs. multi-nodes, etc.
  * Production vs. Non-production
  * Region
* Screenshots (do not share personal data)
* Correlation ID (from [log collection](https://learn.microsoft.com/azure/azure-local/manage/get-support-for-deployment-issues#perform-standalone-log-collection))
  
At a bare minimum, issues reported on this repository must:

1. Be reproducible outside of the current system

* This means that if you file an issue that would require direct access to your system and/or Azure resources you will be redirected to open an Azure support ticket. Microsoft employees may not ask for personal / subscription information on Github.
  * For example, if your issue is related to custom scenarios such as custom network devices, configuration, authentication issues related to your Azure subscription, etc.

2. Contain the following information:

* A good title: Clear, relevant and descriptive - so that a general idea of the problem can be grasped immediately
* Description: Before you go into the detail of steps to replicate the issue, you need a brief description.
  * Assume that whomever is reading the report is unfamiliar with the issue/system in question
* Clear, concise steps to replicate the issue outside of your specific system.
  * These should let anyone clearly see what you did to see the problem, and also allow them to recreate it easily themselves. This section should also include results - both expected and the actual - along with relevant URLs.
* Be sure to include any supporting information you might have that could aid the developers.
  * This includes YAML files/deployments, scripts to reproduce, exact commands used, screenshots, etc.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Legal Notices

Microsoft and any contributors grant you a license to the Microsoft documentation and other content
in this repository under the [Creative Commons Attribution 4.0 International Public License](https://creativecommons.org/licenses/by/4.0/legalcode),
see the [LICENSE](LICENSE) file, and grant you a license to any code in the repository under the [MIT License](https://opensource.org/licenses/MIT), see the
[LICENSE-CODE](LICENSE-CODE) file.

Microsoft, Windows, Microsoft Azure and/or other Microsoft products and services referenced in the documentation
may be either trademarks or registered trademarks of Microsoft in the United States and/or other countries.
The licenses for this project do not grant you rights to use any Microsoft names, logos, or trademarks.
Microsoft's general trademark guidelines can be found at http://go.microsoft.com/fwlink/?LinkID=254653.

Privacy information can be found at https://privacy.microsoft.com/en-us/

Microsoft and any contributors reserve all others rights, whether under their respective copyrights, patents,
or trademarks, whether by implication, estoppel or otherwise.
