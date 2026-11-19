# Contributing to Azure Local Supportability

Welcome! This repository provides troubleshooting guides and documentation for Azure Local.

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Table of contents

- [Contribution process](#contribution-process)
- [Quick start](#quick-start-5-minutes)
- [Requirements](#requirements)
- [Detailed guidelines](#detailed-guidelines)
- [Need help](#need-help)
- [Additional resources](#additional-resources)

## Contribution Process

1. **Fork** this repository
2. **Create** your document using the appropriate template
3. **Test** all code examples thoroughly
4. **Update** the component README.md
5. **Submit** a pull request

## Quick Start (5 minutes)

### Step 1: Identify document type

| Document Type | Template                                                               | Description                                                 |
| ------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------- |
| Troubleshoot  | [`Troubleshoot-Template.md`](./TSG/Templates/Troubleshoot-Template.md) | A troubleshooting guide, how to detect and resolve an issue |
| Reference     | [`Reference-Template.md`](./TSG/Templates/Reference-Template.md)       | Reference configuration examples and settings               |
| How-To        | [`HowTo-Template.md`](./TSG/Templates/HowTo-Template.md)               | Step-by-step instructions for tasks                         |
| Deep Dive     | [`DeepDive-Template.md`](./TSG/Templates/DeepDive-Template.md)         | In-depth exploration of a topic                             |
| Overview      | [`Overview-Template.md`](./TSG/Templates/Overview-Template.md)         | High-level overview of a subject                            |

Does your content not fit any of these categories? Consider creating a new document type.

### Step 2: Identify Component

Put your file in the appropriate component folder. Here are some examples:

| Component                         | What Goes Here                                   |
| --------------------------------- | ------------------------------------------------ |
| [`Deployment`](./TSG/Deployment/) | Installation, setup, prerequisites, registration |
| [`Networking`](./TSG/Networking/) | Connectivity, TOR switches, SDN, Arc Gateway     |
| [`Storage`](./TSG/Storage/)       | Storage Spaces Direct, disks, volumes            |
| [`Security`](./TSG/Security/)     | WDAC, BitLocker, authentication                  |
| [`Update`](./TSG/Update/)         | Patching, Azure Update Manager                   |
| [`ArcVMs`](./TSG/ArcVMs/)         | Virtual machine management                       |

Don't see a component? [See all components](./README.md#table-of-contents)

### Step 3: Create your document

1. **Copy the template** from Step 1
2. **Replace placeholders** (marked with `{curly braces}`)
3. **Declare applicability**: products, deployment modes, versions, and exclusions
4. **Complete the hidden metadata marker**: detector, fidelity, substrate, and automation status
5. **Test all code examples**: they must be safe for production
6. **Save with correct naming**: `<Type>-<Topic>-<Specifics>.md`
7. **Update the component README.md** with validation and automation fields
8. **Submit a pull request** with evidence for every tested claim

Reference [Markdown Snippets](./TSG/Templates/Markdown-Snippets.md) for helpful formatting tips, diagrams, and more.

## Requirements

### Code Safety (CRITICAL)

All PowerShell/scripts **MUST be safe for production**

- Use placeholders like `<hostname>` instead of real values
- Label state-changing commands [LOW RISK], [MEDIUM RISK], or [HIGH RISK]
- Include a pre-check, expected output, stop condition, rollback, and verification
- Add comments explaining what commands do
- Test all examples before submitting

For a read-only command, use [READ-ONLY] as the action type and record risk as not applicable.
Do not label a non-mutating check [LOW RISK], because that blurs observation and state change.

```powershell
# Good: Check state before changing
if ((Get-Service "ServiceName").Status -eq "Stopped") {
    Start-Service "ServiceName"
}

# Bad: Don't assume current state
Start-Service "ServiceName"
```

### Product applicability

Verify product and version applicability against current public Microsoft documentation. State
what the article applies to and what it does not apply to. Consider Azure Local connected and
disconnected deployments, disaggregated deployments, multi-rack deployments, and any feature-specific
requirements. Do not infer applicability from a similar product or older release.

### TSG automation metadata

Every article created from a template includes one hidden
`azure-local-supportability/tsg-metadata/v1` JSON marker. Fill it in and keep it valid JSON. The
authoritative allowed values are in
[`tsg-metadata.schema.json`](./TSG/Templates/tsg-metadata.schema.json). The marker must identify:

- Document type
- Applicable products
- Detector type and signal
- Validation fidelity level, from L0 through L4
- Technical grade, or `null` until TSG-FORGE produces one
- Reproduction substrate
- Automation status
- Last validation date and the internal test specification reference, when available

Use `null` for a validation date that has not been established. Never add customer or lab
identifiers to tracked metadata.

Use the same fidelity scale for every article:

| Level | Evidence required |
| --- | --- |
| L0 | Static structure, safety, and persona review only |
| L1 | Diagnostic commands exercised read-only |
| L2 | Real detector and remediation direction exercised with a safe proxy |
| L3 | Real failure and remediation exercised on an isolated scratch object |
| L4 | Full baseline, inject, detect, mitigate, and revalidate loop exercised live |

Technical grade records the TSG outcome:

| Grade | Meaning |
| --- | --- |
| `null` | No TSG-FORGE technical grade has been established |
| A | The article is complete for its type, safety gates are present, metadata is valid, links resolve, and lint is clean |
| B | Usable, but non-blocking gaps remain, such as missing optional evidence or a documented false-positive warning |
| C | Incomplete validation, fallback-only validation, missing required routing metadata, or unclear automation readiness |
| F | A structural, safety, metadata, or command defect that must block publishing |

Validation depth (static-only through a full live inject-detect-mitigate loop) is recorded
separately in `fidelity_level` (L0 to L4), not in the grade.

Use `not-assessed`, `scaffold`, `ready`, `proven`, `blocked`, or `manual` for automation status.
Record `on-device`, `mixed`, `cloud-diagnostic`, `cloud-control`, or `thin` separately as the
execution surface. `manual` is an automation status, not an execution surface.

### Evidence required in a pull request

Include the following in the pull request description:

1. Static structure and safety result
2. Commands or procedures exercised, with the environment class and product build
3. Expected and observed results
4. Rollback or cleanup result
5. Remaining automation blockers

Maintainers run the TSG-FORGE persona and live-validation workflow. A static pass alone does not
prove that a remediation restores a cluster.

For administrator detection surfaces, use `shown`, `not-evident`, or `absent`. A
`not-evident` claim requires an authoritative check with a stated scope, time window, or freshness
basis. `absent` means the surface is still uncharacterized and is a publication gap.

## Detailed Guidelines

<details>
<summary><strong>Document Types & Templates</strong></summary>

| Document Type    | Purpose                                         | Template                                                               | Structure                                              |
| ---------------- | ----------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------ |
| **Troubleshoot** | Help users fix specific errors or problems      | [`Troubleshoot-Template.md`](./TSG/Templates/Troubleshoot-Template.md) | Symptoms > Diagnosis > Contributing factors > Mitigation > Verification |
| **Reference**    | Provide configuration examples and settings     | [`Reference-Template.md`](./TSG/Templates/Reference-Template.md)       | Overview > Configuration > Examples > Validation       |
| **How-To**       | Step-by-step instructions                       | [`HowTo-Template.md`](./TSG/Templates/HowTo-Template.md)               | Prerequisites > Steps > Verification > Next steps      |
| **Deep Dive**    | Technical explanations and architecture details | [`DeepDive-Template.md`](./TSG/Templates/DeepDive-Template.md)         | Overview > Technical details > Examples > References   |
| **Overview**     | High-level introductions and summaries          | [`Overview-Template.md`](./TSG/Templates/Overview-Template.md)         | Introduction > Key concepts > Architecture > Resources |

</details>

<details>
<summary><strong>File Naming Conventions</strong></summary>

File names should be CamelCase with hyphens as spaces. Topic should categorize the content.

```
Type-Topic-Specifics.md
```

**Examples:**

- `Troubleshoot-SDNExpress-HealthAlert-HostNotConnectedToController.md`
- `Reference-TOR-Disaggregated-Switched-Storage.md`
</details>

<details>
<summary><strong>Recommended File Structure</strong></summary>

### Recommended Structure

```
TSG/
└── [Component]/
    ├── README.md                    # Component overview and TOC
    ├── CONTRIBUTING.md              # Component-specific guidelines
    ├── [Topic-Area-1]/
    │   ├── images/                  # Screenshots, diagrams
    │   ├── examples/                # Config files, scripts
    │   ├── Reference-[Topic]-[Specific].md
    │   ├── Troubleshoot-[Topic]-[Specific].md
    │   └── HowTo-[Topic]-[Specific].md
    └── [Topic-Area-2]/
        ├── images/
        ├── DeepDive-[Topic]-[Specific].md
        └── Overview-[Topic]-[Specific].md
```

### Images and Assets

- Place images in `images/` folder within the relevant topic area
- Use descriptive filenames: `deployment-error-screenshot.png`
- Optimize image sizes for web viewing

</details>

<details>
<summary><strong>Setting Up New Components</strong></summary>

When creating a new component area:

1. **Copy template files**:

   - [`TSG/Templates/Component/README-Template.md`](./TSG/Templates/Component/README-Template.md) → `TSG/{ComponentName}/README.md`
   - [`TSG/Templates/Component/CONTRIBUTING-Template.md`](./TSG/Templates/Component/CONTRIBUTING-Template.md) → `TSG/{ComponentName}/CONTRIBUTING.md`

2. **Customize templates**:

   - Replace `{COMPONENT_NAME}` with your component name
   - Define topic areas specific to your component
   - Update folder structure as needed

3. **Update main README**:
   - Add your component to the [Table of Contents](./README.md#table-of-contents)

</details>

---

## Need Help?

- **Not sure where your content fits?** Check the [component descriptions](./README.md#table-of-contents)
- **Questions about templates?** Look at existing documents for examples
- **Need to report an Azure Local issue?** Use our [bug report template](./.github/ISSUE_TEMPLATE/bug_report.md)
- **Found a problem with existing content?** Open an issue with the `documentation` label

**Questions?** Open an issue or check component-specific `CONTRIBUTING.md` files for additional guidance.

## Additional Resources

- [Markdown formatting guide](./TSG/Templates/Markdown-Snippets.md)
- [Azure Local documentation](https://learn.microsoft.com/azure/azure-local/)
- [Microsoft Writing Style Guide](https://learn.microsoft.com/style-guide/)
