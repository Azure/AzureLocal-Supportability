# Project Overview

This is a public repository for all of Azure Local Troubleshooting guides (TSGs), known issues and reporting feedback - this repo is intended to provide a central location for community driven supportability content. This is the material that is referenced by Customer Support Services when a ticket is created, by Azure Local engineering responding to an incident, and by users when self discovering resolutions to active system issues.

## Table of contents

- [PR review guidelines and checklists](#pr-review-guidelines-and-checklists)
- [Applicability and automation metadata](#applicability-and-automation-metadata)
- [Language assistance guidelines](#language-assistance-guidelines)
- [PowerShell code guidelines](#powershell-code-guidelines)
- [Link guidelines](#link-guidelines)
- [New file guidelines](#new-file-guidelines)

## PR Review Guidelines and Checklists
### Review Process Guidance
- Focus on consistency with existing documentation and templates
- Limit comments to substantive issues (3-5 max per PR)
- Use concise, actionable language in comments
- Link to relevant templates or examples when possible
- Adapt review depth based on PR size:
  - For large PRs (5+ files): Focus only on critical issues and structure
  - For small PRs (1-2 files): Provide more comprehensive feedback

### Priority Review Areas
When reviewing any document, prioritize checking these elements (in order of importance):
1. Safety issues (potentially harmful code)
2. Technical inaccuracies
3. Missing critical information
4. Structural improvements
5. Style and formatting issues (only if significantly impacting readability)

### Review Comment Structure
Format each review comment with:
- What: Identify the specific issue
- Why: Briefly explain the impact or importance
- How: Suggest a specific, actionable improvement

### Document-Specific Checklists
#### Common Elements (All Documents)
- **Technical Accuracy**
  - [ ] Commands use appropriate parameters and syntax
  - [ ] PowerShell examples include proper error handling
  - [ ] Version-specific information is clearly indicated
  - [ ] Prerequisites are accurate and complete
  - [ ] Applicable Azure Local products, deployment modes, and supported versions are explicit
  - [ ] Claims identify their evidence source and validation status

- **Formatting and Structure**
  - [ ] Follows consistent markdown formatting for commands vs. outputs
  - [ ] Uses appropriate callouts (note/warning/important)
  - [ ] Employs logical headings and subheadings
  - [ ] Contains Table of Contents for documents exceeding 3 sections
  - [ ] Code examples use consistent formatting and indentation
  - [ ] Customer-facing prose contains no emoji

- **User Experience**
  - [ ] Instructions are complete without assumptions of prior knowledge
  - [ ] Examples include realistic scenarios relevant to Azure Local
  - [ ] Links follow the guidelines (no version references in URLs)
  - [ ] Images are properly placed in an images/ subfolder
  - [ ] Every action states the expected result and a stop condition for unexpected output
  - [ ] The `azure-local-supportability/tsg-metadata/v1` marker is present and current

#### Troubleshooting Guide (TSG) Checklist
- [ ] Clear symptoms description at the beginning
- [ ] Problem statement defines impact and scope
- [ ] Every administrator detection surface is shown or explicitly marked not evident
- [ ] Diagnostic steps are in logical sequence
- [ ] Resolution steps are distinct from diagnostic steps
- [ ] State-changing steps carry a [LOW RISK], [MEDIUM RISK], or [HIGH RISK] label
- [ ] Preconditions, workload impact, rollback, and escalation criteria are explicit
- [ ] Verification steps confirm issue resolution
- [ ] PowerShell code follows safety guidelines
- [ ] Causal claims are framed as evidence-backed contributing factors

Use the administrator-surface states consistently:

- `shown`: the article names the exact signal and where to find it.
- `not-evident`: an authoritative check with a stated scope, time window, or freshness basis shows
  that this surface does not carry the issue.
- `absent`: the author has not characterized the surface. This is a documentation gap and is not
  publish-ready evidence that the issue does not appear there.

#### How-To Guide Checklist
- [ ] Clear prerequisites section
- [ ] Numbered step-by-step instructions
- [ ] Each step has a single, clear action
- [ ] Each state-changing step includes risk, impact, expected result, and rollback
- [ ] Verification steps follow configuration changes
- [ ] Expected outcomes are clearly documented
- [ ] Alternative approaches mentioned where applicable

#### Reference Document Checklist
- [ ] Information organized in logical categories
- [ ] Tables used for parameter/setting references
- [ ] Examples provided for complex configurations
- [ ] Default values clearly indicated
- [ ] Supported values, constraints, applicability, and validation methods are explicit

## Applicability and automation metadata

Every article template carries one hidden JSON marker with schema
`azure-local-supportability/tsg-metadata/v1`. Preserve it when creating an article and replace
its placeholders. The authoritative allowed values are in
[`tsg-metadata.schema.json`](../TSG/Templates/tsg-metadata.schema.json). The marker records:

- Document type and applicable products
- Detector type and signal
- Validation fidelity level
- Technical grade, or `null` until TSG-FORGE produces one
- Reproduction substrate
- Automation status
- Last validation date and internal specification reference

Do not place customer names, cluster names, subscription IDs, IP addresses, credentials, or other
environment-specific identifiers in this marker.

Use these fidelity values consistently:

| Level | Evidence required |
| --- | --- |
| L0 | Static structure, safety, and persona review only |
| L1 | Every diagnostic command exercised read-only |
| L2 | The real detector and remediation direction exercised with a safe proxy |
| L3 | The real failure and remediation exercised on an isolated scratch object |
| L4 | Full baseline, inject, detect, mitigate, and revalidate loop exercised live |

Technical grade records the TSG outcome, not the cluster outcome:

| Grade | Meaning |
| --- | --- |
| `null` | No TSG-FORGE technical grade has been established |
| A | The article is complete for its type, safety gates are present, metadata is valid, links resolve, and lint is clean |
| B | Usable, but non-blocking gaps remain, such as missing optional evidence or a documented false-positive warning |
| C | Incomplete validation, fallback-only validation, missing required routing metadata, or unclear automation readiness |
| F | A structural, safety, metadata, or command defect that must block publishing |

Validation depth (static-only through a full live inject-detect-mitigate loop) is recorded
separately in `fidelity_level` (L0 to L4), not in the grade.

Automation status is separate from execution surface:

| Status | Meaning |
| --- | --- |
| `not-assessed` | No automation assessment has been completed |
| `scaffold` | Metadata exists, but executable automation is incomplete |
| `ready` | Automation is implemented and awaiting a qualifying live run |
| `proven` | Automation completed its declared validation loop |
| `blocked` | A named safety, access, or substrate requirement prevents the run |
| `manual` | The verification surface requires an operator |

Execution surface describes where steps run. Use `on-device`, `mixed`, `cloud-diagnostic`,
`cloud-control`, or `thin`. `manual` is an automation status, not an execution surface. Do not
store execution-surface values in `validation.automation_status`.

## Language Assistance Guidelines
When reviewing or suggesting language improvements (in order of importance):
1. Focus on clarity rather than perfect English
2. Prioritize technical accuracy over language perfection
3. Suggest corrections for spelling

Frame language suggestions as "improvements" rather than "corrections"

## PowerShell Code Guidelines
When reviewing or suggesting PowerShell code in documentation:
- Pay special attention to commands that change environment state (e.g., restart, stop, remove, set, write).
- For state-changing commands:
  - Assign one canonical risk label: [LOW RISK], [MEDIUM RISK], or [HIGH RISK].
  - Verify code is safe for production environments.
  - Implement defensive coding techniques (check conditions before taking action). But avoid excessive complexity.
  - Include a pre-check, expected output, stop condition, rollback, and verification.
  - Ensure commands don't disrupt workloads. If they do, provide clear warnings.
  - Check for proper error handling.
  - Use placeholders like <hostname> instead of hardcoded values.
- For read-only commands:
  - Use [READ-ONLY] as the action type, not as a risk label.
  - Record the risk label as not applicable because the command does not change state.

Example:
```powershell
# DANGEROUS EXAMPLE - Could cause an unexpected state
Restart-Service -Name "CriticalService" -Force

# SAFER ALTERNATIVE - Don't use force
Restart-Service -Name "CriticalService"
```

Example:
```powershell
# Explicitly set ErrorActionPreference
$ErrorActionPreference = "Stop"
Get-Service -Name "NonExistentService"
```

## Link Guidelines
- Check for broken internal links and references
- External links should only reference Microsoft documentation, and should not include the release
    - GOOD: https://learn.microsoft.com/en-us/azure/azure-local
    - BAD: https://learn.microsoft.com/en-us/azure/azure-local/?view=azloc-2505 <- Includes 2505

## New File Guidelines
- Most new MD files should follow naming convention: <Type>-<Topic>-<Specifics>.md
- Most new MD files should use one of the templates provided
- The component README.md inventory must be updated with the article type, applicable products,
  owner, validation grade, automation readiness, and last validation date
- Place images in an images/ subfolder within the relevant component
