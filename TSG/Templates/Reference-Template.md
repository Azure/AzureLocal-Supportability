<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "reference",
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

<!--
Reference Template

Purpose:
- Use this template for configuration references, supported settings, technical specifications, option comparisons, and examples.
- Do not force troubleshooting-only sections into a reference. Use a troubleshooting template instead when the article is about symptoms, contributing factors, mitigation, or where a failure appears.
- Replace all {placeholders} before publishing. Search for placeholders with this regex: \{([^}]+)\}

Style and publishing rules:
- No emojis, em dashes, or double-hyphen clause separators in prose.
- External links must point to public Microsoft documentation. Prefer latest-version Microsoft Learn URLs without version query strings.
- Images must be placed in an images folder next to the article and referenced with relative links.
- Wrap command, JSON, and output examples in fenced code blocks with a language identifier.
- Use tables for settings, defaults, requirements, constraints, and option comparisons.
- Keep this article type focused on reference content. Do not add mandatory Severity, Symptoms, Root Cause, or Where this failure appears sections.

Metadata marker:
- Keep exactly one tsg-metadata HTML comment in each generated article.
- Before publishing, replace products. If you select a detector, update detector.type and detector.signal together, then update validation fields if TSG-FORGE validation has run.
-->

# {Title}

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>{Component Name}</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Topic</th>
    <td><strong>{Topic Name}</strong>: {Brief description of what this reference covers}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Document type</th>
    <td><strong>Reference</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Audience</th>
    <td>{Primary reader, owner, and handoff audience, such as Microsoft Customer Support Services (CSS) or a systems integrator (SI)}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Applicable products</th>
    <td>{Azure Local product, component, OEM, or feature family}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Supported versions</th>
    <td>{Supported Azure Local release, build, or version range}</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Scope</th>
    <td>{Brief description of configurations, scenarios, or deployment patterns this covers}</td>
  </tr>
</table>

## Overview

{Brief description of what this reference document provides: configurations, specifications, defaults, constraints, examples, validation methods, and why the safest default matters.}

## At-a-glance applicability

Use this summary so readers can decide whether this reference applies before copying a setting or command.

**Fast-path decision card:** Fill in these three lines near the top of every generated reference so leaders and field engineers can make a quick go or no-go decision.

| Decision line | Required content |
| ------------- | ---------------- |
| Applies | {Yes, no, or conditional. Name the exact product, supported versions, deployment phase, and scale where this reference applies.} |
| Safe to proceed | {Yes, no, or conditional. State whether every placeholder has been replaced, every source has been verified, and the pre-check is passing.} |
| Next owner if blocked | {Customer IT, partner or systems integrator (SI), Microsoft Customer Support Services (CSS), networking, storage, security, update, OEM, or product group, plus the evidence to attach.} |

| Field | Required content |
| ----- | ---------------- |
| Audience | {Who should read this: IT admin, Microsoft Customer Support Services (CSS) engineer, partner deployment engineer, OEM engineer, or other role} |
| Owner or lane | {Customer IT, partner or systems integrator (SI), Microsoft Customer Support Services (CSS), OEM, networking, storage, security, update, or product group owner} |
| Applicable products | {Explicit Azure Local product or component names. Replace the metadata marker products array too.} |
| Supported versions | {Release, build, firmware, driver, or module versions where this reference applies} |
| Deployment phase | {Deployment, add node, update, upgrade, steady state, disconnected operation, or other phase} |
| Scale of application | {Per node, per cluster, per site, across a fleet, or not applicable} |
| Environment assumptions | {Connected or disconnected mode, hardware class, OEM, region, domain, network, or subscription assumptions} |
| Customer impact | {What reader decision or operational outcome this reference supports} |
| Expected decision time | {Estimated time to decide applicability, or why timing is not applicable} |
| Maintenance-window length | {Expected maintenance-window length, or why no window is required} |
| Downtime or workload risk | {None, read-only, maintenance window required, workload impact possible, or not applicable} |
| Workload-impact checklist | {State whether the guidance can involve VM movement, drain, reboot, live migration, or application-availability risk} |
| Handoff trigger and evidence | {When networking, OEM, Microsoft Customer Support Services (CSS), partner, or product group owns the next step, and the exact logs, command output, firmware data, or screenshots to attach} |
| Fastest validation | {The shortest safe command or check that proves the configured state} |

## Scope

### In scope

{What configurations, settings, examples, or deployment patterns this reference covers.}

- {Configuration type 1}
- {Scenario 1}
- {Deployment pattern 1}

### Out of scope

{What is not covered by this reference. Include explicit unsupported products, versions, deployment phases, or ownership lanes.}

- {Configuration type not covered}
- {Scenario not applicable}
- {Product, version, or OEM model not supported by this reference}

## Applicable products and supported versions

Verify these values against current public Microsoft documentation and the product source of truth before publishing.

| Product or component | Supported versions | Supported scenarios | Unsupported scenarios | Source of truth |
| -------------------- | ------------------ | ------------------- | --------------------- | --------------- |
| {Azure Local product or component} | {Version or build range} | {Where this applies} | {Where this does not apply} | {Public Microsoft Learn URL or product documentation} |
| {OEM, hardware, driver, firmware, or module when applicable} | {Version or model range} | {Supported use} | {Unsupported use} | {Public Microsoft Learn URL} |

## Required inputs

List every value the reader must collect before using the reference. Define each value in plain language and provide a safe example.

Do not run any example until every `{placeholder}` has been replaced with an environment-specific value and the source for that value has been verified. Brace placeholders are authoring markers, not runnable command text.

| Input | Plain-language definition | Example value | Required or optional | How to find it | Notes |
| ----- | ------------------------- | ------------- | -------------------- | -------------- | ----- |
| {Input name} | {What this value means} | {Example} | {Required or optional} | {Command, portal location, or document} | {Constraints or cautions} |
| {Input name} | {What this value means} | {Example} | {Required or optional} | {Command, portal location, or document} | {Constraints or cautions} |

Add a short glossary for terms that a first-time Azure Local reader may not know.

| Term | Definition | Why it matters here |
| ---- | ---------- | ------------------- |
| {Term 1} | {Plain-language definition} | {How misunderstanding this term could lead to the wrong setting or owner} |
| {Term 2} | {Plain-language definition} | {How this term affects validation or handoff} |

## Requirements

{Technical requirements, prerequisites, permissions, dependencies, or constraints that apply to the configurations in this reference.}

| Requirement | Specification | Required privilege | Notes |
| ----------- | ------------- | ------------------ | ----- |
| {Requirement 1} | {Specification} | {None, local admin, Azure role, OEM access, or other privilege} | {Additional context} |
| {Requirement 2} | {Specification} | {None, local admin, Azure role, OEM access, or other privilege} | {Additional context} |

## Table of contents

Update this table of contents if you rename, add, or remove sections.

- [Overview](#overview)
- [At-a-glance applicability](#at-a-glance-applicability)
- [Scope](#scope)
- [Applicable products and supported versions](#applicable-products-and-supported-versions)
- [Required inputs](#required-inputs)
- [Requirements](#requirements)
- [Configuration reference](#configuration-reference)
- [Action pattern for generated examples](#action-pattern-for-generated-examples)
- [Examples](#examples)
- [Validation](#validation)
- [Configuration comparison](#configuration-comparison)
- [Future automation metadata](#future-automation-metadata)
- [Related documentation](#related-documentation)

## Configuration reference

{Main configuration content. Organize by setting family, option, API, registry value, policy, resource type, or deployment pattern.}

### {Configuration area 1}

{Description of this configuration area, when it is used, and why the recommended default is safe.}

#### Settings and defaults

| Setting or parameter | Purpose | Default value | Default source | Allowed values or range | Required or optional | Constraints and edge cases | Security implications |
| -------------------- | ------- | ------------- | -------------- | ----------------------- | -------------------- | -------------------------- | --------------------- |
| `{parameter1}` | {Description and purpose} | {Default value or not applicable} | {Source of truth} | {Allowed values} | {Required or optional} | {Constraints, unsupported values, or side effects} | {Identity, Role-Based Access Control (RBAC), certificate, firewall, or secret exposure considerations} |
| `{parameter2}` | {Description and purpose} | {Default value or not applicable} | {Source of truth} | {Allowed values} | {Required or optional} | {Constraints, unsupported values, or side effects} | {Security implications, or Not applicable} |

#### Action or configuration example

Classify the action type first. Use [READ-ONLY] for non-mutating inspection or validation. If the action changes or could change state, choose one canonical risk label: [LOW RISK] for low-impact state changes, [MEDIUM RISK] for reversible configuration changes that may affect availability or operations, and [HIGH RISK] for privileged, broad, hard-to-rollback, or workload-impacting changes.

| Field | Required content |
| ----- | ---------------- |
| Action type | {[READ-ONLY] for non-mutating actions, otherwise state-changing} |
| Risk label | {Not applicable for read-only action type, otherwise [LOW RISK], [MEDIUM RISK], or [HIGH RISK]} |
| Privilege required | {None, local administrator, Azure role, OEM access, or other privilege} |
| State-changing | {Yes or no} |
| Workload impact | {Expected VM, cluster, network, storage, update, security, drain, reboot, live migration, or application-availability impact} |
| Maintenance window | {Required, recommended, or not required} |
| Pre-check | {Command or inspection that proves it is safe to proceed} |
| Action | {Command, portal action, or configuration update} |
| Expected result or output | {Exact success shape, expected output, expected state, and accepted variance} |
| Stop condition | {Condition that tells the reader to stop and escalate before changing more state} |
| Handoff trigger | {Which owner takes over if the stop condition is met, and what evidence to attach} |
| Rollback | {How to restore the previous state, or why rollback is not applicable} |
| Expected rollback output | {Output or state that proves rollback ran successfully} |
| Rollback verification | {Independent check that proves the previous or safe state is restored} |
| Escalation | {Owner, support path, and evidence package if rollback or verification fails} |
| Verification | {How to prove the final state matches this reference} |

**Pre-check command:**

```console
{read-only pre-check command}
```

**Action command or portal action summary:**

```console
{configuration command or portal action summary}
```

**Verification command:**

```console
{validation command}
```

**Expected output:**

```console
{Expected command output, status, or state. Include the failure output shape when it changes the next step.}
```

#### {Sub-configuration or option 2}

{Explanation of an alternative option, including why a reader would choose it and how its constraints differ from the default.}

### {Configuration area 2}

{Description of another configuration area, including ownership lane, defaults, constraints, and validation.}

## Action pattern for generated examples

Every generated action pattern must include all rows below. If a row does not apply, write `Not applicable` and explain why.

| Pattern element | Author prompt |
| --------------- | ------------- |
| Action type | {[READ-ONLY] for non-mutating actions, otherwise state-changing} |
| Risk label | {Not applicable for read-only action type, otherwise [LOW RISK], [MEDIUM RISK], or [HIGH RISK]} |
| Privilege required | {None, local administrator, Azure role, OEM access, or other privilege} |
| Workload impact | {Expected VM, cluster, network, storage, update, security, drain, reboot, live migration, or application-availability impact} |
| Maintenance window or approval gate | {Required, recommended, not required, or not applicable, plus the approval owner when required} |
| Pre-check | {What confirms the current state and proves it is safe to continue?} |
| Action | {What exact command, portal operation, file edit, or configuration change should the reader perform?} |
| Expected result or output | {What exact output or state should appear after the action?} |
| Stop condition | {What error, missing prerequisite, unexpected state, or risk should make the reader stop?} |
| Rollback | {How does the reader return to the prior state if the action fails or is no longer wanted?} |
| Expected rollback output | {What output or state proves the rollback command succeeded?} |
| Rollback verification | {What independent check proves rollback restored the previous or safe state?} |
| Escalation owner and evidence | {Who owns the next step if stopped or rollback fails, and what evidence must be attached?} |
| Verification | {What final check proves the reference guidance was applied correctly?} |

## Examples

{Real-world Azure Local configuration examples that demonstrate the concepts. Each example should be safe to copy after the reader replaces placeholders.}

### {Example scenario 1}

{Description of the scenario this example addresses and why it is relevant to Azure Local.}

**Environment assumptions:**

- Applicable products: {Product or component}
- Supported versions: {Version or build range}
- Ownership lane: {Customer IT, partner, Microsoft Customer Support Services (CSS), OEM, or product group}
- Scale of application: {Per node, per cluster, per site, across a fleet, or not applicable}
- Workload impact: {None, possible, expected, or unknown. Call out VM movement, drain, reboot, live migration, and application-availability risk when relevant.}
- Required privileges: {Privilege required}

**Variables:**

| Variable | Example | Notes |
| -------- | ------- | ----- |
| `{variable1}` | `{example-value}` | {Meaning and constraints} |
| `{variable2}` | `{example-value}` | {Meaning and constraints} |

**Configuration:**

| Field | Value |
| ----- | ----- |
| Action type | {[READ-ONLY] for non-mutating examples, otherwise state-changing} |
| Risk label | {Not applicable for read-only action type, otherwise [LOW RISK], [MEDIUM RISK], or [HIGH RISK]} |
| Pre-check | {Pre-check command or inspection} |
| Action | {Configuration command or portal action} |
| Expected result or output | {Exact expected result} |
| Stop condition | {When to stop} |
| Handoff trigger | {Next owner and evidence package if blocked} |
| Rollback | {Rollback command or manual recovery} |
| Expected rollback output | {Output or state that proves rollback succeeded} |
| Rollback verification | {Independent check that proves rollback restored the previous or safe state} |
| Escalation | {Owner and evidence package if rollback or verification fails} |
| Verification | {Validation command or method} |

```console
{Complete configuration example}
```

**Expected output:**

```console
{Expected output or final state}
```

### {Example scenario 2}

{Description of another scenario, including what differs from the default, what constraints apply, and how to validate it.}

## Validation

{Methods to verify that configurations are working correctly. Include the evidence a support engineer, partner, or automation system should collect.}

### {Validation method 1}

{Description of what this validates and which setting or example it covers.}

| Field | Required content |
| ----- | ---------------- |
| Action type | {[READ-ONLY] for non-mutating validation, otherwise state-changing} |
| Risk label | {Not applicable for read-only action type, otherwise [LOW RISK], [MEDIUM RISK], or [HIGH RISK]} |
| Privilege required | {None, local administrator, Azure role, OEM access, or other privilege} |
| Workload impact | {Expected VM, cluster, network, storage, update, security, drain, reboot, live migration, or application-availability impact} |
| Maintenance window or approval gate | {Required, recommended, not required, or not applicable, plus the approval owner when required} |
| Pre-check | {Read-only state check before validation} |
| Validation action | {Command, portal check, API call, or inspection} |
| Expected output | {Exact passing output or state} |
| Failure output | {Common failing output or unexpected state} |
| Accepted variance | {Values that can differ without changing the conclusion} |
| Stop condition | {When to stop and collect evidence} |
| Rollback | {Rollback if validation requires a state-changing probe, otherwise Not applicable} |
| Expected rollback output | {Output or state that proves rollback succeeded, or Not applicable} |
| Rollback verification | {Independent check that proves rollback restored the previous or safe state, or Not applicable} |
| Escalation | {Owner and evidence package if validation, rollback, or rollback verification fails} |
| Verification | {Final proof that the intended configuration is active} |
| Evidence to collect | {Logs, command output, screenshots, or exported data} |

```console
Validation command:
{command to run}
```

**Expected output:**

```console
{sample of expected output}
```

### {Validation method 2}

{Another validation approach. Include pass criteria, fail criteria, and what the reader should collect if validation fails.}

## Configuration comparison

{Optional section. Use this when comparing configuration options, defaults, supported versions, or deployment patterns.}

| Feature | {Option 1} | {Option 2} | {Option 3} |
| ------- | ---------- | ---------- | ---------- |
| Default | {Value and source} | {Value and source} | {Value and source} |
| Constraints | {Constraints} | {Constraints} | {Constraints} |
| Supported versions | {Versions} | {Versions} | {Versions} |
| Use case | {When to use} | {When to use} | {When to use} |
| Action type | {[READ-ONLY] or state-changing} | {[READ-ONLY] or state-changing} | {[READ-ONLY] or state-changing} |
| State-changing risk label | {Not applicable, [LOW RISK], [MEDIUM RISK], or [HIGH RISK]} | {Not applicable, [LOW RISK], [MEDIUM RISK], or [HIGH RISK]} | {Not applicable, [LOW RISK], [MEDIUM RISK], or [HIGH RISK]} |
| Validation | {How to validate} | {How to validate} | {How to validate} |

## Future automation metadata

Keep the `tsg-metadata` marker at the top of the generated article. Validate it against the [metadata JSON Schema](../Templates/tsg-metadata.schema.json) before publishing, then update these fields so future tooling can route, validate, and automate the reference without changing the article type.

The schema link above is correct after copying this template to a component root folder, for example `TSG/Storage/Reference-Example.md`. If the article is copied into a nested topic folder, add one `../` for each extra folder level, for example `../../Templates/tsg-metadata.schema.json` from `TSG/Storage/Topic/Reference-Example.md`.

| Metadata field | Required value |
| -------------- | -------------- |
| `schema` | `azure-local-supportability/tsg-metadata/v1` |
| `document_type` | `reference` |
| `products` | {Replace `replace-me` with explicit applicable products} |
| `detector.type` | `none` unless this reference has an automation detector |
| `detector.signal` | Use JSON `null` when `detector.type` is `none`; when selecting a detector, set `detector.type` and `detector.signal` together. |
| `validation.fidelity_level` | `L0` until live or static validation proves a higher fidelity level |
| `validation.technical_grade` | JSON `null` until TSG-FORGE produces authoritative grade `A`, `B`, `C`, or `F` with report or spec evidence |
| `validation.reproduction_substrate` | `none` unless validation requires `vm`, `hardware`, or `either` |
| `validation.automation_status` | `not-assessed`, `scaffold`, `ready`, `proven`, `blocked`, or `manual` |
| `validation.last_validated` | `null` or a date in `YYYY-MM-DD` format |
| `validation.spec_ref` | {Path to the validation spec, or an empty string} |

Use the definitions below when completing metadata. Keep execution surface separate from automation status: execution surface describes where a consumer runs the guidance, such as on-device, cloud, or mixed. Automation status describes how ready the automation is.

| Vocabulary | Values and meaning |
| ---------- | ------------------ |
| Fidelity level | `L0`: static lint and persona review only. `L1`: read-only commands or checks were validated. `L2`: faithful proxy or data-source validation was exercised. `L3`: scratch-object or isolated reproduction was exercised. `L4`: full inject, detect, mitigate, and revalidate loop was proven. |
| Technical grade | `validation.technical_grade` is the authoritative technical grade. Use JSON `null` until TSG-FORGE produces `A`, `B`, `C`, or `F` with report or spec evidence. |
| Reproduction substrate | `none`: no live substrate. `vm`: disposable virtual or nested environment. `hardware`: physical lab hardware. `either`: either VM or hardware can reproduce the validation. |
| Automation status | `not-assessed`: no automation assessment yet. `scaffold`: metadata or helpers exist but are incomplete. `ready`: automation is designed and ready to run. `proven`: automation has been validated and has evidence. `blocked`: automation cannot proceed until a dependency is removed. `manual`: human validation is required. |
| Detector type and signal | Allowed detector types are `command`, `control-plane`, `envchecker`, `eventlog`, `feature`, `manual`, `none`, `portal`, `registry`, `service`, and `telemetry`. `none` with `signal` set to JSON `null` means no detector. If the article uses a detector, choose the detector type and set `signal` to the command, event, telemetry table, portal location, or other observable signal together. |
| Execution surface | This is separate from `validation.automation_status`. Use `on-device`, `mixed`, `cloud-diagnostic`, `cloud-control`, or `thin`. `thin` means prose-only reference content with no executable diagnostic or action. |
| Admin surface state, if used | Use `shown`, `not-evident`, or `absent`. `not-evident` means the surface was checked and the issue is not expected there. `absent` means the surface is uncharacterized and is not publish-ready. |

## Related documentation

Use only public Microsoft links for external references. Prefer latest-version Microsoft Learn URLs and do not include release-specific query strings. Use repo-relative links only for other public files in this repository.

- [{Azure Local documentation}](https://learn.microsoft.com/azure/azure-local/) - Public Azure Local documentation
- [{Related public Microsoft document}](https://learn.microsoft.com/azure/azure-local/) - Brief description
- [{Related public Microsoft document}](https://learn.microsoft.com/azure/azure-local/) - Brief description
