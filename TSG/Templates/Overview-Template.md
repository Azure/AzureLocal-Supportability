<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "overview",
  "products": ["replace-me"],
  "detector": {
    "type": "none",
    "signal": null
  },
  "validation": {
    "fidelity_level": "L0",
    "technical_grade": null,
    "reproduction_substrate": "none",
    "automation_status": "not-assessed",
    "last_validated": null,
    "spec_ref": ""
  }
}
-->

# {Title}

_{Brief subtitle that summarizes the document purpose, scope, and reader decision}_

> [!IMPORTANT]
> This is an overview template. Use it for architectural guidance, conceptual orientation, and decision support. Do not turn an overview into a troubleshooting guide. If the article primarily diagnoses or fixes a failure, use the Troubleshoot template instead.

## At-a-glance routing card

Complete this card before writing the body. It gives skimmers, account teams, and urgent field readers the first-screen answer they need.

| Routing field | Author prompt |
| ------------- | ------------- |
| **Plain-language summary** | {In the first 100 words, explain the topic without assuming Azure Local expertise. Expand acronyms on first use. Examples that often need expansion: Azure Arc, Arc Resource Bridge, Storage Spaces Direct, Windows Admin Center, original equipment manufacturer (OEM), Microsoft Customer Service and Support (CSS), and systems integrator (SI).} |
| **Use this overview when** | {State the reader situation where conceptual orientation or decision support is the right article type.} |
| **Do not use this overview when** | {State when the reader should use a Troubleshoot, How-To, Reference, or Deep Dive article instead. If the reader is blocked by an active failure, point them to the appropriate public troubleshooting article when one exists.} |
| **Customer or workload impact** | {Summarize whether the topic can affect customers, virtual machine (VM) availability, deployment timelines, operations, security posture, or has no expected customer impact.} |
| **Downtime or change risk** | {State whether the overview implies no change, planning-only change, or a potential state-changing action that must use [LOW RISK], [MEDIUM RISK], or [HIGH RISK] labeling in the action pattern.} |
| **Expected reader decision** | {Name the decision, understanding, or next conversation the reader should be ready for after reading.} |
| **Accountable owner and escalation lane** | {Name the owning role and the handoff path. Examples: customer IT, Microsoft CSS, product engineering, partner or SI, or OEM vendor.} |
| **Next action** | {Link or name the next public Microsoft article, decision review, or owner follow-up.} |

## Table of Contents

- [At-a-glance routing card](#at-a-glance-routing-card)
- [1. Purpose and audience](#1-purpose-and-audience)
- [2. Scope and applicability](#2-scope-and-applicability)
- [3. Architecture and key concepts](#3-architecture-and-key-concepts)
- [4. Operational boundaries and risks](#4-operational-boundaries-and-risks)
- [5. Claims and validation](#5-claims-and-validation)
- [6. Frequently asked questions](#6-frequently-asked-questions)
- [7. Additional resources](#7-additional-resources)
- [8. Before publishing checklist](#8-before-publishing-checklist)

## 1. Purpose and audience

{Explain what this overview covers, why it matters, and how it fits into the broader Azure Local ecosystem.}

| Field | Author prompt |
| ----- | ------------- |
| **Audience** | {Primary readers. Examples: IT leadership, Azure Local operators, deployment partners, CSS, OEM field engineers.} |
| **Reader decision or outcome** | {State what the reader should understand or decide after reading this overview.} |
| **Assumed knowledge** | {List the Azure Local, Windows Server, networking, storage, security, or Azure concepts the reader should already know.} |
| **Accessibility notes** | {Define terms that may block new readers. Avoid unexplained acronyms.} |
| **Owner or accountable team** | {Name the team or role responsible for keeping the overview current.} |

This overview complements the official [Azure Local documentation](https://learn.microsoft.com/azure/azure-local/) and provides practical guidance with focus on:

- {Key focus area 1}
- {Key focus area 2}
- {Key focus area 3}
- {Key focus area 4}

## 2. Scope and applicability

{Define the exact product area, deployment phase, and reader scenario this overview covers.}

| Applicability field | Required value |
| ------------------- | -------------- |
| **Applicable products** | {List each product explicitly. Example: Azure Local, Azure Arc, Azure Kubernetes Service on Azure Local.} |
| **Supported versions** | {List supported Azure Local releases, OS builds, extension versions, hardware generation, or service versions. Use current public Microsoft documentation as the source.} |
| **In scope** | {List what this overview explains.} |
| **Out of scope and non-goals** | {List what this overview does not explain. Link to a Troubleshoot, How-To, Reference, or Deep Dive article when a different document type is better.} |
| **Environment assumptions** | {State whether the guidance assumes connected Azure, disconnected operations, specific OEM hardware, specific network topology, or a deployed cluster.} |
| **Rollout repeatability** | {State what changes across sites, OEMs, supported versions, deployment modes, scale units, regions, or customer environments. If nothing varies, say that explicitly.} |
| **OEM and partner ownership boundary** | {State whether the topic is hardware-owned, firmware-owned, partner-owned, Microsoft-owned, customer-owned, or explicitly not an OEM issue.} |
| **Handoff boundaries** | {State when the reader should hand off to customer IT, partner or SI, OEM vendor, Microsoft CSS, or product engineering.} |

## 3. Architecture and key concepts

{Describe the architecture, dependencies, data flow, ownership model, or conceptual model. Keep this section explanatory rather than procedural.}

### Key terminology

{Include terms that readers need to understand before they act on the overview.}

| Term | Definition |
| ---- | ---------- |
| **{Term 1}** | {Clear definition and why the term matters.} |
| **{Term 2}** | {Clear definition and why the term matters.} |
| **{Term 3}** | {Clear definition and why the term matters.} |

### Conceptual model

{Explain the major components and how they interact.}

> [!TIP]
> If a diagram helps, place it in the local `images` folder, use descriptive alt text, and reference only the actual file. Remove the image line if no diagram is supplied.

![{Descriptive diagram alt text}](images/{diagram-filename}.png)

### Comparison or decision matrix

{Use tables to compare options, patterns, responsibilities, or tradeoffs.}

| Option or pattern | When to use | Benefits | Constraints | Owner |
| ----------------- | ----------- | -------- | ----------- | ----- |
| **{Option 1}** | {Scenario} | {Benefit} | {Constraint} | {Owner} |
| **{Option 2}** | {Scenario} | {Benefit} | {Constraint} | {Owner} |
| **{Option 3}** | {Scenario} | {Benefit} | {Constraint} | {Owner} |

## 4. Operational boundaries and risks

{Use this section when overview guidance could influence operations, change planning, support routing, workload availability, security posture, or vendor ownership. If there is no operational effect, state that explicitly.}

| Boundary or risk | Author prompt |
| ---------------- | ------------- |
| **Safe use** | {Explain how the overview should be used without treating it as a procedure.} |
| **Not covered here** | {State which troubleshooting, deployment, or repair actions belong in another article type.} |
| **Workload or availability considerations** | {State whether concepts in this overview imply virtual machine (VM) downtime, maintenance windows, quorum risk (risk that the cluster loses enough voting members to stay online), network interruption, or no workload effect.} |
| **Security posture considerations** | {State whether the topic affects identity, role-based access control (RBAC), certificates, firewall policy, secrets, or has no expected security effect.} |
| **Risk label when actions are included** | {Use [LOW RISK], [MEDIUM RISK], or [HIGH RISK] for any example that could change state.} |
| **Escalation or handoff** | {State when to involve CSS, product engineering, an OEM vendor, a partner or SI, or customer change-control owners.} |

### Action pattern for any state-changing example

Overview articles should avoid step-by-step repair flows. If an example action is necessary for context, label the risk and include every field below.

| Field | Required prompt |
| ----- | --------------- |
| **Risk label** | {Choose [LOW RISK], [MEDIUM RISK], or [HIGH RISK].} |
| **Privilege and approval gate** | {State the minimum role, local admin right, RBAC assignment, vendor approval, or change-control approval required before the action.} |
| **Pre-check** | {Condition that must be true before the action is safe. Include health, backup, recovery-key, and ownership checks where applicable.} |
| **Workload or maintenance gate** | {State the required maintenance window, workload-drain state, customer approval, or confirmation that the example has no workload effect.} |
| **Action** | {The exact action or link to the proper How-To or Troubleshoot article. Prefer a link instead of embedding a repair flow in the overview.} |
| **Expected result or output** | {What the reader should see if the action worked.} |
| **Stop condition and escalation target** | {When the reader must stop, who owns the escalation, and what evidence to collect before handing off.} |
| **Rollback** | {How to return to the prior state if the action is unsuccessful or no longer needed.} |
| **Expected rollback output** | {What the reader should see when rollback succeeds.} |
| **Rollback verification** | {How to confirm the rollback restored the prior safe state before resuming.} |
| **Verification** | {How to confirm the environment is healthy after the action.} |

## 5. Claims and validation

{List the claims a reader may rely on. Include a source or validation reference for each testable claim. Do not make operationally important claims without a reference.}

| Claim | Evidence or validation reference | Applicable products or supported versions | Validation status | Last reviewed |
| ----- | -------------------------------- | ----------------------------------------- | ----------------- | ------------- |
| {Claim 1} | {Public Microsoft Learn link, lab validation note, source reference, or product documentation} | {Products and versions} | {Not assessed, doc-backed, lab-validated, field-validated} | {YYYY-MM-DD} |
| {Claim 2} | {Public Microsoft Learn link, lab validation note, source reference, or product documentation} | {Products and versions} | {Not assessed, doc-backed, lab-validated, field-validated} | {YYYY-MM-DD} |

### Validation vocabulary

Use these terms consistently. The claim status describes evidence for one statement, the fidelity level describes how deeply the article was validated, and a technical grade belongs in a separate grade report or component index.

| Vocabulary | Allowed values | Meaning |
| ---------- | -------------- | ------- |
| **Claim validation status** | `Not assessed`, `doc-backed`, `lab-validated`, `field-validated` | `Not assessed` means no evidence yet. `doc-backed` means a public Microsoft source supports the claim. `lab-validated` means the claim was tested in a lab for the stated products and versions. `field-validated` means support or deployment evidence confirms the claim for the stated scope. |
| **Fidelity level** | `L0`, `L1`, `L2`, `L3`, `L4` | `L0` is static review only. `L1` validates read-only diagnostics. `L2` validates a safe proxy or synthetic signal. `L3` validates a scratch-object failure and fix. `L4` validates a full inject, detect, mitigate, and revalidate loop. |
| **Automation status** | `not-assessed`, `scaffold`, `ready`, `proven`, `blocked`, `manual` | `not-assessed` means no automation review. `scaffold` means metadata exists but automation is incomplete. `ready` means the automation path is designed but not proven. `proven` means automation was validated. `blocked` means automation cannot proceed until a stated dependency is resolved. `manual` means the article intentionally requires human execution or review. |
| **Execution surface** | `on-device`, `mixed`, `cloud-diagnostic`, `cloud-control`, `thin` | Describes where diagnostics or actions run. Keep this distinct from `automation_status`, which describes readiness rather than location. |
| **Admin surface state** | `shown`, `not-evident`, `absent` | Use only when characterizing admin visibility. `shown` means the surface carries evidence. `not-evident` means checked and not visible there. `absent` means uncharacterized and not publish-ready. |
| **Technical grade** | JSON `null`, `A`, `B`, `C`, or `F` | Use `validation.technical_grade` as the authoritative grade field. Keep it as JSON `null` until TSG-FORGE produces `A`, `B`, `C`, or `F`, then cite the report or spec evidence that produced the grade. |

### Future automation metadata

Keep the metadata marker at the top of this file. When creating a real article, update the marker before publication and validate it against the [TSG metadata schema](../Templates/tsg-metadata.schema.json). This schema link is correct for an article copied to a component root such as `TSG/<Component>/`; for each deeper topic folder, add one `../` segment, for example `../../Templates/tsg-metadata.schema.json` from `TSG/<Component>/<Topic>/`.

| Metadata field | Author prompt |
| -------------- | ------------- |
| **document_type** | Keep `overview` for this template. |
| **products** | Replace `replace-me` with explicit product names. |
| **detector.type and detector.signal** | Keep `type` as `none` and `signal` as JSON `null` for purely conceptual content. If the article gains a detection signal, set both fields together, reassess whether it is still an overview, and use only schema detector types. |
| **validation.fidelity_level** | Use `L0` unless this overview has been validated by a stronger documented process. See the fidelity rubric in this section. |
| **validation.technical_grade** | Keep JSON `null` until TSG-FORGE produces `A`, `B`, `C`, or `F`. This is the authoritative technical grade for component indexes and validation reports. |
| **validation.reproduction_substrate** | Use `none` for a conceptual overview unless a validation companion proves a `vm`, `hardware`, or `either` substrate path. |
| **validation.automation_status** | Use `not-assessed` until a TSG-FORGE or converter review assesses automation readiness. Allowed values are `not-assessed`, `scaffold`, `ready`, `proven`, `blocked`, and `manual`. |
| **validation.last_validated** | Keep JSON `null` until a dated validation event exists, then use an ISO date such as `YYYY-MM-DD`. |
| **validation.spec_ref** | Link a public or repository-local validation companion only when one exists and is appropriate for public use. |

## 6. Frequently asked questions

### Q: {Common question about the topic}?

**A:** {Clear answer with practical guidance and context. State assumptions and link to official public Microsoft documentation when possible.}

### Q: {Another frequently asked question}?

**A:** {Clear answer. If the answer depends on product, version, hardware, or deployment phase, say so explicitly.}

**{Scenario or option 1}:**

- {Specific guidance for this scenario}
- {Key considerations and boundaries}

**{Scenario or option 2}:**

- {Alternative guidance}
- {When this applies}

## 7. Additional resources

Use public Microsoft links only. Prefer links that do not pin a release view unless the article is explicitly version-specific.

### Official documentation

- **[Azure Local documentation](https://learn.microsoft.com/azure/azure-local/)**
  {Brief description of how this source supports the overview.}

- **[{Official Microsoft Learn doc 2}]({Public Microsoft Learn URL})**
  {Brief description of what this covers.}

- **[{Official Microsoft Learn doc 3}]({Public Microsoft Learn URL})**
  {Brief description of what this covers.}

### Related public Microsoft documents

- **[{Related public Microsoft document 1}]({Public Microsoft Learn URL})**: {Brief description}
- **[{Related public Microsoft document 2}]({Public Microsoft Learn URL})**: {Brief description}

### Tools and utilities

- **[{Public Microsoft tool 1}]({Public Microsoft URL})**: {Description of the tool and its purpose}
- **[{Public Microsoft tool 2}]({Public Microsoft URL})**: {Description of the tool and its purpose}

## 8. Before publishing checklist

Use this checklist before opening a pull request. It prevents the reusable template prompts from leaking into a published overview.

| Check | Required result |
| ----- | --------------- |
| **Placeholder sweep** | {Search for unresolved brace prompts such as `{Title}` and replace or remove every one.} |
| **Diagram cleanup** | {Remove the sample diagram line unless a real image exists in the local `images` folder with useful alt text.} |
| **Metadata marker** | {Keep exactly one valid `<!-- tsg-metadata` marker, replace `products`: [`replace-me`] before publication, and keep `detector.signal` as JSON `null` when `detector.type` is `none`.} |
| **Plain-language opening** | {Confirm the first 100 words define the topic, expand acronyms, and state why the reader should care.} |
| **Public-link hygiene** | {Use public Microsoft links only. Remove internal work-item, wiki, Kusto, or engineering links from the public article.} |
| **Applicability** | {Confirm applicable products, supported versions, environment assumptions, rollout repeatability, and OEM or partner boundaries are explicit.} |
| **Claims** | {Confirm every testable or operationally important claim has an evidence or validation reference.} |
| **Actions, if any** | {Confirm any state-changing example has risk, privilege, workload or maintenance gate, pre-check, action, expected output, stop condition and escalation target, rollback, expected rollback output, rollback verification, and final verification.} |
