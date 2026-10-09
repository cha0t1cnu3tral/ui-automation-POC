# Accessibility exposure lab

A Windows proof of concept for studying accessibility metadata in a controlled application. This is a starting point for defensive research into what an application exposes through its accessibility provider.

## Run

From Windows PowerShell 5.1 in this directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Run-Lab.ps1
```

The command starts a visible demo app containing synthetic data, captures its UI Automation control tree, writes `artifacts/snapshot.json`, and closes the demo. No installation or administrator privileges are required. The execution-policy override applies only to the launched process.

```powershell
Get-Content .\artifacts\snapshot.json
```

## Scope

The inspector accepts only the window handle of the demo process it starts, checks process ownership for each element, and limits traversal to 200 nodes and 12 levels. It records names, identifiers, control types, password flags, and supported pattern names. It does not retrieve text/value patterns, invoke controls, monitor keyboard input, enumerate the desktop, or contact the network.

Names and identifiers can themselves disclose information. Use only synthetic data in this fixture. Password nodes have their names redacted; this is a collection policy, not a claim that every provider protects sensitive data correctly.

## PII exposure demonstration

The fixture deliberately exposes a fictional name, email, and address in the accessible name of `SyntheticIdentity`. The separate inspector checks for that exact synthetic canary and records a finding with its evidence node index. This demonstrates cross-process collection of identity-shaped metadata without searching other applications or collecting real PII.

The report also contains an explicitly simulated targeting scenario. It performs no damaging action. Reading accessibility metadata alone does not establish the ability to damage a computer, obtain elevated privileges, or evade detection.

## Research questions

- Which labels and identifiers appear in the control tree?
- Which controls advertise Value, Text, or Invoke patterns?
- Is the password field identified as a password control?
- How does changing the fixture's accessibility metadata change the snapshot?

Modify `fixtures/Demo.ps1` to explore those questions. A successful snapshot demonstrates metadata exposure in this fixture; it does not establish exploitability, permission bypass, or behavior in other applications.

## Layout

- `fixtures/Demo.ps1`: visible WPF demo with synthetic controls.
- `scripts/Run-Lab.ps1`: scoped, read-only inspection and JSON export.
- `artifacts/`: generated local reports (ignored by Git).

Microsoft reference: [Navigate among UI Automation elements with TreeWalker](https://learn.microsoft.com/en-us/dotnet/framework/ui-automation/navigate-among-ui-automation-elements-with-treewalker).
