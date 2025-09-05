# Project Overview

This is a public repository for all of Azure Local Troubleshooting guides (TSGs), known issues and reporting feedback - this repo is intended to provide a central location for community driven supportability content. This is the material that is referenced by Customer Support Services when a ticket is created, by Azure Local engineering responding to an incident, and by users when self discovering resolutions to active system issues.

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

- **Formatting and Structure**
  - [ ] Follows consistent markdown formatting for commands vs. outputs
  - [ ] Uses appropriate callouts (note/warning/important)
  - [ ] Employs logical headings and subheadings
  - [ ] Contains Table of Contents for documents exceeding 3 sections
  - [ ] Code examples use consistent formatting and indentation

- **User Experience**
  - [ ] Instructions are complete without assumptions of prior knowledge
  - [ ] Examples include realistic scenarios relevant to Azure Local
  - [ ] Links follow the guidelines (no version references in URLs)
  - [ ] Images are properly placed in an images/ subfolder

#### Troubleshooting Guide (TSG) Checklist
- [ ] Clear symptoms description at the beginning
- [ ] Problem statement defines impact and scope
- [ ] Diagnostic steps are in logical sequence
- [ ] Resolution steps are distinct from diagnostic steps
- [ ] Verification steps confirm issue resolution
- [ ] PowerShell code follows safety guidelines

#### How-To Guide Checklist
- [ ] Clear prerequisites section
- [ ] Numbered step-by-step instructions
- [ ] Each step has a single, clear action
- [ ] Verification steps follow configuration changes
- [ ] Expected outcomes are clearly documented
- [ ] Alternative approaches mentioned where applicable

#### Reference Document Checklist
- [ ] Information organized in logical categories
- [ ] Tables used for parameter/setting references
- [ ] Examples provided for complex configurations
- [ ] Default values clearly indicated

## Language Assistance Guidelines
- Suggest corrections for spelling and grammar in a supportive manner
- Frame language suggestions as "improvements" rather than "corrections"
- Focus on clarity rather than perfect English
- Prioritize technical accuracy over language perfection

## PowerShell Code Guidelines
When reviewing or suggesting PowerShell code in documentation:
- Pay special attention to commands that change environment state (e.g., restart, stop, remove, set, write).
- For state-changing commands:
  - Verify code is safe for production environments.
  - Implement defensive coding techniques (check conditions before taking action).
  - Include verification steps before and after changes.
  - Ensure commands don't disrupt workloads.
  - Check for proper error handling.
  - Use placeholders like <hostname> instead of hardcoded values.

Example:
```powershell
# DANGEROUS EXAMPLE - Could cause an unexpected state
Restart-Service -Name "CriticalService" -Force

# SAFER ALTERNATIVE - Checks status and confirm before action
$serviceName = "CriticalService"
$service = Get-Service -Name $serviceName
Write-Host "Current status of $serviceName is: $($service.Status)"

$confirmation = Read-Host "Are you sure you want to restart $serviceName? (y/n)"
if ($confirmation -eq 'y') {
    Write-Host "Restarting $serviceName..."
    Restart-Service -Name $serviceName
}
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
- The table of contents in the component's README.md files should be updated when adding new content
- Place images in an images/ subfolder within the relevant component

