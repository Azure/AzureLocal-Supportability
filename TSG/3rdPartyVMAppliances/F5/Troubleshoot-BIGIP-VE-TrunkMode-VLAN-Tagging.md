# F5 BIG-IP Virtual Edition Sees the Wrong VLAN ID on Frames Delivered via a Hyper-V Trunk-Mode vNIC

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Networking / Third-Party VM Appliances</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>High</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Hosting F5 BIG-IP Virtual Edition as a Hyper-V guest on Azure Local, with a vNIC in VLAN trunk mode</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td><strong>F5 BIG-IP VE 17.5.1.x builds earlier than 17.5.1.6 (confirmed on 17.5.1.3 Build 0.0.19). All currently supported Azure Local releases.</strong></td>
  </tr>
</table>

## Overview

When an F5 BIG-IP Virtual Edition (VE) guest runs on an Azure Local Hyper-V host with a virtual NIC attached to the Hyper-V virtual switch in **VLAN trunk mode**, BIG-IP builds earlier than **17.5.1.6** parse the 802.1Q Tag Control Information (TCI) field incorrectly. The Priority (PCP) bits of the TCI are concatenated onto the VLAN Identifier (VID) instead of being held separately, so BIG-IP reports a VLAN ID that is the true VID shifted left by four bits. For example, VLAN **201** (hex `0xC9`) is read by the guest as VLAN **3216** (hex `0xC90`) when PCP is `0`. Traffic is therefore classified to a VLAN inside F5's Traffic Management Operating System (TMOS, the OS that runs on BIG-IP) that does not correspond to the tag actually on the wire, and per-VLAN listeners, virtual servers, and routing decisions downstream of the F5 behave incorrectly.

The 802.1Q tag itself is present and correct on the frames arriving at the guest — the Azure Local host delivers them correctly — the defect is in how the F5 guest's high-performance network driver path (`xnet`/`dpdk`) reads the TCI field. This is a defect in F5 BIG-IP's guest-side driver; it is **not** an Azure Local host, Hyper-V virtual switch, or physical-fabric issue. Fix: upgrade the F5 BIG-IP VE guest to **17.5.1.6 or later**. No Azure Local host configuration change is required.

The same F5 configuration running on VMware ESXi, or running on Hyper-V with the vNIC in access mode (single VLAN — no 802.1Q tag visible to the guest), is not affected — the defect is specific to the combination of an affected F5 build, the `xnet`/`dpdk` driver path, and a Hyper-V trunk-mode vNIC.

## Symptoms

**Observable behaviors:**

- BIG-IP sees traffic on a trunk vNIC, but classifies it to an unexpected TMOS VLAN that corresponds to the true VLAN ID shifted left by four bits.
- The mis-read VLAN ID matches the pattern `(PCP << 13) | (DEI << 12) | VID` treated as a single value. With PCP = 0 and DEI = 0, that reduces to `VID << 4`. Example: VLAN 201 on the wire appears inside BIG-IP as VLAN 3216 (201 × 16).
- Traffic sent on VLAN `X` is classified by BIG-IP as if it arrived on a different VLAN (`VID << 4`) bound to the same trunk interface. Virtual servers, self-IPs, and routing rules scoped to VLAN `X` do not match, while rules scoped to the shifted VLAN match traffic that was not intended for them.
- Downstream services that rely on correct per-VLAN handling through the F5 break in ways that look like configuration drift: for example, Citrix Provisioning Services (PVS) DHCP reservations failing for hosts on the "broken" VLAN, VLAN tagging not being honored end-to-end, and target VMs failing to boot because DHCP/PXE replies are returned on the wrong VLAN.
- The same BIG-IP VE, identically configured, works correctly when moved to a Hyper-V vSwitch in **access mode** (single VLAN, no 802.1Q tag reaches the guest), or when running on VMware ESXi.
- Host-side packet captures taken on the Azure Local host (filtered to the F5 VM's vNIC MAC) show the **correct** 802.1Q VLAN IDs on frames delivered to the guest — proving the host is not mis-tagging.

**Confirming the driver path on the F5 VE:**

```text
# The defect lives in the xnet/dpdk driver path. From a root shell on the BIG-IP VE:
tmsh show /sys software status
tmctl -d blade tmm/device_probed
tmctl -d blade tmm/xnet/device_probed

# If tmm/xnet/device_probed shows driver_selected = dpdk on a pre-17.5.1.6 build
# with a trunk-mode vNIC, this TSG applies.
```

**Confirming the tag-parsing signature in-guest (decisive):**

```text
# On the F5 BIG-IP VE, capture on the trunk interface (for example, 1.1) while sending
# tagged traffic from a known source IP:
tcpdump -ni <trunkInterface> -e host <sourceIP>

# Compare the VLAN ID decoded by tcpdump in the guest to the VLAN ID known to be on
# the wire at the host (from a host-side capture). If the guest-side VLAN ID equals
# the host-side VLAN ID shifted left by four bits (i.e., true_vid * 16 when PCP=0),
# the bug is confirmed.
```

## Root Cause

In F5 BIG-IP VE builds earlier than 17.5.1.6, the `xnet`/`dpdk` receive path does not parse the 802.1Q Tag Control Information (TCI) field correctly when frames arrive from a Hyper-V synthetic NIC in trunk mode. Instead of extracting only the 12-bit VID from the TCI, the driver treats the Priority (PCP) and Drop Eligible Indicator (DEI) bits as if they were the low-order bits of the VID. The observable effect is that the VID reported to TMOS equals `(PCP << 13) | (DEI << 12) | true_vid` — which, in the common case of PCP = 0 and DEI = 0, is the true VID multiplied by 16 (left-shifted by four bits). The 802.1Q tag on the wire is correct; the parsing inside the F5 guest is not.

Put another way, the bug bites at the boundary between Hyper-V and BIG-IP: Hyper-V hands the frame and its NDIS VLAN metadata to the netvsc PMD, the PMD mis-packs that metadata into the mbuf's `vlan_tci`, and TMM then matches the wrong VID against your TMOS VLAN configuration — so the tagged TMOS VLAN never sees its traffic.

The defect lives in the **DPDK `netvsc` poll-mode driver (PMD)** — the DPDK driver that talks to Hyper-V synthetic NICs — which F5's `xnet`/`dpdk` path links against. The bug has a specific upstream fix in DPDK:

- **Upstream fix:** [`DPDK/dpdk@f7654c8c13f4`](https://github.com/DPDK/dpdk/commit/f7654c8c13f46ab537e8220ea4d6b4911f9f0fd5) — `net/netvsc: fix VLAN metadata parsing` (merged 2024-02-19; `Cc: stable@dpdk.org` so backported to DPDK stable branches).
- **File:** `drivers/net/netvsc/hn_rxtx.c`.
- **What the commit says:** "The previous code incorrectly parsed the VLAN ID and priority. If the 16-bits of VLAN ID and priority/CFI on the wire was `0123456789ABCDEF` the code parsed it as `456789ABCDEF3012`. There were macros defined to handle this conversion but they were not used."
- **Regression origin:** the netvsc PMD shipped with this bug from its original "add Hyper-V network device" commit ([`4e9c73e96e83`](https://github.com/DPDK/dpdk/commit/4e9c73e96e83)) — it was latent in netvsc from day one and only surfaces under 802.1Q trunk mode, which is why it was not caught earlier.

F5 BIG-IP 17.5.1.3 was built against a netvsc PMD predating the fix, which is why the `xnet`/`dpdk` path exhibits the bug. F5 Engineering has confirmed this defect and delivered the fix in BIG-IP 17.5.1.6.

## Resolution

### Prerequisites

- Administrative access to the affected F5 BIG-IP VE.
- Ability to obtain an F5 BIG-IP VE build of **17.5.1.6 or later** from F5's standard distribution channels. (If 17.5.1.6 is not yet published in your distribution channel, open a support case with F5 and reference this interoperability defect to obtain the corresponding pre-GA engineering hotfix.)
- A maintenance window for the F5 upgrade.

### Steps

1. **Confirm the host side is delivering tagged frames correctly (optional but recommended)**
   Rule the Azure Local host out before upgrading F5. On the Azure Local host that owns the F5 VM:

   ```powershell
   # Confirm the F5 VM's data vNIC is configured for trunk with the expected VLAN list
   Get-VMNetworkAdapterVlan -VMName <F5VmName>
   # Expect: OperationMode=Trunk with the correct AllowedVlanIdList on the data adapter,
   #         and OperationMode=Access on any single-VLAN management adapter.

   # Confirm the adapter is healthy and connected to the expected vSwitch
   Get-VMNetworkAdapter -VMName <F5VmName> | Format-List Name, SwitchName, MacAddress, Status
   ```

   If `Get-VMNetworkAdapterVlan` shows the expected trunk configuration and the adapter is healthy, the host is not the cause.

2. **Record the current F5 BIG-IP VE build**
   From the F5 management console:

   ```bash
   # On the F5 BIG-IP VE
   tmsh show sys version
   # If the output shows a version earlier than 17.5.1.6 (for example, 17.5.1.3 Build 0.0.19),
   # this TSG applies.
   ```

3. **Upgrade the F5 BIG-IP VE to 17.5.1.6 or later**
   Follow F5's standard BIG-IP VE upgrade procedure from F5 documentation. Microsoft does not distribute F5 builds; obtain the image from F5's standard channels. No Azure Local host-side change is required as part of the upgrade.

4. **Verify resolution**
   After the upgrade, from the F5 BIG-IP VE:

   ```bash
   # Confirm the running version
   tmsh show sys version

   # Confirm traffic is now classified to the expected TMOS VLANs on the trunk interface
   tmsh show net vlan

   # Confirm interface counters are advancing as expected on the correct per-VLAN members
   tmsh show net interface
   ```

   Downstream services that depend on correct per-VLAN handling through the F5 (for example, Citrix PVS DHCP reservations and VLAN-segmented VM boot) should return to normal.

## Prevention

- When planning to host F5 BIG-IP Virtual Edition on Azure Local with a Hyper-V trunk-mode vNIC, require **BIG-IP 17.5.1.6 or later** as a deployment prerequisite.
- When migrating third-party virtual appliances from VMware to Azure Local, validate VLAN-trunk behavior in a lab environment on the target appliance build before cutover. Vendor-side guest driver differences between hypervisors can expose latent defects that did not surface on the source hypervisor.

## What Not To Do

- Do not change the Hyper-V vSwitch from trunk mode to access mode as a long-term workaround. That collapses BIG-IP's VLAN-trunking design and is not a supported substitute for running a fixed F5 build.
- Do not alter `AllowedVlanIdList`, VLAN IDs, or other host-side trunk settings in an attempt to compensate. The host is delivering the frames correctly; the fix must be on the F5 side.
- Do not disable or modify synthetic NIC drivers, VMQ, or other Hyper-V networking features on the Azure Local host as a workaround. Those changes do not address the guest-side defect and can introduce unrelated platform issues.

## Related Issues

- F5 BIG-IP 17.5.1.6 release notes (vendor documentation).
- [DPDK commit `f7654c8c13f4` — `net/netvsc: fix VLAN metadata parsing`](https://github.com/DPDK/dpdk/commit/f7654c8c13f46ab537e8220ea4d6b4911f9f0fd5) — upstream DPDK fix that F5 BIG-IP 17.5.1.6 incorporates. Any DPDK-based virtual appliance running on Hyper-V that was built against a netvsc PMD predating this commit is a candidate for the same defect.
- [`Set-VMNetworkAdapterVlan`](https://learn.microsoft.com/powershell/module/hyper-v/set-vmnetworkadaptervlan) — Hyper-V PowerShell reference for VM VLAN configuration.

---
