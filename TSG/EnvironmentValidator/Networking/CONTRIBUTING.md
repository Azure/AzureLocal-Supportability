# Contributing to Azure Local Networking Environment Validator Documentation

## Contribution Guidelines

1. Copy the TSG Template below and fill in the required sections
2. Name the file according to the [File Naming Conventions](#file-naming-conventions)
3. Keep content focused and actionable
4. Any mitigation steps provided should be safe to perform and not disrupt the system
5. Update the [README.md](README.md) with any new topics or files added

## File Naming Conventions

Use the following naming schema for new files, use - to separate words:
```
Troubleshooting-Network-Test-<validator_name>.md
```

Example: `Troubleshooting-AzureLocal-Network-Test-StorageConnections-VMSwitch-Configuration.md`

## TSG Template

```markdown
# !!VALIDATOR_NAME

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>!!VALIDATOR_NAME</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>!!VALIDATOR_LEVEL</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>!!WHAT_SCENARIOS_DOES_THIS_APPLY_TO? (Deployment,AddNode,Update)</strong></td>
  </tr>
</table>

## Overview

!!OVERVIEW - Put a brief description of what this validator does, and why it is needed here. What components does it apply to? What does it check?

## Requirements

!!REQUIREMENTS - Explicitely list each requirement here, if something causes the validator to fail, that must be documented here

- Failure Condition #1
- Failure Condition #2

You can also use this section to expand upon different scenarios and configuration. For example, the requirements might be different between 

## Troubleshooting Steps

### Review Environment Validator Output

!!OUTPUT - Capture the Alert from a test run and put it here. See the example below:

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for summary of which Hosts are not configured properly. You can identify the host by the `TargetResourceID` field.

Here is an example:
```json
{
  "Name":  "AzStackHci_Network_Test_StorageConnections_ConnectivityCheck",
  "DisplayName":  "Validate that the Storage Adapters on each node can reach their connected adapters on other nodes.",
  "Tags":  {},
  "Title":  "Validate that the Storage Adapters on each node can reach their connected adapters on other nodes.",
  "Status":  1,
  "Severity":  2,
  "Description":  "The Storage Adapters on each node must be able to reach their connected adapters on other nodes, based on the expected network topology. This topology is determined by the Intent and Switch/Switchless configuration. Connectivity is tested using ICMP (ping) between the APIPA addresses of the Storage Adapters.",
  "Remediation":  "https://aka.ms/azurelocal/envvalidator/storageconnections",
  "TargetResourceID":  "azloc-node3",
  "TargetResourceName":  "azloc-node3",
  "TargetResourceType":  "StorageAdapterConnection",
  "Timestamp":  "\/Date(1749592635804)\/",
  "AdditionalData":  {
                        "Detail":  "azloc-node3 (0/2 checks passed): ethernet 4[169.254.138.15] to azloc-node1/ethernet 4[169.254.38.73] = FAIL, ethernet 3[169.254.74.115] to azloc-node1/ethernet 3[169.254.246.79] = FAIL",
                        "Status":  "FAILURE",
                        "TimeStamp":  "06/10/2025 21:57:15",
                        "Resource":  "StorageAdapterConnection",
                        "Source":  "azloc-node3"
                      },
  "HealthCheckSource":  "Manual\\Standard\\Medium\\Network\\13d8dbb9"
}
```

### Failure: !!FAILURE_MESSAGE - Put any failure messages from the Detail section here, if there ar emultiple possible messages, split them into different sections

!!FAILURE_MESSAGE_DESCRIPTION - Put a description of the failure message here. How should it be interpreted?

#### Example !!EXAMPLE_FAILURE_MESSAGE
```text
!!EXAMPLE_FAILURE_MESSAGE
```

!!EXAMPLE_FAILURE_MESSAGE_DESCRIPTION - Break down an example failure, how should it be interpreted?

You can have multiple examples

#### Remediation Steps

##### !!REMEDIATION_STEPS - Break down the remediation steps into larger catgories, if there is only one, you can remove this section

!!REMEDIATON_STEP_DESCRIPTION - Explain what the remediation steps are, and why we take them

!!REMEDIATION_STEPS
1. Step 1
    - Step 1.b
    - Step 1.a

2. Step 2

and more...

## Verification Method

!!VERIFICATION_METHOD - How can the customer verify that they configured everything properly, without running the Environment Validator from scratch?
```