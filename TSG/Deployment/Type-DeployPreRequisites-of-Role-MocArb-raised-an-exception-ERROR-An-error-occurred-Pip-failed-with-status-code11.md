# Type 'DeployPreRequisites' of Role 'MocArb' raised an exception: ERROR: An error occurred. Pip failed with status code 1. Use --debug for more information

Deployment in 10.2503. fails with a similar error:

```
Type 'DeployPreRequisites' of Role 'MocArb' raised an exception:

ERROR: An error occurred. Pip failed with status code 1. Use --debug for more information.
at CheckAndInstall-CliExtensions, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\content\Scripts\MocArbHelper.psm1: line 395
at Install-ValidatedRecipeModules, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2502.0.12\Content\Scripts\MocArbHelper.psm1: line 736
at <ScriptBlock>, <No file>: line 25,
```

The cluster is configured with Proxy or Arc Gateway. 


# Issue Validation
To confirm the scenario that you are encountering is the issue documented in this article, confirm you are seeing the following behavior(s):

1. Proxy, Arc gateway are configured in the cluster.
2. Run the following command to manually install the extension:

```Powershell
az extension add --name “arcappliance” --version 1.4.0 --debug --upgrade
```

This command should fail. From output of the command you should see a similar error:
```Powershell
Starting new HTTPS connection (5): pypi.org:443
Incremented Retry for (url='/simple/jsonschema/'): Retry(total=0, connect=None, read=None, redirect=None, status=None)
WARNING: Retrying (Retry(total=0, connect=None, read=None, redirect=None, status=None)) after connection broken by 'SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1000)'))': /simple/jsonschema/
Starting new HTTPS connection (6): pypi.org:443
Could not fetch URL https://pypi.org/simple/jsonschema/: There was a problem confirming the ssl certificate: HTTPSConnectionPool(host='pypi.org', port=443): Max retries exceeded with url: /simple/jsonschema/ (Caused by SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1000)'))) - skipping
```

# Cause
In proxy-enabled setups, when the Arc Appliance cli is installed, it attempts to download a critical root certificate, it fails, resulting in a SSLCertVerificationError.

# Mitigation Details

To resolve this issue, it is necessary to manaully download the certificate. Follow these steps in **all nodes** to mitigate:

1.  **Download certificate (in all nodes)**:
```Powershell
iwr http://crl.globalsign.com -UseBasicParsing
iwr http://pypi.org -UseBasicParsing
```

2.  **Confirm that certificate is installed (in all nodes)**:
```Powershell
Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Subject -match "CN=GlobalSign" } | Select-Object Subject
```

3. **Resume deployment from Portal**:


### **Additional Notes**
*   Ensure that all nodes in the cluster have downloaded the certificate before resuming the Deployment from Portal.
*   In case of failure after the certificate has been installed, please run manual installation again and confirm that the output still includes the same error:
```Powershell
az extension add --name “arcappliance” --version 1.4.0 --debug --upgrade
```
```Powershell
Starting new HTTPS connection (5): pypi.org:443
Incremented Retry for (url='/simple/jsonschema/'): Retry(total=0, connect=None, read=None, redirect=None, status=None)
WARNING: Retrying (Retry(total=0, connect=None, read=None, redirect=None, status=None)) after connection broken by 'SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1000)'))': /simple/jsonschema/
Starting new HTTPS connection (6): pypi.org:443
Could not fetch URL https://pypi.org/simple/jsonschema/: There was a problem confirming the ssl certificate: HTTPSConnectionPool(host='pypi.org', port=443): Max retries exceeded with url: /simple/jsonschema/ (Caused by SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1000)'))) - skipping
```


