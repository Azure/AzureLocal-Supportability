# Contributing to Azure Local Networking Documentation

This document extends the [universal contribution guidelines](../Templates/CONTRIBUTING.md) with component-specific requirements.

## Component-Specific Guidelines

Networking topologies can vary significantly based on the type and scale of a deployment. All documentation should make clear which topologies are applicable to the specific scenario being addressed. For example: Storage Switched vs Switchless deployments.

## File Naming

Follow the universal naming convention: `<Type>-<Topic>-<Specifics>.md`

For this component (`Networking`), use these specific topic areas, or create new ones as needed:

### `<topics>`:

- `ArcGateway` - Arc Gateway and related services
- `OutboundConnectivity` - Network connectivity and routing
- `SDNExpress` - Software-defined networking components
- `TOR` - Top of Rack switch management

## Structure

The repo is organized by major topic areas, you can add new files to existing folders or create new ones as needed. Here’s a quick overview of the main folders:

| Folder                               | Description                                                    |
| ------------------------------------ | -------------------------------------------------------------- |
| `Arc-Gateway-Outbound-Connectivity/` | Outbound traffic flow and connectivity through Arc Gateway     |
| `SDN-Express/`                       | SDN scenarios enabled through SDN Express and WAC              |
| `Top-Of-Rack-Switch/`                | Top of Rack switch configuration and reference implementations |

## Review Checklist

- [ ] Follows universal TSG template
- [ ] Uses correct file naming convention
- [ ] Code examples are safe for production
- [ ] Updated component README.md
