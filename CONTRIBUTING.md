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
4. **Complete the hidden metadata marker**: document type, applicable products, and detector
5. **Test all code examples**: they must be safe for production
6. **Save with correct naming**: `<Type>-<Topic>-<Specifics>.md`
7. **Update the component README.md** inventory with the article type, applicable products, and owner
8. **Submit a pull request** with evidence for every tested claim

Reference [Markdown Snippets](./TSG/Templates/Markdown-Snippets.md) for helpful formatting tips, diagrams, and more.

## Requirements

### Code Safety (CRITICAL)

All PowerShell/scripts **MUST be safe for production**

- Use placeholders like `<hostname>` instead of real values
- Describe what each state-changing command changes with a `**Changes:**` line, and what it does not affect
- Add `**Plan for:**` for disruptive steps, and a `> [!WARNING]` callout for steps that can't be undone, can interrupt running workloads, change firmware or security posture, or can lose data. You can also label those steps `[HIGH RISK]`.
- Do not add `[LOW RISK]`, `[MEDIUM RISK]`, or `[READ-ONLY]` labels. Older articles that use them are not required to change.
- Include a pre-check, expected output, stop condition, rollback, and verification
- Add comments explaining what commands do
- Test all examples before submitting

Read-only commands need no label. Optionally add one short sentence, such as "This step changes nothing."
See [Describing step impact](.github/copilot-instructions.md#describing-step-impact) for examples.

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

### TSG metadata

Every article created from a template includes one hidden
`azure-local-supportability/tsg-metadata/v2` JSON marker. Fill it in and keep it valid JSON. The
authoritative allowed values are in
[`tsg-metadata.schema.json`](./TSG/Templates/tsg-metadata.schema.json). The marker records
discovery metadata only:

- Document type
- Applicable products
- Detector type and signal

Do not add validation records, such as test runs, grades, lab environments, or automation
readiness, to the marker or the article. Describe validation in the pull request instead. Never add
customer or lab identifiers to tracked metadata.

Record `on-device`, `mixed`, `cloud-diagnostic`, `cloud-control`, or `thin` as the execution
surface in the article body when the template asks for it.

### Evidence required in a pull request

Include the following in the pull request description:

1. Static structure and safety result
2. Commands or procedures exercised, with the environment class and product build
3. Expected and observed results
4. Rollback or cleanup result

A static pass alone does not prove that a remediation restores a cluster.

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
