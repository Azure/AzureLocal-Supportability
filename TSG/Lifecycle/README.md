# Infra Lifecycle Operations

* [Add node, repair node fails with Type 'AddAsZHostToDomain' of Role 'BareMetal' raised an exception after cluster upgrade fail when upgraded from <=2311](./Add-node-repair-node-fails-with-Type-AddAsZHostToDomain-of-Role-BareMetal-raised-an-exception.md)

The status of any ARC Node can be ascertained by looking at it's Census records. A sample query could be:

```KQL
cluster("https://aeoprodtelemetry.eastus.kusto.windows.net").database("Telemetry").Census
| where AEODeviceARMResourceUri =~ '<resource_id>'
| where AEOClusterNodeName =~ "Node name"
| take 20
| order by PreciseTimeStamp desc
```
Regular census reports indicate a healthy node. The 'EventString' column provides detailed information of various components of the Arc Node reporting in.
