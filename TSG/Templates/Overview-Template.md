<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v2",
  "document_type": "overview",
  "products": ["replace-me"],
  "detector": {
    "type": "none",
    "signal": null
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
| **What could change** | {State whether the overview implies no change, planning-only change, or a potential state-changing action that must be described with `**Changes:**` and, when needed, `**Plan for:**` statements in the action pattern.} |
| **Expected reader decision** | {Name the decision, understanding, or next conversation the reader should be ready for after reading.} |
| **Accountable owner and escalation lane** | {Name the owning role and the handoff path. Examples: customer IT, Microsoft CSS, product engineering, partner or SI, or OEM vendor.} |
| **Next action** | {Link or name the next public Microsoft article, decision review, or owner follow-up.} |

## Table of Contents

- [At-a-glance routing card](#at-a-glance-routing-card)
- [1. Purpose and audience](#1-purpose-and-audience)
- [2. Scope and applicability](#2-scope-and-applicability)
- [3. Architecture and key concepts](#3-architecture-and-key-concepts)
- [4. Operational boundaries and impact](#4-operational-boundaries-and-impact)
- [5. Claims and evidence](#5-claims-and-evidence)
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

## 4. Operational boundaries and impact

{Use this section when overview guidance could influence operations, change planning, support routing, workload availability, security posture, or vendor ownership. If there is no operational effect, state that explicitly.}

| Boundary or impact | Author prompt |
| ---------------- | ------------- |
| **Safe use** | {Explain how the overview should be used without treating it as a procedure.} |
| **Not covered here** | {State which troubleshooting, deployment, or repair actions belong in another article type.} |
| **Workload or availability considerations** | {State whether concepts in this overview imply virtual machine (VM) downtime, maintenance windows, possible loss of quorum (the cluster losing enough voting members that it can't stay online), network interruption, or no workload effect.} |
| **Security posture considerations** | {State whether the topic affects identity, role-based access control (RBAC), certificates, firewall policy, secrets, or has no expected security effect.} |
| **Impact statement when actions are included** | {For any example that could change state, add a `**Changes:**` statement, `**Plan for:**` when the step is disruptive, and a `> [!WARNING]` callout, optionally with a `[HIGH RISK]` label, when it can't be undone, can interrupt running workloads, change firmware or security posture, or can lose data.} |
| **Escalation or handoff** | {State when to involve CSS, product engineering, an OEM vendor, a partner or SI, or customer change-control owners.} |

### Action pattern for any state-changing example

Overview articles should avoid step-by-step repair flows. If an example action is necessary for context, describe what it changes and include every field below.

| Field | Required prompt |
| ----- | --------------- |
| **What changes** | {Write a `**Changes:**` statement that says what changes and what is not affected. Add `**Plan for:**` for disruptive steps and a `> [!WARNING]` callout for steps that can't be undone, can interrupt running workloads, change firmware or security posture, or can lose data.} |
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

## 5. Claims and evidence

{List the claims a reader may rely on. Include a source reference for each testable claim. Do not make operationally important claims without a reference. Record test runs and other validation in the pull request description, not in the article.}

| Claim | Evidence reference | Applicable products or supported versions | Last reviewed |
| ----- | ------------------ | ----------------------------------------- | ------------- |
| {Claim 1} | {Public Microsoft Learn link, source reference, or product documentation} | {Products and versions} | {YYYY-MM-DD} |
| {Claim 2} | {Public Microsoft Learn link, source reference, or product documentation} | {Products and versions} | {YYYY-MM-DD} |

"Last reviewed" is the date the claim's content was last reviewed against its evidence reference; it is not a validation record.

### Vocabulary

Use these terms consistently.

| Vocabulary | Allowed values | Meaning |
| ---------- | -------------- | ------- |
| **Execution surface** | `on-device`, `mixed`, `cloud-diagnostic`, `cloud-control`, `thin` | Describes where diagnostics or actions run. Record it in the article body, not in the metadata marker. |
| **Admin surface state** | `shown`, `not-evident`, `absent` | Use only when characterizing admin visibility. `shown` means the surface carries evidence. `not-evident` means checked and not visible there. `absent` means uncharacterized and not publish-ready. |

### Metadata marker

Keep the metadata marker at the top of this file. The marker records discovery metadata only: document type, applicable products, and detector. Keep validation records, such as test runs, grades, and lab details, out of the article and its marker. When creating a real article, update the marker before publication and validate it against the [TSG metadata schema](../Templates/tsg-metadata.schema.json). This schema link is correct for an article copied to a component root such as `TSG/<Component>/`; for each deeper topic folder, add one `../` segment, for example `../../Templates/tsg-metadata.schema.json` from `TSG/<Component>/<Topic>/`.

| Metadata field | Author prompt |
| -------------- | ------------- |
| **document_type** | Keep `overview` for this template. |
| **products** | Replace `replace-me` with explicit product names. |
| **detector.type and detector.signal** | Keep `type` as `none` and `signal` as JSON `null` for purely conceptual content. If the article gains a detection signal, set both fields together, reassess whether it is still an overview, and use only schema detector types. |

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
| **Claims** | {Confirm every testable or operationally important claim has an evidence reference.} |
| **Actions, if any** | {Confirm any state-changing example has a `**Changes:**` statement, privilege, workload or maintenance gate, pre-check, action, expected output, stop condition and escalation target, rollback, expected rollback output, rollback verification, and final verification.} |
