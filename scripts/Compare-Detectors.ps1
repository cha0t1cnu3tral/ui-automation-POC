[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$artifactDirectory = Join-Path $projectRoot 'artifacts'
$results = @()
foreach ($reportName in @('snapshot.json', 'snapshot-hardened.json')) {
    $report = Get-Content (Join-Path $artifactDirectory $reportName) -Raw | ConvertFrom-Json
    if ($report.schemaVersion -ne 3 -or $report.telemetry.source -ne 'cooperative-inspector') {
        throw 'Generate current lab reports with Test-Lab.ps1 before comparing detectors.'
    }
    $starts = @($report.telemetry.events | Where-Object type -eq 'fixture-process-started')
    $reads = @($report.telemetry.events | Where-Object type -eq 'metadata-observed')
    $canaries = @($reads | Where-Object syntheticCanaryObserved -eq $true)
    $results += [pscustomobject]@{
        mode = $(if ($report.hardened) { 'hardened' } else { 'baseline' })
        simulation = $true
        launchOnly = [pscustomobject]@{
            inputEventCount = $starts.Count
            fixtureLaunchObserved = $starts.Count -gt 0
            identityExposureAssessment = 'unknown'
            explanation = 'Launch events contain no evidence of which metadata was read.'
        }
        instrumented = [pscustomobject]@{
            inputEventCount = $reads.Count
            syntheticCanaryAlert = $canaries.Count -gt 0
            evidenceNodeIndexes = @($canaries | ForEach-Object { $_.nodeIndex })
            explanation = 'Toy rule flags LAB-ONLY canaries in cooperative inspector observations.'
        }
    }
}
$comparison = [pscustomobject]@{
    schemaVersion = 1
    simulation = $true
    limitation = 'Models telemetry coverage, not malware classification. An uncooperative reader need not emit these events. No real AV/EDR product is tested.'
    results = $results
}
$comparison | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $artifactDirectory 'detection-comparison.json') -Encoding UTF8
$results | Select-Object mode, @{Name='Launch-only assessment';Expression={$_.launchOnly.identityExposureAssessment}}, @{Name='Instrumented canary alert';Expression={$_.instrumented.syntheticCanaryAlert}} | Format-Table -AutoSize
