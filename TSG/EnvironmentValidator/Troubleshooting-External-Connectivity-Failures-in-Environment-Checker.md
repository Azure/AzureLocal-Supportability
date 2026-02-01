# Overview

Environment Validator runs external connectivity checks during Deployment, Update, ScaleOut and Upgrade actions in AzureLocal. The tool detects connectivity issues with the required endpoints for Azure Local.

The tool downloads an online manifest from https://aka.ms/hciconnectivitytargets to get a list of endpoints to test. This list changes periodically and the changes are documented here: https://github.com/Azure/AzureStack-Tools/blob/master/HCI/.

The complete solution to fixing connectivity problems is often environment specific, ultimately the node cannot communicate with the endpoint and the network infrastructure that Azure Local is hosted on needs allow that communication.  There are some additional details that can help with troubleshooting the network infrastructure, this document attempts to highlight these.

# Issue Validation

There are two ways to receive a failure, standalone invocation on a workstation or Azure local node following [Evaluate the deployment readiness of your environment for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/manage/use-environment-checker?tabs=connectivity) or via an Azure Local fabric operation like Deployment, Update, ScaleOut and Upgrade actions.

## Standalone - Running Invoke-AzStackHciConnectivityValidation from PowerShell
```
C:\Users\lcmuser> Invoke-AzStackHciConnectivityValidation
```
```
Invoke-AzStackHciConnectivityValidation v1.2100.2850.619 started.
Connectivity Results

Arc For Servers:
► ✓ Healthy External Endpoint Agent Telemetry For Agent telemetry
► ✓ Healthy External Endpoint Arc Server Resource Manager For Azure Resource Manager to create or delete the Arc Server resource
► ✓ Healthy External Endpoint Azure Active Directory For Active Directory Authority and authentication, token fetch, and validation
► ✓ Healthy External Endpoint Azure Active Directory For Azure Active Directory
► ✓ Healthy External Endpoint Azure Active Directory For Azure Active Directory
► ✓ Healthy External Endpoint Notification Service For the notification service for extension and connectivity scenarios
► ✓ Healthy External Endpoint Notification Service For the notification service for extension and connectivity scenarios
► ✓ Healthy External Endpoint Windows Installation Package For downloading the Windows installation package.
⚠ ▼ Needs Attention External Endpoint - Installation Download Script For resolving the download script during installation.
  ⚠  LAPTOP-BFEENPAC -> https://aka.ms/hciconnectivitytargets

  ✎  Help URL: https://learn.microsoft.com/en-us/azure/azure-arc/servers/network-requirements?tabs=azure-cloud#urls

....

Summary

The following is summary of the unique issues found, these issues should be reviewed prior to continuing.  Critical issues require remediation and are blocking issues. Warning issues are sub-optimal non-blocking issues. Informational issues are for your information.

 ✓ 90 successes

Remediation:
  ✎  https://learn.microsoft.com/en-us/azure/azure-arc/servers/network-requirements?tabs=azure-cloud#urls

Summary
►  ✓  90 / 91 (97%) resources test successfully.

Failed Urls log: C:\Users\lcmuser\.AzStackHci\FailedUrls.txt
Log location: C:\Users\lcmuser\.AzStackHci\AzStackHciEnvironmentChecker.log
Report location: C:\Users\lcmuser\.AzStackHci\AzStackHciEnvironmentReport.json
Use -Passthru parameter to return results as a PSObject.
```

The output is reporting connectivity https://aka.ms/hciconnectivitytargets is not working.  Open the log location listed at the bottom and examine for any additional information. Searching on 'FAILURE' or 'Debug' will focus in on the key information. (The example has been annotated with <--comments ):

```
[11/03/2025 19:38:18] [WARNING] [Invoke-WebrequestEx] FAILURE: LAPTOP-BFEENPAC https://aka.ms/hciconnectivitytargets (Unable to connect to the remote server)
[11/03/2025 19:38:18] [WARNING] [Invoke-WebrequestEx] Debug LAPTOP-BFEENPAC: https://aka.ms/hciconnectivitytargets {
  "NonHTTPFailure": true,                                         <-- The exception was not from a web server.
  "StatusCode": null,
  "ErrorDetails": null,
  "Uri": "https://aka.ms/hciconnectivitytargets",
  "ExceptionMessage": "Unable to connect to the remote server",   <--  indicates a transport layer issue (application firewall or routing).
  "ResponseUriMatch": false,
  "Server": null,
  "WebResponse": null,
  "ResponseMethodIsGet": false,
  "Headers": null,
  "Retries": "3 / 3",                                             <-- All 3 attempts failed.
  "Test": false,
  "Exception": {
    "ExceptionMessage": "Unable to connect to the remote server",
    "ErrorDetails": null,
    "NonHTTPFailure": true
  },
  "ResponseUri": null,
  "PowerShellVersion": 5,
  "LatencyInMs": 39,                                              <-- It only took 39ms to fail.
  "TCPNetConnection": true,                                       <-- Test-NetConnection succeeded.
  "serviceUnavailable": false
}
```
This is indicating it is likely an application layer firewall device, based on the following factors:
- A NonHttp error. The test sent a web request out and did not get a web response back.
- Test-NetConnection worked so TCP:443 is open on IP layer to destination. This means something is blocking Application layer.
- It is not a routing problem, because it is a single url affected, there is no latency and Test-NetConnection worked.

Another example is a proxy, and this gives a little more information:
```
[3/8/2025 8:50:17 AM] [WARNING] [Invoke-WebrequestEx] FAILURE: NODE01 https://aka.ms (The remote server returned an error: (403) Forbidden.)   <-- The node and the endpoint
[3/8/2025 8:50:17 AM] [WARNING] [Invoke-WebrequestEx] Debug NODE01: https://aka.ms {
    "serviceUnavailable":  false,
    "Retries":  "3 / 3",
    "Server":  "Zscaler/6.2",                                                       <-- A proxy product, this would tend to be a webserver product like IIS or similar if the response got through.
    "ResponseUriMatch":  false,                                                     <-- ResponseUri is not the same as the RequestUri, so the call did not reach the required endpoint.
    "Exception":  {
                      "ExceptionMessage":  "The remote server returned an error: (403) Forbidden.",
                      "NonHTTPFailure":  false,
                      "ErrorDetails":  "Possibly some http page response by proxy"          
                  },
    "ResponseMethodIsGet":  false,                                                  <-- The request was a HTTP GET, but the response was not.
    "ExceptionMessage":  "The remote server returned an error: (403) Forbidden.",   <-- A forbidden from a proxy
    "PowerShellVersion":  5,
    "ErrorDetails":  "Possibly some http page response by proxy",
    "NonHTTPFailure":  false,
    "Test":  false,                                                                 <-- The overall decision about this test is that it failed.
    "WebResponse":  {
                        "IsMutuallyAuthenticated":  false,
                        "Cookies":  [],
                        "Headers":  [
                                        "Access-Control-Allow-Origin",
                                        "Content-Length",
                                        "Cache-Control",
                                        "Content-Type",
                                        "Server"
                                    ],
                        "SupportsHeaders":  true,
                        "ContentLength":  16885,
                        "ContentEncoding":  "",
                        "ContentType":  "text/html",
                        "CharacterSet":  "ISO-8859-1",
                        "Server":  "Zscaler/6.2",
                        "LastModified":  "\/Date(1741423800485)\/",
                        "StatusCode":  "Forbidden",
                        "StatusDescription":  "Forbidden",
                        "ProtocolVersion":  {
                                                "Major":  1,
                                                "Minor":  1,
                                                "Build":  -1,
                                                "Revision":  -1,
                                                "MajorRevision":  -1,
                                                "MinorRevision":  -1
                                            },
                        "ResponseUri":  "http://proxy.contoso.com/",                <-- The proxy address
                        "Method":  "CONNECT",                                       <-- The request issued a GET not a CONNECT
                        "IsFromCache":  false
                    },
    "LatencyInMs":  29,
    "ResponseUri":  "http://proxy.contoso.com/",                                    <-- Where the HTTP response came from
    "Headers":  {
                    "Content-Length":  "16885",
                    "Server":  "Zscaler/6.2",
                    "Content-Type":  "text/html",
                    "Access-Control-Allow-Origin":  "*",
                    "Cache-Control":  "no-cache"
                },
    "Uri":  "https://aka.ms",
    "StatusCode":  403,
    "TCPNetConnection":  false
}
[3/8/2025 8:50:17 AM] [WARNING] [Invoke-WebrequestEx] FAILURE: NODE01 https://aka.ms (The remote server returned an error: (403) Forbidden.)
```
The tool determines that ResponseUri does not match the RequestUri and therefore 403 did not come from the required endpoint.  The forbidden HTTP status code was for a CONNECT, not a GET (which was issued). So the proxy refused this connection.

In this example a proxy (http://proxy.contoso.com) blocked the connection to https://aka.ms on node01.  
## Validation blocks Fabric Operation (deployment, scaleout, upgrade)
Similar information is available in the portal prior to deployment, scaleout or upgrade.
```
Type 'ValidateConnectivity' of Role 'EnvironmentValidator' raised an exception: {
    "ExceptionType": "json",
    "ErrorMessage": {
        "Message": "Connectivity requirements not met. Review output and remediate.",
        "Results": [
            {
                "Name": "Azure_Stack_HCI_Dataplane",
                "DisplayName": "Dataplane",
                "Tags": {
                    "Mandatory": "True",
                    "ARCGateway": "False",
                    "Region": "Global",
                    "Service": "Azure Stack HCI"
                },
                "Title": "Dataplane",
                "Status": 1,
                "Severity": 2,
                "Description": "For Dataplane that pushes up diagnostics data, billing data and used in the Portal pipeline",
                "Remediation": "https://learn.microsoft.com/en-us/azure-stack/hci/concepts/firewall-requirements?#required-firewall-urls",
                "TargetResourceID": "node01/https://billing.platform.edge.azure.com/_health",
                "TargetResourceName": "https://billing.platform.edge.azure.com/_health",
                "TargetResourceType": "External Endpoint",
                "Timestamp": "\/Date(1736154477157)\/",
                "AdditionalData": {
                    "Source": "node1",
                    "Retry": "3 / 3",
                    "ExceptionMessage": "The underlying connection was closed: An unexpected error occurred on a send.",                    <-- A device on the network is blocking the traffic.
                    "DebugDtls": "redacted",
                    "TimeStamp": "01/06/2025 09:07:57",
                    "Detail": "TestIsSuccess: False\r\nStatusCode: \r\nResponseUri: \r\nResponseUriMatch: False\r\nResponseMethodIsGet: False\r\nTCPNetConnection: True\r\nserviceUnavailable: False",
                    "Resource": "https://billing.platform.edge.azure.com/_health",
                    "LatencyInMs": "10011",
                    "Status": "FAILURE",
                    "Protocol": "",
                    "StatusCode": ""
                },
                "HealthCheckSource": "Deployment\\Medium\\Connectivity\\4d61e190"
            },
```
In this example the response is not HTTP response, but the underlying connection was closed on sending the request. This would indicate a device on the network did not allow the connection out to the required endpoint.

## Validation blocks Updates
The action to CheckCloudHealth runs daily as well as before Update to ensure the environment is ready to perform an update.

You can see the results of these checks using the Update cmdlets. [More information](https://learn.microsoft.com/en-us/azure/azure-local/update/update-troubleshooting-23h2)

```
Get-SolutionUpdateEnvironment | Select-Object -ExpandProperty HealthCheckResult | Where-Object {$_.Status -ne "SUCCESS" -and $_.Severity -ne "INFORMATIONAL"}
```
This will return an array of results in which connectivity failures can be triaged as above.
## Redirects

If any endpoint has been allowed for a specific endpoint and that endpoint still fails the test, it could be that a redirect happens and it fails. For example, http://aka.ms is allowed on the network infrastructure but the test fails. That's because a redirect service, aka.ms is shortlinking another endpoint that is likely to change for a new release. Redirects can happen for any endpoint as services upgrades, migrate or move to different platforms.

Curl is a good tool to quickly see if this is the case.
```
c:\> curl.exe https://aka.ms/hciconnectivitytargets  --verbose --location --include --no-progress-meter --connect-timeout 5 > $null
```

```
* Host aka.ms:443 was resolved.                            <-- DNS worked to resolve aka.ms
* IPv6: (none)
* IPv4: 95.101.226.131
*   Trying 95.101.226.131:443...
* schannel: disabled automatic use of client certificate
* ALPN: curl offers http/1.1
* ALPN: server accepted http/1.1
* Connected to aka.ms (95.101.226.131) port 443
* using HTTP/1.x
> GET /hciconnectivitytargets HTTP/1.1
> Host: aka.ms
> User-Agent: curl/8.10.1
> Accept: */*
>
* Request completely sent off
* schannel: remote party requests renegotiation
* schannel: renegotiating SSL/TLS connection
* schannel: SSL/TLS connection renegotiated
* schannel: remote party requests renegotiation
* schannel: renegotiating SSL/TLS connection
* schannel: SSL/TLS connection renegotiated

< HTTP/1.1 301 Moved Permanently                         <-- The response a redirect saying that url has moved permanently to another place we can see 3 properties down in Location:
< Content-Length: 0
< Server: Kestrel
< Location: https://azurestackreleases.download.prss.microsoft.com/dbazure/AzureStackHCI/OnRamp/1.2100.3000.649/AzStackHciConnectivityTargets-Global.xml
                                                        /\-- The place the redirect is pointing at

< Request-Context: appId=cid-v1:d94c0f68-64bf-4036-8409-a0e761bb7ee1
< X-Response-Cache-Status: True
< Expires: Tue, 11 Mar 2025 19:31:04 GMT
< Cache-Control: max-age=0, no-cache, no-store
< Pragma: no-cache
< Date: Tue, 11 Mar 2025 19:31:04 GMT
< Connection: keep-alive
< Strict-Transport-Security: max-age=31536000 ; includeSubDomains
* Ignoring the response-body
* setting size while ignoring
<
* Connection #0 to host aka.ms left intact
                                                        \/-- Another request is made to the redirect URL
* Issue another request to this URL: 'https://azurestackreleases.download.prss.microsoft.com/dbazure/AzureStackHCI/OnRamp/1.2100.3000.649/AzStackHciConnectivityTargets-Global.xml'
* Host azurestackreleases.download.prss.microsoft.com:443 was resolved.   <-- The redirected domain is resolved to an IP
* IPv6: (none)
* IPv4: 86.0.165.16, 86.0.165.42
*   Trying 86.0.165.16:443...
* connect to 86.0.165.16 port 443 from 0.0.0.0 port 56146 failed: Bad access     <-- Something is blocking this
*   Trying 86.0.165.42:443...
* connect to 86.0.165.42 port 443 from 0.0.0.0 port 56147 failed: Bad access     <-- Something is blocking this
* Failed to connect to azurestackreleases.download.prss.microsoft.com port 443 after 19 ms: Could not connect to server
* closing connection #1

curl: (7) Failed to connect to azurestackreleases.download.prss.microsoft.com port 443 after 19 ms: Could not connect to server                               
                                                                                /\-- The call to the redirected endpoint failed

```

The original call to aka.ms succeeded and it send an instruction back to go to azurestackreleases.download.prss.microsoft.com. This redirected domain is being blocked by something on the network. azurestackreleases.download.prss.microsoft.com should be allowed on the network infrastructure and the test will succeed.

# Summary
Determine the following information to assist with troubleshooting the network infrastructure:
- Get a list of failed Endpoints. Run the tool standalone from powershell and it will generate a list (FailedUrls.txt).
- Get a list of nodes affected. It may be all nodes, or it may be a subset.
- Use the logs and errors message to gain a better understanding of the network environment Azure Local is hosted on.
- Get an understanding of whether it is Proxy related.
  - Is the response a HTTP response? Proxies respond with HTTP response (typically 403 or 407).
  - What is the proxy address?
- Get an understanding of whether it is another network device?
  - Application firewalls block http traffic but Test-NetConnection on port 443 works.
  - Intrusion Protection Systems inspect traffic and block it.
  - Network Access control devices are used to allow traffic from nodes.

This should give enough information to pass to the network/proxy administrators, they should then be able to remediate the access controls on network infrastructure.