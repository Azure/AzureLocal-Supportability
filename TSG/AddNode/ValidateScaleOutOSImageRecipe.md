# Symptoms
In Add/Repair node flow, when adding a new node, validation fails with ValidateScaleoutOSImageRecipe failure.

# Error: 
Validating that the Build ID installed on the cluster matches the Build Id on the host to add node to the cluster.
The OS Image Version on the node does not match the version on the node.

# Resolution:
Make sure incoming node and existing nodes have same Composed Image version by running this command-
    ```powershell
 Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\ComposedBuildInfo\Parameters
```


