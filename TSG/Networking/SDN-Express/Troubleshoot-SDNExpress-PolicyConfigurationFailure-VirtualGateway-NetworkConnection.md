# Symptoms
After deploying a Gateway Connection and configure BGP Peering, may observe that BGP route exchange does not appear. 
Under this circumstance, will see that the traffic for the Virtual Network will not flow through the L3 Gateway Connection. In some instances without this configuration the tunnel comes up, but may drop/disconnect at random intervals.

# Issue Validation
To confirm the scenario that you are encountering is the issue documented in this article, you can follow the validation steps below:

1. Install or update SdnDiagnostics module. Refer to [
Install the SDN diagnostics PowerShell module on the client computer](https://learn.microsoft.com/en-us/azure/azure-local/manage/sdn-log-collection#install-the-sdn-diagnostics-powershell-module-on-the-client-computer) for instructions.
   
```powershell
# get the SDN environment details
Get-SdnInfrastructureInfo -NetworkController 'NC-NAME' 

# get all the VirtualGateways deployed and locate the VirtualGateway associated with your virtualNetwork
# if you know the ResourceId or ResourceRef, update the cmdlet below to reduce how many data is displayed on screen
Get-SdnResource -NcUri $Global:SdnDiagnostics.EnvironmentInfo.NcUrl -Resource VirtualGateways -ConvertToJson
```

Examine the output and look for any errors that resemble the following:

```
  "configurationState": {
    "status": "Failure",
    "detailedInfo": [
      {
        "source": "ResourceGlobal",
        "message": "Peers {NetworkConnection_GUID}_ROUTER,{NetworkConnection_GUID}_ROUTER_2 do not have connectivity through any networkconnection. Ensure one of the networkconnections has static routes configured these BGP peers.",
        "code": "PolicyConfigurationFailure"
      }
    ],
    "lastUpdatedTime": "2025-05-21T12:55:33.3380174+01:00"
  }
```

# Cause
Depending on the routes that are advertised via your remote BGP Peer, it may cause routing issues with the Virtual Gateway in which the remote BGP Peer IP falls within an advertised route, which breaks the BGP Peering between the two endpoints.

# Mitigation Details
You must configure a static route entry for each BGP Peer IP. To do this, navigate to your Gateway Connection in WAC and added a static route entry for each BGP Peer IP.

| DestinationPrefix | NextHop | Metric |
|-|-|-|
BGP_Peer_IP/32 | 0.0.0.0 | 10 |
BGP_Peer_IP_2/32 | 0.0.0.0 | 10 |

Alternatively, you can leverage PowerShell directly to update these properties. Below is a sample script to make this modification.
```powershell
$ncRestUri = 'https://NC.FQDN' # UPDATE ME
$networkConnection = Get-SdnResource -NcUri $ncRestUri -ResourceRef '/VirtualGateways/<REPLACE ME>/NetworkConnections/<REPLACE ME>' # UPDATE ME
$bgpPeerIpAddresses = @('BGP_PEER_IP/32','BGP_PEER_IP/32') # define each of your routes here with /32 prefix

# add each of the peer IPs as a static route entry within the routes property
foreach ($peerIP in $bgpPeerIpAddresses) {
    $networkConnection.properties.routes += @{
        destinationPrefix = $peerIP
        nextHop = "0.0.0.0"
        metric = 10
        protocol = "Static"
    }
}

# perform PUT operation against the resource
Set-SdnResource -NcUri $ncRestUri -ResourceRef $networkConnection.resourceRef -Object $networkConnection 
```


