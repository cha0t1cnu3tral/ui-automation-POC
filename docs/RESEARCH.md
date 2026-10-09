# Accessibility exposure research plan

## Claim under test

A separate process running as the same interactive user can observe accessibility metadata that the demo application's provider exposes. The current runner measures that exposure through Windows UI Automation, using only a window it launches.

The `SyntheticIdentity` accessible name contains a fictional name, email, and address. A successful finding demonstrates the narrower claim that PII-shaped data deliberately placed in an accessible label can be collected across processes. The fixture is intentionally vulnerable to metadata disclosure; it is not evidence of a vulnerability in unrelated software.

This is a concrete cross-process experiment. It does not test malware evasion, privilege escalation, or bypass of a security boundary. Absence of a security alert alone would not prove any of those claims.

## Reproduce the baseline

1. Use a Windows test machine with an interactive desktop.
2. Run `scripts/Run-Lab.ps1` as a normal user.
3. Inspect `artifacts/snapshot.json` for `DemoAccount`, `DemoPassword`, and `DemoAction`.
4. Confirm the password control has `isPassword: true` and a redacted name.
5. Note advertised pattern names. An advertised pattern does not establish that its content can be retrieved or that an action can be performed.

## Controlled experiment

Change an `AutomationProperties.Name` in `fixtures/Demo.ps1` to a unique synthetic marker, run the lab again, and check whether the new marker appears in the report. Keep the operating system, user, execution command, and other fixture controls constant. This tests provider metadata exposure directly.

## Paired metadata remediation experiment

Run `scripts/Test-Lab.ps1` to capture baseline and hardened fixtures. The baseline deliberately exposes exact fictional identity canaries through normal, visually masked, and disabled controls. Hardened mode changes only the accessible names to descriptions consistent with visible content. Compare findings and evidence node indexes in the two reports.

The disabled control must remain disabled in both runs. This separates interaction state from metadata exposure. The test also checks that the password control remains identified and redacted. A passing result supports removing surplus metadata as a mitigation for these specific disclosures; it does not establish that all identity information or all UI Automation patterns are inaccessible.

## Defensive visibility experiment

The runnable toy comparison is `scripts/Compare-Detectors.ps1`, also executed by `Test-Lab.ps1`. It filters inspector-reported events into launch-only and metadata-observation views. Launch-only assessment remains unknown in both configurations; the cooperative observation rule flags synthetic canaries only in baseline mode. This models an instrumentation gap, not evasion. The fixture does not independently audit requests, and these self-reported events provide no assurance against an uncooperative reader.

In an isolated machine you own, record the configured process-creation and PowerShell logging alongside the lab's timestamp and process ID. Document which logging is enabled before running the experiment. Compare observations with the expected PowerShell parent/child process launch and local JSON write.

Do not infer that tree traversal is logged merely because process creation is logged. If your instrumentation cannot observe individual UI Automation reads, record that as an instrumentation limitation. Do not disable security controls to obtain a preferred result.

## Evidence for a portfolio write-up

- Research question and authorization scope.
- Operating system build, shell version, and logging configuration.
- Exact command and source commit used for each experiment.
- Synthetic fixture change and resulting metadata difference.
- Sanitized report and any relevant defender observations.
- Limitations: one WPF provider, same-user context, metadata-only inspection, and no tested permission boundary.

Keep original lab reports local. Review and sanitize any evidence before publishing it; window names and automation IDs can contain application data.
