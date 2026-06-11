# Azure Local: LLDP, DCBX, and PFC Configuration Guide

| Field | Value |
|---|---|
| **Component** | Networking / Top-of-Rack Switch / RDMA (RoCEv2) |
| **Severity** | High |
| **Applicable Scenarios** | Azure Local clusters using RoCEv2 storage with Mellanox ConnectX or Intel E810 NICs and Cisco NX-OS or Aruba CX top-of-rack switches |
| **Affected Versions** | Azure Local 23H2 and later |
| **Audience** | Azure Local operators and network engineers |
| **Document Version** | 1.0 (2026-06-10) |

> **Version naming used in this guide.** "23H2" is the Azure Local release family;
> "12.2607" is a specific Azure Local solution (build) version within that family.
> Where a behavior or platform fix is tied to a particular build, this guide cites
> the solution version (for example, 12.2607); where guidance applies to the whole
> release, it says 23H2. To read your own build, run `Get-AzureStackHCI` (or check
> the Azure portal) and compare the reported solution version to the build cited.

> **Start here (TL;DR).** If your storage NICs are Mellanox ConnectX, your
> top-of-rack switches are Cisco NX-OS or Aruba CX, and you see PFC failing to
> stay on or an Aruba `multiple_peers` LLDP error on storage ports, this guide
> confirms a dual LLDP-agent conflict (Diagnosis Steps) and then fixes it in three
> moves: make the Windows LLDP agent durable (Resolution Step 1), force PFC on at
> the switch (Resolution Step 2), and disable the Mellanox firmware LLDP agent
> (Resolution Step 3).
>
> **Plan a maintenance window.** Working this guide end to end touches NIC
> firmware and resets or reboots storage NICs node by node. Schedule **at least a
> 4-hour maintenance window for a 4-node cluster**, and budget longer for larger
> clusters or for clusters whose storage plane has no card-level redundancy
> (single card per plane), where each node must be drained and rebooted in
> sequence. The Diagnosis steps are read-only and safe during production hours;
> the Resolution steps are not.

## Contents

1. [Relationship to Official Documentation](#relationship-to-official-documentation)
2. [Recommended Configuration (RoCEv2 Deployments)](#recommended-configuration-rocev2-deployments)
3. [Problem](#problem)
4. [Symptoms](#symptoms)
5. [Affected Configurations](#affected-configurations)
6. [Contributing Factors](#contributing-factors)
7. [Running the PowerShell in this guide](#running-the-powershell-in-this-guide)
8. [Mapping NIC Roles to Switch Ports](#mapping-nic-roles-to-switch-ports)
9. [Diagnosis Steps](#diagnosis-steps)
10. [Resolution](#resolution)
11. [Verification After Remediation](#verification-after-remediation)
12. [Prevention](#prevention)
13. [Background: DCBX Dialects and Why They Matter](#background-dcbx-dialects-and-why-they-matter)
14. [Known Limitations and Open Items](#known-limitations-and-open-items)
15. [References](#references)
16. [Appendix A: Test Evidence Matrix](#appendix-a-test-evidence-matrix)
17. [Appendix B: Switch-Side Command Reference](#appendix-b-switch-side-command-reference)
18. [Appendix C: Acronym Quick Reference](#appendix-c-acronym-quick-reference)

## Relationship to Official Documentation

This guide supplements the official Azure Local network requirements
documentation. It does not replace or contradict the published guidance.

**Official requirements (from Microsoft Learn):**
- Switches must comply with IEEE 802.1Qbb, Priority Flow Control (PFC),
  IEEE 802.1Qaz, Enhanced Transmission Selection (ETS), and IEEE 802.1AB,
  Link Layer Discovery Protocol (LLDP)
- Data Center Bridging (DCB), meaning PFC + ETS, is required for RDMA
  over Converged Ethernet version 2 (RoCEv2) and optional for Internet
  Wide Area RDMA Protocol (iWARP)
- Remote Direct Memory Access (RDMA) traffic class: Priority 3, PFC
  enabled, 50% bandwidth reservation
- Cluster heartbeat traffic class: Priority 7, 1% bandwidth reservation
- Switches should advertise LLDP Type-Length-Value (TLV) fields including
  Data Center Bridging Exchange (DCBX) PFC and ETS Configuration TLVs on
  storage ports

**How this guide refines the official guidance:**
The official documentation states that DCBX TLVs "must be dynamically
enabled." This means the switch should be capable of advertising DCBX TLVs
via LLDP. It does NOT mean PFC must be negotiated dynamically via DCBX.
This guide prescribes forcing PFC ON at the switch (rather than relying on
DCBX negotiation) because DCBX-negotiated (auto) PFC does not converge once
the cluster is in the remediated single-LLDP-agent state (see Contributing
Factors and
Appendix A). Forced PFC is fully compatible with the IEEE 802.1Qbb
requirement; it simply removes the dependency on a successful DCBX handshake
and therefore hardens the RDMA configuration for Azure Local cluster storage
traffic.

**What this guide adds:**
- Diagnosis and resolution for DCBX interoperability issues between
  Mellanox ConnectX Network Interface Card (NIC) firmware and specific
  switch platforms (Aruba CX,
  Cisco NX-OS)
- Guidance on forced PFC configuration as a reliable alternative to
  DCBX-negotiated PFC when firmware-level DCBX TLV conflicts prevent
  negotiation from converging
- Guidance on installing and using the Mellanox Firmware Tools (WinMFT)
  to diagnose and configure NIC firmware LLDP/DCBX settings
- A mitigation for an Azure Local platform bug in which the Windows LLDP
  agent, enabled by the pre-deployment Environment Validator, was not kept
  enabled across operating system reboots, along with guidance on which
  clusters still require the mitigation

**Important note on DCBX and forced PFC:**
The official documentation requires switches to support DCBX TLV
advertisement. This guide recommends forcing PFC on the switch rather than
relying on DCBX negotiation. This does not disable DCBX on the switch; it
only changes PFC from negotiated to locally enforced, so DCBX TLVs (including
ETS and Application Priority) can still be exchanged for telemetry. Advertising
the DCBX TLVs over LLDP may require a platform-specific option (for example, the
`send-tlv` keyword on the `priority-flow-control` line on some Cisco NX-OS
versions; consult your switch vendor's documentation for whether the option is
supported on your firmware version and for the equivalent on Aruba CX or other
platforms). When the switch is configured to advertise DCBX TLVs, set
switch-side DCBX Willing to False so the host stays authoritative. See
[Reference-TOR-QOS-Policy-Configuration.md](./Reference-TOR-QOS-Policy-Configuration.md)
for the switch-side QoS, DCBX, and TLV-advertisement details. The only change
forced PFC introduces is that PFC activation no longer depends on a successful
DCBX handshake, which avoids the DCBX auto-negotiation issue described in this
guide.

For the official network requirements and background on RDMA, DCBX, and related concepts, see:
- [Host network requirements for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/concepts/host-network-requirements)
- [Physical network requirements for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/plan/physical-network-requirements)

## Recommended Configuration (RoCEv2 Deployments)

For any Azure Local cluster using RoCEv2 for storage RDMA, the recommended
configuration is:

**Host side:**
- Windows LLDP agent: **Enabled** by Azure Local's pre-deployment Environment
  Validator. Keep it enabled durably with the Step 1 toggle in the Resolution
  section (otherwise the enablement is lost on the next reboot). See Resolution Step 1 for
  which clusters still require the toggle on Azure Local 12.2607 and later.
- Mellanox NIC firmware LLDP agent: **Disabled** (this may require a `mlxconfig` change)
- Intel NIC firmware LLDP agent: see the Intel note in Resolution Step 3
  (whether a competing Intel firmware agent is present is not established on the
  tested adapters; if one is active alongside the Windows agent, the same
  single-agent guidance applies)
- DCBX Willing: **False** (required, host-authoritative). The Willing flag
  decides who wins when the host and the switch disagree on DCBX settings:
  Willing = True means "defer to the switch's settings," and Willing = False
  means "use the host's own settings and ignore what the switch advertises."
  Azure Local sets the host DCBX Willing flag to False; the Resolution Step 1 toggle
  re-asserts it so the posture is preserved across reboots. Do not set
  Willing to True.

**Switch side:**
- PFC: **Forced ON** for priority 3 on **storage ports only**. Do not use
  AUTO or DCBX-negotiated PFC on storage ports.
  - Cisco NX-OS: `priority-flow-control mode on` (already the default on
    most Azure Local validated switch templates)
  - Aruba CX (AOS-CX): `flow-control priority rxtx 3` on each storage
    interface (priority 3 must be mapped to a lossless queue/pool, which the
    standard Azure Local Aruba template already configures)
  - Dell OS10: `priority-flow-control mode on`
  - Arista EOS: `priority-flow-control mode on`
- Compute and management ports: set PFC **explicitly OFF**. These ports carry
  TCP traffic that handles retransmission at the transport layer, and Microsoft's
  traffic-class model places all management and VM/compute traffic in the default
  class, which is defined as PFC-disabled (priority 0, no host PFC configuration).
  Setting these ports explicitly OFF (rather than leaving them at AUTO) is
  deterministic, keeps them out of any DCBX negotiation, and avoids the same
  PFC auto-negotiation issue that affects storage ports. Enabling PFC on
  compute ports is unnecessary and can cause unintended pause behavior on VM
  traffic.
  - Cisco NX-OS: `priority-flow-control mode off`
  - Aruba CX (AOS-CX): no `flow-control priority` mapping on the interface (leave
    the lossless priority unconfigured on management/compute ports)
  - Dell OS10: `priority-flow-control mode off`
  - Arista EOS: `priority-flow-control mode off`

  > **Special case (converged topology):** The explicit-OFF guidance applies to a
  > disaggregated design, where storage runs on dedicated NICs and the
  > management/compute ports carry no RDMA. In a **fully converged** design, the
  > same physical port trunks storage, compute, and management on different
  > priorities, so that port must keep PFC **forced ON** for the storage priority;
  > do not set it OFF. Use the "Mapping NIC Roles to Switch Ports" section to
  > confirm which model applies before configuring any port.
  >
  > Guest (in-VM) RDMA does **not** create an exception here: Guest RDMA is not
  > supported on Azure Local, so tenant VMs and AKS Arc nodes (which run as VMs)
  > never carry RDMA on the compute ports. There is no workload that requires PFC
  > on a disaggregated compute port.

**Why forced PFC, not AUTO:** the recommended remediation disables the
Mellanox firmware LLDP agent to resolve the dual-agent conflict (see
Contributing Factors). In that single-agent state the host transmits bare LLDP with no DCBX
TLVs at the NDIS layer (CONFIRMED by direction-split packet capture; see
Appendix A), yet a switch in AUTO mode still detects the Mellanox host as `CIN`
and PFC auto-negotiation does not converge (likely from legacy CEE TLVs the
firmware adds below the capture point and the absence of a clean IEEE peer; see
Contributing Factors). Forcing PFC bypasses the DCBX handshake entirely and is
dialect-independent, which makes it the safe universal configuration for both
Mellanox and Intel clusters.

**The Willing flag is not the cause of the PFC failure.** The DCBX dialect
(IEEE vs CEE) is the sole factor that determines whether PFC converges, not the
DCBX Willing flag. Set the host Willing flag to False (host-authoritative);
this is the required posture. Do not set Willing to True.

> **Corroborating Azure Local guidance (this guide does not change these
> settings).** The priority and PFC posture above is the established Azure Local
> baseline, documented elsewhere in this repository. This troubleshooting guide
> promotes the same settings and exists to explain a dual-LLDP-agent failure
> mode that prevents them from taking effect, plus how to resolve it. For the
> baseline configuration these recommendations align with, see:
> - [Reference-TOR-QOS-Policy-Configuration.md](./Reference-TOR-QOS-Policy-Configuration.md):
>   priority-3 storage (RDMA) as a no-drop class, priority-7 cluster, host-authoritative
>   DCBX with Willing=False, and forced PFC on storage.
> - [Reference-TOR-Explicit-Congestion-Notification.md](./Reference-TOR-Explicit-Congestion-Notification.md):
>   ECN/WRED congestion handling for the lossless storage class.
> - Per-topology switch templates that apply forced PFC on storage ports:
>   [Fully-Converged](./Reference-TOR-Fully-Converged-Storage.md),
>   [Disaggregated](./Reference-TOR-Disaggregated-Switched-Storage.md), and
>   [2-Node Switchless](./Reference-TOR-2Node-Switchless-Storage.md).

## Problem

Azure Local clusters using Mellanox ConnectX NICs with RoCEv2 storage may
experience PFC failures when connected to switches that negotiate PFC
through DCBX. The trigger is a dual-LLDP-agent conflict on each storage port:
the Windows OS agent and the Mellanox NIC firmware agent are both active (see
the dual-agent description below). Once the firmware agent is disabled to
resolve that conflict, the host operating-system LLDP agent transmits bare
LLDP with no DCBX TLVs at the NDIS layer (CONFIRMED by direction-split packet
capture; see Appendix A). Even so, a Cisco switch port configured for PFC
auto-negotiation detects the affected Mellanox host as `CIN` (Cisco/Intel/Nuova)
and PFC does not converge, while a port on the same host configured for forced
PFC (`mode on`) detects `IEEE 802.1` and PFC stays up (CONFIRMED on Cisco
NX-OS 10.3(4a)). The most likely explanation is that the ConnectX firmware
continues to add legacy CEE DCBX TLVs to the host's outbound LLDP frames below
the NDIS capture point, which a switch in auto mode reads as a CIN-only peer
(LIKELY; not captured on the wire, as confirming it requires switch-side port
mirroring that was not available). Because auto-negotiation is unreliable for
this reason, PFC must be forced at the switch.

Additionally, on Mellanox-based clusters two LLDP agents are typically active
on each storage port at the same time: the Windows OS agent, which Azure
Local's pre-deployment Environment Validator (Environment Checker) enables on
the physical adapters so it can read the switch-side DCBX and PFC
advertisements during validation, and the Mellanox NIC firmware agent, which
is enabled by the NIC firmware default and is not disabled during deployment.
The Windows LLDP agent lifecycle is owned by the operating system (the
`Mslldp` agent), not by NetworkATC (Azure Local's host networking
configuration engine). Azure Local does not deliberately configure a
dual-agent setup; the dual-agent state is the combined result of the
Environment Validator enabling the Windows agent and the firmware shipping with
its own agent enabled. The two agents produce two conflicting LLDP identities
per port and can cause switches to enter a "multiple peers" state that blocks
DCBX negotiation entirely.

When PFC is inactive, RDMA storage traffic, specifically Server Message
Block (SMB) Direct over RoCEv2, loses its lossless guarantee. Under load,
this can
cause storage timeouts, RDMA.Alert health faults, and in severe cases,
Cluster Shared Volume (CSV) access failures and VM disruption.

On Intel E810 Network Interface Cards (NICs) with the Windows LLDP agent
active, host egress is also bare LLDP with no DCBX TLVs (CONFIRMED by a
direction-split capture on an Intel node), so the host-sent DCBX dialect is
not what distinguishes the vendors. What matters is whether the NIC also runs
a competing firmware LLDP agent; this is established for Mellanox ConnectX and
is a data gap for Intel E810 on the tested adapters. Intel E810 supports both
iWARP and RoCEv2; if an Intel cluster is configured for RoCEv2, PFC is still
required and should be forced ON at the switch.

## Symptoms

Operators may observe one or more of the following:

- `Microsoft.Health.FaultType.StorageSubsystem.RDMA.Alert` health faults
  oscillating across cluster nodes
- `Get-NetAdapterQos` shows `OperationalFlowControl` missing priority 3
  or `RemoteFlowControl: Not Available`
- Switch-side `show interface priority-flow-control` shows `PFC Oper Off`
  on storage ports configured with PFC auto
- Switch-side `show lldp dcbx` shows `Detected: CIN` (instead of IEEE) on
  storage ports in PFC auto mode, while a port on the same host configured for
  forced PFC (`mode on`) shows `IEEE 802.1` (observed on Cisco NX-OS 10.3(4a)).
  The likely cause is legacy CEE DCBX TLVs that the Mellanox firmware adds below
  the host capture point; this was not confirmed on the wire (see Contributing
  Factors and Known Limitations).
- Switch-side `show lldp neighbors` shows two different chassis-IDs per
  storage port (MAC-based from NIC firmware and hostname-based from Windows)
- On Aruba CX: `DCBx operational state: multiple_peers` and
  `PFC operational state: inactive` on cluster storage ports.
  This behavior was observed on AOS-CX 10.16.1030. Earlier versions
  (e.g., 10.13.1150) may silently pick one LLDP peer and converge, masking
  the dual-agent issue until an upgrade exposes it.
- On Cisco NX-OS: PFC auto mode fails to converge despite PFC being
  configured on both host and switch
- Periodic storage latency spikes or SMB Direct connection drops during
  normal operation

## Affected Configurations

| Component | Affected | Not Affected |
|---|---|---|
| NIC | Mellanox ConnectX-6 Lx, ConnectX-6 Dx (runs a competing firmware LLDP agent) | Intel E810 (competing firmware LLDP agent not confirmed on tested adapters; see the Intel note in Step 3) |
| RDMA Transport | RoCEv2 (requires PFC) | iWARP (PFC not required, but note: Intel E810 supports both iWARP and RoCEv2; if configured for RoCEv2, PFC is required) |
| Switch: Aruba CX | Affected (multiple_peers deadlock) | N/A |
| Switch: Cisco NX-OS 10.3(4a) | Affected: PFC auto does not converge (switch reports `Detected: CIN`, likely from legacy CEE DCBX TLVs the NIC firmware adds below the host capture point; see Contributing Factors) | Not affected when PFC mode on (forced) |
| Switch: Dell OS10 / SONiC | Potentially affected (untested) | N/A |
| Switch: Arista EOS | Potentially affected (untested) | N/A |

### RDMA Transport Availability by NIC Vendor

Not all NIC vendors support both RDMA transports. This determines whether
PFC is mandatory for a given cluster.

| NIC Vendor | iWARP | RoCEv2 | PFC Required? |
|---|---|---|---|
| NVIDIA / Mellanox | Not available | Yes | **Always** (RoCEv2 is the only option) |
| Intel | Yes | Yes (E810 series) | Only if configured for RoCEv2; not required for iWARP |
| Marvell (QLogic) | Yes | Yes | Only if configured for RoCEv2 |
| Broadcom | Not available | Yes | **Always** (same as Mellanox) |

**Key implication:** If a cluster uses Mellanox or Broadcom NICs, PFC is
always required because RoCEv2 is the only RDMA transport available. There
is no iWARP fallback. This makes the forced PFC recommendation mandatory,
not optional, for these NIC vendors.

## Contributing Factors

Three independent factors contribute to PFC failures on Mellanox clusters.
Any one of them can cause problems, and a given cluster may exhibit all three or only a subset.

### Factor 1: Dual LLDP Agent (Host Side)

On Mellanox-based clusters, two LLDP agents are typically active on each
storage port at the same time. Azure Local's pre-deployment Environment
Validator enables the Windows agent on the physical adapters (to validate the
switch DCBX and PFC advertisements before deployment); the NIC firmware agent
is enabled by the firmware's own default and is not disabled during
deployment:

| Agent | Identity | TTL | DCBX TLVs | Source |
|---|---|---|---|---|
| Windows `mslldp.sys` | Hostname (e.g., `NODE01`) | ~120s | None (bare LLDP, CONFIRMED on host egress) | OS networking stack |
| Mellanox NIC firmware | NIC MAC address | ~30s | IEEE 802.1 DCBX (clean) | NIC firmware |

The two agents race on each storage port. The switch sees one identity at
a time (on Cisco NX-OS) or both simultaneously (on Aruba CX).

On Aruba CX, seeing two chassis-IDs on the same port causes the switch to
enter `DCBx operational state: multiple_peers`, where it refuses to
negotiate DCBX with either agent and PFC goes inactive. This Aruba behavior is
inferred from a production deployment; it was not reproduced in the
in-house Cisco test matrix.

### Factor 2: Cisco Auto-Negotiation Detects CIN, Not IEEE

The Mellanox firmware LLDP agent is the component that supplies clean IEEE
802.1Qaz DCBX (OUI `00:80:C2`) to the switch. When it is the sole active agent
(Windows agent disabled), a Cisco NX-OS switch in auto mode detects
`IEEE 802.1` and PFC auto-negotiation succeeds (CONFIRMED on Cisco NX-OS
10.3(4a); see Appendix A, states C1/C2).

Disabling the firmware agent to resolve the dual-agent conflict (Factor 1)
removes that clean IEEE speaker. Direction-split packet capture confirms that
the Windows OS agent transmits bare LLDP with no DCBX TLVs at the host NDIS
layer, on both Mellanox and Intel (CONFIRMED; Appendix A, states A1/A2). Yet in
this state a Cisco port in PFC auto mode still reports `Detected: CIN` with
`Willing=No` and PFC does not converge, while a port on the same Mellanox host
configured for forced PFC reports `IEEE 802.1` and PFC stays up (CONFIRMED on
Cisco NX-OS 10.3(4a)).

Two mechanisms can produce this `CIN` result, and both lead to the same
conclusion: do not rely on auto PFC.

1. **Conflicting DCBX dialects on the wire.** An earlier (non-direction-split)
   capture near the Mellanox host showed both IEEE 802.1 (`00:80:C2`) and legacy
   CEE (`00:1B:21`) DCBX TLVs. When a switch port in auto mode sees both
   dialects, it cannot settle on one and reports `CIN`. The likely source of the
   CEE is the Mellanox ConnectX firmware adding the legacy TLVs to the host's
   outbound frames below the NDIS capture point, which is why the host NDIS
   capture looks bare while the switch still receives CEE (LIKELY; the
   direction-split capture attributed the two TLVs to the switch's inbound side,
   and no switch-side port mirror was available to localize them on the wire).
2. **No clean IEEE peer presented by the host.** With the firmware agent
   disabled, the host no longer presents a usable IEEE DCBX peer, so a switch
   port in auto mode has nothing to converge on and falls back to its `CIN`
   default.

The available evidence does not isolate which mechanism dominates, and they are
not mutually exclusive. Note that whatever the firmware contributes, it is not
unconditional CEE: when the firmware agent is the sole active agent (states
C1/C2), the switch detects clean IEEE 802.1, so auto PFC converges in that
state.

The practical consequence is the same under either mechanism: with the firmware
agent disabled, PFC must be forced at the switch so that activation does not
depend on DCBX auto-negotiation.

### Factor 3: Switch PFC Mode (Switch Side)

Most Azure Local switch configurations use `priority-flow-control mode on`
(locally forced PFC), which is not affected by DCBX negotiation issues.
However, some deployments use `priority-flow-control auto` or rely on DCBX
to negotiate PFC. In these configurations, Factors 1 and 2 prevent PFC
from converging.

## Running the PowerShell in this guide

The PowerShell blocks in this guide are meant to be copied and pasted, in full,
into an **elevated** Windows PowerShell session on a cluster node (open it from an
RDP session to the node, or from the node's local console). Right-click PowerShell
and choose "Run as administrator"; the storage, cluster, and firmware cmdlets used
here require it.

Most of the larger blocks run cluster-wide from a single node: they call
`Get-ClusterNode` and `Invoke-Command` to fan out to every node, so you only need
to paste them on one node, not on each node in turn. Where a command must be run
locally on a specific node (for example the firmware reset in Resolution Step 3), the step
says so explicitly. The switch-side commands are different: those are entered on
the top-of-rack switch CLI, not in PowerShell, and each such block is labeled with
the switch vendor it applies to.

> When you paste a multi-line block, paste the whole block at once. The PowerShell
> prompt will show continuation markers (`>>`) for the inner lines; that is normal.
> Press Enter once after the final line if the prompt does not return on its own.

> **Tip: capture the output to a file for Microsoft Support.** The discovery
> commands in this guide are read-only, so it is safe to record an entire session
> to a transcript file. If you may need to share results with Microsoft Customer
> Support, start a transcript before you begin and stop it when you are done:
>
> ```powershell
> Start-Transcript -Path "C:\Temp\LLDP-DCBX-PFC_$($env:COMPUTERNAME)_$(Get-Date -Format yyyyMMdd-HHmmss).txt"
> # ... run the discovery steps in this guide ...
> Stop-Transcript
> ```
>
> The transcript captures every command and its output in one text file you can
> attach to a support case. Note that it records everything typed in the session,
> so review the file before sharing.

## Mapping NIC Roles to Switch Ports

> **Prerequisite, do this first.** Complete this mapping before the Diagnosis and
> Resolution steps. Diagnosis Steps 4 through 6 and every Resolution step reference
> the per-port storage and mgmt/compute map you build here. If you jump straight
> into the diagnosis scripts you will stall at the first "Which ports?" callout.

Before you run any switch-side command that targets specific ports (the
diagnosis steps below, the forced PFC policy in the Resolution section, and the
switch-side verification), you must know which physical switch port on each
top-of-rack (ToR) switch connects to which **role** of host NIC. The PFC policy
is asymmetric (forced PFC on storage ports, explicitly off on management and
compute ports), so applying it to the wrong port is a real risk. This section shows how
to build, on each node, a list of storage NIC MAC addresses and a separate list
of management/compute NIC MAC addresses, then correlate those MACs to specific
switch ports so the correct ports can be identified, labeled, and configured.

Work through this once per cluster. The host MAC addresses are stable, so the
mapping is durable until you re-cable or replace a NIC.

### First, determine your network topology

Azure Local clusters use one of two network topologies, defined by how NetworkATC
intents assign physical NICs to traffic types. The correct PFC policy depends on
which one you have, so determine this before mapping or configuring any port.

| Topology | What it means | How NICs carry traffic | Storage-port PFC | Mgmt/compute-port PFC |
|----------|---------------|------------------------|------------------|-----------------------|
| **Disaggregated** | Storage runs on its own dedicated NICs, separate from management/compute | Distinct physical NICs per role; storage NICs carry only RDMA storage traffic | **Forced ON** (priority 3) | **Explicitly OFF** |
| **Fully converged** | One intent; the same physical NICs carry storage, compute, and management | Every physical NIC trunks storage, compute, and management on different priorities | **Forced ON** (priority 3) | N/A: there are no separate mgmt/compute ports; every port is also a storage port and stays Forced ON |

To determine which you have, list the NetworkATC intents:

```powershell
Get-NetIntent | Select-Object IntentName, IntentType
```

- **Disaggregated:** you will see a **dedicated storage intent** (its `IntentType`
  prints as `Storage`) separate from the management/compute intent (whose
  `IntentType` prints as a number such as `10`, because it combines management and
  compute). Storage runs on its own NICs. This is the asymmetric case, and the
  rest of this section and the forced-ON/explicit-OFF policy in Step 2 apply
  directly.
- **Fully converged:** you will see a **single intent** whose `IntentType` combines
  storage with management and compute (no separate `Storage` intent). Every
  physical NIC is a storage port. There is no asymmetry to configure: force PFC ON
  on all of those host ports and do not set any of them OFF.

The remainder of this section is written for the disaggregated topology (the
common Azure Local deployment model and the one in scope for this guide). If your
cluster is fully converged, classify every physical NIC as a storage port and
force PFC ON on all of them.

### Step A: Classify host NIC ports by role and collect MACs

The authoritative source for which adapters are storage versus
management/compute is the NetworkATC intent that assigned them. Do not infer the
role from "RDMA enabled": in a converged or partly converged design, the
management and compute uplinks are often RDMA-capable Mellanox ports too, and
they also report RDMA enabled, so classifying on RDMA alone mislabels them as
storage.

Instead, read the storage adapter list directly from the `Storage`-type intent.
NetworkATC exposes that list in the intent's `NetAdapterNamesAsList` field (the
singular `NetAdapterName` is blank on most builds). Any physical adapter named in
the storage intent is a storage port; every other physical adapter is a
management/compute port. Run the following **once** from any node in the cluster;
it loops over every node with `Get-ClusterNode` so you do not have to collect
MACs node by node:

```powershell
# Collect and classify the physical NICs on EVERY cluster node in one pass.
# The NetworkATC intents are the authoritative source: an adapter is Storage if
# it is in the Storage intent, Mgmt/Compute if it is in the management/compute
# intent, and "Other" if it is in no intent at all (for example a Dell onboard
# LOM or BMC-shared port that NetworkATC does not manage).
$nodes = (Get-ClusterNode).Name      # or list node names explicitly
$rows = Invoke-Command -ComputerName $nodes -ScriptBlock {
    # Adapter names for each plane come straight from the intents. They live in
    # NetAdapterNamesAsList (NetAdapterName is blank on most builds). Normalize to
    # an array whether the field is a real array or a single comma-joined string.
    $storageIntent   = Get-NetIntent | Where-Object { $_.IntentType -match 'Storage' }
    $storageAdapters = @($storageIntent.NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }
    $mgmtIntent      = Get-NetIntent | Where-Object { $_.IntentType -notmatch 'Storage' }
    $mgmtAdapters    = @($mgmtIntent.NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }

    foreach ($nic in Get-NetAdapter -Physical -ErrorAction SilentlyContinue) {
        # No dedicated Storage intent => the cluster is fully converged; every
        # physical NIC carries storage (see the converged note after this step).
        # If the mgmt/compute intent list is unreadable on this build, fall back to
        # treating any non-storage adapter as Mgmt/Compute so real uplinks are never
        # hidden. Adapters in NO intent are tagged "Other" so onboard/BMC LOMs do
        # not get mislabeled as mgmt/compute uplinks.
        $role = if (-not $storageAdapters)                   { 'Storage (converged)' }
                elseif ($storageAdapters -contains $nic.Name)  { 'Storage' }
                elseif (-not $mgmtAdapters)                    { 'Mgmt/Compute' }
                elseif ($mgmtAdapters -contains $nic.Name)     { 'Mgmt/Compute' }
                else                                           { 'Other (not in ATC intent)' }
        # Card identity: two ports sharing the same Segment:Bus:Device are the two
        # ports of one dual-port card. Formatted in hex so it matches the
        # seg:bus:dev shown by `mst status -v` (for example 0000:8b:00). Slot is the
        # physical PCI slot, a human-friendly "which card" label (may read blank or
        # 'Onboard' on some platforms; CardNo below is the reliable indicator).
        $hw   = Get-NetAdapterHardwareInfo -Name $nic.Name -ErrorAction SilentlyContinue
        $card = if ($hw) { '{0:x4}:{1:x2}:{2:x2}' -f $hw.Segment, $hw.Bus, $hw.Device } else { '' }
        $slot = if ($hw -and $null -ne $hw.Slot -and $hw.Slot) { "Slot $($hw.Slot)" }
                elseif ($hw) { 'Onboard' } else { '' }
        [pscustomobject]@{
            Node    = $env:COMPUTERNAME
            NIC     = $nic.Name                  # interface alias, e.g. 'ethernet 3'
            Adapter = $nic.InterfaceDescription  # model, e.g. 'Mellanox ConnectX-6 Dx Adapter'
            MAC     = $nic.MacAddress            # format: 00-00-5E-00-53-A1
            Status  = $nic.Status
            Role    = $role
            Card    = $card                      # PCI Segment:Bus:Device (same value = same card)
            Slot    = $slot                      # physical PCI slot label
        }
    }
} | Select-Object Node, NIC, Adapter, MAC, Status, Role, Card, Slot

# Assign a friendly per-node card number (Card 1, Card 2, ...) so two ports on the
# same physical card visibly share a label. This is what makes "same card" obvious.
foreach ($g in ($rows | Group-Object Node)) {
    $i = 0; $map = @{}
    foreach ($c in ($g.Group | Where-Object { $_.Card } |
            Select-Object -ExpandProperty Card | Sort-Object -Unique)) {
        $i++; $map[$c] = "Card $i"
    }
    foreach ($r in $g.Group) {
        $label = if ($r.Card -and $map.ContainsKey($r.Card)) { $map[$r.Card] } else { 'n/a' }
        $r | Add-Member -NotePropertyName CardNo -NotePropertyValue $label -Force
    }
}

# Full table, sorted so each node's ports are grouped by role and physical card.
# (Includes Disconnected ports so you can see the complete inventory.) Ports that
# share a CardNo (or Slot) are on the same physical card.
$rows | Sort-Object Node, Role, Card, NIC |
    Format-Table Node, NIC, MAC, Status, Role, CardNo, Slot, Adapter, Card -AutoSize

# The MAC lists you will carry to the switch. Only 'Up' ports are listed,
# because a Disconnected port has no live link and therefore no entry in the
# switch MAC address table to map (revisit those ports if they later come Up).
# CardNo and Slot show, at a glance, whether the two ports of a plane are on the
# same card (NOT-REDUNDANT) or on different cards (REDUNDANT).
"STORAGE MACs (Up):"
$rows | Where-Object { $_.Role -like 'Storage*' -and $_.Status -eq 'Up' } |
    Sort-Object Node, NIC | Select-Object Node, NIC, Adapter, MAC, CardNo, Slot | Format-Table -AutoSize
"MGMT/COMPUTE MACs (Up):"
$rows | Where-Object { $_.Role -eq 'Mgmt/Compute' -and $_.Status -eq 'Up' } |
    Sort-Object Node, NIC | Select-Object Node, NIC, Adapter, MAC, CardNo, Slot | Format-Table -AutoSize
# Adapters in no ATC intent (for example onboard/BMC LOMs, or the iDRAC RNDIS
# virtual NIC, which shows as 'Remote NDIS Compatible Device' with no Card/Slot).
# These are NOT storage and NOT ATC-managed mgmt/compute uplinks; do not put them
# on the storage switch PFC lists. Listed only so you can account for every port.
"OTHER (not in ATC intent) (Up):"
$rows | Where-Object { $_.Role -like 'Other*' -and $_.Status -eq 'Up' } |
    Sort-Object Node, NIC | Select-Object Node, NIC, Adapter, MAC, CardNo, Slot | Format-Table -AutoSize

# ===== CARD-LEVEL REDUNDANCY VERDICT (printed last so it is the final thing you
# see). One row per node. 'Storage cards' / 'Mgmt cards' = how many distinct
# physical cards that plane's ports are spread across. 2+ on BOTH planes =>
# REDUNDANT (a whole-card mlxfwreset leaves a surviving port in every plane, so
# the firmware reset is safe live). Anything less => NOT-REDUNDANT (a plane sits on one card,
# so resetting it drops the whole plane; drain the node before the firmware reset). This is
# about CARD-level redundancy only; port/cable/switch redundancy, which a
# two-port-per-plane design has either way, is unaffected.
$verdict = foreach ($g in ($rows | Group-Object Node)) {
    $sCards = @($g.Group | Where-Object { $_.Role -like 'Storage*'  -and $_.Card } |
        Select-Object -ExpandProperty Card | Sort-Object -Unique)
    $mCards = @($g.Group | Where-Object { $_.Role -eq 'Mgmt/Compute' -and $_.Card } |
        Select-Object -ExpandProperty Card | Sort-Object -Unique)
    # The card-level redundancy verdict (REDUNDANT/NOT-REDUNDANT) is useful on any
    # vendor, so we always show it. The reset ACTION (Step 3 Option 1/2/3) is
    # Mellanox-only, so on a node with no Mellanox NICs we still report the verdict
    # but mark the action n/a and point to the switch-side neighbor check.
    $hasMlx = @($g.Group | Where-Object { $_.Adapter -match 'Mellanox|ConnectX|NVIDIA' }).Count -gt 0
    $isRedundant = ($sCards.Count -ge 2 -and $mCards.Count -ge 2)
    [pscustomobject]@{
        Node            = $g.Name
        'Storage cards' = $sCards.Count
        'Mgmt cards'    = $mCards.Count
        Verdict         = if ($isRedundant) { 'REDUNDANT' } else { 'NOT-REDUNDANT' }
        'Reset action'  = if (-not $hasMlx)     { 'n/a; Step 3 reset/reboot is Mellanox-only (use switch-side neighbor check)' }
                          elseif ($isRedundant) { 'Live reset OK (no drain)' }
                          else                  { 'DRAIN node first (Option 2 or 3)' }
    }
}
""
"==================== CARD-LEVEL REDUNDANCY VERDICT (firmware reset) ===================="
$verdict | Sort-Object Node | Format-Table -AutoSize
"'Storage cards' / 'Mgmt cards' = how many physical cards back the storage plane"
"and the management/compute plane on that node. NOT-REDUNDANT means at least one"
"of those planes has both its ports on a single card; resetting that card drops"
"the whole plane, so drain the node first. Port/cable/switch redundancy is"
"unaffected. On a non-Mellanox node the verdict is still shown for awareness, but"
"the Reset action reads n/a because Step 3's reset/reboot procedures are"
"Mellanox-only; use the switch-side neighbor check instead."
"=============================================================================="
```

If `Invoke-Command` remoting is not available, run the inner `foreach` block
directly on each node (it works unchanged, using the local adapters).

This script prints a clean **CARD-LEVEL REDUNDANCY VERDICT** table at the very
bottom of its output, one row per node, with `Storage cards` / `Mgmt cards` counts,
a `Verdict` (REDUNDANT or NOT-REDUNDANT), and the matching `Reset action`. Above
that, every table includes a `CardNo` column (Card 1, Card 2, ...) and a `Slot`
column: the two ports of a single dual-port card share the same `CardNo` and
`Slot`, so a glance at the STORAGE MACs and MGMT/COMPUTE MACs tables tells you
whether each plane's two ports are piled on one card or split across two. The
verdict here is the same one the dedicated "Determine card-level redundancy" check
below produces; that snippet is a standalone version for re-checking a single node.

You can view the intent-to-adapter mapping directly to confirm the
classification, including which physical card each adapter sits on. The
`Storage`-type intent's `NetAdapterNamesAsList` is the storage port list; the
combined management/compute intent (whose `IntentType` prints as a number such as
`10`) lists the management/compute adapters. Expanding one row per adapter lets us
attach the same friendly `CardNumber` (Card 1, Card 2, ...) and `Slot` you saw in
Step A, so you can confirm each intent's ports share a card. This runs across every
node in the cluster, so you can compare all nodes at once:

```powershell
$nodes = (Get-ClusterNode).Name      # or list node names explicitly
$intentRows = Invoke-Command -ComputerName $nodes -ScriptBlock {
    # Build a per-node card map: each distinct physical card (PCI seg:bus:dev) gets
    # a friendly "Card N" label, sorted so the numbering is stable on this node.
    # This is the SAME numbering scheme Step A uses, so the values line up.
    $cardMap = @{}; $i = 0
    foreach ($pci in (Get-NetAdapterHardwareInfo -ErrorAction SilentlyContinue |
            ForEach-Object { '{0:x4}:{1:x2}:{2:x2}' -f $_.Segment, $_.Bus, $_.Device } |
            Sort-Object -Unique)) {
        $i++; $cardMap[$pci] = "Card $i"
    }
    Get-NetIntent | ForEach-Object {
        $intent = $_
        # NetAdapterNamesAsList may be a real array or a single comma-joined string;
        # normalize to one name per element either way.
        $names = @($intent.NetAdapterNamesAsList) |
            ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }
        foreach ($a in $names) {
            $hw  = Get-NetAdapterHardwareInfo -Name $a -ErrorAction SilentlyContinue
            $pci = if ($hw) { '{0:x4}:{1:x2}:{2:x2}' -f $hw.Segment, $hw.Bus, $hw.Device } else { '' }
            [pscustomobject]@{
                Node       = $env:COMPUTERNAME
                IntentName = $intent.IntentName
                IntentType = $intent.IntentType
                Adapter    = $a
                CardNumber = if ($pci -and $cardMap.ContainsKey($pci)) { $cardMap[$pci] } else { 'n/a' }
                Slot       = if ($hw -and $null -ne $hw.Slot -and $hw.Slot) { "Slot $($hw.Slot)" }
                             elseif ($hw) { 'Onboard' } else { '' }
            }
        }
    }
} | Select-Object Node, IntentName, IntentType, Adapter, CardNumber, Slot
$intentRows | Sort-Object Node, IntentName, Adapter | Format-Table -AutoSize
```

A separate `Storage` intent alongside a combined management/compute intent is the
disaggregated case this section is written for. On a node with two dual-port
Mellanox cards, you will typically see the storage intent list two ports (one
card) and the management/compute intent list the other two ports (the second
card), even though all four ports report RDMA enabled.

> **About the "Other (not in ATC intent)" rows.** Some nodes have physical NICs
> that belong to no NetworkATC intent, for example Dell onboard LOM ports or a
> BMC-shared management port (often shown with a GUID name and a non-Mellanox
> OUI, frequently Disconnected). These are
> neither storage nor ATC-managed management/compute uplinks. The script tags them
> "Other" rather than sweeping them into the mgmt/compute list, so do not put their
> MACs on the storage-switch PFC lists. They are listed only so you can account for
> every physical port; if one is Up it is typically the host/BMC management LOM on a
> separate network, not a ToR storage-switch port.

> Topology reminder: if the cluster is **fully converged** instead (a single intent
> combining storage with management and compute, no separate `Storage` intent),
> every physical NIC is a storage port. Force PFC ON on all of them and do not set
> any port OFF. See "First, determine your topology" above.

#### Determine card-level redundancy (REDUNDANT vs NOT-REDUNDANT)

Now that you know which ports are storage and which are management/compute,
determine how those ports are spread across the physical Mellanox cards. This is a
**card-level** redundancy check, and it is specific to the firmware reset in Resolution Step 3:
`mlxfwreset` resets a whole card (both of its ports) at once, so what matters here
is whether a single full-card reset can be absorbed without taking a plane offline.

This is separate from, and does not contradict, the normal port, cable, and
top-of-rack switch redundancy your cluster already has. A plane with two ports
split across ToR-A and ToR-B (with SMB Multichannel on storage or SET failover on
management/compute) already survives a single port, cable, or switch failure
regardless of how the ports map to cards. The check below asks the narrower
question: does each plane also survive a *whole-card* event?

Two ports that share the same PCI Segment, Bus, and Device are the two ports of one
dual-port card. Record the result alongside the port map:

- **REDUNDANT (card-level)** (each plane has a port on two or more separate cards):
  resetting one card always leaves a surviving member in every plane, so SET
  failover and SMB Multichannel keep the node online during a live reset. Resolution Step 3 can
  be applied live without a drain.
- **NOT-REDUNDANT (card-level / single-card plane)** (both ports of a plane are on
  one card, for example both storage ports on one card and both management/compute
  ports on the other): a whole-card reset takes that entire plane down for the
  duration of the reset, including the management path if that card backs the
  management/compute plane, because there is no port on a second card to carry the
  traffic. The node must be drained before that card is reset. This says nothing
  about your everyday network redundancy, which remains intact; it only means a
  live whole-card reset would briefly drop the plane.

Run this once from any node; it loops over every node in the cluster with
`Get-ClusterNode` and `Invoke-Command`, then prints one clean row per node showing
how many cards back each plane and whether the node is REDUNDANT or NOT-REDUNDANT:

```powershell
# Two ports sharing the same PCI Segment:Bus:Device are one dual-port card.
$nodes = (Get-ClusterNode).Name      # or list node names explicitly
$cardRedundancy = Invoke-Command -ComputerName $nodes -ScriptBlock {
    $storageAdapters = @((Get-NetIntent |
        Where-Object { $_.IntentType -match 'Storage' }).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }
    $mgmtAdapters = @((Get-NetIntent |
        Where-Object { $_.IntentType -notmatch 'Storage' }).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }

    function Get-CardId([string]$Name) {
        $hw = Get-NetAdapterHardwareInfo -Name $Name -ErrorAction SilentlyContinue
        if ($hw) { '{0:x4}:{1:x2}:{2:x2}' -f $hw.Segment, $hw.Bus, $hw.Device }
    }

    $storageCards = @($storageAdapters | ForEach-Object { Get-CardId $_ } |
        Where-Object { $_ } | Sort-Object -Unique)
    $mgmtCards = @($mgmtAdapters | ForEach-Object { Get-CardId $_ } |
        Where-Object { $_ } | Sort-Object -Unique)

    # The card-level redundancy verdict (REDUNDANT/NOT-REDUNDANT) is useful on any
    # vendor, so we always show it. The reset ACTION (Step 3 Option 1/2/3) is
    # Mellanox-only, so on a node with no Mellanox NICs we still report the verdict
    # but mark the action n/a and point to the switch-side neighbor check.
    $hasMlx = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -match 'Mellanox|ConnectX|NVIDIA' }).Count -gt 0
    $isRedundant = ($storageCards.Count -ge 2 -and $mgmtCards.Count -ge 2)
    [pscustomobject]@{
        Node            = $env:COMPUTERNAME
        'Storage cards' = $storageCards.Count
        'Mgmt cards'    = $mgmtCards.Count
        Verdict         = if ($isRedundant) { 'REDUNDANT' } else { 'NOT-REDUNDANT' }
        'Reset action'  = if (-not $hasMlx)     { 'n/a; Step 3 reset/reboot is Mellanox-only (use switch-side neighbor check)' }
                          elseif ($isRedundant) { 'Live reset OK (no drain)' }
                          else                  { 'DRAIN node first (Option 2 or 3)' }
    }
} | Select-Object Node, 'Storage cards', 'Mgmt cards', Verdict, 'Reset action'

""
"==================== CARD-LEVEL REDUNDANCY VERDICT (firmware reset) ===================="
$cardRedundancy | Sort-Object Node | Format-Table -AutoSize
"'Storage cards' / 'Mgmt cards' = how many physical cards back the storage plane"
"and the management/compute plane on that node. NOT-REDUNDANT means at least one"
"of those planes has both its ports on a single card; resetting that card drops"
"the whole plane, so drain the node first. Port/cable/switch redundancy is"
"unaffected. On a non-Mellanox node the verdict is still shown for awareness, but"
"the Reset action reads n/a because Step 3's reset/reboot procedures are"
"Mellanox-only; use the switch-side neighbor check instead."
"=============================================================================="
```

Note the verdict in your port map. The example in Step C is a NOT-REDUNDANT node
(both storage ports on one Mellanox card, both management/compute ports on the
other). "First, determine your topology" in Step 3 runs this same check again at remediation
time, so you can either carry the value forward or re-run it then.

### Step B: Correlate each host port to a physical switch port

How you map a port depends on its role, because storage and mgmt/compute NICs
behave very differently on the wire. Map storage ports by MAC; identify
mgmt/compute ports by host name and elimination.

**Storage ports: map by the switch MAC address table (reliable).** Storage NICs
are native, non-teamed adapters, so the host sources traffic from each storage
port's own MAC and the switch learns it on exactly one port. This gives a clean,
direct port mapping.

**MAC format differs by vendor.** Windows prints `00-00-5E-00-53-A1`. Cisco
prints `0000.5e00.53a1`. Aruba CX prints `00005e-0053a1` (or colon-separated).
Convert the host MAC to the switch's format before searching.

**Cisco NX-OS:**
```
show mac address-table address 0000.5e00.53a1
```

**Aruba CX (AOS-CX):**
```
show mac-address-table | include 00005e-0053a1
```

Each command returns the switch interface (for example `Ethernet1/21` on Cisco
or `1/1/17` on Aruba) that the storage MAC is connected to. Repeat for every MAC
in the STORAGE list.

> Tip: Before Resolution Step 3, the Mellanox firmware LLDP agent advertises each storage
> NIC's own MAC as the LLDP chassis ID, so storage MACs also appear directly in
> the switch LLDP neighbor table (`show lldp neighbors detail`). This is a
> convenient cross-check, but it disappears once you disable the firmware agent in
> Resolution Step 3, so capture storage mappings during planning if you want it.

**Mgmt/compute ports: identify by host and elimination, not by MAC.** Do not try
to map these by MAC. They are SET team members behind the vSwitch, so two things
work against a MAC-based lookup:

1. The switch MAC table learns the **floating vNIC/VM MACs**, which can move
   between member ports after a rehash or a link event, so they do not pin to one
   port.
2. The port's own **burned-in MAC is generally never learned**, because the
   vSwitch sources data frames from vNIC MACs (not the physical port MAC), and the
   only frames that carry the physical MAC (LLDP and DCBX) use a reserved multicast
   destination that the switch consumes rather than learns from.

The Windows LLDP agent (enabled by Step 1) does advertise these ports, but it sends
the host **System Name** (hostname) and a host-level chassis ID, not the physical
port MAC, so you cannot join an LLDP neighbor entry back to a specific row in your
MAC inventory. Instead, identify the mgmt/compute ports two ways:

- **LLDP neighbor** (`show lldp neighbors` on Cisco, `show lldp neighbor-info` on
  Aruba): confirms which switch ports land on an Azure Local host, by System Name.
- **Elimination:** any host-connected port that is not in your storage port list
  is a mgmt/compute port.

Because the action on every mgmt/compute port is identical (PFC explicitly OFF),
you never need a per-port MAC correlation for them. Confirm the port reaches the
right host, then set it OFF.

### Step C: Build the port map and label the ports

Combine the results into a single table, then label the switch ports
accordingly. Example (a disaggregated node with one dual-port Mellanox card
dedicated to storage and a **second dual-port Mellanox card teamed for
management/compute**). The management/compute ports are RDMA-capable Mellanox
ports, but they are classified as management/compute because they are members of
the converged virtual switch, not because they lack RDMA:

| Node    | Host port (role source)      | MAC / identifier  | Role         | ToR / Port    | PFC policy | Mapped by               |
|---------|------------------------------|-------------------|--------------|---------------|------------|-------------------------|
| Node-01 | ethernet 3                   | 00-00-5E-00-53-01 | Storage      | ToR-A Eth1/22 | Forced ON  | MAC table               |
| Node-01 | ethernet 4                   | 00-00-5E-00-53-02 | Storage      | ToR-B Eth1/22 | Forced ON  | MAC table               |
| Node-01 | ethernet (vSwitch member)    | host "Node-01"    | Mgmt/Compute | ToR-A Eth1/5  | Off        | LLDP name / elimination |
| Node-01 | ethernet 2 (vSwitch member)  | host "Node-01"    | Mgmt/Compute | ToR-B Eth1/5  | Off        | LLDP name / elimination |

Note that only the two storage ports (one dual-port card) are storage, even
though all four Mellanox ports report RDMA enabled. The two management/compute
ports are the second Mellanox card, teamed into the converged virtual switch, so
they are identified by host name through LLDP rather than by MAC (their port MACs
are masked behind floating vNIC MACs, as explained in Step B). Because both
storage ports sit on one card and both management/compute ports sit on the other,
this node is **NOT-REDUNDANT at the card level** (see "Determine card-level
redundancy" in Step A): a whole-card reset drops the entire plane, so Resolution Step 3 must be
applied with the node drained. (Port and switch redundancy still exist: each plane
has two ports across ToR-A and ToR-B.) The "Storage" rows
give you the exact storage port list to force PFC ON in Resolution Step 2
(`priority-flow-control mode on` on Cisco, `flow-control priority rxtx 3` on
Aruba CX). The "Mgmt/Compute" rows are the ports to set explicitly PFC off in
Resolution Step 2. Applying a label or description to each switch port (for example a Cisco
interface `description Storage-Node01` or the Aruba equivalent) makes the policy
self-documenting and reduces the risk of forcing PFC on the wrong port during
future maintenance.

## Diagnosis Steps

### Prerequisites: Mellanox Firmware Tools (WinMFT)

Several diagnosis and resolution steps below inspect or modify NIC firmware
settings using the Mellanox Firmware Tools (WinMFT). Install WinMFT on each
cluster node before starting, so the `mst` and `mlxconfig` commands are
available when the steps call for them. (If the cluster has no Mellanox NICs,
skip this and the Mellanox-specific steps.)

1. Download the Windows x64 WinMFT package from the
   [NVIDIA Firmware Tools page](https://network.nvidia.com/products/adapter-software/firmware-tools/).
   Pick the build that matches the node architecture (x64).
2. Copy the installer to each cluster node and run it interactively. On Azure
   Local nodes the WinMFT silent or unattended install does not complete
   correctly, so do not rely on a `/S`-style silent switch. Instead, connect to
   the node over RDP, launch the installer, and step through the GUI prompts to
   completion. Repeat on every cluster node.

   The tools install to `C:\Program Files\Mellanox\WinMFT`. Installing WinMFT
   does not require a node reboot and is safe to perform on production
   clusters.
3. Verify the install and enumerate NIC firmware devices on every node at once.
   Run this from any one node; it loops over the cluster with `Get-ClusterNode`
   and `Invoke-Command` and prints one row per node, so you can confirm WinMFT is
   present everywhere and see each node's Mellanox devices side by side. A node
   where WinMFT is missing shows `NOT INSTALLED` (go back to step 2 for it):

   ```powershell
   $nodes = (Get-ClusterNode).Name      # or list node names explicitly
   $winmft = Invoke-Command -ComputerName $nodes -ScriptBlock {
       $mstDir = 'C:\Program Files\Mellanox\WinMFT'
       $mst    = Join-Path $mstDir 'mst.exe'
       if (-not (Test-Path $mst)) {
           [pscustomobject]@{
               Node = $env:COMPUTERNAME; WinMFT = 'NOT INSTALLED'
               Devices = 0
               'Device names' = 'WinMFT not installed (Mellanox-only tool); if non-Mellanox, firmware state is not host-readable (use switch-side check)'
           }
           return
       }
       # mst.exe must run with the WinMFT folder as the working directory (it loads
       # sibling files from there); invoking it by full path makes 'mst status'
       # enumerate nothing. Push-Location replicates the known-working manual run.
       Push-Location $mstDir
       try {
           # Trim the long banner ("mst, mft 4.35.0-159 built on ...") to just the version.
           $ver = ((& .\mst.exe version 2>&1) | Select-Object -First 1)
           if ($ver -match 'mft\s+(\S+)') { $ver = $matches[1] }
           # Each NIC firmware device looks like mt4127_pciconf0; collect the distinct set.
           $devices = @((& .\mst.exe status 2>&1) |
               Select-String 'mt\d+_pciconf\d+' -AllMatches |
               ForEach-Object { $_.Matches.Value } | Sort-Object -Unique)
       }
       finally { Pop-Location }
       [pscustomobject]@{
           Node           = $env:COMPUTERNAME
           WinMFT         = $ver
           Devices        = $devices.Count
           'Device names' = if ($devices) { $devices -join ', ' }
                            else { 'No Mellanox NICs on this host; firmware LLDP/DCBX is not host-readable (use switch-side check)' }
       }
   } | Select-Object Node, WinMFT, Devices, 'Device names'
   $winmft | Sort-Object Node | Format-Table -AutoSize -Wrap
   ```

   Expected output (one row per node):

   ```
   Node           WinMFT     Devices Device names
   ----           ------     ------- ------------
   ContosoNode-01 4.35.0-159       2 mt4125_pciconf0, mt4127_pciconf0
   ContosoNode-02 4.35.0-159       2 mt4125_pciconf0, mt4127_pciconf0
   ```

   Each `mt<model>_pciconfN` entry is one NIC (PCI function). On a two-NIC
   storage configuration you will typically see `pciconf0` and `pciconf1`.
   Use the exact device name from `mst status` in the firmware commands below.

   **Important:** The `mt<model>` prefix varies by NIC model (for example,
   `mt4125` = ConnectX-6 Lx, `mt4127` = ConnectX-6 Dx, `mt4129` = ConnectX-7).
   The firmware commands in this guide auto-discover every device by parsing
   `mst status`, so you normally do not need to type a device name. If you run a
   single `mlxconfig` command by hand, substitute the device name that
   `mst status` reports on your node. If a `mlxconfig` command returns no output,
   the two most common causes are: the node has no Mellanox NICs at all (for
   example, an Intel-only cluster, where `mst status` lists no devices and the
   Mellanox firmware steps do not apply), or the device name used does not exist
   on the node. Append `2>&1` to the command (as shown below) so any "device not
   found" error is shown instead of hidden.

### Step 1: Identify NIC Vendor and RDMA Transport

```powershell
# Identify the storage NICs, their vendor, and their RDMA transport on every node.
# Storage NICs come from the NetworkATC storage intent (authoritative), NOT from
# "RDMA enabled": converged management/compute ports can also be RDMA-enabled and
# would otherwise be misclassified as storage. Runs cluster-wide from one node.
$nodes = (Get-ClusterNode).Name      # or list node names explicitly
Invoke-Command -ComputerName $nodes -ScriptBlock {
    $storageAdapters = @((Get-NetIntent |
        Where-Object { $_.IntentType -match 'Storage' }).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }
    $storageNics = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $storageAdapters -contains $_.Name }

    $storageNics | ForEach-Object {
        $nic = $_
        # *NetworkDirectTechnology reports the RDMA transport (RoCEv2 vs iWARP).
        # Current Mellanox/NVIDIA ConnectX drivers populate this as RoCEv2 (ConnectX is
        # RoCE-only). If a given driver does not expose the property, the value is blank;
        # that fallback is handled below.
        $ndt = Get-NetAdapterAdvancedProperty -Name $nic.Name `
            -RegistryKeyword "*NetworkDirectTechnology" -ErrorAction SilentlyContinue

        [pscustomobject]@{
            Node                 = $env:COMPUTERNAME
            Name                 = $nic.Name
            InterfaceDescription = $nic.InterfaceDescription   # vendor and model
            RdmaTransport        = if ($ndt) { $ndt.DisplayValue }
                                   else { '(not reported by driver)' }
        }
    }
} | Select-Object Node, Name, InterfaceDescription, RdmaTransport |
    Sort-Object Node, Name | Format-Table -AutoSize
```

Expected output (one row per storage port, per node):

```
Node           Name       InterfaceDescription              RdmaTransport
----           ----       --------------------              -------------
ContosoNode-01 ethernet 3 Mellanox ConnectX-6 Dx Adapter #2 RoCEv2
ContosoNode-01 ethernet 4 Mellanox ConnectX-6 Dx Adapter    RoCEv2
ContosoNode-02 ethernet 3 Mellanox ConnectX-6 Dx Adapter #2 RoCEv2
ContosoNode-02 ethernet 4 Mellanox ConnectX-6 Dx Adapter    RoCEv2
```

Interpret the output by vendor:

- **Mellanox ConnectX** (`InterfaceDescription` shows ConnectX-6 Lx/Dx):
  `RdmaTransport` reports **RoCEv2** on current drivers. ConnectX supports only RoCE,
  so RoCEv2 is the only valid transport here; if an older driver leaves the value
  blank ("not reported by driver"), treat it as RoCEv2 regardless. Either way PFC is
  required, so continue with Step 2. ConnectX is also the vendor that runs the
  competing firmware LLDP agent this guide addresses.
- **Intel E810 / Chelsio** (`RdmaTransport` shows a value): the value tells you the
  selected transport.
  - **RoCEv2**: PFC is required. Continue with Step 2.
  - **iWARP**: PFC is not required. LLDP/DCBX issues are informational only.

> **If no Mellanox NICs are present**, the Mellanox-specific remediation in this
> guide (Resolution Step 3, disable the Mellanox firmware LLDP agent using WinMFT)
> does not apply: only Resolution Steps 1 and 2 are relevant. See "Which steps apply
> to your cluster" at the top of the Resolution section. Intel E810 and Broadcom NICs
> may also ship a firmware LLDP agent; if one is active alongside the Windows agent,
> the same dual-agent guidance applies, but the command to disable it is
> vendor-specific (the WinMFT procedure in Step 3 is Mellanox-only).

### Step 2: Check PFC Status on Host

Paste this into one PowerShell terminal on one node; it queries every node in the
cluster and returns one row per storage NIC, plus that node's host-wide priority 3
flow-control setting:

```powershell
# Check PFC on every storage NIC across the cluster. Storage NICs come from the
# NetworkATC storage intent (authoritative), NOT from "RDMA enabled": converged
# management/compute ports can also be RDMA-enabled, and their PFC state should be
# OFF, so including them here would be misleading.
$nodes = (Get-ClusterNode).Name      # or list node names explicitly
$pfc = Invoke-Command -ComputerName $nodes -ScriptBlock {
    $storageAdapters = @((Get-NetIntent |
        Where-Object { $_.IntentType -match 'Storage' }).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }
    $storageNics = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $storageAdapters -contains $_.Name }

    # Host-wide priority 3 flow control (applies to all adapters on this node).
    $hostPri3 = (Get-NetQosFlowControl |
        Where-Object { $_.Priority -eq 3 }).Enabled

    foreach ($nic in $storageNics) {
        $ofc = (Get-NetAdapterQos -Name $nic.Name).OperationalFlowControl
        [pscustomobject]@{
            Node                   = $env:COMPUTERNAME
            NIC                    = $nic.Name
            OperationalFlowControl = ($ofc -join '; ')
            'Host Pri3 FC'         = $hostPri3
        }
    }
} | Select-Object Node, NIC, OperationalFlowControl, 'Host Pri3 FC'
$pfc | Sort-Object Node, NIC | Format-Table -AutoSize
```

Expected output when PFC is healthy (one row per storage NIC, per node):

```
Node           NIC        OperationalFlowControl Host Pri3 FC
----           ---        ---------------------- ------------
ContosoNode-01 ethernet 3 Priority 3 Enabled             True
ContosoNode-01 ethernet 4 Priority 3 Enabled             True
ContosoNode-02 ethernet 3 Priority 3 Enabled             True
ContosoNode-02 ethernet 4 Priority 3 Enabled             True
```

Interpret the output:
- **GOOD:** every storage NIC's `OperationalFlowControl` reads `Priority 3 Enabled`
  = PFC is active on that port.
- **GOOD:** `Host Pri3 FC` is `True` on each node = host-wide priority 3 flow
  control is configured.
- **BAD:** a storage NIC not showing `Priority 3 Enabled`, or `Host Pri3 FC` is
  `False` on a node = PFC is not active there.
  Check the NetworkATC intent status to confirm whether the storage intent
  applied its QoS policy successfully (run on the affected node):

  ```powershell
  # List all intents and their types (the storage intent has IntentType 'Storage')
  Get-NetIntent | Select-Object IntentName, IntentType

  # Resolve the storage intent name automatically and check its status
  $storageIntent = Get-NetIntent |
      Where-Object { $_.IntentType -match 'Storage' } |
      Select-Object -First 1 -ExpandProperty IntentName

  if (-not $storageIntent) {
      Write-Warning "No storage intent found on this host."
  } else {
      Get-NetIntentStatus |
          Where-Object { $_.IntentName -eq $storageIntent } |
          Format-List IntentName, ConfigurationStatus, ProvisioningStatus, Host
  }
  ```

  > Note: `IntentType` is a bit-flag enum, so a combined intent prints as a
  > number (for example `10` for management+compute) while a dedicated storage
  > intent prints as `Storage`. The `-match 'Storage'` filter above matches
  > either form, so you do not need to read the number.

  `ConfigurationStatus = Success` and `ProvisioningStatus = Completed` mean the
  intent (including its PFC/QoS policy) applied. Any other state, or a
  `Retrying`/`Failed` status, indicates the QoS policy did not apply and is why
  Priority 3 is not enabled. Re-run the intent or inspect the per-host error
  before continuing.

### Step 3: Check for Dual LLDP Agents

The Mellanox part requires WinMFT (see Prerequisites above). Paste this into one
PowerShell terminal on one node; it checks every node and distills the result to
one short row per item, so you do not have to read the raw multi-scope LLDP dump.
The Windows LLDP check covers both ATC planes (storage and management/compute) and
adds a `Role` column. The post-reboot bug toggles the Windows LLDP agent host-wide
rather than per port, so listing both planes makes that visible at a glance: when a
node is affected, every ATC uplink flips together. iDRAC/LOM ports (not in any ATC
intent) are excluded so they do not add noise:

```powershell
$nodes = (Get-ClusterNode).Name      # or list node names explicitly
$lldp = Invoke-Command -ComputerName $nodes -ScriptBlock {
    # Both ATC planes from the NetworkATC intents (authoritative): storage and
    # management/compute. Listing both shows the Windows agent's reach across every
    # ATC-managed uplink and keeps iDRAC/LOM ports (in no intent) out of the result.
    $storageAdapters = @((Get-NetIntent |
        Where-Object { $_.IntentType -match 'Storage' }).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }
    $mgmtAdapters = @((Get-NetIntent |
        Where-Object { $_.IntentType -notmatch 'Storage' }).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }

    # Windows LLDP agent: Get-NetLldpAgent returns one row per Scope (3 per NIC),
    # all with the same Status. Collapse to a single state per ATC NIC.
    # Note: read .Status (the friendly ScriptProperty: Enabled/Disabled), NOT
    # .AdminStatus (the raw uint32, e.g. 3 = RxTx) which renders as an integer.
    function Get-WinLldpRow($name, $role) {
        $agent = Get-NetLldpAgent -NetAdapterName $name -ErrorAction SilentlyContinue |
            Select-Object -First 1
        [pscustomobject]@{
            Node  = $env:COMPUTERNAME
            Check = 'Windows LLDP agent'
            Role  = $role
            Item  = $name
            State = if ($agent) { "$($agent.Status)" } else { '(not present)' }
        }
    }
    $win = @()
    foreach ($a in $storageAdapters) { $win += Get-WinLldpRow $a 'Storage' }
    foreach ($a in $mgmtAdapters)    { $win += Get-WinLldpRow $a 'Mgmt/Compute' }

    # Mellanox FW LLDP TX: one row per card + port (P1/P2). OFF(0) = disabled (good).
    $fw = @()
    $mstDir = 'C:\Program Files\Mellanox\WinMFT'
    # Physical NIC models present; used to make a non-Mellanox result explicit
    # instead of leaving the firmware section silently empty.
    $nonMlx = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -notmatch 'Mellanox|ConnectX|NVIDIA|Remote NDIS|USB' } |
        ForEach-Object { $_.InterfaceDescription -replace '\s*#\d+\s*$', '' } | Sort-Object -Unique)
    function New-FwNote($text) {
        [pscustomobject]@{ Node = $env:COMPUTERNAME; Check = 'Mellanox FW LLDP TX'
            Role = ''; Item = '(firmware agent)'; State = $text }
    }
    if (-not (Test-Path (Join-Path $mstDir 'mst.exe'))) {
        $fw += New-FwNote 'WinMFT not installed; firmware state not host-readable (use switch-side neighbor check)'
    }
    else {
        Push-Location $mstDir
        try {
            $devices = @((& .\mst.exe status 2>&1) |
                Select-String 'mt\d+_pciconf\d+' -AllMatches |
                ForEach-Object { $_.Matches.Value } | Sort-Object -Unique)
            if (-not $devices) {
                $what = if ($nonMlx) { "No Mellanox NICs ($($nonMlx -join ', '))" } else { 'No Mellanox NICs' }
                $fw += New-FwNote "$what; firmware state not host-readable (use switch-side neighbor check)"
            }
            foreach ($dev in $devices) {
                foreach ($l in ((& .\mlxconfig.exe -d $dev query 2>&1) |
                        Select-String 'LLDP_NB_TX_MODE_P\d')) {
                    if ($l.Line -match 'LLDP_NB_TX_MODE_(P\d)\s+(\S+)') {
                        $fw += [pscustomobject]@{
                            Node  = $env:COMPUTERNAME
                            Check = 'Mellanox FW LLDP TX'
                            Role  = ''
                            Item  = "$dev $($matches[1])"
                            State = $matches[2]
                        }
                    }
                }
            }
        }
        finally { Pop-Location }
    }
    $win + $fw
} | Select-Object Node, Check, Role, Item, State
$lldp | Sort-Object Node, Check, Role, Item | Format-Table -AutoSize
```

Example output from a cluster where the two nodes are in different states. Node
ContosoNode-01 is correct (Windows agent on, firmware agent off). Node ContosoNode-02 has the
post-reboot bug: the Windows agent is Disabled on every ATC plane and the firmware
agent is transmitting (`ALL(2)`), so the only LLDP speaker is the firmware agent:

```
Node           Check               Role         Item               State
----           -----               ----         ----               -----
ContosoNode-01 Mellanox FW LLDP TX              mt4125_pciconf0 P1 OFF(0)
ContosoNode-01 Mellanox FW LLDP TX              mt4125_pciconf0 P2 OFF(0)
ContosoNode-01 Mellanox FW LLDP TX              mt4127_pciconf0 P1 OFF(0)
ContosoNode-01 Mellanox FW LLDP TX              mt4127_pciconf0 P2 OFF(0)
ContosoNode-01 Windows LLDP agent  Mgmt/Compute ethernet           Enabled
ContosoNode-01 Windows LLDP agent  Mgmt/Compute ethernet 2         Enabled
ContosoNode-01 Windows LLDP agent  Storage      ethernet 3         Enabled
ContosoNode-01 Windows LLDP agent  Storage      ethernet 4         Enabled
ContosoNode-02 Mellanox FW LLDP TX              mt4125_pciconf0 P1 ALL(2)
ContosoNode-02 Mellanox FW LLDP TX              mt4125_pciconf0 P2 ALL(2)
ContosoNode-02 Mellanox FW LLDP TX              mt4127_pciconf0 P1 ALL(2)
ContosoNode-02 Mellanox FW LLDP TX              mt4127_pciconf0 P2 ALL(2)
ContosoNode-02 Windows LLDP agent  Mgmt/Compute ethernet           Disabled
ContosoNode-02 Windows LLDP agent  Mgmt/Compute ethernet 2         Disabled
ContosoNode-02 Windows LLDP agent  Storage      ethernet 3         Disabled
ContosoNode-02 Windows LLDP agent  Storage      ethernet 4         Disabled
```

Interpret the output per node (the desired end state is the Windows agent Enabled
and every firmware `ALL(2)` turned to `OFF(0)`):
- **GOOD (single agent):** `Windows LLDP agent` = `Enabled` on every ATC NIC AND
  every `Mellanox FW LLDP TX` row = `OFF(0)`. Only the Windows agent speaks (node ContosoNode-01 above).
- **BAD (dual-agent state):** `Windows LLDP agent` = `Enabled` AND any
  `Mellanox FW LLDP TX` row = `ALL(2)`. Both agents transmit; this is the conflict
  this guide addresses. Apply Resolution Step 3 to disable the firmware agent.
- **BAD (wrong agent / post-reboot bug):** `Windows LLDP agent` = `Disabled` across
  both planes (as on node ContosoNode-02 above), usually with firmware `ALL(2)`. Because the
  bug is host-wide, the storage and mgmt/compute rows flip together. The Windows
  agent was turned off by the post-reboot bug (fixed in Azure Local 12.2607),
  leaving the firmware agent as the only speaker. Re-enable the Windows agent per
  Resolution Step 1, then disable the firmware agent per Resolution Step 3.
- Per-node differences are normal: a fix applied on one node does not change the
  others, so expect nodes to be in different states until every node is remediated.

### Step 4: Check DCBX Dialect from the Switch

> **Which ports?** Use the storage port list from the port map you built in
> "Mapping NIC Roles to Switch Ports" (Step C). Substitute each storage port for
> `<port>` below and repeat per storage port.

On Cisco NX-OS:
```
show lldp dcbx interface ethernet 1/<port>
```

On Aruba CX:
```
show lldp neighbor-info detail
show dcbx interface 1/1/<port>
```

Interpret the output (either platform):
- **GOOD:** `Detected: IEEE 802.1` = correct dialect, DCBX should converge.
- **BAD:** `Detected: CIN` = the switch has no IEEE DCBX peer and fell back to its CIN default; PFC auto will not converge.
- **BAD:** `DCBx operational state: multiple_peers` (Aruba) = dual-agent deadlock.

### Step 5: Check PFC Status on the Switch

> **Which ports?** Check the storage ports from your port map (Mapping NIC Roles
> to Switch Ports, Step C). These are the ports where PFC must be active.

On Cisco NX-OS:
```
show interface priority-flow-control
```

On Aruba CX:
```
show interface 1/1/<port> flow-control
```

Interpret the output (either platform):
- **GOOD:** `Mode On, Oper On` = PFC is forced and working (not affected by DCBX issues).
- **BAD:** `Mode Auto, Oper Off` = PFC depends on DCBX and is not converging.
- **BAD:** `PFC operational state: inactive` (Aruba) = PFC is off.

### Step 6: Check Mellanox NIC Firmware DCBX Settings (Requires WinMFT)

With WinMFT installed (see Prerequisites above), paste this into one PowerShell
terminal on one node. It queries every node in the cluster and distills the result
to the three actionable firmware toggles per card port (P1/P2), instead of the full
`mlxconfig` dump. The read-only DCBX capability bits (`DCBX_IEEE`, `DCBX_CEE`,
`DCBX_WILLING`) are intentionally omitted: they cannot be changed and are not what
you act on here. What matters is whether the firmware LLDP/DCBX agent is off:

```powershell
$nodes = (Get-ClusterNode).Name      # or list node names explicitly
$fwDcbx = Invoke-Command -ComputerName $nodes -ScriptBlock {
    $mstDir = 'C:\Program Files\Mellanox\WinMFT'
    # Physical NIC models present; used to make a non-Mellanox result explicit
    # instead of returning an empty table.
    $nonMlx = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -notmatch 'Mellanox|ConnectX|NVIDIA|Remote NDIS|USB' } |
        ForEach-Object { $_.InterfaceDescription -replace '\s*#\d+\s*$', '' } | Sort-Object -Unique)
    function New-Note($text) {
        [pscustomobject]@{
            Node = $env:COMPUTERNAME; Device = $text
            Port = ''; FW_LLDP_TX = 'n/a'; FW_LLDP_RX = 'n/a'; FW_DCBX = 'n/a'
        }
    }
    if (-not (Test-Path (Join-Path $mstDir 'mst.exe'))) {
        New-Note 'WinMFT NOT INSTALLED. If this is a Mellanox cluster install WinMFT; otherwise firmware LLDP/DCBX is not host-readable (use the switch-side neighbor check).'
        return
    }
    # Pull a single firmware value (e.g. LLDP_NB_TX_MODE_P1) out of an mlxconfig query.
    function Get-Val($queryLines, $key) {
        $m = $queryLines | Select-String "$key\s+(\S+)" | Select-Object -First 1
        if ($m) { $m.Matches[0].Groups[1].Value } else { '' }
    }
    Push-Location $mstDir
    try {
        $devices = @((& .\mst.exe status 2>&1) |
            Select-String 'mt\d+_pciconf\d+' -AllMatches |
            ForEach-Object { $_.Matches.Value } | Sort-Object -Unique)
        if (-not $devices) {
            # WinMFT is installed but mst found no Mellanox devices: a non-Mellanox
            # host (for example Intel E810 or Broadcom). Firmware LLDP/DCBX is not
            # host-readable on these NICs; validate at the switch instead.
            $what = if ($nonMlx) { "No Mellanox NICs (this host has $($nonMlx -join ', '))." }
                    else         { 'No Mellanox NICs on this host.' }
            New-Note "$what Firmware LLDP/DCBX is not host-readable; use the switch-side neighbor check."
            return
        }
        foreach ($dev in $devices) {
            $q = (& .\mlxconfig.exe -d $dev query 2>&1)
            foreach ($p in 'P1', 'P2') {
                [pscustomobject]@{
                    Node       = $env:COMPUTERNAME
                    Device     = $dev
                    Port       = $p
                    FW_LLDP_TX = Get-Val $q "LLDP_NB_TX_MODE_$p"   # want OFF(0)
                    FW_LLDP_RX = Get-Val $q "LLDP_NB_RX_MODE_$p"   # want OFF(0)
                    FW_DCBX    = Get-Val $q "LLDP_NB_DCBX_$p"      # want False(0)
                }
            }
        }
    }
    finally { Pop-Location }
} | Select-Object Node, Device, Port, FW_LLDP_TX, FW_LLDP_RX, FW_DCBX
$fwDcbx | Sort-Object Node, Device, Port | Format-Table -AutoSize
```

Expected output when the firmware agent is correctly disabled:

```
Node           Device          Port FW_LLDP_TX FW_LLDP_RX FW_DCBX
----           ------          ---- ---------- ---------- -------
ContosoNode-01 mt4125_pciconf0 P1   OFF(0)     OFF(0)     False(0)
ContosoNode-01 mt4125_pciconf0 P2   OFF(0)     OFF(0)     False(0)
ContosoNode-01 mt4127_pciconf0 P1   OFF(0)     OFF(0)     False(0)
ContosoNode-01 mt4127_pciconf0 P2   OFF(0)     OFF(0)     False(0)
ContosoNode-02 mt4125_pciconf0 P1   OFF(0)     OFF(0)     False(0)
ContosoNode-02 mt4125_pciconf0 P2   OFF(0)     OFF(0)     False(0)
ContosoNode-02 mt4127_pciconf0 P1   OFF(0)     OFF(0)     False(0)
ContosoNode-02 mt4127_pciconf0 P2   OFF(0)     OFF(0)     False(0)
```

Interpret the output (per row):
- **GOOD:** `FW_LLDP_TX` = `OFF(0)`, `FW_LLDP_RX` = `OFF(0)`, and `FW_DCBX` =
  `False(0)`. The firmware LLDP/DCBX agent is off; only the Windows agent speaks.
- **BAD:** `FW_LLDP_TX` = `ALL(2)` (firmware LLDP transmitting, dual-agent risk) or
  `FW_DCBX` = `True(1)` (firmware DCBX active). Apply Resolution Step 3 to disable the firmware
  agent on the affected cards.

## Resolution

The resolution is a single procedure carried out as three sequential steps, in the
order below. Do **not** perform them out of order:

- **Step 1** establishes a durable host LLDP identity, so a storage port is never
  left with no LLDP speaker.
- **Step 2** forces PFC statically on the switch, so PFC no longer depends on DCBX
  negotiation.
- **Step 3** removes the firmware LLDP/DCBX agent. Because PFC is already pinned on
  the switch (Step 2) and a durable host LLDP speaker is already in place (Step 1),
  removing the firmware agent cannot drop lossless behavior on the storage fabric.

(All step numbers in this section refer to the Resolution steps below, not to the
Diagnosis Steps earlier in the guide.)

**Which steps apply to your cluster.** This TSG addresses a PFC negotiation failure
rooted in a competing firmware LLDP agent on Mellanox ConnectX clusters, and in the
loss of host DCBX once that agent is disabled (see Affected Configurations). How much
of the resolution you run depends on your NIC vendor:

| Step | Mellanox ConnectX cluster | Non-Mellanox cluster (for example, Intel E810) |
|------|---------------------------|------------------------------------------------|
| Step 1: durable Windows LLDP agent (Willing = False) | Required | Recommended hardening; vendor-agnostic |
| Step 2: force PFC on the switch | Required (RoCEv2 is the only transport, so PFC is mandatory) | Required if the cluster runs RoCEv2; otherwise recommended |
| Step 3: disable the firmware LLDP agent | Required; this collapses each storage port to a single LLDP agent and resolves the dual-agent conflict | Does not apply as written: Step 3 disables the Mellanox firmware agent using Mellanox-only tooling. Skip Step 3 and the WinMFT prerequisite. See the note on other vendors below. |

- **No Mellanox NICs at all (for example, an Intel E810 cluster):** there is no
  Mellanox firmware LLDP agent to disable, so Step 3 does not apply. Run Step 1, and
  on a RoCEv2 cluster run Step 2, as standard lossless-fabric hygiene.
- **Mixed cluster:** run Step 3 only on the nodes whose Mellanox cards the diagnostics
  flagged with firmware LLDP `ALL(2)`. Nodes with no Mellanox NICs need only Steps 1
  and 2.
- **Broadcom NICs:** like Mellanox, Broadcom is RoCEv2-only, so Steps 1 and 2 apply
  the same way. Step 3 as written uses the Mellanox WinMFT tooling and is specific to
  ConnectX; to silence a Broadcom firmware agent, first confirm it is competing using
  the switch-side neighbor-count check, then see the vendor pointers in the
  neighbor-count note under Verification After Remediation.
- **Other NICs also have firmware LLDP agents.** Intel E810 and Broadcom ship a
  firmware LLDP agent too, so a competing agent is not unique to Mellanox. The
  shared problem is the dual-agent state itself: on Aruba CX the `multiple_peers`
  deadlock (Factor 1) comes from two chassis-IDs on a port and is independent of any
  DCBX dialect, so a non-Mellanox cluster that leaves a firmware agent enabled could
  see the same deadlock. What is established for Mellanox ConnectX is that it runs
  such a competing agent; whether a given Intel or Broadcom adapter does is a data gap
  on the tested hardware. The remedy follows the same principle (one durable host
  agent, firmware agent off), but the command to disable a non-Mellanox firmware agent
  is vendor-specific; see the vendor pointers in the neighbor-count note under
  Verification After Remediation.

### Step 1: Ensure the Windows LLDP Agent Is Durably Enabled (Willing = False) [LOW RISK]

> **RUN CLUSTER-WIDE FROM ONE NODE.** This is a host-side control-plane change
> with no NIC reset and no link drop, so it is safe to apply to every node at once.
> Paste it into one elevated PowerShell terminal on one node; it fans out to all
> nodes via `Invoke-Command`. (This differs from Step 3, which resets the NIC and
> therefore must run locally on one node at a time.)

Apply this first. Before removing the NIC firmware LLDP agent (Step 3), make sure
the Windows LLDP agent is reliably present on the storage NICs and survives
reboots. If you disable the firmware agent while the Windows agent is not
durable, a later reboot can leave a storage port with no LLDP speaker at all.

Azure Local's pre-deployment Environment Validator enables the Windows LLDP
agent. However, on the affected builds that enablement is written only to the
active (in-memory) state and is lost when the node reboots, which silently
disables the Windows LLDP agent and removes the host DCBX peer until it is
re-enabled. This is a known issue that Microsoft is tracking, and a platform
fix is being delivered in Azure Local 12.2607 (see below for which clusters the
fix covers).

**Which clusters need this toggle.** The platform fix applies
only to clusters **newly deployed** on Azure Local 12.2607 or later. A cluster
that was originally deployed on an earlier build and then **updated** to 12.2607
or later does **not** inherit the durable enablement, because the fix takes
effect during the initial deployment-time validation. Such updated clusters
still require this toggle. In short:

- Newly deployed on 12.2607 or later: no toggle needed.
- Deployed on an earlier build (whether or not later updated to 12.2607+):
  apply this toggle.

**If you are not sure which case applies, apply the toggle.** It is idempotent and
safe to re-apply, including on a cluster that already has the durable platform fix;
re-asserting the durable state and Willing = False posture causes no harm.

Use the following one-time toggle, applied to every node, to write a durable LLDP
agent state that survives reboot and to re-assert the host-authoritative DCBX
posture (Willing = False). It targets the ATC-managed fabric uplinks (the storage
and management/compute ports). It deliberately does not enable LLDP on the
iDRAC/BMC USB NIC (a GUID-named Remote NDIS adapter that is always Up but has no
switch peer). Use `Set-NetLldpAgent` only; do not use
`Enable-NetLldpAgent`. `Enable-NetLldpAgent` writes only to the active store, so
its effect is wiped on the next reboot, while `Set-NetLldpAgent` writes a
persistent state. The `Disable` then `Set` bounce below is required:
`Set-NetLldpAgent` only writes the persistent state when `AdminStatus` actually
changes, so the agent is forced to `Disabled` first, then set to `Enabled`.

```powershell
$nodes = (Get-ClusterNode).Name      # or list node names explicitly
$result = Invoke-Command -ComputerName $nodes -ScriptBlock {
    # Enable the Windows LLDP agent only on the ATC-managed fabric uplinks (storage
    # and management/compute), taken from the NetworkATC intents (authoritative).
    # We deliberately do NOT blanket-enable on "every Up physical adapter": that also
    # picks up the iDRAC/BMC USB NIC (a GUID-named Remote NDIS device that is always
    # Up but has no switch peer), which has no reason to run an LLDP agent.
    $atcAdapters = @((Get-NetIntent).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ } | Sort-Object -Unique
    $fabricNics = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'Up' -and $atcAdapters -contains $_.Name }

    if (-not $fabricNics) {
        Write-Warning "$($env:COMPUTERNAME): no Up ATC-managed adapters found."
    }

    foreach ($nic in $fabricNics) {
        # Durably enable the Windows LLDP agent. The Disable -> Set bounce makes the
        # enable persist across reboots (Set-NetLldpAgent writes the persistent state
        # only when AdminStatus changes).
        Set-NetLldpAgent -NetAdapterName $nic.Name -AdminStatus Disabled -ErrorAction SilentlyContinue
        Set-NetLldpAgent -NetAdapterName $nic.Name -AdminStatus Enabled  -ErrorAction Stop

        # Re-assert host-authoritative DCBX (Willing = False), matching the deployment posture
        Set-NetQosDcbxSetting -InterfaceAlias $nic.Name -Willing $false -Confirm:$false -ErrorAction SilentlyContinue
    }

    # Confirm: Get-NetLldpAgent returns 3 Scope rows per NIC, all with the same
    # status. Collapse to one row per NIC. Read .Status (friendly ScriptProperty:
    # Enabled/Disabled), not .AdminStatus (raw uint32 that renders as an integer).
    foreach ($nic in $fabricNics) {
        $agent = Get-NetLldpAgent -NetAdapterName $nic.Name -ErrorAction SilentlyContinue |
            Select-Object -First 1
        [pscustomobject]@{
            Node        = $env:COMPUTERNAME
            NIC         = $nic.Name
            AdminStatus = if ($agent) { "$($agent.Status)" } else { '(not present)' }
        }
    }
} | Select-Object Node, NIC, AdminStatus
$result | Sort-Object Node, NIC | Format-Table -AutoSize
```

Every NIC should report `AdminStatus = Enabled`. Example output on the two-node
cluster (`ethernet`/`ethernet 2` are the mgmt/compute ports, `ethernet 3`/`ethernet 4`
the storage ports):

```
Node           NIC        AdminStatus
----           ---        -----------
ContosoNode-01 ethernet   Enabled
ContosoNode-01 ethernet 2 Enabled
ContosoNode-01 ethernet 3 Enabled
ContosoNode-01 ethernet 4 Enabled
ContosoNode-02 ethernet   Enabled
ContosoNode-02 ethernet 2 Enabled
ContosoNode-02 ethernet 3 Enabled
ContosoNode-02 ethernet 4 Enabled
```

**Effect:** The Windows LLDP agent remains `Enabled` on the storage NICs across
reboots without requiring a scheduled task (validated on a ConnectX-6 Dx node
through a full Suspend / Restart / Resume cluster reboot cycle), and the host
DCBX Willing flag is set to False (host-authoritative) to match the deployment
posture.

**Confirm durability before proceeding to Step 3.** Reboot one node (or wait for
a planned reboot), then verify `Get-NetLldpAgent` still reports
`AdminStatus = Enabled` on the storage NICs. Only after the Windows LLDP agent
is confirmed durable should you disable the firmware LLDP agent in Step 3.

**Note:** This is an interim workaround, not a supported configuration. It can
be retired only on clusters newly deployed on Azure Local 12.2607 or later,
which carry the platform fix and persist the Windows LLDP agent
state by default. Clusters deployed on an earlier build still need this toggle
even after updating to 12.2607 or later. It is unrelated to the switch-side
forced-PFC step (Step 2), which protects PFC regardless of host LLDP state and
should still be applied.

### Step 2: Force PFC on the Switch [LOW RISK]

> **DO THIS BEFORE STEP 3.** Pinning PFC statically here means PFC no longer
> depends on DCBX negotiation, so the later removal of the firmware DCBX agent
> (Step 3) cannot drop lossless behavior on the storage fabric.

Configure PFC to be enforced locally on each **storage port**, independent
of DCBX negotiation. This is the single most impactful step and works
regardless of the host LLDP configuration. Force PFC ON for priority 3 on the
storage ports, and set the compute and management ports **explicitly OFF**
(see the dedicated step below); compute and management ports do not carry RDMA
traffic on a disaggregated design. If you have not yet identified which switch
ports are the storage ports, work through the "Mapping NIC Roles to Switch
Ports" section first to build the storage port list.

> **Which ports?** Apply the commands below to the **"Storage" rows** of the port
> map you built in "Mapping NIC Roles to Switch Ports" (Step C). Those rows give
> you the exact storage switch ports per node and ToR. Apply forced PFC ON to
> every storage port; do not apply it to any mgmt/compute port.

**Cisco NX-OS** (already the default on most Azure Local deployments):
```
interface ethernet 1/21-36
  priority-flow-control mode on
```
Note: Replace `ethernet 1/21-36` with the actual storage port range from the
"Storage" rows of your port map. Storage ports are typically labeled
`Switched-Storage` in the switch configuration.

**Aruba CX (AOS-CX):**
```
interface 1/1/17-1/1/22
  flow-control priority rxtx 3
```
Note: Replace `1/1/17-1/1/22` with the actual storage port range. The command
`flow-control priority rxtx 3` enables bidirectional (symmetric) PFC for
priority 3 locally on the interface; it is the per-priority PFC command and is
distinct from the plain `flow-control` (802.3x link pause) command, which is
negotiated with the link partner. Priority 3 must already be assigned to a
lossless queue and pool, which the standard Azure Local Aruba QoS template
configures. This syntax applies to AOS-CX 10.10 and later (the
`flow-control priority rxtx <list>` form was finalized in 10.10); Azure Local
Aruba CX deployments typically run 10.13 or later.

> **Lab-validation note (Aruba CX).** The `flow-control priority rxtx 3` syntax is
> verified against the AOS-CX command documentation but was not validated on live
> Aruba hardware in our test lab; the lab evidence in this guide is from Cisco
> NX-OS. See "Known Limitations and Open Items." Confirm the command against your
> AOS-CX version, and validate on a non-production port first.

Follow-on validation (confirm the change took effect on the switch):
```
show interface 1/1/<port> flow-control
```
Run this on a representative storage port immediately after applying the
configuration. The output should show priority-based flow control enabled on
priority 3. If it does not, confirm priority 3 is mapped to a lossless
queue/pool in the active QoS profile before re-applying.

**Set compute and management ports explicitly OFF:**

> **Which ports?** Apply the commands below to the **"Mgmt/Compute" rows** of the
> port map (Mapping NIC Roles to Switch Ports, Step C). These are the ports that
> get PFC explicitly OFF.

On a disaggregated design, set PFC explicitly OFF on the management and compute
ports. This aligns with Microsoft's traffic-class model (management and VM/compute
traffic is in the default class, which is PFC-disabled), and keeps these ports
out of DCBX negotiation entirely so they cannot be affected by the same PFC
auto-negotiation issue that affects storage ports. Use the "Mgmt/Compute" rows
from the port map to identify these ports.

Cisco NX-OS:
```
interface ethernet 1/1-20
  priority-flow-control mode off
```
Aruba CX (AOS-CX): leave the lossless priority unmapped on these interfaces (do
not apply `flow-control priority rxtx 3`). Dell OS10 and Arista EOS:
`priority-flow-control mode off`.

> **Special case (converged topology):** Do NOT set ports OFF if the deployment
> is fully converged (a single intent where the same physical NICs carry storage,
> compute, and management). On a converged port, the storage priority shares the
> physical link, so PFC must remain forced ON. The "Mapping NIC Roles to Switch
> Ports" section tells you which model you have. Guest (in-VM) RDMA is not an
> exception: Guest RDMA is not supported on Azure Local, so tenant VM and AKS Arc
> traffic on a disaggregated compute port never needs PFC.

**Verification:**

Cisco:
```
show interface priority-flow-control
```
Expected: `Mode On, Oper On (8)` on all storage ports.

Aruba:
```
show interface 1/1/<port> flow-control
```
Expected: priority-based flow control shown as enabled on priority 3.

**Effect:** PFC is always on for the RDMA priority class, regardless of
LLDP or DCBX state. ETS and Application Priority are still configured
statically on both host and switch, so DCBX negotiation is not needed for
any DCB parameter.

### Step 3: Disable the Mellanox Firmware LLDP Agent [MEDIUM RISK]

> **THIS STEP APPLIES ONLY TO MELLANOX ConnectX NICs.** Disabling a NIC firmware
> LLDP/DCBX agent is the only part of this remediation that is vendor-specific, and
> the code blocks below use the Mellanox WinMFT tooling (`mst`, `mlxconfig`,
> `mlxfwreset`). The preflight script in this step prints a `NIC CHECK:` line that
> tells you whether this node has Mellanox NICs. If it reports none, **skip Step 3
> entirely**: there is no Mellanox firmware agent to disable. Steps 1 (durable Windows
> LLDP agent) and 2 (forced PFC on the switch) are vendor-agnostic and still apply to
> your cluster. To confirm a non-Mellanox firmware agent (Intel E810, Broadcom) is
> silent, use the vendor-neutral switch-side neighbor-count check in Verification
> After Remediation; if it shows the agent is competing, that same note lists the
> vendor tools and URLs for disabling it.

> **COMPLETE STEP 1 AND STEP 2 FIRST.** This step removes the firmware DCBX/LLDP agent,
> which is what currently negotiates PFC with the switch. Make sure the durable
> Windows LLDP agent is in place (Step 1) and that PFC is forced statically on the
> switch (Step 2) **before** running this. With PFC already pinned on the switch,
> removing the firmware agent cannot drop lossless behavior on the storage fabric.

> **RUN LOCALLY ON EACH AFFECTED NODE, ONE NODE AT A TIME.** Unlike the read-only
> diagnostics earlier in this guide (which fan out from one node with
> `Invoke-Command`), this is a disruptive firmware change: it resets the NIC, so it
> must be run from a PowerShell session **on the node being changed** (RDP into that
> node), and it must be done one node at a time, not fanned out across the cluster.
> Apply it only to the nodes that Diagnosis Step 3 and Diagnosis Step 6 flagged with firmware
> LLDP `ALL(2)`. A node already showing `OFF(0)` on every card is done; skip it. (In
> the worked example, node ContosoNode-01 is already `OFF(0)` and needs no change, while node
> ContosoNode-02 shows `ALL(2)` and is the node to remediate here.)

With the Windows LLDP agent confirmed durable (Step 1), disable the firmware LLDP
agent so the Windows agent becomes the sole LLDP speaker on each storage port.
This eliminates the dual-agent race condition. The `mlxconfig` change is written
to NIC firmware (NVM) and persists across reboots, but it takes effect only after
the NIC receives a PCIe card reset, either by a live `mlxfwreset` or by a full node reboot.

#### How card-level redundancy decides which option is safe

A live `mlxfwreset` resets a whole card (both of its ports) at once. What matters
is therefore not how many ToR switches you have, but how many physical cards back
each traffic plane. The two pictures below show the same four uplinks wired two
different ways. The detection script that follows tells you which one you have.

**Case A: single card per plane (this cluster). NOT card-redundant.**

```
                          NODE
   +------------------------+   +------------------------+
   | Card 1  ConnectX-6 Dx  |   | Card 2  ConnectX-6 Lx  |
   |    STORAGE plane       |   |   MGMT / COMPUTE plane |
   |   P1           P2      |   |   P1           P2      |
   +----+------------+------+   +----+------------+------+
        |            |              |            |
        v            v              v            v
      ToR_A        ToR_B          ToR_A        ToR_B

   Storage plane = Card 1 only.  Reset Card 1 and ALL storage drops.
   Mgmt plane    = Card 2 only.  Reset Card 2 and ALL mgmt drops.

   Each plane still criss-crosses to BOTH ToRs (switch and port redundant),
   but each plane rides a SINGLE card. That is NOT card-redundant, so a
   no-drain card reset (Option 1) would take a whole plane offline.
   You must drain the node first: use Option 2 or Option 3.
```

**Case B: each plane split across two cards. Card-redundant.**

```
                          NODE
   +------------------------+   +------------------------+
   | Card 1  ConnectX-6     |   | Card 2  ConnectX-6     |
   |   P1           P2      |   |   P1           P2      |
   |  STORAGE      MGMT     |   |  STORAGE      MGMT     |
   +----+------------+------+   +----+------------+------+
        |            |              |            |
        v            v              v            v
      ToR_A        ToR_B          ToR_B        ToR_A

   Storage plane = Card 1 P1 + Card 2 P1.  Spans BOTH cards.
   Mgmt plane    = Card 1 P2 + Card 2 P2.  Spans BOTH cards.

   Reset Card 1 and Card 2 still carries a live port in each plane (and
   vice versa). That is card-redundant, so a gated no-drain card reset
   (Option 1) is safe: one card per plane always survives.
```

**First, determine your topology, then choose an activation method.** A live
`mlxfwreset` performs a PCIe reset of one Mellanox card at a time. Whether a PCIe card reset is
non-disruptive depends on how each traffic plane (storage and
management/compute) is spread across the physical cards. Run this on the node to
see which case applies:

```powershell
# NIC CHECK: does this node have Mellanox NICs, and is the WinMFT tooling present?
# Step 3, and every code block in it, applies only to Mellanox NICs.
$mellanoxNics = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceDescription -match 'Mellanox|ConnectX|NVIDIA' }
$winMftPresent = Test-Path 'C:\Program Files\Mellanox\WinMFT\mst.exe'
if (-not $mellanoxNics) {
    "NIC CHECK: No Mellanox NICs detected on this node."
    "  Step 3 is Mellanox-specific and does NOT apply here. Skip Step 3 on this node."
    "  Steps 1 (durable Windows LLDP) and 2 (forced PFC) still apply to this cluster."
    "  The card-level topology verdict below is skipped automatically on this node."
}
elseif (-not $winMftPresent) {
    "NIC CHECK: Mellanox NICs present, but WinMFT (mst.exe) is not installed."
    "  Install WinMFT (see Prerequisites) on this node before running the Option commands below."
}
else {
    "NIC CHECK: Mellanox NICs present and WinMFT is installed. Ready to proceed."
}
""

# How many distinct Mellanox cards back each traffic plane on this node?
# Two ports sharing the same PCI Segment/Bus/Device are one dual-port card.
# This card-level redundancy verdict only governs the Step 3 PCIe card reset, so it
# is computed only when Mellanox NICs are present. On a non-Mellanox node it is
# skipped: Step 3 does not apply, so there is no reset or reboot choice to make.
if (-not $mellanoxNics) {
    "TOPOLOGY VERDICT: not computed on this node (no Mellanox NICs)."
    "  Step 3's Option 1/2/3 PCIe card reset and reboot procedures are Mellanox-only,"
    "  so the card-level redundancy verdict does not apply here."
    "  IMPORTANT: this does NOT mean there is nothing to do. From the host we cannot"
    "  read whether this NIC's firmware LLDP agent is transmitting, so we cannot"
    "  confirm here whether a competing (dual) LLDP agent exists on this cluster."
    "  To find out, use the switch-side neighbor check (see Verification, Switch Side):"
    "  run 'show lldp neighbors' on a storage port. Exactly ONE neighbor (the host)"
    "  means no competing firmware agent and Steps 1 and 2 are sufficient. TWO"
    "  neighbors (host + a NIC-MAC chassis-ID) means a firmware LLDP agent IS"
    "  competing and must be disabled using the NIC vendor's or OEM's procedure,"
    "  which Step 3 does not provide for non-Mellanox NICs."
    "  Steps 1 (durable Windows LLDP) and 2 (forced PFC) apply to this cluster either way."
}
else {
    $storageAdapters = @((Get-NetIntent |
        Where-Object { $_.IntentType -match 'Storage' }).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }
    $mgmtAdapters = @((Get-NetIntent |
        Where-Object { $_.IntentType -notmatch 'Storage' }).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }

    function Get-CardId([string]$Name) {
        $hw = Get-NetAdapterHardwareInfo -Name $Name -ErrorAction SilentlyContinue
        if ($hw) { '{0:x4}:{1:x2}:{2:x2}' -f $hw.Segment, $hw.Bus, $hw.Device }
    }

    $phys = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'Up' }
    $storageCards = @($phys | Where-Object { $storageAdapters -contains $_.Name } |
        ForEach-Object { Get-CardId $_.Name } | Where-Object { $_ } | Sort-Object -Unique)
    $mgmtCards = @($phys | Where-Object { $mgmtAdapters -contains $_.Name } |
        ForEach-Object { Get-CardId $_.Name } | Where-Object { $_ } | Sort-Object -Unique)

    "Storage plane spans $($storageCards.Count) card(s)."
    "Mgmt/Compute plane spans $($mgmtCards.Count) card(s)."
    ""
    if ($storageCards.Count -ge 2 -and $mgmtCards.Count -ge 2) {
        "VERDICT: REDUNDANT (card-level)."
        "  Each plane spans 2 or more cards."
        "  A gated live PCIe card reset keeps both planes up."
        "  ACTION: Option 1 (live PCIe card reset, no drain) is safe."
    } else {
        "VERDICT: NOT-REDUNDANT (card-level / SINGLE-CARD PLANE)."
        "  At least one plane is on a single card."
        "  Do NOT use Option 1."
        "  ACTION: Drain the node first, then use Option 2 (drain + live PCIe card reset)"
        "          or Option 3 (drain + reboot)."
        "  Port and switch redundancy are unaffected."
    }
}
```

**Your topology verdict decides which options are safe; the table lists the three
from least to most conservative (fastest to slowest).** Pick one, then go to that
option's section below and run it from top to bottom. Each option section is
self-contained, so you never need to read the other two.

| Option | Drain node first? | Activation method | Node stays online during the change? | Speed | When to use it |
|--------|-------------------|-------------------|--------------------------------------|-------|----------------|
| Option 1 | No | Live PCIe card reset, one card at a time | Yes, throughout | Fastest | Only when the verdict is REDUNDANT |
| Option 2 | Yes | Live PCIe card reset, one card at a time | No, the node is drained | Medium | Any topology; the recommended choice for a single-card plane |
| Option 3 | Yes | Full node reboot | No, the node is drained and rebooted | Slowest | Any topology; the most conservative fallback |

**How to choose:**

- **Verdict REDUNDANT (each plane spans 2 or more cards):** all three options are
  safe. Option 1 is fastest and needs no drain; pick Option 2 or Option 3 only if
  you would rather drain the node first.
- **Verdict NOT-REDUNDANT (single-card plane):** do **not** use Option 1, because a
  PCIe card reset would take a whole traffic plane down. You must drain first, then
  use Option 2 (recommended) or Option 3.
- **Option 2 versus Option 3 (when you must drain):** Option 2 is faster and keeps
  the node up after a short per-card interruption; choose Option 3 instead when
  `mlxfwreset` reports that a live PCIe card reset is not supported on the NIC or
  firmware, or when you simply prefer a full node reboot.

All three options reach the same end state: the firmware LLDP/DCBX agent disabled
on every Mellanox card on the node. They differ only in how the change is
activated (a live PCIe card reset versus a full node reboot) and whether the node
is drained first. Run your chosen option on the node being remediated.

#### Option 1: Live PCIe card reset, no drain (REDUNDANT topology only)

Use this only if the check above reported REDUNDANT. Each plane spans two or more
cards, so a single PCIe card reset at a time leaves a surviving card in every plane and
the node stays online throughout. Run these two commands in order.

**1. Write the firmware setting to NVM.** This is non-disruptive on its own; it
takes effect only when the NIC receives a PCIe card reset in the next command.

```powershell
# Requires WinMFT (Mellanox Firmware Tools).
$mstDir = 'C:\Program Files\Mellanox\WinMFT'
if (-not (Test-Path (Join-Path $mstDir 'mst.exe'))) {
    # WinMFT is not installed. Say why, and whether Step 3 applies to this node.
    if (Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceDescription -match 'Mellanox|ConnectX|NVIDIA' }) {
        Write-Warning "WinMFT (mst.exe) is not installed, but this node has Mellanox NICs. Install WinMFT (see Prerequisites) and re-run this block."
    }
    else {
        Write-Host "No Mellanox NICs on this node. Step 3 is Mellanox-specific and does not apply here; skip it. Steps 1 and 2 still apply to this cluster."
    }
}
else {
    Push-Location $mstDir

    # Discover all Mellanox firmware devices on this node from `mst status`.
    $devices = @(
        (.\mst.exe status 2>&1) |
            Select-String -Pattern 'mt\d+_pciconf\d+' -AllMatches |
            ForEach-Object { $_.Matches.Value } |
            Sort-Object -Unique
    )

    if (-not $devices) {
        Write-Warning "No Mellanox devices found via 'mst status'. Nothing to do on this node (for example, an Intel-only cluster)."
    }

    # Write the setting to NVM on each device (both ports). Persists across reboots;
    # not yet active until the NIC receives a PCIe card reset below.
    foreach ($dev in $devices) {
        Write-Host "Writing firmware LLDP/DCBX-off setting to $dev ..."
        .\mlxconfig.exe -y -d $dev set LLDP_NB_TX_MODE_P1=0 LLDP_NB_TX_MODE_P2=0 LLDP_NB_RX_MODE_P1=0 LLDP_NB_RX_MODE_P2=0 LLDP_NB_DCBX_P1=0 LLDP_NB_DCBX_P2=0
    }

    Pop-Location
}
```

**2. Activate it with a live PCIe card reset, one card at a time.** This performs a PCIe reset of each
Mellanox card (about 30 seconds offline per card) and waits for both traffic
planes to recover before moving to the next card, so only one card is ever offline
at once. If `mlxfwreset` reports that a live PCIe card reset is not supported on this NIC or
firmware, stop and use Option 3 instead (the NVM setting is already saved and
activates on the next boot).

```powershell
# Requires WinMFT. The NVM write above must have completed on this node first.
$mstDir = 'C:\Program Files\Mellanox\WinMFT'
if (-not (Test-Path (Join-Path $mstDir 'mst.exe'))) {
    # WinMFT is not installed. Say why, and whether Step 3 applies to this node.
    if (Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceDescription -match 'Mellanox|ConnectX|NVIDIA' }) {
        Write-Warning "WinMFT (mst.exe) is not installed, but this node has Mellanox NICs. Install WinMFT (see Prerequisites) and re-run this block."
    }
    else {
        Write-Host "No Mellanox NICs on this node. Step 3 is Mellanox-specific and does not apply here; skip it. Steps 1 and 2 still apply to this cluster."
    }
}
else {
    Push-Location $mstDir

    # Re-discover the Mellanox devices on this node.
    $devices = @(
        (.\mst.exe status 2>&1) |
            Select-String -Pattern 'mt\d+_pciconf\d+' -AllMatches |
            ForEach-Object { $_.Matches.Value } |
            Sort-Object -Unique
    )

    if (-not $devices) {
        Write-Warning "No Mellanox devices found via 'mst status'. Nothing to reset on this node."
    }

    $resetRecoveryTimeout = 60   # max seconds to wait for both planes to recover before the next reset
    $resetPollInterval    = 5    # how often to re-check recovery while waiting

    # Identify the adapters in each traffic plane from the NetworkATC intents, so we
    # wait for BOTH planes (storage and management/compute) to recover between resets
    # rather than guessing a fixed delay or assuming "RDMA enabled" means storage
    # (converged mgmt/compute Mellanox ports are RDMA-capable too).
    $storageAdapters = @((Get-NetIntent |
        Where-Object { $_.IntentType -match 'Storage' }).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }
    $mgmtAdapters = @((Get-NetIntent |
        Where-Object { $_.IntentType -notmatch 'Storage' }).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }

    function Get-UpCount([string[]]$Names) {
        @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
            Where-Object { $Names -contains $_.Name -and $_.Status -eq 'Up' }).Count
    }

    # Default gateway, used as a management-plane reachability check between resets.
    $gateway = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object RouteMetric | Select-Object -First 1 -ExpandProperty NextHop

    $baselineStorage = Get-UpCount $storageAdapters
    $baselineMgmt    = Get-UpCount $mgmtAdapters

    for ($i = 0; $i -lt $devices.Count; $i++) {
        $dev = $devices[$i]
        Write-Host "Activating firmware change on $dev via live PCIe card reset ..."

        # Live per-NIC PCIe reset (~30s offline for this NIC only) to apply the NVM setting.
        .\mlxfwreset.exe -y -d $dev reset

        # Wait for BOTH traffic planes to actually recover before resetting the next
        # card, so only one card is ever down at a time. We poll for real recovery
        # (storage and mgmt/compute adapters back to baseline Up count, SMB
        # Multichannel re-established, and the default gateway reachable) instead of a
        # blind sleep; $resetRecoveryTimeout is only the ceiling.
        if ($i -lt $devices.Count - 1) {
            Write-Host "Waiting for both planes to recover after $dev before the next card ..."
            $deadline = (Get-Date).AddSeconds($resetRecoveryTimeout)
            do {
                Start-Sleep -Seconds $resetPollInterval
                $upStorage = Get-UpCount $storageAdapters
                $upMgmt    = Get-UpCount $mgmtAdapters
                $smb       = @(Get-SmbMultichannelConnection -ErrorAction SilentlyContinue).Count
                $gwOk      = if ($gateway) {
                    Test-Connection -ComputerName $gateway -Count 1 -Quiet -ErrorAction SilentlyContinue
                } else { $true }
                $recovered = ($upStorage -ge $baselineStorage) -and
                             ($upMgmt -ge $baselineMgmt) -and
                             ($smb -ge 1) -and $gwOk
            } until ($recovered -or (Get-Date) -gt $deadline)

            $status = "storage $upStorage/$baselineStorage, mgmt/compute $upMgmt/$baselineMgmt, SMB channels $smb, gateway $(if($gwOk){'ok'}else{'unreachable'})"
            if (-not $recovered) {
                Write-Warning "Both planes did not fully recover after $dev within $resetRecoveryTimeout s ($status). Verify node health before resetting the next card; do not proceed if the node has lost storage or management connectivity."
            } else {
                Write-Host "Both planes recovered ($status)."
            }
        }
    }

    Pop-Location
}
```

> **Important during the live PCIe card reset.** On a converged SET design the
> management/compute plane often rides Mellanox ports too, so when the loop resets
> that card your RDP or SSH session to the node stalls and reconnects on its own.
> Run this option from an out-of-band path (the server's iDRAC, BMC, or KVM
> console) or from a session that tolerates a brief reconnect. The recovery poll
> keeps a surviving card in every plane between resets, but if you see the timeout
> warning, stop and confirm node health (`Get-VirtualDisk | Format-Table
> FriendlyName, HealthStatus, OperationalStatus`; `Get-StorageJob`; and management
> reachability) before continuing. If redundancy turns out thinner than expected,
> switch to Option 2 and drain the node first.

The node was not drained, so there is nothing to resume. Option 1 is complete.

#### Option 2: Drain, then live PCIe card reset (recommended for single-card plane)

Use this if the check above reported NOT-REDUNDANT (single-card plane). Draining
first means the brief per-card interruptions during the live PCIe card reset have no
workload to affect, while you keep the fast live activation (no reboot). Run these
commands in order.

**1. Write the firmware setting to NVM.** Non-disruptive on its own; it takes
effect only when the NIC receives a PCIe card reset below.

> This is the same NVM-write block shown in Option 1. It is repeated here so you
> can follow Option 2 top to bottom; there is no hidden difference to spot.

```powershell
# Requires WinMFT (Mellanox Firmware Tools).
$mstDir = 'C:\Program Files\Mellanox\WinMFT'
if (-not (Test-Path (Join-Path $mstDir 'mst.exe'))) {
    # WinMFT is not installed. Say why, and whether Step 3 applies to this node.
    if (Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceDescription -match 'Mellanox|ConnectX|NVIDIA' }) {
        Write-Warning "WinMFT (mst.exe) is not installed, but this node has Mellanox NICs. Install WinMFT (see Prerequisites) and re-run this block."
    }
    else {
        Write-Host "No Mellanox NICs on this node. Step 3 is Mellanox-specific and does not apply here; skip it. Steps 1 and 2 still apply to this cluster."
    }
}
else {
    Push-Location $mstDir

    # Discover all Mellanox firmware devices on this node from `mst status`.
    $devices = @(
        (.\mst.exe status 2>&1) |
            Select-String -Pattern 'mt\d+_pciconf\d+' -AllMatches |
            ForEach-Object { $_.Matches.Value } |
            Sort-Object -Unique
    )

    if (-not $devices) {
        Write-Warning "No Mellanox devices found via 'mst status'. Nothing to do on this node (for example, an Intel-only cluster)."
    }

    # Write the setting to NVM on each device (both ports). Persists across reboots;
    # not yet active until the NIC receives a PCIe card reset below.
    foreach ($dev in $devices) {
        Write-Host "Writing firmware LLDP/DCBX-off setting to $dev ..."
        .\mlxconfig.exe -y -d $dev set LLDP_NB_TX_MODE_P1=0 LLDP_NB_TX_MODE_P2=0 LLDP_NB_RX_MODE_P1=0 LLDP_NB_RX_MODE_P2=0 LLDP_NB_DCBX_P1=0 LLDP_NB_DCBX_P2=0
    }

    Pop-Location
}
```

**2. Drain the node.**

```powershell
Suspend-ClusterNode -Name $env:COMPUTERNAME -Drain -Wait
```

**3. Activate it with a live PCIe card reset, one card at a time.** This performs a PCIe reset of each
Mellanox card (about 30 seconds offline per card) and waits for both traffic
planes to recover before moving to the next card. Because the node is drained,
these interruptions affect no workload. If `mlxfwreset` reports that a live PCIe card reset
is not supported on this NIC or firmware, skip the loop, reboot the node instead
(the NVM setting activates on boot), then continue to the resume command.

```powershell
# Requires WinMFT. The NVM write above must have completed on this node first.
$mstDir = 'C:\Program Files\Mellanox\WinMFT'
if (-not (Test-Path (Join-Path $mstDir 'mst.exe'))) {
    # WinMFT is not installed. Say why, and whether Step 3 applies to this node.
    if (Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceDescription -match 'Mellanox|ConnectX|NVIDIA' }) {
        Write-Warning "WinMFT (mst.exe) is not installed, but this node has Mellanox NICs. Install WinMFT (see Prerequisites) and re-run this block."
    }
    else {
        Write-Host "No Mellanox NICs on this node. Step 3 is Mellanox-specific and does not apply here; skip it. Steps 1 and 2 still apply to this cluster."
    }
}
else {
    Push-Location $mstDir

    # Re-discover the Mellanox devices on this node.
    $devices = @(
        (.\mst.exe status 2>&1) |
            Select-String -Pattern 'mt\d+_pciconf\d+' -AllMatches |
            ForEach-Object { $_.Matches.Value } |
            Sort-Object -Unique
    )

    if (-not $devices) {
        Write-Warning "No Mellanox devices found via 'mst status'. Nothing to reset on this node."
    }

    $resetRecoveryTimeout = 60   # max seconds to wait for both planes to recover before the next reset
    $resetPollInterval    = 5    # how often to re-check recovery while waiting

    # Identify the adapters in each traffic plane from the NetworkATC intents, so we
    # wait for BOTH planes (storage and management/compute) to recover between resets
    # rather than guessing a fixed delay or assuming "RDMA enabled" means storage
    # (converged mgmt/compute Mellanox ports are RDMA-capable too).
    $storageAdapters = @((Get-NetIntent |
        Where-Object { $_.IntentType -match 'Storage' }).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }
    $mgmtAdapters = @((Get-NetIntent |
        Where-Object { $_.IntentType -notmatch 'Storage' }).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ }

    function Get-UpCount([string[]]$Names) {
        @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
            Where-Object { $Names -contains $_.Name -and $_.Status -eq 'Up' }).Count
    }

    # Default gateway, used as a management-plane reachability check between resets.
    $gateway = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object RouteMetric | Select-Object -First 1 -ExpandProperty NextHop

    $baselineStorage = Get-UpCount $storageAdapters
    $baselineMgmt    = Get-UpCount $mgmtAdapters

    for ($i = 0; $i -lt $devices.Count; $i++) {
        $dev = $devices[$i]
        Write-Host "Activating firmware change on $dev via live PCIe card reset ..."

        # Live per-NIC PCIe reset (~30s offline for this NIC only) to apply the NVM setting.
        .\mlxfwreset.exe -y -d $dev reset

        # Wait for BOTH traffic planes to actually recover before resetting the next
        # card, so only one card is ever down at a time. We poll for real recovery
        # (storage and mgmt/compute adapters back to baseline Up count, SMB
        # Multichannel re-established, and the default gateway reachable) instead of a
        # blind sleep; $resetRecoveryTimeout is only the ceiling.
        if ($i -lt $devices.Count - 1) {
            Write-Host "Waiting for both planes to recover after $dev before the next card ..."
            $deadline = (Get-Date).AddSeconds($resetRecoveryTimeout)
            do {
                Start-Sleep -Seconds $resetPollInterval
                $upStorage = Get-UpCount $storageAdapters
                $upMgmt    = Get-UpCount $mgmtAdapters
                $smb       = @(Get-SmbMultichannelConnection -ErrorAction SilentlyContinue).Count
                $gwOk      = if ($gateway) {
                    Test-Connection -ComputerName $gateway -Count 1 -Quiet -ErrorAction SilentlyContinue
                } else { $true }
                $recovered = ($upStorage -ge $baselineStorage) -and
                             ($upMgmt -ge $baselineMgmt) -and
                             ($smb -ge 1) -and $gwOk
            } until ($recovered -or (Get-Date) -gt $deadline)

            $status = "storage $upStorage/$baselineStorage, mgmt/compute $upMgmt/$baselineMgmt, SMB channels $smb, gateway $(if($gwOk){'ok'}else{'unreachable'})"
            if (-not $recovered) {
                Write-Warning "Both planes did not fully recover after $dev within $resetRecoveryTimeout s ($status). Verify node health before resetting the next card; do not proceed if the node has lost storage or management connectivity."
            } else {
                Write-Host "Both planes recovered ($status)."
            }
        }
    }

    Pop-Location
}
```

> **Important during the live PCIe card reset.** Because the node is drained, no workload is
> affected, but on a converged SET design your interactive RDP or SSH session to
> the node still stalls and reconnects when the management/compute card resets, so
> run this option from an out-of-band path (the server's iDRAC, BMC, or KVM
> console) if you want to watch it. Wait for the loop to report both planes
> recovered before moving on. If the loop prints the timeout warning, confirm node
> health (`Get-VirtualDisk | Format-Table FriendlyName, HealthStatus,
> OperationalStatus`; `Get-StorageJob`) before continuing.

**4. After all resets complete, return the node to service.**

```powershell
Resume-ClusterNode -Name $env:COMPUTERNAME -Failback Immediate
```

Option 2 is complete.

#### Option 3: Drain, then reboot (any topology, most conservative)

Use this on any topology, including a single-card plane, when you prefer a reboot
over a live PCIe card reset (for example, if `mlxfwreset` reports that a live PCIe card reset is not
supported on this NIC or firmware). The firmware change activates on boot, so
there is no PCIe card reset loop. Run these commands in order.

**1. Write the firmware setting to NVM.** Persists across reboots; activates on
the next boot.

> This is the same NVM-write block shown in Options 1 and 2. It is repeated here so
> you can follow Option 3 top to bottom; there is no hidden difference to spot.

```powershell
# Requires WinMFT (Mellanox Firmware Tools).
$mstDir = 'C:\Program Files\Mellanox\WinMFT'
if (-not (Test-Path (Join-Path $mstDir 'mst.exe'))) {
    # WinMFT is not installed. Say why, and whether Step 3 applies to this node.
    if (Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceDescription -match 'Mellanox|ConnectX|NVIDIA' }) {
        Write-Warning "WinMFT (mst.exe) is not installed, but this node has Mellanox NICs. Install WinMFT (see Prerequisites) and re-run this block."
    }
    else {
        Write-Host "No Mellanox NICs on this node. Step 3 is Mellanox-specific and does not apply here; skip it. Steps 1 and 2 still apply to this cluster."
    }
}
else {
    Push-Location $mstDir

    # Discover all Mellanox firmware devices on this node from `mst status`.
    $devices = @(
        (.\mst.exe status 2>&1) |
            Select-String -Pattern 'mt\d+_pciconf\d+' -AllMatches |
            ForEach-Object { $_.Matches.Value } |
            Sort-Object -Unique
    )

    if (-not $devices) {
        Write-Warning "No Mellanox devices found via 'mst status'. Nothing to do on this node (for example, an Intel-only cluster)."
    }

    # Write the setting to NVM on each device (both ports). Activates on the next boot.
    foreach ($dev in $devices) {
        Write-Host "Writing firmware LLDP/DCBX-off setting to $dev ..."
        .\mlxconfig.exe -y -d $dev set LLDP_NB_TX_MODE_P1=0 LLDP_NB_TX_MODE_P2=0 LLDP_NB_RX_MODE_P1=0 LLDP_NB_RX_MODE_P2=0 LLDP_NB_DCBX_P1=0 LLDP_NB_DCBX_P2=0
    }

    Pop-Location
}
```

**2. Drain the node.**

```powershell
Suspend-ClusterNode -Name $env:COMPUTERNAME -Drain -Wait
```

**3. Reboot the node.** The setting written above activates during boot.

```powershell
Restart-Computer -Force
```

**4. After the node rejoins the cluster, return it to service.**

```powershell
Resume-ClusterNode -Name $env:COMPUTERNAME -Failback Immediate
```

Option 3 is complete.

#### Notes that apply to all three options

**Effect:** Removes the firmware LLDP agent's separate identity (the MAC-based
chassis-ID), collapsing each storage port to a single LLDP agent: the Windows
agent (hostname chassis-ID, bare LLDP with no DCBX TLVs). This resolves the
Aruba CX dual-agent `multiple_peers` deadlock. Because the host then presents
no IEEE DCBX peer, a Cisco NX-OS switch in auto mode reports `Detected: CIN`
with `Willing=No` (likely a combination of legacy CEE DCBX TLVs the firmware
adds below the host capture point and the absence of a clean IEEE peer; see
Contributing Factors) and PFC auto-negotiation will not
converge. This is why Step 2 (forced PFC on the switch) is mandatory and is the
actual PFC fix; Step 3 resolves the dual-agent deadlock, not the auto-negotiation
fallback.

**Limitation:** This does not provide DCBX negotiation capability. The
switch must force PFC locally (Step 2).

**Persistence:** The `mlxconfig` change is written to NIC firmware (NVM) and
persists across reboots. It takes effect only after the NIC receives a PCIe card reset.

**NetworkATC interaction:** NetworkATC does not manage `mlxconfig` firmware
settings, so it will not revert this change. However, NIC firmware updates
delivered through SBE or OEM update packages may reset the firmware LLDP
settings to defaults. Re-check after any firmware update.

**What you lose:** Disabling the firmware LLDP agent removes the host's only
DCBX speaker (the firmware-supplied IEEE DCBX). The switch will no longer
receive DCBX PFC or ETS configuration from the host via LLDP. This is why
Step 2 (forced PFC on the switch) is required alongside this step: the switch
must enforce PFC locally because DCBX negotiation is no longer available.

### Why All Three Steps Are Required (on a Mellanox cluster)

The three steps are not alternatives; together they form one remediation and
provide defense in depth:

- Step 1 keeps a single, durable host LLDP identity across reboots.
- Step 2 pins PFC statically on the switch so it never depends on DCBX negotiation,
  and keeps PFC active even if Step 3 is later reverted by an OS update, NIC
  firmware update, or configuration drift.
- Step 3 disables the Mellanox firmware LLDP agent, collapsing each storage port to
  a single LLDP agent and resolving the Aruba CX dual-agent deadlock.

All three steps are independently reversible. Step 1 and Step 2 are control-plane
changes that carry no link disruption; the MEDIUM risk for the overall procedure
comes from Step 3, whose firmware reset drops the link on the card being reset.
Whether the node must be drained first depends on the card-level redundancy verdict:
a REDUNDANT topology can take a live reset without draining (Option 1), while a
NOT-REDUNDANT (single-card plane) topology must be drained first (Option 2 or 3).
See Step 3 for the topology check and options.


## Verification After Remediation

The host-side checks below run cluster-wide from one node: they fan out to every
node with `Invoke-Command` and return a single distilled table, so you do not log
in to each node separately. The switch-side checks are per switch port and are run
on the switch.

### Host Side

```powershell
$nodes = (Get-ClusterNode).Name
$verify = Invoke-Command -ComputerName $nodes -ScriptBlock {
    function Get-Val($lines, $key) {
        $m = $lines | Select-String "$key\s+(\S+)" | Select-Object -First 1
        if ($m) { $m.Matches[0].Groups[1].Value } else { '' }
    }

    # Scope to the NetworkATC fabric uplinks (excludes the iDRAC/BMC USB NIC).
    $atc = @((Get-NetIntent).NetAdapterNamesAsList) |
        ForEach-Object { $_ -split '\s*,\s*' } | Where-Object { $_ } | Sort-Object -Unique
    $fabricNics = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'Up' -and $atc -contains $_.Name })

    $rows = @()

    foreach ($nic in $fabricNics) {
        # Windows LLDP agent returns 3 Scope rows per NIC, all the same; take one.
        $agent = Get-NetLldpAgent -NetAdapterName $nic.Name -ErrorAction SilentlyContinue |
            Select-Object -First 1
        $rows += [pscustomobject]@{ Node = $env:COMPUTERNAME; Check = 'Windows LLDP agent'
            Item = $nic.Name; State = if ($agent) { "$($agent.Status)" } else { '(not present)' }; Expected = 'Enabled' }

        $dcbx = Get-NetQosDcbxSetting -InterfaceAlias $nic.Name -ErrorAction SilentlyContinue
        $rows += [pscustomobject]@{ Node = $env:COMPUTERNAME; Check = 'Host DCBX Willing'
            Item = $nic.Name; State = if ($dcbx) { "$($dcbx.Willing)" } else { '(n/a)' }; Expected = 'False' }

        $rdma = Get-NetAdapterRdma -Name $nic.Name -ErrorAction SilentlyContinue
        $rows += [pscustomobject]@{ Node = $env:COMPUTERNAME; Check = 'RDMA enabled'
            Item = $nic.Name; State = if ($rdma) { "$($rdma.Enabled)" } else { '(n/a)' }; Expected = 'True' }
    }

    # Host PFC on priority 3 (node-level).
    $pfc = Get-NetQosFlowControl -Priority 3 -ErrorAction SilentlyContinue
    $rows += [pscustomobject]@{ Node = $env:COMPUTERNAME; Check = 'Host PFC priority 3'
        Item = 'Priority 3'; State = if ($pfc) { "$($pfc.Enabled)" } else { '(n/a)' }; Expected = 'True' }

    # Mellanox firmware LLDP/DCBX (requires WinMFT; Mellanox NICs only). On a
    # non-Mellanox host this emits one explicit n/a row instead of going silent.
    $mstDir = 'C:\Program Files\Mellanox\WinMFT'
    $nonMlx = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -notmatch 'Mellanox|ConnectX|NVIDIA|Remote NDIS|USB' } |
        ForEach-Object { $_.InterfaceDescription -replace '\s*#\d+\s*$', '' } | Sort-Object -Unique)
    if (-not (Test-Path (Join-Path $mstDir 'mst.exe'))) {
        $rows += [pscustomobject]@{ Node = $env:COMPUTERNAME; Check = 'Mellanox FW LLDP/DCBX'
            Item = 'WinMFT not installed; not host-readable (use switch-side check)'; State = 'n/a'; Expected = 'n/a' }
    }
    else {
        Push-Location $mstDir
        try {
            $devices = @((& .\mst.exe status 2>&1) |
                Select-String 'mt\d+_pciconf\d+' -AllMatches |
                ForEach-Object { $_.Matches.Value } | Sort-Object -Unique)
            if (-not $devices) {
                $what = if ($nonMlx) { "No Mellanox NICs ($($nonMlx -join ', '))" } else { 'No Mellanox NICs' }
                $rows += [pscustomobject]@{ Node = $env:COMPUTERNAME; Check = 'Mellanox FW LLDP/DCBX'
                    Item = "$what; not host-readable (use switch-side check)"; State = 'n/a'; Expected = 'n/a' }
            }
            foreach ($dev in $devices) {
                $q = (& .\mlxconfig.exe -d $dev query 2>&1)
                foreach ($p in 'P1', 'P2') {
                    $rows += [pscustomobject]@{ Node = $env:COMPUTERNAME; Check = 'Mellanox FW LLDP TX'
                        Item = "$dev $p"; State = (Get-Val $q "LLDP_NB_TX_MODE_$p"); Expected = 'OFF(0)' }
                    $rows += [pscustomobject]@{ Node = $env:COMPUTERNAME; Check = 'Mellanox FW DCBX'
                        Item = "$dev $p"; State = (Get-Val $q "LLDP_NB_DCBX_$p"); Expected = 'False(0)' }
                }
            }
        }
        finally { Pop-Location }
    }

    $rows
} | Select-Object Node, Check, Item, State, Expected,
        @{ Name = 'OK'; Expression = { if ($_.Expected -eq 'n/a') { 'n/a' } elseif ($_.State -eq $_.Expected) { 'PASS' } else { 'FAIL' } } }

$verify | Sort-Object Node, Check, Item | Format-Table -AutoSize
```

Every row should read `PASS`. Any `FAIL` row names the node, the check, and the
item (NIC, or Mellanox device and port) that still needs attention. The expected
end state is the Windows LLDP agent `Enabled` on every fabric NIC, host DCBX
`Willing = False`, RDMA `True`, host PFC on priority 3 `True`, and every Mellanox
port reporting firmware LLDP TX `OFF(0)` and firmware DCBX `False(0)`.

Sample (abbreviated; both nodes remediated, additional NIC and device rows
omitted):

```
Node           Check               Item               State    Expected OK
----           -----               ----               -----    -------- --
ContosoNode-01 Host DCBX Willing   ethernet 3         False    False    PASS
ContosoNode-01 Host PFC priority 3 Priority 3         True     True     PASS
ContosoNode-01 Mellanox FW DCBX    mt4125_pciconf0 P1 False(0) False(0) PASS
ContosoNode-01 Mellanox FW LLDP TX mt4125_pciconf0 P1 OFF(0)   OFF(0)   PASS
ContosoNode-01 RDMA enabled        ethernet 3         True     True     PASS
ContosoNode-01 Windows LLDP agent  ethernet 3         Enabled  Enabled  PASS
ContosoNode-02 Host PFC priority 3 Priority 3         True     True     PASS
ContosoNode-02 Mellanox FW LLDP TX mt4127_pciconf0 P2 OFF(0)   OFF(0)   PASS
ContosoNode-02 Windows LLDP agent  ethernet 4         Enabled  Enabled  PASS
```

### Switch Side

> **Which ports?** Verify the **storage ports** from your port map (Mapping NIC
> Roles to Switch Ports, Step C); these must show PFC Oper On. If you also set
> mgmt/compute ports OFF, spot-check one of those "Mgmt/Compute" rows to confirm
> PFC is off there.

**Cisco NX-OS:**
```
show lldp neighbors interface ethernet 1/<port>
show interface priority-flow-control | include Ethernet1/<port>
```
Expected: exactly one LLDP neighbor per port (your host's hostname), PFC Mode On / Oper On. See the neighbor-count note below.

**Aruba CX:**
```
show lldp neighbor-info interface 1/1/<port>
show interface 1/1/<port> flow-control
```
Expected: exactly one LLDP neighbor per port, PFC active on priority 3. See the neighbor-count note below.

> **Reading the neighbor count (vendor-neutral firmware-agent check).** Exactly one
> LLDP neighbor per storage port, your host's hostname, confirms the firmware LLDP
> agent is silent and the Windows agent is the sole speaker. Two neighbors on a port
> (your hostname plus a NIC MAC address as a second chassis-ID) mean a firmware LLDP
> agent is still transmitting. This neighbor count is the authoritative check for any
> NIC vendor, and on non-Mellanox clusters (Intel E810, Broadcom), where the host-side
> table above has no firmware rows to inspect, it is the only way to confirm the
> firmware agent's state.
>
> **If a storage port shows two neighbors on a non-Mellanox NIC**, the firmware agent
> is competing with the Windows agent and should be silenced (the same end state that
> Step 3 achieves on Mellanox). Whether you need to act at all is decided by this
> neighbor count: one neighbor means there is nothing more to do; two neighbors means
> you do. The command to silence the agent is vendor-specific and version-specific, so
> confirm the exact syntax against your NIC vendor's and server OEM's current
> documentation before applying. The general path is the same for every vendor:
> download the vendor's Windows NIC management or firmware tool for your exact adapter
> model, then follow that tool's own documentation for the command that disables the
> firmware LLDP/DCBX agent. Starting points:
>
> - **Broadcom NetXtreme:** use the Broadcom `niccli` (NIC command-line) utility, which
>   sets the adapter's nonvolatile configuration (for example,
>   `niccli -nic <index> -lldp_agent --disable`, or the `-dcbx_agent --disable` form;
>   option names vary by firmware version). Download the utility for your model from the
>   [Broadcom network-adapter portal](https://www.broadcom.com/products/ethernet-connectivity/network-adapters)
>   and see the [NICCLI configuration guide](https://techdocs.broadcom.com/us/en/storage-and-ethernet-connectivity/ethernet-nic-controllers/bcm957xxx/adapters/ethernet-network-adapter-utilities/nic-cli-configuration-utility.html).
>   The same DCB/LLDP control is often also exposed in the server BIOS/UEFI device
>   settings or in the adapter's Windows Advanced properties.
> - **Intel E810:** there is currently no Windows-side toggle (no PROSet setting, no
>   registry key, no PowerShell property) for the firmware LLDP agent; it is governed at
>   the firmware level. Intel documents the behavior in
>   ["FW LLDP Usage Control"](https://cdrdv2-public.intel.com/783899/783899_FW_LLDP_Agent_Usage_Control_v1.1.pdf);
>   drivers and firmware/NVM packages are on the
>   [Intel Download Center](https://www.intel.com/content/www/us/en/download/19314/intel-ethernet-adapter-complete-driver-pack.html).
>   Contact Intel support if your firmware does not expose the control. (On Linux the
>   control is `ethtool --set-priv-flags <interface> fw-lldp-agent off`.) Note that
>   on the tested Intel adapters, host egress with the Windows agent active carries no
>   DCBX TLVs (CONFIRMED); the risk an Intel firmware agent would carry, if active, is
>   the dual-agent `multiple_peers` case (Factor 1) on Aruba CX, not a DCBX dialect.
> - **Server OEM (Dell, HPE, and others):** the firmware DCBX/LLDP agent can also be
>   governed by BIOS/UEFI HII or by BMC (iDRAC, iLO) DCB settings; check the OEM's DCB
>   configuration guide.
>
> Whatever method you use, the goal state is the same: `show lldp neighbors` reports
> exactly one neighbor (the host) per storage port.

## Prevention

1. **Include forced PFC (Resolution Step 2) in standard switch deployment templates.** Ensure all
   Azure Local switch configurations use forced PFC (`priority-flow-control
   mode on` on Cisco, `flow-control priority rxtx 3` on Aruba CX) rather than
   DCBX-negotiated PFC.

2. **Monitor for FW LLDP re-enablement.** NIC firmware updates or SBE
   updates may re-enable the Mellanox FW LLDP agent. Include a periodic
   check in maintenance runbooks.

3. **Run periodic verification** across the cluster after maintenance windows,
   firmware updates, or SBE updates to catch LLDP/DCBX configuration drift. The
   cluster-wide host check is in the Verification After Remediation section above.

4. **Confirm the Windows LLDP agent survives reboot.** After any planned node
   reboot, verify `Get-NetLldpAgent` still reports `AdminStatus = Enabled` on
   the storage NICs. If it reverts to `Disabled`, apply the Resolution Step 1 toggle in
   the Resolution section. The platform fix only
   benefits clusters newly deployed on Azure Local 12.2607 or later; clusters
   deployed on an earlier build still need the toggle even after updating to
   12.2607 or later.

## Background: DCBX Dialects and Why They Matter

DCBX is the protocol that allows a host and switch to automatically
agree on PFC, ETS, and application priority settings. It runs as a set of
TLVs inside LLDP frames.

The problem is that DCBX was implemented by vendors BEFORE the IEEE
finalized the standard, resulting in three incompatible dialects:

### CIN
Cisco Intel Nuova (CIN) was the earliest implementation, developed jointly
by Cisco, Intel, and Nuova Systems (acquired by Cisco in 2008). It uses
proprietary TLV encoding. On Cisco NX-OS 10.3(4a), a storage port in PFC auto
mode reports `Detected: CIN` with `Willing=No` against the affected Mellanox
hosts in the remediated single-agent state. The likely causes are legacy CEE
DCBX TLVs the NIC firmware adds below the host capture point and the absence of
a clean IEEE peer (see Contributing Factors and Known Limitations); the CEE
origin was not confirmed at the wire.

### CEE
Converged Enhanced Ethernet (CEE) was a later pre-standard draft developed
by Intel and partners. It uses OUI `00:1B:21` (Intel's registered OUI). In
the scenarios this guide covers, CEE TLVs are not present on the host's
NDIS-layer egress (CONFIRMED by direction-split packet capture; see Appendix A).
They are nonetheless the suspected source of the Cisco `CIN` detection: an
earlier capture near the host showed CEE alongside IEEE TLVs, and the Mellanox
firmware likely adds the CEE TLVs to the wire below the host capture point. This
was not confirmed at the wire (see Known Limitations).

### IEEE 802.1Qaz (2011, ratified standard)
The Institute of Electrical and Electronics Engineers (IEEE) ratified this
as the final standard. It uses OUI `00:80:C2` (IEEE's own OUI). This is
the only dialect that all modern switches are required to support. Azure
Local's NetworkATC configures the host QoS settings to match the IEEE
standard's PFC and ETS parameters.

### Why DCBX state matters for PFC convergence

When a switch port is configured for PFC auto-negotiation (rather than
forced PFC), the switch uses DCBX to determine whether the host wants PFC
and on which priorities. If the switch has no IEEE 802.1 DCBX peer, it cannot
converge PFC.

On Mellanox ConnectX, the firmware LLDP agent is the component that supplies
IEEE 802.1 DCBX to the switch. With that agent active, a Cisco NX-OS 10.3(4a)
switch in auto mode detects `IEEE 802.1` and PFC converges (Appendix A, states
C1/C2). Once the firmware agent is disabled to resolve the dual-agent conflict,
the host NDIS-layer egress is bare LLDP with no DCBX TLVs (CONFIRMED on both
Mellanox and Intel; Appendix A, states A1/A2), the switch reports `Detected:
CIN` (likely from legacy CEE TLVs the firmware adds below the capture point
combined with the absence of a clean IEEE peer; see Known Limitations), and PFC
auto-negotiation does not converge.

This is why forced PFC (`mode on`) is recommended: it bypasses DCBX
negotiation entirely, so PFC activation does not depend on the host presenting
a DCBX peer.

## Known Limitations and Open Items

**The origin of the CEE DCBX TLVs is not confirmed at the wire.** With the
Windows LLDP agent active and the firmware agent disabled, the host NDIS-layer
egress is bare LLDP with no DCBX TLVs on both Mellanox and Intel (CONFIRMED by
direction-split packet capture). On the same Mellanox host, a Cisco port in PFC
auto mode is detected as `CIN` while a port in forced PFC is detected as
`IEEE 802.1` (CONFIRMED on Cisco NX-OS 10.3(4a)). An earlier
(non-direction-split) capture near the host showed both IEEE 802.1 (`00:80:C2`)
and legacy CEE (`00:1B:21`) DCBX TLVs. Two mechanisms can produce the `CIN`
reading, and both point to forcing PFC: a switch in auto mode that receives both
dialects cannot settle on one and reports `CIN`, and a switch that receives no
clean IEEE peer falls back to its `CIN` default. The likely source of the CEE is
the ConnectX firmware adding the legacy TLVs to the wire below the host capture
point when the Windows agent is the active host agent, which would explain why
the host NDIS capture looks bare. This could not be confirmed directly, because
doing so requires switch-side port mirroring and Top-of-Rack contributor access
that were not available; the direction-split capture attributed the two TLVs to
the switch's inbound side. The remediation (force PFC at the switch) resolves
the symptom under either mechanism. The firmware does not advertise CEE
unconditionally: when it is the sole active agent (states C1/C2), the switch
detects clean IEEE 802.1. The `mlxconfig DCBX_CEE_P1` / `DCBX_CEE_P2` and
`DCBX_IEEE` parameters were not used in the recommended remediation, which does
not depend on suppressing CEE in firmware.

This is consistent with the Azure Local QoS guidance that the host operating
system does not configure or send DCB TLVs (see
[Reference-TOR-QOS-Policy-Configuration.md](./Reference-TOR-QOS-Policy-Configuration.md),
which states the host has no DCBX settings and does not send DCB TLVs back to the
switch). The OS LLDP agent egress is bare (CONFIRMED); any DCBX TLVs reaching the
switch originate from the separate NIC firmware LLDP agent, which Azure Local does
not configure and which this guide disables. The OS-level "no DCB TLVs" posture
and the suspected firmware-level CEE injection are therefore not in conflict:
they describe two different agents.

**The injection point of the firmware DCBX TLVs is not localized.** Both the
firmware-supplied IEEE DCBX (states C1/C2) and the suspected CEE TLVs originate
below the host packet-capture tap, so the captures confirm the switch-side
effect but do not localize where on the host the firmware generates the frames.
This does not affect the remediation.

**Aruba CX PFC syntax (verified against AOS-CX CLI documentation).** The
correct AOS-CX command for locally enabling PFC on priority 3 is
`flow-control priority rxtx 3` at the interface level (confirmed against the
HPE Aruba Networking AOS-CX CLI Bank, `flow-control` command reference, which
applies to the 8100, 8325, 8360, 9300/9300S, and 10000 series). The
`pfc mode forced` / `pfc priority 3 enable` form does not exist on AOS-CX
(that syntax belongs to ArubaOS-Switch / Comware). This syntax has not been
applied on live Aruba hardware in our lab; confirm command availability and
the lossless queue/pool prerequisites against the exact AOS-CX version and
switch model deployed in your environment before applying. Per the AOS-CX
CLI Bank Command History, the `flow-control priority rxtx <list>` syntax was
finalized in AOS-CX 10.10; it is current as of the 2025 documentation and
applies to the 10.13 and 10.16 releases referenced elsewhere in this guide.

## References

- [Physical network requirements for Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/plan/physical-network-requirements)
- [Data Center Bridging (DCB)](https://learn.microsoft.com/en-us/windows-server/networking/technologies/dcb/dcb-top)
- [Priority-based Flow Control (PFC)](https://learn.microsoft.com/en-us/windows-server/networking/technologies/dcb/dcb-top#pfc)
- [Set-NetQosDcbxSetting](https://learn.microsoft.com/en-us/powershell/module/dcbqos/set-netqosdcbxsetting)
- [NVIDIA Mellanox Firmware Tools (WinMFT)](https://network.nvidia.com/products/adapter-software/firmware-tools/)

## Appendix A: Test Evidence Matrix

The following tests were executed on two in-house clusters (7-node Mellanox
ConnectX-6 Lx and 3-node Intel E810) with Cisco NX-OS 10.3(4a) Top-of-Rack
(ToR) switches. Host DCBX on egress was measured with direction-split host
`pktmon` captures (host TX separated from switch RX by source MAC, OUI-decoded
on-box); the "Cisco DCBX detected" column is the DCBX state the switch
reported.

| Test | Win LLDP | FW LLDP | Host DCBX on egress (pktmon TX) | Cisco DCBX detected | PFC (mode on) | PFC (auto) |
|---|---|---|---|---|---|---|
| B1 (production) | Enabled | Enabled (TX) | firmware IEEE [INFERRED] | CIN | On | not tested |
| A1 (baseline) | Enabled | Disabled | none, bare 802.3 [CONFIRMED] | CIN (see note) | On | Off |
| A2 (asserter) | Enabled | Disabled | none, bare 802.3 [CONFIRMED] | CIN (see note) | On | Off |
| C1 (FW only, Willing=True) | Disabled | Enabled (DCBX) | IEEE 802.1 [INFERRED: FW-generated, below host tap] | IEEE 802.1 | On | On |
| C2 (FW only, Willing=False) | Disabled | Enabled (DCBX) | IEEE 802.1 [INFERRED] | IEEE 802.1 | On | On |

The "Cisco DCBX detected" column is the DCBX state the switch reported. In
states A1/A2 the host NDIS-layer egress is bare (CONFIRMED). The `CIN` reading
likely results from legacy CEE DCBX TLVs the Mellanox firmware adds below the
host capture point combined with the absence of a clean IEEE peer (LIKELY; not
captured at the wire, as it requires switch-side port mirroring that was not
available). Both possibilities point to forcing PFC; see Contributing Factors
and Known Limitations.

Key conclusions from the matrix:
- Forced PFC (`mode on`) works in every configuration. No exceptions.
- On the same Mellanox host, a Cisco port in PFC auto detected `CIN` while a
  port in forced PFC (`mode on`) detected `IEEE 802.1` and PFC stayed up
  (CONFIRMED). This per-port contrast is the practical basis for mandating
  forced PFC.
- Auto PFC converges only when the firmware LLDP agent is the active DCBX
  speaker and the switch detects IEEE 802.1 (states C1/C2).
- With the Windows agent active and the firmware agent disabled (states A1/A2),
  host NDIS-layer egress is bare LLDP and the switch reports `CIN`; auto PFC
  does not converge. The host NDIS capture is identical on Mellanox and Intel.
- The Willing flag (True vs False) has no effect on PFC convergence.
- The firmware LLDP agent alone (C1, C2) produces IEEE detection and working
  auto PFC, but this configuration loses the Windows LLDP identity and is not
  recommended for production.

Direction-split wire evidence (host `pktmon` captures, TX separated from RX):
- Mellanox node, A1 state (Windows agent on, firmware agent off): host TX
  (60 frames) carried IEEE 802.3 only, with no IEEE 802.1 and no CEE DCBX TLVs
  (CONFIRMED). The IEEE 802.1 + CEE TLVs observed near the host were inbound
  (switch RX), not host egress.
- Intel node (Windows agent on), negative control: host TX (60 frames) carried
  IEEE 802.3 only, with no DCBX TLVs (CONFIRMED), matching the Mellanox A1
  result.
- No host-side OUI-level decode was captured for the firmware-only states
  (C1/C2); the firmware-supplied IEEE DCBX is inferred from the switch-side
  detection.

Aruba CX `multiple_peers` behavior referenced elsewhere in this guide is
inferred from a production deployment; it was not reproduced in
this Cisco test matrix.

## Appendix B: Switch-Side Command Reference

> For any command below that takes a `<port>`, substitute the specific switch
> ports from the port map you built in "Mapping NIC Roles to Switch Ports"
> (Step C): the "Storage" rows for storage-port checks, the "Mgmt/Compute" rows
> when verifying those ports.

### Cisco NX-OS
```
show lldp neighbors detail
show lldp dcbx interface ethernet 1/<port>
show interface priority-flow-control
show queuing interface ethernet 1/<port>
show interface counters errors non-zero
show logging last 200
```

### Aruba CX (AOS-CX)
```
show lldp neighbor-info detail
show interface 1/1/<port> flow-control
show qos interface 1/1/<port>
show running-config interface 1/1/<port>
```

### Dell OS10 / Enterprise SONiC
```
show lldp neighbors detail
show pfc counters
show qos interface
show ecn
show running-config
```

### Arista EOS
```
show lldp neighbors detail
show priority-flow-control
show dcbx
show interfaces counters errors
```

## Appendix C: Acronym Quick Reference

| Acronym | Full Name | One-Sentence Definition |
|---|---|---|
| **ATC** | Network Adapter Traffic Control | Azure Local's automated host networking configuration engine; manages QoS, VLAN, and RDMA settings on storage NICs. It does not manage the Windows LLDP agent, whose lifecycle is owned by the OS and which is enabled by the pre-deployment Environment Validator. |
| **CEE** | Converged Enhanced Ethernet | A pre-standard DCBX dialect (OUI `00:1B:21`) developed by Intel as a stepping stone toward IEEE 802.1Qaz; still emitted by some Mellanox NIC firmware. |
| **CIN** | Cisco Intel Nuova | The earliest pre-standard DCBX dialect (2008), co-developed by Cisco, Intel, and Nuova Systems; Cisco NX-OS uses "CIN" as its internal label when it detects pre-standard DCBX framing. |
| **CoS** | Class of Service | An 802.1p priority tag (0 through 7) carried in the VLAN header that identifies the traffic class a frame belongs to. |
| **CSV** | Cluster Shared Volume | A shared filesystem layer that allows multiple cluster nodes to read and write the same NTFS or ReFS volume simultaneously. |
| **DCB** | Data Center Bridging | A collection of IEEE standards (PFC, ETS, DCBX) that enable lossless Ethernet for storage traffic. |
| **DCBX** | Data Center Bridging Exchange | An LLDP-based protocol that allows a host and switch to negotiate PFC, ETS, and application priority settings automatically. |
| **ETS** | Enhanced Transmission Selection | IEEE 802.1Qaz feature that allocates bandwidth percentages to traffic classes (e.g., 50% for RDMA, 1% for cluster heartbeat). |
| **FW** | Firmware | In this document, refers to the NIC's onboard firmware (Mellanox ConnectX or Intel E810), which runs independently of the OS. |
| **IEEE** | Institute of Electrical and Electronics Engineers | The standards body that ratified 802.1Qaz (ETS), 802.1Qbb (PFC), and 802.1AB (LLDP). |
| **iWARP** | Internet Wide Area RDMA Protocol | An RDMA transport that runs over TCP; does not require PFC or ETS because TCP handles retransmission. |
| **LLDP** | Link Layer Discovery Protocol | IEEE 802.1AB protocol used by network devices to advertise their identity and capabilities to directly connected neighbors. |
| **NIC** | Network Interface Card | The physical network adapter in the server. |
| **NVM** | Non-Volatile Memory | Persistent storage on the NIC that holds firmware configuration parameters (e.g., `mlxconfig` settings). |
| **OUI** | Organizationally Unique Identifier | A 3-byte prefix in LLDP TLVs that identifies which organization defined the TLV (e.g., `00:80:C2` = IEEE, `00:1B:21` = Intel/CEE). |
| **PFC** | Priority Flow Control | IEEE 802.1Qbb feature that sends pause frames for specific CoS priorities, preventing packet drops on lossless traffic classes. |
| **RDMA** | Remote Direct Memory Access | A technology that allows one server to read from or write to another server's memory without involving either server's CPU. |
| **RoCE** | RDMA over Converged Ethernet | Version 1 runs over Ethernet (layer 2); version 2 (RoCEv2) runs over UDP and requires PFC for lossless delivery. |
| **S2D** | Storage Spaces Direct | The software-defined storage subsystem in Azure Local that pools local disks across cluster nodes into shared volumes. |
| **SMB** | Server Message Block | The file-sharing protocol used by Azure Local for storage traffic; SMB Direct enables RDMA acceleration. |
| **TLV** | Type-Length-Value | The encoding format for data elements within an LLDP frame; each TLV carries one piece of information (e.g., chassis ID, PFC config). |
| **ToR** | Top-of-Rack | The network switch physically located at the top of the server rack, connecting all servers in that rack to the network. |
