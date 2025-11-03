# [2503] UpdatePreRequisites Failure: Update fails with "invalid escape sequence" error because of extension incompatibility

# Symptoms
An update to 10.2503.0.13 fails with errors like below:

*C:\CloudContent\AzCliExtensions\hybridaks\azext_hybridaks\vendored_sdks\hybridaks\models\_models_py3.py:3800: SyntaxWarning: invalid escape sequence '\W'*

*C:\CloudContent\AzCliExtensions\connectedmachine\azext_connectedmachine\aaz\latest\connectedmachine\_delete.py:54: SyntaxWarning: invalid escape sequence '\.'*

*C:\CloudContent\AzCliExtensions\azurestackhci\azext_azurestackhci\generated\_validators.py:18: SyntaxWarning: invalid escape sequence '\['*

# Issue Validation
This TSG is only for updates to 10.2503.0.13.

Below is the list of AzCli extensions which are expected to be installed for 10.2503.0.13 updates:
| Az CLI Extension Name     | RequiredVersion |
| ------------- | ------------- |
| arcappliance | 1.3.0 |
| k8s-extension | 1.4.5 |
| customlocation | 0.1.3 |
| stack-hci-vm | 1.4.2 |

If there are any extensions installed that are not in the above list, it could be causing the failures described in this TSG.

Run the following command on all nodes to verify the Azure CLI extensions installed on each node:

`az version`

Example for az version output (we are only focusing on the "extensions" section):
![image.png](./images/azversionexampleoutput.png)

# Mitigation Details

If there are any extensions installed that are not in the list, run below command on all nodes to remove the unexpected extension:
`az extension remove --name "<extension name>"`
