# Infra Lifecycle Operations

* [Add node, repair node fails with Type 'AddAsZHostToDomain' of Role 'BareMetal' raised an exception after cluster upgrade fail when upgraded from <=2311](./Add-node-repair-node-fails-with-Type-AddAsZHostToDomain-of-Role-BareMetal-raised-an-exception.md)

The status of any ARC Node can be ascertained by looking at its Census records. A sample query could be:

> [!NOTE]
> This sample query requires access to the appropriate Kusto cluster and database. Replace the placeholders with values from your environment and ensure you have the required permissions before running it.

```KQL
cluster("<kusto_cluster_uri>").database("Telemetry").Census
| where AEODeviceARMResourceUri =~ '<resource_id>'
| where AEOClusterNodeName =~ "<node_name>"
| take 20
| order by PreciseTimeStamp desc
```
Regular census reports indicate a healthy node. The 'EventString' column provides detailed information of various components of the Arc Node reporting in.
