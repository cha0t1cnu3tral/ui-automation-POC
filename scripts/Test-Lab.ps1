$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'Run-Lab.ps1')
& (Join-Path $PSScriptRoot 'Run-Lab.ps1') -Hardened
$baseline = Get-Content (Join-Path $projectRoot 'artifacts\snapshot.json') -Raw | ConvertFrom-Json
$hardened = Get-Content (Join-Path $projectRoot 'artifacts\snapshot-hardened.json') -Raw | ConvertFrom-Json
foreach ($report in @($baseline, $hardened)) {
    if ($report.truncated -or $report.nodeCount -ne $report.nodes.Count) { throw 'Incomplete report.' }
    if ($report.findings.Count -ne 3) { throw 'Missing detector results.' }
    $events = @($report.telemetry.events | Where-Object type -eq 'metadata-observed')
    if ($events.Count -ne $report.nodeCount) { throw 'Missing cooperative observation events.' }
    $password = @($report.nodes | Where-Object automationId -eq 'DemoPassword')
    if ($password.Count -ne 1 -or -not $password[0].isPassword -or $password[0].name -ne '[redacted password control]') {
        throw 'Password redaction failed.'
    }
    $disabled = @($report.nodes | Where-Object automationId -eq 'DisabledIdentity')
    if ($disabled.Count -ne 1 -or $disabled[0].isEnabled) { throw 'Disabled scenario was not reproduced.' }
    foreach ($finding in $report.findings) {
        if ($finding.observed -eq $report.hardened) { throw "Unexpected finding: $($finding.id)" }
        foreach ($index in $finding.evidenceNodeIndexes) {
            if ($index -lt 0 -or $index -ge $report.nodeCount) { throw 'Invalid evidence reference.' }
        }
    }
}
& (Join-Path $PSScriptRoot 'Compare-Detectors.ps1')
$comparison = Get-Content (Join-Path $projectRoot 'artifacts\detection-comparison.json') -Raw | ConvertFrom-Json
if (-not $comparison.simulation -or $comparison.results.Count -ne 2) { throw 'Invalid simulated comparison.' }
foreach ($result in $comparison.results) {
    if ($result.launchOnly.inputEventCount -ne 1 -or -not $result.launchOnly.fixtureLaunchObserved -or $result.launchOnly.identityExposureAssessment -ne 'unknown') {
        throw 'Launch-only detector overstated its coverage.'
    }
    if ($result.instrumented.syntheticCanaryAlert -ne ($result.mode -eq 'baseline')) { throw 'Unexpected instrumented alert.' }
}
Write-Host 'PASS: all three canaries exposed in baseline and absent after metadata remediation; password redaction preserved.'
Write-Host 'PASS: launch-only visibility stays unknown; cooperative telemetry flags baseline canaries only.'
