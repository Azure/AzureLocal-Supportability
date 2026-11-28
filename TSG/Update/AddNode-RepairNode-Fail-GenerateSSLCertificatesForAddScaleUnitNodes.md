# Add/Repair Node fails at "GenerateSSLCertificatesForAddScaleUnitNodes" with "The system cannot find the file specified."

# Symptoms
After update to 2411, the Add Node or Repair Node operation will fail at "GenerateSSLCertificatesForAddScaleUnitNodes" with the error:

_ActionPlanInstanceID: 00000000-0000-0000-0000-000000000000 WarningMessage:[NODE01]:Task: Invocation of interface 'GenerateSSLCertificatesForAddScaleUnitNodes' of role 'Cloud\Infrastructure\ASCA' failed:

Type 'GenerateSSLCertificatesForAddScaleUnitNodes' of Role 'ASCA' raised an exception:

System.Management.Automation.MethodInvocationException: Exception calling "GetResult" with "0" argument(s): "The system cannot find the file specified.
" ---> System.Security.Cryptography.CryptographicException: The system cannot find the file specified.

   at System.Security.Cryptography.CryptographicException.ThrowCryptographicException(Int32 hr)
   at System.Security.Cryptography.X509Certificates.X509Utils._QueryCertFileType(String fileName)
   at System.Security.Cryptography.X509Certificates.X509Certificate.LoadCertificateFromFile(String fileName, Object password, X509KeyStorageFlags keyStorageFlags)
   at System.Security.Cryptography.X509Certificates.X509Certificate2..ctor(String fileName, SecureString password, X509KeyStorageFlags keyStorageFlags)
   at Microsoft.AzureStack.Security.CertificateAuthority.CertificateAuthorityManager.<>c__DisplayClass10_0.<GenerateCertificates>b__0(String x)
   at System.Linq.Enumerable.WhereSelectListIterator 2.MoveNext()
   at System.Collections.Generic.List 1..ctor(IEnumerable 1 collection)
   at System.Linq.Enumerable.ToList[TSource](IEnumerable 1 source)
   at Microsoft.AzureStack.Security.CertificateAuthority.CertificateAuthorityManager.GenerateCertificates(List`1 newCertsRequests, Boolean isClusterCert, List1 existingCertPaths)
   at Microsoft.AzureStack.Orchestration.Roles.CertificateAuthority.ASCA.GenerateSSLCertificates(IManagedInterfaceParameters parameters, AdminOperation adminOperation, CertificateType certificateType)
   at Microsoft.AzureStack.Orchestration.Roles.CertificateAuthority.ASCA.GenerateSSLCertificatesForAddScaleUnitNodes(IManagedInterfaceParameters parameters)
   --- End of inner exception stack trace ---
   at System.Management.Automation.ExceptionHandlingOps.CheckActionPreference(FunctionContext funcContext, Exception exception)
   at System.Management.Automation.Interpreter.ActionCallInstruction 2.Run(InterpretedFrame frame)
   at System.Management.Automation.Interpreter.EnterTryCatchFinallyInstruction.Run(InterpretedFrame frame)
   at System.Management.Automation.Interpreter.EnterTryCatchFinallyInstruction.Run(InterpretedFrame frame)
at Invoke-EceInterfaceInternal, C:\Agents\Microsoft.AzureStack.Solution.ECEWinService.10.2411.1.760\content\ECEWinService\InvokeInterfaceInternal.psm1: line 152
at <ScriptBlock>, <No file>: line 33 - 1/3/2025 4:46:05 AM_


# Issue Validation

Query the action plan instance logs:
EtlLogs
| where AEODeviceARMResourceUri contains "<ARM RESOURCE URI>" and * contains "<ACTION PLAN INSTANCE ID OF ADD NODE/REPAIR NODE> "

You should see the following in the logs:
ActionPlanInstanceID: **<ID>** VerboseMessage:[NODE01]:[ASCA:GenerateSSLCertificatesForAddScaleUnitNodes] Creating **-NC.<fqdn>** Certificate Request for node02 - 1/3/2025 4:34:59 AM

SDN Prefix shouldnt have been set:

ActionPlanInstanceID: **<ID>** VerboseMessage:[NODE01]:[ASCA:GenerateSSLCertificatesForAddScaleUnitNodes] Could not get SDN Prefix: Object reference not set to an instance of an object. - 1/3/2025 9:48:59 AM

The action plan should be looking for the below 2 pfx paths:

ActionPlanInstanceID: **<ID>** VerboseMessage:[NODE01]:[ASCA:GenerateSSLCertificatesForAddScaleUnitNodes] Got certificate paths: C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\AzureStackCertStore\Internal\Current\ALMManagedAgents\node01\ECServiceSecretEncryption.pfx C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\AzureStackCertStore\Internal\Current\ALMManagedAgents\node01\ **-NCREST.pfx** - 1/3/2025 9:48:59 AM

Notice that the -NCREST.pfx has no value before the '-'. The expected value is <prefix>-NCREST.pfx.


For further confirmation, navigate to path 
C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\AzureStackCertStore\Internal\Current\ALMManagedAgents\ **<Any pre-existing node name folder>**

and you should see pfx's for NCREST with a non-null value for the prefix.

# Mitigation Details

To mitigate the issue, do the following on all pre-existing nodes (i.e. all nodes that existed before add-node was initiated.)

Make a copy of the <prefix>-NCREST.pfx, <prefix>-NCREST.cer and <prefix>-NCREST.txt files and name the copies as "-NCREST.pfx", "-NCREST.txt" and "-NCREST.cer".

Once that is done, resume the add node/ repair node admin operation.
