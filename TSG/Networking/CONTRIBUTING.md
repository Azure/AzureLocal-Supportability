# Contributing to Azure Local Networking Documentation

## Contribution Guidelines

1. Choose the correct folder based on the topic, or create a new one if necessary
2. Use the filename schema below
3. Reference existing files for formatting and structure
4. Keep content focused, concise, and technically accurate
5. Update the README.md with any new topics or files added

## File Naming Conventions

Use the following naming schema for new files:

```
<type>-<topic>-<specifics>.md
```

### `<type>`:
| Type           | Use for...                                   |
|----------------|----------------------------------------------|
| `DeepDive`     | Detailed technical explanations              |
| `HowTo`        | Step-by-step deployment or config guides     |
| `Troubleshoot` | Troubleshooting known issues                 |
| `Reference`    | Reference configurations and resources       |

### `<topics>`:
- `ArcGateway` - Arc Gateway and related services
- `OutboundConnectivity` - Network connectivity and routing
- `SDNExpress` - Software-defined networking components
- `TOR` - Top of Rack switch management

### `<specifics>`:
- Use descriptive keywords that summarize the content, e.g., `2Node-Switchless-Storage`,  `Recreate-Intent-No-SRIOV`, etc.
- Try to keep it concise but informative.

### Examples:
- `Reference-TOR-Explicit-Congestion-Notification.md`
- `Troubleshoot-SDNExpress-PolicyConfigurationFailure-VirtualGateway-NetworkConnection.md`
- `DeepDive-ArcGateway-Outbound-Traffic.md`

## Folder Structure

The repo is organized by major topic areas, you can add new files to existing folders or create new ones as needed. Here’s a quick overview of the main folders:

| Folder                               | Description                                                          |
|--------------------------------------|----------------------------------------------------------------------|
| `Arc-Gateway-Outbound-Connectivity/` | Outbound traffic flow and connectivity through Arc Gateway           |
| `SDN-Express/`                       | SDN scenarios enabled through SDN Express and WAC                    |
| `Top-Of-Rack-Switch/`                | Top of Rack switch configuration and reference implementations       |
