[CmdletBinding()]
param()

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
    $child = $script:walker.GetFirstChild($Element)
    while ($null -ne $child) {
        Read-LabNode -Element $child -Depth ($Depth + 1) -ParentIndex $index
        if ($script:rows.Count -ge 200) { $script:truncated = $true; break }
        $child = $script:walker.GetNextSibling($child)
    }
}

try {
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $demo = Start-Process -FilePath $powershell -ArgumentList @(
        '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $fixture)
    ) -WindowStyle Hidden -PassThru
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
    $null = New-Item -ItemType Directory -Path $outputDirectory -Force
    $report = [pscustomobject]@{
        schemaVersion = 1
        capturedAtUtc = [DateTime]::UtcNow.ToString('o')
        scope = 'launched synthetic fixture only'
        processId = $demo.Id
        truncated = $script:truncated
        nodeCount = $script:rows.Count
        findings = @([pscustomobject]@{
            id = 'synthetic-identity-in-accessible-name'
            observed = $identityExposed
            evidenceNodeIndexes = @($identityNodes | ForEach-Object { $_.index })
            interpretation = 'A separate same-user process can read the fictional identity label exposed by this fixture.'
        })
        simulatedImpact = [pscustomobject]@{
            triggered = $identityExposed
            scenario = 'Fictional identity disclosure could support targeting if equivalent real data were exposed.'
            computerDamageDemonstrated = $false
            action = 'Report only; no destructive operation or transmission.'
        }
        nodes = @($script:rows.ToArray())
    }
    $destination = Join-Path $outputDirectory 'snapshot.json'
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
