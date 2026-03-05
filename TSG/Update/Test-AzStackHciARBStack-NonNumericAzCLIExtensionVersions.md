
# Test-AzStackHciARBStack Fails on Non-Numeric Az CLI Extension Versions

## Symptoms
- Environment Validator fails in the Test-AzStackHciARBStack function with an error related to parsing az cli extension versions containing non-numeric characters (e.g., "1.0.0b1").
- Error message similar to:
   Exception occurred (Test-AzStackHciARBStack): Cannot convert value "1.0.0b1" to type "System.Version". Error: "Input string was not in a correct format."


## Summary
A bug in the Environment Validator's Test-AzStackHciARBStack function causes it to fail when az cli extensions have non-numeric version strings (such as beta versions like "1.0.0b1").

**Applies to:**
- Azure Stack HCI releases 2601, 2602, and 2603 only.
- **Note:** From release 2604 onwards, the validator has been reworked and no longer checks extension versions in this way.

## Mitigation
Refer to the main TSG for incompatible az cli extensions for mitigation steps:

- [UpdatePrerequisites Failure: Remove Incompatible Extensions](./UpdatePrerequisites-Failure-Remove-Incompatible-Extensions.md)
