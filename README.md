# UI Automation POC

What can another process learn from an app's accessibility tree?

This project explores that question with a small Windows app and completely fictional customer data. The app makes a few deliberate mistakes: it puts extra identity details in an accessibility label, masks an email on screen while leaving the full address in metadata, and disables a field without removing its metadata. A separate process inspects the app and saves what it finds.

The interesting part is the gap between what the screen shows, what accessibility exposes, and what a detector has enough evidence to notice.

## Try it

You'll need Windows, Windows PowerShell 5.1, and an interactive desktop. There are no packages to install, and you can run it as a normal user.

From the project directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Lab.ps1
```

Two demo windows open in turn and close after inspection. The first exposes the fictional data. The second uses cleaned-up accessibility labels. The command checks both results and prints the detector comparison.

`ExecutionPolicy Bypass` here is a process-local setting to run the lab scripts. It isn't an antivirus bypass and doesn't change the machine's policy.

## What you should see

| Experiment | Baseline | Cleaned-up labels |
| --- | --- | --- |
| Extra fictional identity details in a label | Found | Removed |
| Full fictional email behind a masked label | Found | Removed |
| Fictional identity metadata on a disabled field | Found | Removed |
| Password control name | Redacted | Redacted |
| Launch-only detector's exposure assessment | Unknown | Unknown |
| Instrumented detector's synthetic-data alert | Yes | No |

The cleaned-up app still exposes information that's intentionally visible, including the fictional customer's name. The fix removes surplus details; it doesn't make the interface secret or disable accessibility.

## About the detection demo

The lab compares two toy detectors using different slices of the same event stream. One receives only a fixture-launch event. It can tell that a process started, but has no evidence of which data was read. Its answer is **unknown**, not "safe."

The other receives metadata observations logged by the inspector and flags the demo's `LAB-ONLY` markers. That gives it enough information to spot the fictional data exposure in the baseline run.

These events are self-reported by our inspector. The demo app doesn't independently audit UI Automation reads, and another reader could omit the events. This is a simulation of a telemetry coverage gap, not a test of real antivirus or EDR detection. The rule recognizes synthetic markers; it doesn't classify a reader as malware.

## Look at the evidence

Each run writes local reports under `artifacts/`:

- `snapshot.json`: baseline tree, findings, and cooperative events.
- `snapshot-hardened.json`: the same experiment with cleaned-up labels.
- `detection-comparison.json`: each toy detector's inputs and conclusions.

Findings refer to node indexes so you can check the underlying evidence. Reports stay out of Git.

For a single baseline run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Run-Lab.ps1
```

Add `-Hardened` to inspect the cleaned-up fixture. To compare existing reports again, run `scripts/Compare-Detectors.ps1`.

## What this proves

In this deliberately configured WPF app, a separate process running as the same user can collect fictional identity details from accessible names. Visual masking and disabled controls don't remove that metadata. Removing surplus details from those names fixes the three specific disclosures we test.

It doesn't establish a vulnerability in another app, a Windows permission bypass, an AV/EDR bypass, or the ability to damage a computer. The impact section of the snapshot is a clearly labeled scenario, with no destructive action behind it.

## Keep experiments local

The inspector starts its own fixture, uses that window's handle, and checks each element's process ID. Traversal stops at 200 nodes or 12 levels. It records metadata and supported pattern names, without reading text/value patterns or invoking controls. Password names are redacted.

Use fictional data when changing the fixture. Accessibility names and IDs can contain sensitive information themselves. There is no desktop-wide collection, keyboard monitoring, or network transmission in the lab.

## Where things live

- `fixtures/Demo.ps1`: the app and its two metadata configurations.
- `scripts/Run-Lab.ps1`: inspection, findings, and cooperative telemetry.
- `scripts/Compare-Detectors.ps1`: the simulated detection comparison.
- `scripts/Test-Lab.ps1`: the paired experiment and checks.
- [docs/RESEARCH.md](docs/RESEARCH.md): research questions and evidence guidance.

The tree traversal follows Microsoft's [UI Automation TreeWalker documentation](https://learn.microsoft.com/en-us/dotnet/framework/ui-automation/navigate-among-ui-automation-elements-with-treewalker).
