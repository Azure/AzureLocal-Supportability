# Invoke-AzStackHciLLDPValidation Core Functions - Technical Documentation

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites and Requirements](#prerequisites-and-requirements)
3. [What Invoke-AzStackHciLLDPValidation Does](#what-invoke-azstackhcilldpvalidation-does)
4. [Why LLDP for Azure Local Validation](#why-lldp-for-azure-local-validation)
5. [LLDP TLV Data Collection](#lldp-tlv-data-collection)
6. [Function Usage and Parameters](#function-usage-and-parameters)
7. [How the Function Processes LLDP Data](#how-the-function-processes-lldp-data)
8. [NetLLDPAgent Commands and Usage](#netlldpagent-commands-and-usage)
9. [Practical Examples](#practical-examples)
10. [Output Files and Analysis](#output-files-and-analysis)
11. [Key Benefits of Invoke-AzStackHciLLDPValidation](#key-benefits-of-invoke-azstackhcilldpvalidation)
12. [Common Use Cases for Invoke-AzStackHciLLDPValidation](#common-use-cases-for-invoke-azstackhcilldpvalidation)
13. [Frequently Asked Questions (FAQ)](#frequently-asked-questions-faq)

## Overview

This documentation describes the core functions of `Invoke-AzStackHciLLDPValidation` and focuses on **why**, **what**, and **how** the tool collects LLDP TLVs, parses them, and validates network connections and configurations for Azure Local environments.

`Invoke-AzStackHciLLDPValidation` is a core validation function within the **Azure Stack Environment Validator tool** that performs comprehensive LLDP (Link Layer Discovery Protocol) network validation. This PowerShell function is designed for **Azure local administrators and deployment teams** to validate physical network connections and configurations before cluster deployment.

**Function Location**: Part of the Azure Stack Environment Validator (`AzStackHci.EnvironmentChecker`) module  
**Primary Purpose**: Collect, parse, and validate LLDP TLV data to ensure network switches and connections meet Azure Local requirements

The function automatically discovers network connectivity between Azure Local hosts and their connected Top-of-Rack (ToR) switches by collecting LLDP TLVs, parsing the raw data into structured information, and validating that cables are properly connected and network configurations comply with deployment requirements.

## Prerequisites and Requirements

### Software Requirements
- Windows Server 2019/2022 or Azure Local OS on target nodes
- PowerShell 5.1 or later
- Local administrator privileges on all nodes
- PowerShell remoting enabled between nodes

### Network Requirements  
- LLDP enabled on connected switch ports (coordinate with network team if needed)
- Physical Ethernet adapters in 'Up' status
- Layer 2 connectivity between hosts and switches

### Pre-Deployment Setup Commands
Run these commands on each Azure Local node before using the tool:

```powershell
# Install required Windows features (run as administrator)
Install-WindowsFeature Data-Center-Bridging, RSAT-DataCenterBridging-LLDP-Tools

# Verify NetLldpAgent module is available
Get-Module -ListAvailable NetLldpAgent

# The tool will automatically enable LLDP agents when run
# No manual LLDP configuration needed
```

## What Invoke-AzStackHciLLDPValidation Does

### Core Function Responsibilities
The `Invoke-AzStackHciLLDPValidation` function performs the following validation tasks within the Azure Stack Environment Validator:

1. **Physical Connection Validation**: Verifies all network cables are connected to correct switch ports as per deployment plan
2. **LLDP Neighbor Discovery**: Automatically discovers connected switches and their configurations using LLDP protocol
3. **Network Configuration Verification**: Validates VLAN settings, MTU sizes, and QoS configurations across all nodes
4. **Switch Compatibility Check**: Ensures connected switches support required LLDP TLVs and network features
5. **Topology Documentation**: Generates detailed connection maps and validation reports

### Integration with Environment Validator
This function integrates seamlessly with the broader Azure Stack Environment Validator workflow:

- **Pre-Deployment Validation**: Runs as part of the comprehensive environment validation before cluster creation
- **Automated Execution**: Can be invoked standalone or as part of the full validation suite
- **Result Integration**: Outputs structured validation results that integrate with other validator functions
- **Report Generation**: Contributes network validation data to the overall environment assessment report

## Why LLDP for Azure Local Validation?

The `Invoke-AzStackHciLLDPValidation` function leverages LLDP (Link Layer Discovery Protocol) as a critical component of Azure Local environment validation because:

- **Automated Network Discovery**: Eliminates manual cable tracing by automatically discovering switch connections and configurations
- **Standards-Based Validation**: Uses industry-standard IEEE 802.1AB protocol supported by all enterprise switches
- **Real-Time Configuration Check**: Provides current network state validation including VLANs, QoS, and connectivity
- **Multi-Vendor Support**: Works consistently across different switch vendors (Cisco, Dell, HPE, Aruba, etc.)
- **Environment Validator Integration**: Provides network validation data that integrates with other Azure Local readiness checks

## LLDP TLV Data Collection

### What are TLVs?
**TLV** stands for **Type-Length-Value** - a simple data structure used by network protocols to organize information:

- **Type**: Identifies what kind of information is being sent (e.g., "System Name", "Port ID")
- **Length**: Specifies how many bytes of data follow
- **Value**: Contains the actual information (e.g., "Switch-01.contoso.com", "Ethernet1/29")

Think of TLVs like labeled containers that switches use to share information about themselves with connected devices. When a switch sends LLDP information, it packages details like its name, port descriptions, VLAN settings, and capabilities into these TLV containers.

**Example TLV Structure**:
```
Type: 5 (System Name) | Length: 15 bytes | Value: "TOR-Switch-01"
```

The `Invoke-AzStackHciLLDPValidation` function collects these TLV containers from network switches and converts the raw byte data into human-readable information for validation.

### TLV Types Collected by the Tool

The tool collects and analyzes various LLDP TLVs that provide essential network information:

### Standard TLVs (Types 1-8)

| TLV Type | Name | Description | Example Use |
|----------|------|-------------|-------------|
| **1** | Chassis ID | Unique identifier of the switch | MAC address of the switch chassis |
| **2** | Port ID | Identifier of the specific switch port | "Ethernet1/29" or port MAC address |
| **3** | Time To Live | How long LLDP information remains valid | Typically 120 seconds |
| **4** | Port Description | Human-readable port description | "Storage NIC2" or "Management Port" |
| **5** | System Name | Hostname of the switch | "TOR-Switch-01.contoso.local" |
| **6** | System Description | Switch model and software version | "Cisco Nexus 9000 NX-OS 10.3" |
| **7** | System Capabilities | What the device can do | Bridge, Router capabilities |
| **8** | Management Address | IP address for switch management | Management interface IP |

### Organizational Specific TLVs (Type 127)

These are vendor-specific extensions that provide advanced networking features:

#### IEEE 802.1 Extensions (OUI: 00-80-C2)
- **Subtype 1**: Port VLAN ID (PVID) - Native/untagged VLAN
- **Subtype 3**: VLAN Name - Maps VLAN IDs to descriptive names
- **Subtype 9**: ETS Configuration - Enhanced Transmission Selection for bandwidth allocation
- **Subtype 10**: ETS Recommendation - Recommended ETS settings
- **Subtype 11**: PFC Configuration - Priority Flow Control for lossless traffic

#### Cisco Extensions (OUI: 00-01-42)
- Power consumption and capabilities
- Switch stack information

## Function Usage and Parameters

### Basic Function Invocation
> **Security Note:**  
> For security, never hardcode passwords in scripts. Instead, prompt for credentials at runtime or use secure credential storage (such as Windows Credential Manager or Azure Key Vault). The following example demonstrates secure password input.

```powershell
        $allServers = "<ARRAY OF SERVERS' IP>"
        $logOutputPath = "<LOGFILELOCATION>"
        $userName = "<LOCALADMIN>"
        # Prompt for password securely
        $secPassWord = Read-Host "Enter password for $userName" -AsSecureString
        $hostCred = New-Object System.Management.Automation.PSCredential($userName, $secPassWord)
        [System.Management.Automation.Runspaces.PSSession[]] $allServerSessions = @();
        foreach ($currentServer in $allServers) {
            $currentSession = Microsoft.PowerShell.Core\New-PSSession -ComputerName $currentServer -Credential $hostCred -ErrorAction Stop
            $allServerSessions += $currentSession
        }
        Invoke-AzStackHciLLDPValidation -StorageAdapterVLANIDInfo $StorageAdapterVLANIDInfo -PSSession $allServerSessions -OutputPath $logOutputPath
```

### Function Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `PSSession` | PSSession[] | Yes | PowerShell sessions to target Azure Local nodes |
| `OutputPath` | String | Yes | Directory path for LLDP validation output files |
| `PassThru` | Switch | No | Returns validation objects for further processing |

### Return Values
The function returns Azure Local result objects containing:
- **Validation Status**: SUCCESS, WARNING, or FAILURE
- **Detailed Results**: Connection mappings, TLV analysis, and configuration validation
- **Output Files**: JSON files containing raw and processed LLDP data

## How the Function Processes LLDP Data

### Function Execution Workflow

1. **Session Validation**: Verifies PowerShell sessions to all target HCI nodes are active
2. **Prerequisites Check**: Ensures NetLldpAgent module is available on all nodes
3. **LLDP Agent Enablement**: Enables NetLldpAgent on all physical Ethernet adapters across all nodes
4. **Discovery Phase**: Waits for LLDP neighbor discovery to complete (30 seconds)
5. **Data Collection**: Retrieves raw LLDP TLV data from each adapter on each host
6. **Data Processing**: Converts raw byte strings into structured, human-readable format
7. **Analysis & Validation**: Creates connection mappings and validates network configurations
8. **Report Generation**: Outputs structured validation results and detailed JSON files

### Data Processing Pipeline

```
Raw LLDP TLVs → Byte String Parsing → Data Conversion → Network Analysis → Validation Results
```

#### Example Data Flow:

**Raw Chassis ID TLV**: `"4 36 22 157 159 8 164"`
- **Parsing**: Split by spaces, convert to bytes: [4, 36, 22, 157, 159, 8, 164]
- **Conversion**: Subtype 4 = MAC Address format: `24:16:9D:9F:08:A4`
- **Result**: Switch MAC address for unique identification

## NetLLDPAgent Commands and Usage

The NetLLDPAgent PowerShell module is the core component that enables Windows hosts to collect LLDP information from connected switches. Here are the key commands used by the tool:

### Essential NetLLDPAgent Commands

#### 1. Enable LLDP Agent on Network Adapters
```powershell
# Enable LLDP on a specific adapter
Enable-NetLldpAgent -NetAdapterName "Ethernet 4"

# Enable LLDP on all physical adapters (what the tool does automatically)
Get-NetAdapter -Physical | Where-Object {$_.Status -eq 'Up'} | 
    ForEach-Object { Enable-NetLldpAgent -NetAdapterName $_.Name }
```

#### 2. Check LLDP Agent Status
```powershell
# View LLDP agent status on all adapters
Get-NetLldpAgent

# Check specific adapter
Get-NetLldpAgent -NetAdapterName "Ethernet 4"
```

#### 3. Retrieve LLDP Neighbor Information
```powershell
# Get LLDP neighbors for a specific adapter
Get-NetLldpAgent -NetAdapterName "Ethernet 4" | Where-Object {$_.Scope -eq 'NearestBridge'}

# View neighbor TLV data (what the tool processes)
$neighbor = Get-NetLldpAgent -NetAdapterName "Ethernet 4" | Where-Object {$_.Scope -eq 'NearestBridge'}
$neighbor.Neighbor.Tlvs
```

### Sample Output from NetLLDPAgent

When you run `Get-NetLldpAgent`, you'll see output like this:

```powershell
PS> Get-NetLldpAgent -NetAdapterName "Ethernet 4"

Name               : Ethernet 4
Scope              : NearestBridge
MacAddress         : 0C-42-A1-7E-10-1A
Neighbor           : Microsoft.Management.Infrastructure.CimInstance#ROOT/StandardCimv2/MSFT_NetLldpNeighbor
AdminStatus        : EnabledTxRx
OperStatus         : Up
```

The **Neighbor** property contains all the TLV data that our tool processes:

```powershell
PS> $neighbor = Get-NetLldpAgent -NetAdapterName "Ethernet 4" | Where-Object {$_.Scope -eq 'NearestBridge'}
PS> $neighbor.Neighbor.Tlvs | Select-Object TlvType, TlvName, Data

TlvType TlvName              Data
------- -------              ----
      1 Chassis ID          4 36 22 157 159 8 164
      2 Port ID             5 69 116 104 101 114 110 101 116 49 47 50 57
      5 System Name         84 79 82 45 83 119 105 116 99 104 45 48 49
      6 System Description  67 105 115 99 111 32 78 101 120 117 115...
    127                     3 0 1 0 2 48 50 2 0 0 0 0 0 2 2 2 0 0 0 0 0
```

### Manual LLDP Discovery Process

If you want to manually verify LLDP discovery on a single adapter:

```powershell
# Step 1: Enable LLDP agent
Enable-NetLldpAgent -NetAdapterName "Ethernet 4"

# Step 2: Wait for neighbor discovery (30-60 seconds)
Start-Sleep -Seconds 30

# Step 3: Check for neighbors
$lldpAgent = Get-NetLldpAgent -NetAdapterName "Ethernet 4" -Scope NearestBridge
if ($lldpAgent.Neighbor) {
    Write-Host "LLDP neighbor discovered on Ethernet 4!"
    $lldpAgent.Neighbor.Tlvs | Format-Table TlvType, TlvName, Data -AutoSize
} else {
    Write-Host "No LLDP neighbor found on Ethernet 4"
}
```

This manual process shows what the automated tool does across all adapters on all nodes simultaneously.

## Practical Examples

### Example 1: Connection Discovery

**Scenario**: Verify that host network adapters are connected to the correct switch ports.

**Raw TLV Data**:
```json
"Port ID": {
  "Data": "5 69 116 104 101 114 110 101 116 49 47 50 57",
  "TlvType": 2
}
```

**Conversion Process**:
- Subtype 5 = Interface name format
- Bytes [69, 116, 104, 101, 114, 110, 101, 116, 49, 47, 50, 57] → ASCII
- **Result**: "Ethernet1/29"

**Business Value**: Confirms the host adapter "ethernet 4" is connected to switch port "Ethernet1/29", enabling network administrators to validate cable connectivity.

### Example 2: VLAN Configuration Validation

**Scenario**: Ensure storage traffic is on the correct VLAN.

**Raw PVID TLV Data**:
```json
"Port VLAN ID": {
  "Data": "0 99",
  "TlvType": 127,
  "Oui": "0 128 194",
  "OuiSubtype": 1
}
```

**Conversion Process**:
- IEEE 802.1 extension for PVID
- Bytes [0, 99] → 16-bit integer: 99
- **Result**: Native VLAN ID = 99

**VLAN Name TLV**:
```json
"VLAN Names": [
  {
    "Data": "2 203 2 204 7 83 116 111 114 97 103 101",
    "TlvType": 127,
    "Oui": "0 128 194", 
    "OuiSubtype": 3
  }
]
```

**Conversion Process**:
- VLAN ID 711 (2×256 + 203), Length 7, Name "Storage"
- VLAN ID 712 (2×256 + 204), Length 7, Name "Storage"

**Business Value**: Confirms storage adapters are on VLANs 711-712 named "Storage", validating network segmentation.

### Example 3: QoS and DCB Analysis

**Scenario**: Validate Data Center Bridging configuration for storage traffic.

**Priority Flow Control (PFC) TLV**:
```json
"PFC Config": {
  "Data": "8 8",
  "TlvType": 127,
  "Oui": "0 128 194",
  "OuiSubtype": 11
}
```

**Conversion Process**:
- IEEE 802.1Qbb PFC extension for lossless traffic
- Byte 8 (binary: 00001000) = Priority 3 enabled for PFC
- **Result**: PFC enabled on Priority 3 (RDMA Traffic Class) as required by Microsoft's Azure Local RDMA traffic considerations
- **Requirement**: PFC must be enabled for the RDMA traffic class (Priority 3) to ensure lossless SMB Direct storage traffic in RoCE deployments

**Enhanced Transmission Selection (ETS) TLV**:
```json
"ETS Config": {
  "Data": "3 0 1 0 2 48 50 2 0 0 0 0 0 2 2 2 0 0 0 0 0",
  "TlvType": 127,
  "Oui": "0 128 194",
  "OuiSubtype": 9
}
```

**Conversion Process**:
- Traffic Class assignments and bandwidth allocations per Microsoft's official Azure Local RDMA traffic requirements:
- **System Traffic Class** (Priority 7) → 2% bandwidth reservation (for system heartbeats)
- **RDMA Traffic Class** (Priority 3) → 50% bandwidth reservation (for lossless SMB Direct storage traffic)
- **Default Traffic Class** (Priority 0) → Remaining bandwidth (for VM traffic and management)

**Business Value**: Confirms Data Center Bridging (DCB) configuration aligns with Microsoft's official Azure Local RDMA traffic considerations, ensuring proper bandwidth allocation for system heartbeats (2%), lossless storage traffic (50%), and default traffic classes as required for RoCE deployments.

## Output Files and Analysis

### Generated Files

1. **NBRLLDPTLV_[hostname].json**: Raw LLDP TLV data for each host
2. **HOSTADAPTER_[hostname].json**: Local adapter information for each host  
3. **MergedLLDPData.json**: Processed and structured data combining remote and local information
4. **Node2Switch.json**: Connection mapping showing which host adapters connect to which switch ports
5. **Switch2Node.json**: Reverse mapping from switch perspective
6. **Connections.json**: Comprehensive connection analysis

### Sample Analysis Output

```json
{
  "10.0.1.100": {
    "ethernet 4": {
      "RemoteChassisID": "24:16:9D:9F:08:A4",
      "RemoteSystemName": "TOR-Switch-01.contoso.local",
      "RemotePortID": "Ethernet1/29",
      "RemoteMaxFrameSize": 9216,
      "RemoteNativeVLAN": 99,
      "RemoteVLANIDs": [711, 712],
      "LocalAdapterName": "ethernet 4",
      "LocalAdapterDescription": "Mellanox ConnectX-5 Ex Adapter #2",
      "LocalAdapterLinkSpeed": "10 Gbps"
    }
  }
}
```

## Key Benefits of Invoke-AzStackHciLLDPValidation

### For Deployment Teams Using Azure Stack Environment Validator
- **Integrated Validation**: Seamlessly integrates with the broader Azure Local environment validation workflow
- **Automated Network Verification**: Part of the comprehensive pre-deployment validation that checks all system readiness aspects
- **Environment Validator Results**: Provides structured validation results that integrate with other environment checks
- **Self-Service Validation**: Enables deployment teams to validate network readiness without network team dependency

### For Azure Local Environment Readiness
- **Comprehensive Environment Check**: Network validation as part of complete Azure Local readiness assessment  
- **Pre-Deployment Confidence**: Ensures network infrastructure is ready before cluster deployment begins
- **Integrated Reporting**: Network validation results combine with compute, storage, and other infrastructure checks
- **Deployment Risk Reduction**: Identifies network issues early in the validation process, preventing deployment failures

## Common Use Cases for Invoke-AzStackHciLLDPValidation

### Azure Stack Environment Validator Integration
1. **Comprehensive Environment Validation**: Run as part of the complete Azure Local environment readiness check using `Invoke-AzStackHciEnvironmentChecker`
2. **Pre-Deployment Network Validation**: Execute standalone network validation before cluster deployment begins
3. **Environment Validator Workflow**: Integrate LLDP validation with compute, storage, and other infrastructure readiness checks

### Specific Network Validation Scenarios
4. **Physical Connection Verification**: Validate all network cables are connected to correct switch ports per deployment plan
5. **Switch Compatibility Check**: Ensure connected switches support required LLDP TLVs and Azure Local features
6. **Network Configuration Validation**: Verify VLAN settings, MTU configurations, and QoS parameters across all nodes
7. **Deployment Readiness Assessment**: Generate comprehensive network validation reports for deployment team review


## Frequently Asked Questions (FAQ)

### Q: When should I run Invoke-AzStackHciLLDPValidation during Azure Local deployment?
**A:** This function is typically executed as part of the comprehensive Azure Stack Environment Validator workflow, but can also be run standalone for focused network validation.

**Integration Approaches:**
1. **As part of Environment Validator**: Run `Invoke-AzStackHciEnvironmentChecker` which includes LLDP validation
2. **Standalone Network Validation**: Execute `Invoke-AzStackHciLLDPValidation` directly for network-focused validation
3. **Pre-Deployment Timing**: Run after cable installation but before cluster creation

**Best Practice Timeline:**
1. Data center team completes cable installation
2. **Run Azure Stack Environment Validator** (includes LLDP validation)
3. Fix any network connection issues found
4. Begin Azure Local cluster deployment

### Q: How does Invoke-AzStackHciLLDPValidation integrate with the Environment Validator?
**A:** The function seamlessly integrates with the broader Azure Local environment validation workflow:

- **Unified Execution**: Runs automatically when `Invoke-AzStackHciEnvironmentChecker` is executed
- **Structured Results**: Returns standardized Azure Local result objects that integrate with other validation checks
- **Combined Reporting**: Network validation results are included in comprehensive environment assessment reports
- **Prerequisite Validation**: Can be run independently to validate network readiness before other environment checks

### Q: What should I do if Invoke-AzStackHciLLDPValidation finds network issues?
**A:** Follow this systematic remediation process:

**Immediate Actions:**
1. **Review Validation Results** - Examine the detailed output and generated JSON files
2. **Identify Root Cause** - Determine if issues are cable connections, switch configuration, or LLDP settings
3. **Document Findings** - Save validation results for troubleshooting reference

**Remediation Process:**
4. **Physical Verification** - Check cable connections against deployment documentation
5. **Switch Configuration Review** - Verify LLDP is enabled and properly configured on switch ports
6. **Coordinate Fixes** - Work with network/data center teams to resolve identified issues
7. **Re-run Validation** - Execute the function again to verify all issues are resolved before proceeding with deployment
