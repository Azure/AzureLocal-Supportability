# Project Overview

This is a public repository for all of Azure Local Troubleshooting guides (TSGs), known issues and reporting feedback - this repo is intended to provide a central location for community driven supportability content. This is the material that is referenced by Customer Support Services when a ticket is created, by Azure Local engineering responding to an incident, and by users when self discovering resolutions to active system issues.

## Table of contents

- [PR review guidelines and checklists](#pr-review-guidelines-and-checklists)
- [Article metadata](#article-metadata)
- [Language assistance guidelines](#language-assistance-guidelines)
- [PowerShell code guidelines](#powershell-code-guidelines)
  - [Describing step impact](#describing-step-impact)
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
  - [ ] Claims identify their evidence source

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
  - [ ] The `azure-local-supportability/tsg-metadata/v2` marker is present, current, and carries discovery metadata only
  - [ ] The article carries no validation records, such as test runs, grades, lab environments, or automation readiness

#### Troubleshooting Guide (TSG) Checklist
- [ ] Clear symptoms description at the beginning
- [ ] Problem statement defines impact and scope
- [ ] Every administrator detection surface is shown or explicitly marked not evident
- [ ] Diagnostic steps are in logical sequence
- [ ] Resolution steps are distinct from diagnostic steps
- [ ] State-changing steps describe their impact with a `**Changes:**` line, plus `**Plan for:**` or a `> [!WARNING]` callout when needed, and no `[LOW RISK]`, `[MEDIUM RISK]`, or `[READ-ONLY]` label (see [Describing step impact](#describing-step-impact))
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
- [ ] Each state-changing step includes a `**Changes:**` statement, workload impact, expected result, and rollback
- [ ] Verification steps follow configuration changes
- [ ] Expected outcomes are clearly documented
- [ ] Alternative approaches mentioned where applicable

#### Reference Document Checklist
- [ ] Information organized in logical categories
- [ ] Tables used for parameter/setting references
- [ ] Examples provided for complex configurations
- [ ] Default values clearly indicated
- [ ] Supported values, constraints, applicability, and validation methods are explicit

## Article metadata

Every article template carries one hidden JSON marker with schema
`azure-local-supportability/tsg-metadata/v2`. Preserve it when creating an article and replace
its placeholders. The authoritative allowed values are in
[`tsg-metadata.schema.json`](../TSG/Templates/tsg-metadata.schema.json). The marker records
discovery metadata only:

- Document type and applicable products
- Detector type and signal

Do not place customer names, cluster names, subscription IDs, IP addresses, credentials, or other
environment-specific identifiers in this marker.

Validation records, such as test runs, grades, lab or reproduction environments, automation
readiness, and validation dates, do not belong in the marker or the article. Ask the author to
describe validation in the pull request instead, and flag article text that records how or where
the article itself was tested.

Execution surface describes where steps run. Use `on-device`, `mixed`, `cloud-diagnostic`,
`cloud-control`, or `thin`, and record it in the article body when the template asks for it.

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
  - Describe the impact with a `**Changes:**` line, and add `**Plan for:**` or a `> [!WARNING]` callout when the step is disruptive or can't be undone. See [Describing step impact](#describing-step-impact).
  - Verify code is safe for production environments.
  - Implement defensive coding techniques (check conditions before taking action). But avoid excessive complexity.
  - Include a pre-check, expected output, stop condition, rollback, and verification.
  - Ensure commands don't disrupt workloads. If they do, provide clear warnings.
  - Check for proper error handling.
  - Use placeholders like <hostname> instead of hardcoded values.
- For read-only commands:
  - Do not add a label. Optionally add one short sentence, such as "This step changes nothing."

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

### Describing step impact

Readers want to know what a step changes, not a threat rating. Describe impact in plain words:

- **Read-only or diagnostic steps:** no label. Optionally add one short sentence, such as "This step changes nothing."
- **State-changing steps:** add a line that starts with `**Changes:**` and says concretely what the step changes and what it does not affect. Example: "**Changes:** removes the extra module folder. Running VMs are not affected."
- **Disruptive steps** (restart, drain, node or workload interruption, management interruption, or a maintenance window is needed): also add a line that starts with `**Plan for:**` and states what to arrange first. Example: "**Plan for:** drain the machine and schedule a maintenance window."
- **Steps that can't be undone, can interrupt running workloads, change firmware or security posture, or can lose data:** add a `> [!WARNING]` callout that states the concrete consequence in plain words. Example: "This can't be undone." or "Running VMs stop if the machine is not drained first." You can also add a `[HIGH RISK]` label to these steps, alongside the callout.

Use the word "risk" in a label only for `[HIGH RISK]`. Do not add `[LOW RISK]`, `[MEDIUM RISK]`, or `[READ-ONLY]` labels to new or edited steps. These statements replace those labels only. Every state-changing step still needs its pre-check, expected result, stop condition, rollback, verification, required privilege, maintenance gate, and escalation path.

Existing articles that still use the older bracketed labels, such as `[READ-ONLY]`, `[LOW RISK]`, or `[MEDIUM RISK]`, are acceptable and are not required to change. Do not flag them or block a pull request on them.

## Link Guidelines
- Check for broken internal links and references
- External links should only reference Microsoft documentation, and should not include the release
    - GOOD: https://learn.microsoft.com/en-us/azure/azure-local
    - BAD: https://learn.microsoft.com/en-us/azure/azure-local/?view=azloc-2505 <- Includes 2505

## New File Guidelines
- Most new MD files should follow naming convention: <Type>-<Topic>-<Specifics>.md
- Most new MD files should use one of the templates provided
- The component README.md inventory must be updated with the article type, applicable products,
  and owner
- Place images in an images/ subfolder within the relevant component
