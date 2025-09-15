<!--
Troubleshoot Template
- Focus on providing systematic troubleshooting guidance for specific issues
- Replace all {placeholders} with relevant content
- This template provides a suggested structure - adapt sections as needed for your specific issue
- Skip optional sections if they don't add value

Styling
- Images should be placed in the `./images` folder and referenced
- Any code block should be wrapped in triple backticks (```) with language identifier
- Use numbered lists for sequential steps and bullet points for symptoms/options

Coding Standards
- All code snippets MUST be safe to execute in a production environment
- Check that the environment is in the expected state before performing mitigation

You can use this regex to find placeholders that need to be replaced (search by Regex in your editor): \{([^}]+)\}
-->

# {Issue Title}

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>{Component Name}</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>{Critical/High/Medium/Low}</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>{Deployment/Update/AddNode/etc.}</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td><strong>{Version ranges or "All versions"}</strong></td>
  </tr>
</table>

## Overview

{Brief description of the issue, what causes it, and when it typically occurs}

## Symptoms

{What users will see when encountering this issue}

**Common error messages:**
{Include specific error messages users might see}

```
{Error message example}
```

**Observable behaviors:**

- {Symptom 1}
- {Symptom 2}

## Root Cause

{Why this issue occurs}

## Resolution

### Prerequisites

{Any requirements before starting - skip if none}

- {Prerequisite 1}
- {Prerequisite 2}

### Steps

1. **{Action}**
   {action description, what are we doing, and why?}

   ```powershell
   # Verify current state first
   {Verification command}

   # Perform fix
   {Fix command}
   ```

2. **{Next action}**
   {action description, what are we doing, and why?}

   ```powershell
   {Command}
   ```

3. **Verify resolution**
   ```powershell
   # Confirm fix worked
   {Verification command}
   ```

## Prevention _(Optional)_

{How to prevent this issue from happening again - remove section if not applicable}

## Related Issues _(Optional)_

{Links to related TSGs or documentation - remove section if none}

---
