# TSG Validation Report Card: HowTo_HostNetwork_Change_RDMA_Transport_iWARP_RoCEv2

- **TSG:** TSG/Networking/Host-Network/HowTo-HostNetwork-Change-RDMA-Transport-iWARP-RoCEv2.md
- **Cluster:** not-applicable | **When:** 2026-10-01T00:11:13Z

## Summary

| # | Step | Result |
| --- | --- | --- |
| 1 | Supported source values | PASS |
| 2 | Sealed identities | PASS |
| 3 | Persisted directional state | PASS |
| 4 | Ambiguous-dispatch protection | PASS |
| 5 | Point-of-no-return servicing and quiescence recheck | PASS |
| 6 | Exact Network ATC and adapter coverage | PASS |
| 7 | Active SBL RDMA and zero TCP data connections | PASS |
| 8 | Quorum, witness, and platform health holds | PASS |
| 9 | State-aware rollback preflight | PASS |
| 10 | Operation-scoped evidence with terminal transient failures | PASS |
| 11 | Static lint A | PASS |
| 12 | PowerShell AST 32/32 | PASS |
| 13 | Persona usability grade | 5 / 5 |
| 14 | Overall TSG grade | A |

## Overall grade: A (PASS)
Static L0 only. No live iWARP-to-RoCEv2 or RoCEv2-to-iWARP transport flip was performed.

## Validation loop evidence

| Step | Result | Detail |
| --- | --- | --- |
| Supported source values | PASS | The guide accepts only sealed iWARP value 1 or RoCEv2 value 4, rejects mixed or unknown source values, and rejects a no-op target. |
| Sealed identities | PASS | CSV, complete virtual-disk inventory, pool, MOC, appliance, VM, intent, node, and adapter identities are sealed and re-resolved before mutation. |
| Persisted directional state | PASS | Operation, desired transport, desired value, phase, active-validation start time, and rollback origin persist across session loss and are integrity-checked on resume. |
| Ambiguous-dispatch protection | PASS | IntentSubmissionPending is durable before Set-NetIntent, and an uncertain return requires live desired-state reconciliation instead of resubmission. |
| Point-of-no-return servicing and quiescence recheck | PASS | Immediately before dispatch, the guide rechecks servicing, CAU, nodes, faults, jobs, quorum, sealed identities, offline state, intent health, overrides, adapters, and VM quiescence. |
| Exact Network ATC and adapter coverage | PASS | Every expected node and adapter pair must appear exactly once, the intent name must match, provisioning must be clean, and the complete explicit override set must round-trip unchanged except for transport. |
| Active SBL RDMA and zero TCP data connections | PASS | Representative-load validation requires selected SBL channels, client and server RDMA capability, at least one RDMA connection, and zero TCP data connections on every sealed node. |
| Quorum, witness, and platform health holds | PASS | Restoration and final validation require continuous clean holds covering quorum witness, servicing, nodes, sealed storage identities, Network ATC, MOC, appliance, workloads, events, and active RDMA. |
| State-aware rollback preflight | PASS | Rollback is allowed only from defined forward phases, requires healthy and idle live state appropriate to the origin phase, validates the sealed source direction, and persists RollbackApproved before quiescence. |
| Operation-scoped evidence with terminal transient failures | PASS | Forward and rollback evidence is operation-scoped. Final-hold event exports are attempt-and-sample unique, use no-clobber writes, and terminal artifacts retain the exact evidence paths. Any unhealthy sample or collection exception is a sticky terminal failure requiring explicit disposition. |
| Static lint A | PASS | The final public How-To satisfies the Static L0 structure, safety, metadata, applicability, expected-result, rollback, verification, and escalation requirements represented in the article. |
| PowerShell AST 32/32 | PASS | All 32 PowerShell blocks are represented by the current static evidence as successfully parsed with the PowerShell abstract syntax tree parser. |

## Structure & safety lint
Static structure and safety checks (lint grade **A**). This is the documentation-hygiene component of the report, not the whole TSG grade. The overall grade also requires the live loop and the persona panel.
Static lint grade A: static structure and safety checks all pass.

| Check | Status | Note |
| --- | --- | --- |
| tsg_metadata_contract | pass | Valid public tsg-metadata marker (document_type=how-to, fidelity=L0, automation=manual). |
| picklefactory_contract | info | PickleFactory YAML is not applicable because this public GitHub article uses the repository tsg-metadata contr |
| h1_present | pass | H1 present (How to change the storage RDMA transport between iWARP and RoCEv2 on Azure Local). |
| severity_present | pass | Severity implied by a keyword (no explicit 'Severity' label). |
| where_it_appears | pass | Has a 'where this failure appears' / symptoms section. |
| verify_step | pass | Documents how to re-validate the fix. |
| powershell_blocks | pass | 32 powershell block(s), fences balanced. |
| no_bare_drive_delete | pass | No bare drive-root deletes found (non-exhaustive safety spot-check). |
| onbox_actionability | info | Execution surface: On-device (on-box actionable); consumer: either consumer; on-box catalog ELIGIBLE. on-devic |
| anchor_links | info | All 3 in-page #anchor link(s) resolve to a heading. |
| prose_style | pass | No spaced '--'/em-dashes or tell phrases in prose. |

## Persona usability panel
Overall usability score: **5 / 5** across 13 personas. Each persona gives two short sentences: what was most useful, and the one change they want.

| Persona | Score | Most useful | Suggested change |
| --- | --- | --- | --- |
| IT Director | 5 | The opening decision table and checkpoints expose the full outage, multi-hour window, accountable owners, rollback authority, and hard stop conditions before command detail. | Optional polish: add a one-line placeholder for the approved customer communication channel beside the required status-update cadence. |
| Outsourced MSP Technician | 5 | Every destructive action is gated by sealed identities, durable phases, expected states, retry rules, and explicit prohibitions against unsafe storage repair or blind intent resubmission. | Optional polish: repeat the active evidence-pointer path in the point-of-no-return section for faster literal navigation during an outage bridge. |
| Mid-career Generalist Sysadmin | 5 | The article provides an unambiguous end-to-end path with prerequisites, exact health gates, restart recovery, dependency-ordered restoration, active validation, and bounded rollback. | Optional polish: add a printable checkpoint index that links to the existing detailed sections without replacing their fail-closed gates. |
| Network Engineer | 5 | The transport boundary is precise, RoCEv2 readiness covers PFC, ETS, ECN/WRED, DCBX, and endpoint response, and Windows symptoms are not misrepresented as proof of a fabric cause. | Optional polish: add a blank per-port evidence row that the network team can copy for each host-facing and inter-switch storage path. |
| App / VM Engineer | 5 | The planned full outage is unmistakable, application owners retain shutdown and startup control, VM identity is sealed, and closure requires representative transactions plus owner attestation. | Optional polish: add a sample filename for the application dependency and startup-order attachment in the change record. |
| New-grad IT Temp | 5 | The glossary, warning callouts, expected results, stop conditions, phase table, and repeated do-not-retry rules make the highest-consequence mistakes difficult to perform accidentally. | Optional polish: explicitly say that an empty Get-StorageJob result is the expected healthy output the first time that command appears. |
| Microsoft CSS Support Engineer | 5 | The guide produces a support-ready package with sealed manifests, hashes, transcripts, operation-scoped event exports, attempt-and-sample-unique final-hold evidence, sticky terminal artifacts, and precise escalation boundaries. | Optional polish: provide a suggested support-case title containing the change ID, direction, durable phase, and failure kind. |
| Microsoft CSAM | 5 | Business impact, responsibility boundaries, expected duration, communication cadence, customer validation ownership, and rollback authority are visible without reading the PowerShell. | Optional polish: remind the change owner to record the externally communicated maintenance-window end time at closure. |
| Partner / SI Deployment Engineer | 5 | The workflow discovers and seals site-specific identities, preserves the complete representable override set, checks every node-adapter pair, and rejects unsupported environmental variation. | Optional polish: publish a separate downloadable checkpoint sheet derived from the existing at-a-glance and change-control tables. |
| OEM Hardware Vendor Field Engineer | 5 | The article requires OEM confirmation for adapter, driver, firmware, and transport support, avoids prescribing unsupported firmware tuning, and clearly identifies the evidence the OEM must supply. | Optional polish: add a placeholder for the OEM qualification statement or supported-solution reference in the evidence package. |
| Satya Nadella (CEO lens) | 5 | The guide converts a risky infrastructure change into an accountable, inclusive workflow that empowers each customer role and protects confidence through transparent gates and evidence. | Optional polish: add one plain-language sentence connecting the continuous holds to customer data protection and service confidence. |
| Steve Ballmer (energy / field lens) | 5 | The at-a-glance order, hard stops, single-submit discipline, exact recovery sequence, and clear owner handoffs keep the field team moving without improvising under pressure. | Optional polish: add a compact linked phase index near the top for faster navigation during the outage call. |
| Mark Russinovich (deep-systems lens) | 5 | The procedure fails closed around identity cardinality, durable state transitions, atomic operation ownership, intent dispatch ambiguity, override preservation, storage dependencies, active SBL counters, rollback direction, and terminal evidence retention. | Optional polish: retain the focused phase, override, and final-hold evidence-model inputs beside future Static L0 regrades for reproducible provenance. |

## Work items to fix the TSG (rows scoring below 5)
Every reviewer scored 5/5, so there are no work items: the panel is already at a perfect score. Anything below is optional polish.

## Minor nits (optional, from reviewers already at 5)
These reviewers scored 5; their suggestions are small polish, not required.
- Optional polish: add a one-line placeholder for the approved customer communication channel beside the required status-update cadence. (_optional-change-record-polish_; IT Director, App / VM Engineer, Microsoft CSAM)
- Optional polish: repeat the active evidence-pointer path in the point-of-no-return section for faster literal navigation during an outage bridge. (_optional-navigation-polish_; Outsourced MSP Technician, Steve Ballmer (energy / field lens))
- Optional polish: add a printable checkpoint index that links to the existing detailed sections without replacing their fail-closed gates. (_optional-checklist-polish_; Mid-career Generalist Sysadmin, Partner / SI Deployment Engineer)
- Optional polish: add a blank per-port evidence row that the network team can copy for each host-facing and inter-switch storage path. (_optional-evidence-template_; Network Engineer, OEM Hardware Vendor Field Engineer)
- Optional polish: explicitly say that an empty Get-StorageJob result is the expected healthy output the first time that command appears. (_optional-beginner-clarity_; New-grad IT Temp)
- Optional polish: provide a suggested support-case title containing the change ID, direction, durable phase, and failure kind. (_optional-escalation-polish_; Microsoft CSS Support Engineer)
- Optional polish: add one plain-language sentence connecting the continuous holds to customer data protection and service confidence. (_optional-customer-language_; Satya Nadella (CEO lens))
- Optional polish: retain the focused phase, override, and final-hold evidence-model inputs beside future Static L0 regrades for reproducible provenance. (_optional-validation-provenance_; Mark Russinovich (deep-systems lens))

---
INTERNAL USE ONLY -- findings must be independently validated before action.