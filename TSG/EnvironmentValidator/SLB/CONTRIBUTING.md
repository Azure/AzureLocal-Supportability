# Contributing to Azure Local Software Load Balancer (SLB) Environment Validator Documentation

## Contribution Guidelines

1. Copy the TSG Template below and fill in the required sections
2. Name the file according to the [File Naming Conventions](#file-naming-conventions)
3. Keep content focused and actionable
4. Any mitigation steps provided should be safe to perform and not disrupt the system
5. Update the [README.md](README.md) with any new topics or files added

## File Naming Conventions

Use the following naming schema for new files, use - to separate words:

```
Troubleshoot-Test-SLB_<validator_name>.md
```

Example: `Troubleshoot-Test-SLB_ValidateSoftwareLoadBalancer.md`

## TSG Template

````markdown
# !!VALIDATOR_NAME

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
	<tr>
		<th style="text-align:left; width: 180px;">Name</th>
		<td><strong>!!VALIDATOR_NAME</strong></td>
	</tr>
	<tr>
		<th style="text-align:left; width: 180px;">Severity</th>
		<td><strong>!!VALIDATOR_LEVEL</strong>: This validator will/will not block operations until remediated.</td>
	</tr>
	<tr>
		<th style="text-align:left;">Applicable Scenarios</th>
		<td><strong>!!WHAT_SCENARIOS_DOES_THIS_APPLY_TO? (Deployment,AddNode,Update, etc...)</strong></td>
	</tr>
</table>

## Overview

!!OVERVIEW - Put a brief description of what this validator does, and why it is needed here. What components does it apply to? What does it check?

## Requirements

!!REQUIREMENTS - List what is required for this validator to pass. What causes it to fail?

- Failure Condition #1
- Failure Condition #2

You can also use this section to expand upon different scenarios and configuration. For example, the requirements might be different between scenarios.

## Troubleshooting Steps

### Review Environment Validator Output

!!OUTPUT - Capture the Alert from a test run and put it here. Modify the JSON to remove any references to nodes, ips, or timestamps. See the example below:

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for a summary of the failure. You may also identify the invalid configuration from the `TargetResourceID` and `TargetResourceName` fields.

Here is an example:

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateNumberOfSLBNodes,
    "DisplayName":  "The number of Software Load Balancer (SLB) Multiplexer (MUX) is appropriate for the number of available hosts in an Azure Local deployment.",
    "Tags":  {},
    "Title":  "The number of Software Load Balancer (SLB) Multiplexer (MUX) is appropriate for the number of available hosts in an Azure Local deployment.",
    "Status":  1,
    "Severity":  1,
    "Description":  "Execute critical validation of the SLB node count configuration to ensure proper load balancer deployment in Azure Local environments.",
    "Remediation":  "The number of SLB MUX is not valid with the number of available hosts",
    "TargetResourceID":  "SoftwareLoadBalancer - Mux:1, Hosts:2",
    "TargetResourceName":  "NumberOfMuxes",
    "TargetResourceType":  "SoftwareLoadBalancer",
    "Timestamp":  "\/Date(1760464356344)\/",
    "AdditionalData":  {
                            "Detail":  "\"The minimum number of Multiplexer (MUX) instances (2) required for the multinode deployment is not met. This is not recommended and please increase the number of MUX instances.\"",
                            "Status":  "FAILURE",
                            "TimeStamp":  "10/14/2025 17:52:36",
                            "Resource":  "SoftwareLoadBalancer",
                            "Source":  "SDNIntegration"
                        },
    "HealthCheckSource":  "ScaleSLB\\Standard\\Medium\\NetworkSLB\\56f035e0"
}
```

### Failure Results

#### Failure: !!FAILURE_MESSAGE - Put any failure messages from the Detail section here, if there are multiple possible messages, split them into different sections

!!DESCRIPTION - Put a description of the failure message here. How should it be interpreted?

!!ADDITIONAL_DATA_EXAMPLE:

```text
!!FAILURE_ADDITIONAL_DATA
```

!!Remediation Steps

!!REMEDIATION_STEP_DESCRIPTION - Explain what the remediation steps are, and why we take them

!!REMEDIATION_STEPS

and more...

````
