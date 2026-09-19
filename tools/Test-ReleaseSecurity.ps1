[CmdletBinding()]
param(
    [string[]]$Path = @('./winutil-cn.ps1', './WinUtil-CN.exe'),
    [string]$ReportPath = './security-scan.json',
    [switch]$VerifyOnly
)

# This check never launches the release artifacts or changes Defender settings.
# MpCmdRun return codes and custom-scan behavior:
# https://learn.microsoft.com/en-us/defender-endpoint/command-line-arguments-microsoft-defender-antivirus
function Get-ReleaseDefenderPath {
    $candidate = Get-ChildItem "$env:ProgramData/Microsoft/Windows Defender/Platform/*/MpCmdRun.exe" -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Directory.Name -replace '-.*$', '') } -Descending | Select-Object -First 1
    if (-not $candidate) {
        $candidate = Get-Item "$env:ProgramFiles/Windows Defender/MpCmdRun.exe" -ErrorAction SilentlyContinue
    }
    if ($candidate) { $candidate.FullName }
}

function Invoke-ReleaseDefenderScan {
    param([string]$ScannerPath, [string]$FilePath)

    # Nonzero native exit codes are captured and evaluated below, including in
    # PowerShell 7 environments that promote native errors to terminating errors.
    $PSNativeCommandUseErrorActionPreference = $false
    $ErrorActionPreference = 'Continue'
    $global:LASTEXITCODE = $null
    # DisableRemediation applies ONLY to this scan: it ignores exclusions,
    # scans archives and reports detections without changing the release file.
    # With remediation disabled, code 0 means no detected malware; code 2 may
    # mean a detection OR a scan error, so neither is eligible for release.
    $output = & $ScannerPath -Scan -ScanType 3 -File $FilePath -DisableRemediation 2>&1 | Out-String
    [pscustomobject]@{ ExitCode = $global:LASTEXITCODE; Output = $output }
}

function Assert-ReleaseSecurityReport {
    param([string[]]$Path, [string]$ReportPath)
    $ErrorActionPreference = 'Stop'
    $report = Get-Content -LiteralPath $ReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($report.SchemaVersion -ne 1 -or $report.Result -ne 'Clean' -or @($report.Errors).Count -ne 0) {
        throw 'Release security report is not a completed, successful scan.'
    }
    if (@($report.Files).Count -ne $Path.Count) { throw 'Release artifact list differs from the scanned list.' }
    $names = @($Path | ForEach-Object { [IO.Path]::GetFileName($_) })
    if (@($names | Select-Object -Unique).Count -ne $Path.Count) { throw 'Release artifact names must be unique.' }
    foreach ($file in $Path) {
        $name = [IO.Path]::GetFileName($file)
        $entry = @($report.Files | Where-Object { $_.Name -ceq $name })
        if ($entry.Count -ne 1 -or $entry[0].ScanResult -ne 'Clean' -or $null -eq $entry[0].DefenderExitCode -or $entry[0].DefenderExitCode -ne 0) {
            throw "Missing successful scan for release artifact: $name"
        }
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry[0].SHA256) {
            throw "Release artifact changed after scanning: $name"
        }
    }
}

function Test-ReleaseSecurity {
    param([string[]]$Path, [string]$ReportPath)
    $ErrorActionPreference = 'Stop'
    $outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReportPath)
    foreach ($file in $Path) {
        if ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($file) -eq $outputPath) {
            throw 'The security report cannot overwrite a release artifact.'
        }
    }
    $report = [ordered]@{
        SchemaVersion = 1
        SourceCommit = $env:GITHUB_SHA
        StartedUtc = [DateTime]::UtcNow.ToString('o')
        CompletedUtc = $null
        Result = 'Blocked'
        Defender = $null
        Files = @()
        Errors = @()
    }
    try {
        if ($Path.Count -eq 0) { throw 'No release artifacts were specified.' }
        $names = @($Path | ForEach-Object { [IO.Path]::GetFileName($_) })
        if (@($names | Select-Object -Unique).Count -ne $Path.Count) { throw 'Release artifact names must be unique.' }
        $scanner = Get-ReleaseDefenderPath
        if (-not $scanner) { throw 'MpCmdRun.exe is unavailable; release scan cannot be completed.' }
        $status = Get-MpComputerStatus -ErrorAction Stop
        if (-not $status.AMServiceEnabled -or -not $status.AntivirusEnabled -or -not $status.AntivirusSignatureVersion) {
            throw 'Defender antivirus service or signature information is unavailable.'
        }
        $report.Defender = [ordered]@{
            ScannerPath = $scanner
            EngineVersion = $status.AMEngineVersion
            SignatureVersion = $status.AntivirusSignatureVersion
            SignatureUpdatedUtc = if ($status.AntivirusSignatureLastUpdated) { $status.AntivirusSignatureLastUpdated.ToUniversalTime().ToString('o') } else { $null }
            RealTimeProtectionEnabled = $status.RealTimeProtectionEnabled
        }
        foreach ($file in $Path) {
            $entry = [ordered]@{
                Name = [IO.Path]::GetFileName($file)
                SHA256 = $null
                Length = $null
                AuthenticodeStatus = $null
                SignerSubject = $null
                DefenderExitCode = $null
                ScanResult = 'Blocked'
                ScanOutput = $null
                Error = $null
            }
            $report.Files += $entry
            try {
                $item = Get-Item -LiteralPath $file -ErrorAction Stop
                if ($item.PSIsContainer -or $item.Length -eq 0) { throw "Release artifact is empty or is a directory: $file" }
                $entry.Length = $item.Length
                $entry.SHA256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
                $signature = Get-AuthenticodeSignature -LiteralPath $item.FullName -ErrorAction Stop
                $entry.AuthenticodeStatus = [string]$signature.Status
                if ($signature.SignerCertificate) { $entry.SignerSubject = $signature.SignerCertificate.Subject }
                if ($entry.AuthenticodeStatus -notin @('Valid', 'NotSigned')) {
                    throw "Release artifact has an invalid or unverifiable Authenticode signature: $($entry.Name) ($($entry.AuthenticodeStatus))"
                }
                $scan = Invoke-ReleaseDefenderScan -ScannerPath $scanner -FilePath $item.FullName
                $entry.DefenderExitCode = $scan.ExitCode
                $entry.ScanOutput = $scan.Output
                Write-Host "$($entry.Name): Defender exit code $($scan.ExitCode)"
                Write-Host $scan.Output
                if ($null -eq $scan.ExitCode -or $scan.ExitCode -ne 0) {
                    throw "Defender detected a threat or did not complete its scan: $($entry.Name). See ScanOutput and DefenderExitCode."
                }
                if ((Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash -ne $entry.SHA256) {
                    throw "Release artifact changed during scanning: $($entry.Name)"
                }
                $entry.ScanResult = 'Clean'
            } catch {
                $entry.Error = $_.Exception.Message
                $report.Errors += $entry.Error
            }
        }
        if ($report.Errors.Count -eq 0) { $report.Result = 'Clean' }
    } catch {
        $report.Errors += $_.Exception.Message
    } finally {
        $report.CompletedUtc = [DateTime]::UtcNow.ToString('o')
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outputPath -Encoding UTF8
    }
    if ($report.Result -ne 'Clean') {
        throw "Release blocked. See ${ReportPath}: $($report.Errors -join '; ')"
    }
    Assert-ReleaseSecurityReport -Path $Path -ReportPath $ReportPath
    Write-Host "Defender scan completed for $($Path.Count) artifacts. Evidence: $ReportPath"
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($VerifyOnly) {
        Assert-ReleaseSecurityReport -Path $Path -ReportPath $ReportPath
    } else {
        Test-ReleaseSecurity -Path $Path -ReportPath $ReportPath
    }
}
