# ARM Telemetry

ARM telemetry for a deployment, update, or even status can be queried using a query like:

```KQL
cluster("https://armprodgbl.eastus.kusto.windows.net").database('ARMProd').Unionizer('Deployments', 'DeploymentOperations')
| where providerNamespace contains "AzureStackHCI"
| take 50;
```

The above query is for a deployment, but there are a number of [other databases](https://eng.ms/docs/cloud-ai-platform/azure-core/azure-cloud-native-and-management-platform/control-plane-bburns/azure-resource-reporting/azure-resource-reporting/dataconsumeronboarding/armdata/kustov2/overview_prod) that can be accessed, as listed on that page:

| database | tables |
|---------|----------|
| Requests | EventServiceEntries, HttpIncomingRequests, HttpOutgoingRequests |
| Deployments | DeploymentOperations, Deployments, PreflightEvents |
| Traces | Errors, Traces |
| Providers | ProviderErrors, ProviderTraces |
| Jobs | JobDefinitions, JobDispatchingErrors, JobErrors, JobExecutionStatus, JobHistory, JobOperations, JobStatus, JobThrottles, JobTrace|
| Storage | Compactions, Diagnostics, RedisOperations, RegionalStoreAdminLogs, RegionalStoreAdminTraces, RegionalStoreConfigurationLogs, RegionalStoreGarnetServerLogs, RegionalStoreGarnetServerTraces, RegionalStoreHealthCheckLogs, RegionalStoreJobEngineLogs, RegionalStoreServerLogs, RegionalStoreServerTraces, RegionalStoreService, StorageOperations, StorageRequests |
| General | APIValidationErrors, APIValidationTraces, AppPerfCounters, ArmHttpOutgoingRequests, CapacityErrors, CapacityTraces, ClientErrors, ClientRequests, ClientTelemetry, ClientTraces, DispatcherErrors, DispatcherEvents, DispatcherTraces, IISHttpErrors, IISLogs, ManifestRegistrations, MarketplaceErrors, MarketplaceTraces, PolicyServiceDebug, PolicyServiceError, PolicyServiceWarning, ResourceDeletions, ResourceGroupDeletions, Service, SubscriptionProvisioningRequests2, SysPerfCounters, WindowsEvents |
