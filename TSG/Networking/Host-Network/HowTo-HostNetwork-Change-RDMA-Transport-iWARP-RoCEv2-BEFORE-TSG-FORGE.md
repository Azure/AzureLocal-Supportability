# TSG Validation Report Card: HowTo_HostNetwork_Change_RDMA_Transport_iWARP_RoCEv2

- **TSG:** `TSG/Networking/Host-Network/HowTo-HostNetwork-Change-RDMA-Transport-iWARP-RoCEv2.md`
- **Cluster:** not-applicable | **When:** 2026-09-30T22:24:00Z

The timestamp records when this create-once card was rendered from the preserved baseline assessment. The baseline assessment predates the refined article and the AFTER card.

## Summary

| # | Step | Result |
| --- | --- | --- |
| 1 | Static baseline article reviewed | PASS |
| 2 | Canonical 13-persona panel completed | PASS |
| 3 | Live transport-change failure injected | NA |
| 4 | Live detection and outage-state evidence captured | NA |
| 5 | Documented remediation or rollback applied | NA |
| 6 | Live platform recovery and transport revalidation completed | NA |
| 7 | Persona usability grade | 2.8 / 5 |
| 8 | Overall TSG grade | F |

## Overall grade: F (FAIL)
Baseline static review before TSG Forge refinements. The first mechanical lint failed the PickleFactory publication contract and warned on administrator-surface coverage. No live protocol flip was performed.

## Validation loop evidence

| Step | Result | Detail |
| --- | --- | --- |
| Static baseline article reviewed | PASS | The unmodified baseline article was reviewed for usability, safety gates, command clarity, rollback coverage, and evidence expectations. |
| Canonical 13-persona panel completed | PASS | Each persona from the canonical tsg-forge/personas/v1 definition evaluated the same baseline article once. |
| Live transport-change failure injected | NA | No live Azure Local cluster or reversible iWARP/RoCEv2 transport-change inject was used for this baseline static review. |
| Live detection and outage-state evidence captured | NA | The documented Network ATC, storage, MOC, VM, SMB Direct, and fabric signals were not exercised during a live protocol flip. |
| Documented remediation or rollback applied | NA | No state-changing command, protocol migration, or rollback was performed. |
| Live platform recovery and transport revalidation completed | NA | No inject, detect, remediate, revalidate, or residue check was performed; technical verdict remains PENDING. |

## Persona usability panel
Overall usability score: **2.8 / 5** across 13 personas. Each persona gives two short sentences: what was most useful, and the one change they want.

| Persona | Score | Most useful | Suggested change |
| --- | --- | --- | --- |
| IT Director | 4 | The opening table clearly identifies the multi-hour full outage, required owners, OEM involvement, and high-risk support boundary. | Add a one-page change-control summary with phase estimates, a point-of-no-return, rollback decision triggers, and the named decision owner for each gate. |
| Outsourced MSP Technician | 2 | The procedure repeatedly stops on ambiguity and seals resource identities before high-risk cluster operations. | Replace the appliance step's bare Stop-VM command with an explicitly graceful shutdown method and provide a restart-safe resume procedure that reconstructs every required variable from sealed files after a lost session. |
| Mid-career Generalist Sysadmin | 3 | The dependency order from workloads through CSVs, pool, Network ATC, and platform restoration is unusually explicit and fail-closed. | Turn the long sequence into checkpointed phases with a persisted state file and exact resume or rollback commands, because the current rollback depends on in-memory objects surviving a multi-hour outage. |
| Network Engineer | 3 | The guide correctly distinguishes PFC from ECN-based sender rate control and warns against copying vendor tuning values. | Define the exact pre-change and post-change fabric evidence package for RoCEv2, including port mapping, DCBX mode, priority, PFC, ETS, ECN/WRED, drops, pauses, queue depth, and endpoint ECT or DCQCN confirmation. |
| App / VM Engineer | 2 | The guide gives the workload owner control of shutdown and startup and refuses bulk VM operations without application approval. | Correct the appliance shutdown step because Stop-VM without -Shutdown is not the graceful guest shutdown the prose promises, and add explicit application health and dependency checks after startup. |
| New-grad IT Temp | 2 | The glossary and repeated expected-result and stop-condition blocks explain many Azure Local concepts before the risky steps. | Add a phase checklist that says exactly which commands are copied together, which variables must already exist, how to reopen a fresh session, and what output means stop versus proceed. |
| Microsoft CSS Support Engineer | 3 | The article preserves identities and asks for before-and-after intent, storage, VM, SMB, health, and switch evidence suitable for remote escalation. | Provide an automated collection bundle with UTC phase markers and a support handoff trigger at every failed gate, rather than relying on a transcript plus manually saved output. |
| Microsoft CSAM | 4 | The business impact, participating teams, multi-hour duration, full outage, and escalation owners are visible before technical detail. | Add a concise customer communication timeline with planned checkpoints, success criteria, rollback trigger time, and expected service-restoration updates. |
| Partner / SI Deployment Engineer | 3 | The adapter capability fan-out and preservation of existing Network ATC overrides support heterogeneous multi-node deployments without overwriting unrelated settings. | Add a reusable preflight script that emits one signed or hashed readiness report across all nodes and identifies OEM-specific unsupported adapters before the maintenance window. |
| OEM Hardware Vendor Field Engineer | 3 | The support boundary correctly requires the OEM to approve the adapter, driver, firmware, solution, and target-transport combination. | Specify the exact OEM evidence fields and acceptance artifact required, including adapter SKU, firmware, driver, supported transport, congestion-control capability, and any reboot or activation requirement. |
| Satya Nadella (CEO lens) | 3 | The guide is candid about risk and gives customers a disciplined path instead of implying that a transport migration is a routine live change. | Reduce operator cognitive load with a generated change packet, accessible phase summaries, and explicit handoffs so success does not depend on one expert retaining a very long PowerShell session. |
| Steve Ballmer (energy / field lens) | 3 | The at-a-glance sequence gets directly to the outage order and makes clear that the fastest unsafe shortcut is unacceptable. | Front-load a go or no-go command that produces one readiness verdict and a red stop reason, then give a short execution scoreboard so the field can see exactly where the change stands. |
| Mark Russinovich (deep-systems lens) | 2 | The procedure protects explicit Network ATC overrides, seals cluster resource identities, separates desired state from active RDMA proof, and avoids destructive storage repair. | Fix the false graceful-shutdown claim around Stop-VM, persist enough typed state to reconstruct rollback after process loss, and live-prove both transport directions before treating the command sequence as technically validated. |

## Work items to fix the TSG (rows scoring below 5)
13 reviewer(s) scored below 5. Each row is a change that would raise a reviewer's score; make these in the TSG PR.

| # | Change to make | Theme | Raises | Requested by |
| --- | --- | --- | --- | --- |
| 1 | Replace the appliance step's bare Stop-VM command with an explicitly graceful shutdown method and provide a restart-safe resume procedure that reconstructs every required variable from sealed files after a lost session. | restart-safe-command-path | 2 to 5 | Outsourced MSP Technician, Mid-career Generalist Sysadmin, Mark Russinovich (deep-systems lens) |
| 2 | Add a phase checklist that says exactly which commands are copied together, which variables must already exist, how to reopen a fresh session, and what output means stop versus proceed. | operator-checkpoints | 2 to 5 | New-grad IT Temp, Satya Nadella (CEO lens), Steve Ballmer (energy / field lens) |
| 3 | Add a one-page change-control summary with phase estimates, a point-of-no-return, rollback decision triggers, and the named decision owner for each gate. | executive-change-plan | 4 to 5 | IT Director, Microsoft CSAM |
| 4 | Define the exact pre-change and post-change fabric evidence package for RoCEv2, including port mapping, DCBX mode, priority, PFC, ETS, ECN/WRED, drops, pauses, queue depth, and endpoint ECT or DCQCN confirmation. | fabric-proof | 3 to 5 | Network Engineer, OEM Hardware Vendor Field Engineer |
| 5 | Provide an automated collection bundle with UTC phase markers and a support handoff trigger at every failed gate, rather than relying on a transcript plus manually saved output. | evidence-automation | 3 to 5 | Microsoft CSS Support Engineer, Partner / SI Deployment Engineer |
| 6 | Correct the appliance shutdown step because Stop-VM without -Shutdown is not the graceful guest shutdown the prose promises, and add explicit application health and dependency checks after startup. | graceful-workload-control | 2 to 5 | App / VM Engineer |

> Addressing all 6 work item(s) is projected to bring every reviewer to 5, a perfect 5/5 panel.

---
INTERNAL USE ONLY -- findings must be independently validated before action.