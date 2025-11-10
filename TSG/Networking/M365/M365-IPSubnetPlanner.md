# Network Subnets IP Assignment Configuration

## 📋 Overview

This directory contains JSON configuration files for IP subnet planning and address assignment for Azure Local M365 project deployments. The JSON files serve as a framework that details individual IP address assignments across multiple supernet subnets, organized by networking components to enable efficient utilization of IPv4 address space using non-contiguous addressing schemes.

## 🎯 Purpose

The IP assignment JSON provides a structured framework for:

- **Address Planning**: Systematic allocation of IP addresses across Azure Local M365 infrastructure components
- **Network Segmentation**: Logical organization of subnets by function and security boundaries
- **Resource Documentation**: Clear mapping of IP assignments to specific infrastructure roles
- **Deployment Planning**: Pre-defined address schemes to streamline Azure Local deployments

## 🔧 Microsoft IPSubnetPlanner Integration

### Tool Repository

**GitHub**: https://github.com/microsoft/IPSubnetPlanner

### Tool Capabilities

- Automated IP address calculation based on position values
- CSV export for deployment planning
- Subnet validation and conflict detection
- Support for complex addressing schemes


## ⚡ Quick Start

1. **Clone Configuration**: Copy the JSON file as a template for your environment: [Sample Json File](./M365-IPAssignment_Sample.json)
2. **Update Network Ranges**: Modify supernet addresses to match your allocation
3. **Assign VLANs**: Update VLAN IDs according to your network design
4. **Validate Format**: Ensure VLAN and CIDR values are integers
5. **Run Tool**: Process with IPSubnetPlanner to generate deployment documentation



## 🏗️ Network Architecture

### Supernet Organization

The JSON configuration covers **5 primary supernet subnets**, each subdivided into functional categories:

#### 1. **Switch Infrastructure** (`192.168.100.0/27`)

- **Loopback Networks**: TOR switch loopback addresses
- **Point-to-Point Links**: iBGP connections between TOR switches
- **DMZ Connectivity**: Firewall and load balancer integration

#### 2. **Compute Networks** (`192.168.0.0/24`)

- **CSU Edge Transport Compute** (VLAN 203): Edge transport server connectivity
- **CSU Exchange Compute** (VLAN 102): Exchange mailbox server networks
- **MSU Compute** (VLAN 302): SharePoint, Skype, and SQL server infrastructure

#### 3. **Management Networks** (`172.22.56.0/25`)

- **CSU Edge Transport Management** (VLAN 101): Edge transport node management
- **CSU Exchange Management** (VLAN 301): Exchange infrastructure management
- **MSU Management** (VLAN 201): SharePoint/Office infrastructure management

#### 4. **Optional Infrastructure** (`172.22.57.0/24`)

- **Optional Infrastructure Management** (VLAN 402): AD, RDP jump boxes

#### 5. **Hardware Management** (`10.60.48.128/26`)

- **BMC Management** (VLAN 125): Baseboard Management Controller access

## 📊 JSON Structure

### Network Object Format

```json
{
  "network": "192.168.100.0/27",
  "subnets": [
    {
      "name": "Subnet-Name",
      "vlan": 400,
      "cidr": 30,
      "IPAssignments": [{ "Name": "Device-Role", "Position": 1 }]
    }
  ]
}
```

### Key Fields

- **`network`**: Supernet CIDR block (string)
- **`subnets`**: Array of subnet definitions within the supernet
- **`name`**: Descriptive subnet name (string)
- **`vlan`**: VLAN ID assignment (integer) ⚠️
- **`cidr`**: Subnet prefix length (integer) ⚠️
- **`IPAssignments`**: Array of specific IP assignments
- **`Name`**: Device or service role identifier (string)
- **`Position`**: Relative position within subnet for IP calculation (integer)

### ⚠️ Critical Formatting Requirements

- **VLAN IDs**: Must be defined as `int` values, not strings
- **CIDR Values**: Must be defined as `int` values, not strings
- **Position Values**: Can be positive (from start) or negative (from end) integers

## 🚀 Usage Workflow

### Primary Users

**Azure Local Administrators** responsible for infrastructure deployment and network configuration.

### Typical Workflow

1. **Update Configuration**: Modify the JSON file with desired subnet ranges for your environment
2. **Run IP Planner**: Execute the Microsoft IPSubnetPlanner tool using the JSON as input
3. **Generate CSV Output**: Tool produces CSV file containing calculated IP assignments
4. **Deploy Infrastructure**: Use CSV output for network configuration and documentation

### Command Example

```bash
# Run tool with JSON configuration
ipsubnetplanner -f config.json -csv out.csv 
```


