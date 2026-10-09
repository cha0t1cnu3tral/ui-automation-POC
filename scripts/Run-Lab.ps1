[CmdletBinding()]
param([switch]$Hardened)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$projectRoot = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path $projectRoot 'fixtures\Demo.ps1'
$outputDirectory = Join-Path $projectRoot 'artifacts'
$demo = $null

function Read-LabNode {
    param($Element, [int]$Depth, [int]$ParentIndex)
    if ($Depth -gt 12 -or $script:rows.Count -ge 200) {
        $script:truncated = $true
        return
    }
    $info = $Element.Current
    if ($info.ProcessId -ne $demo.Id) {
        throw 'Element is outside the demo process. Inspection stopped.'
    }
    $index = $script:rows.Count
    $patterns = @($Element.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName })
    $name = $info.Name
    if ($info.IsPassword) { $name = '[redacted password control]' }
    $script:rows.Add([pscustomobject]@{
        index = $index
        parentIndex = $ParentIndex
        depth = $Depth
        name = $name
        automationId = $info.AutomationId
        controlType = $info.ControlType.ProgrammaticName
        isPassword = $info.IsPassword
        isEnabled = $info.IsEnabled
        supportedPatterns = $patterns
    })
    $script:events.Add([pscustomobject]@{
        type = 'metadata-observed'
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        source = 'cooperative-inspector'
        processId = $demo.Id
        nodeIndex = $index
        automationId = $info.AutomationId
        syntheticCanaryObserved = (-not $info.IsPassword -and $name.StartsWith('LAB-ONLY '))
    })
    $child = $script:walker.GetFirstChild($Element)
    while ($null -ne $child) {
        Read-LabNode -Element $child -Depth ($Depth + 1) -ParentIndex $index
        if ($script:rows.Count -ge 200) { $script:truncated = $true; break }
        $child = $script:walker.GetNextSibling($child)
    }
}

try {
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $launchArguments = @(
        '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $fixture)
    )
    if ($Hardened) { $launchArguments += '-Hardened' }
    $demo = Start-Process -FilePath $powershell -ArgumentList $launchArguments -WindowStyle Hidden -PassThru
    $script:events = New-Object 'System.Collections.Generic.List[object]'
    $script:events.Add([pscustomobject]@{
        type = 'fixture-process-started'
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        source = 'cooperative-inspector'
        processId = $demo.Id
    })
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        $demo.Refresh()
        if ($demo.HasExited) { throw 'Demo exited before its window became available.' }
        if ($demo.MainWindowHandle -ne [IntPtr]::Zero) { break }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($demo.MainWindowHandle -eq [IntPtr]::Zero) { throw 'Demo window did not appear within 15 seconds.' }

    $root = [Windows.Automation.AutomationElement]::FromHandle($demo.MainWindowHandle)
    $script:rows = New-Object 'System.Collections.Generic.List[object]'
    $script:truncated = $false
    $script:walker = [Windows.Automation.TreeWalker]::ControlViewWalker
    Read-LabNode -Element $root -Depth 0 -ParentIndex -1
    $identityNodes = @($script:rows.ToArray() | Where-Object {
        $_.automationId -eq 'SyntheticIdentity' -and
        $_.name -eq 'LAB-ONLY identity: Alex Example; email: alex@example.invalid; address: 123 Example Street, Fictional City'
    })
    $identityExposed = $identityNodes.Count -gt 0
    $rules = @(
        @{ id = 'masked-label-exposure'; control = 'MaskedIdentity'; canary = 'LAB-ONLY masked identity: alex@example.invalid'; explanation = 'Visual masking left the full fictional email in the accessible name.' },
        @{ id = 'disabled-field-exposure'; control = 'DisabledIdentity'; canary = 'LAB-ONLY disabled identity: Alex Example, 123 Example Street'; explanation = 'Disabling interaction did not remove fictional identity metadata.' }
    )
    $findings = @([pscustomobject]@{
        id = 'synthetic-identity-in-accessible-name'
        observed = $identityExposed
        evidenceNodeIndexes = @($identityNodes | ForEach-Object { $_.index })
        interpretation = 'A separate same-user process can read the fictional identity label exposed by this fixture.'
    })
    foreach ($rule in $rules) {
        $matched = @($script:rows.ToArray() | Where-Object {
            $_.automationId -eq $rule.control -and $_.name -eq $rule.canary
        })
        $findings += [pscustomobject]@{
            id = $rule.id
            observed = $matched.Count -gt 0
            evidenceNodeIndexes = @($matched | ForEach-Object { $_.index })
            interpretation = $rule.explanation
        }
    }
    $null = New-Item -ItemType Directory -Path $outputDirectory -Force
    $report = [pscustomobject]@{
        schemaVersion = 3
        hardened = [bool]$Hardened
        capturedAtUtc = [DateTime]::UtcNow.ToString('o')
        scope = 'launched synthetic fixture only'
        processId = $demo.Id
        truncated = $script:truncated
        nodeCount = $script:rows.Count
        findings = $findings
        simulatedImpact = [pscustomobject]@{
            triggered = $identityExposed
            scenario = 'Fictional identity disclosure could support targeting if equivalent real data were exposed.'
            computerDamageDemonstrated = $false
            action = 'Report only; no destructive operation or transmission.'
        }
        nodes = @($script:rows.ToArray())
        telemetry = [pscustomobject]@{
            source = 'cooperative-inspector'
            limitation = 'Self-reported by the reader; not provider auditing, OS telemetry, or independent security monitoring.'
            events = @($script:events.ToArray())
        }
    }
    $reportName = 'snapshot.json'
    if ($Hardened) { $reportName = 'snapshot-hardened.json' }
    $destination = Join-Path $outputDirectory $reportName
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $destination -Encoding UTF8
    Write-Host "Captured $($script:rows.Count) nodes: $destination"
    Write-Host "Synthetic identity exposed through accessibility metadata: $identityExposed"
}
finally {
    if ($null -ne $demo -and -not $demo.HasExited) {
        $null = $demo.CloseMainWindow()
        if (-not $demo.WaitForExit(3000)) { $demo.Kill() }
    }
}
