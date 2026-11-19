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
Troubleshoot-Network-Test-<validator_name>.md
```

Example: `Troubleshoot-Network-Test-HostNetworkConfigurationReadiness.md`

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

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for summary of which Hosts are not configured properly. You can identify the host by the `TargetResourceID` field.

Here is an example:

```json
{
  "Name": "AzStackHci_Network_Test_HostNetworkConfigurationReadiness",
  "DisplayName": "Test if host network requirement meets for the deployment on all servers",
  "Tags": {},
  "Title": "Test host network configuration readiness",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking host network configuration readiness status on <hostnode>",
  "Remediation": "Make sure host network configuration readiness is correct. Review detail message to find out the issue.",
  "TargetResourceID": "<hostnode>",
  "TargetResourceName": "HostNetworkReadiness",
  "TargetResourceType": "HostNetworkReadiness",
  "Timestamp": "\\/Date(timestamp)\\/",
  "AdditionalData": {
    "Detail": "On <hostnode>:\\nERROR: External VMSwitch ComputeSwitch(compute) is not having any VMNetworkAdapter attached to it.\\nERROR: Please remove the VMSwich, or add at least one VMNetworkAdapter to it.\\nPASS: DNS Client configuration has valid data for all adapters defined in intent\\nPASS: Hyper-V is running correctly on the system\\nPASS: External VMSwitch ConvergedSwitch(managementintent) have 2 VMNetworkAdapter(s) attached to it\\nPASS: At least 1 VMSwitch is having the network adapter defined in the management intent\\nPASS: All adapters defined in intent are physical NICs and Up in the system\\nPASS: Intent ManagementIntent is already defined in the system with same adapter(s)\\nPASS: Intent ComputeIntent is already defined in the system with same adapter(s)\\nPASS: Intent StorageIntent is already defined in the system with same adapter(s)",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>",
    "Resource": "HostNetworkReadiness configuration status",
    "Source": "<hostnode>"
  }
}
```

---

### Failure: !!FAILURE_MESSAGE - Put any failure messages from the Detail section here, if there are multiple possible messages, split them into different sections

!!FAILURE_MESSAGE_DESCRIPTION - Put a description of the failure message here. How should it be interpreted?

### Example Failures

```text
!!EXAMPLE_FAILURE_MESSAGE
```

!!FAILURE_DESCRIPTION - What does this error mean? What should be checked?

Add more examples as needed

#### Remediation Steps

##### !!REMEDIATION_STEPS - Break down the remediation steps into larger categories, if there is only one, you can remove this section

!!REMEDIATION_STEP_DESCRIPTION - Explain what the remediation steps are, and why we take them

!!REMEDIATION_STEPS

1. Step 1

   - Step 1.b
   - Step 1.a

2. Step 2

and more...

Don't forget to include any cleanup steps!
````
