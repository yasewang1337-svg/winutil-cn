BeforeAll {
    . (Join-Path $PSScriptRoot '../tools/Test-ReleaseSecurity.ps1')
}

Describe 'Native Defender process result capture' {
    BeforeEach {
        $script:previousNativeExitCode = $global:LASTEXITCODE
    }
    AfterEach {
        # Native invocation updates process-wide state. Keep deliberately
        # failing fixtures from affecting later tests in this Pester run.
        $global:LASTEXITCODE = $script:previousNativeExitCode
    }
    It 'captures the actual native exit code and stderr without throwing early' -TestCases @(
        @{ Code = 0 }, @{ Code = 2 }
    ) {
        param($Code)
        # The fixture only prints its arguments and exits. It does not scan,
        # change protection settings, or execute a release artifact.
        $scannerStub = Join-Path $TestDrive 'scanner-stub.cmd'
        @('@echo off', 'echo %*', 'echo fixture diagnostic 1>&2', "exit /b $Code") | Set-Content -LiteralPath $scannerStub -Encoding ASCII
        $result = Invoke-ReleaseDefenderScan -ScannerPath $scannerStub -FilePath 'C:/release/file with spaces.ps1'
        $result.ExitCode | Should -Be $Code
        $result.Output | Should -Match 'fixture diagnostic'
        $result.Output | Should -Match '-ScanType 3'
        $result.Output | Should -Match '-DisableRemediation'
        $result.Output | Should -Match 'file with spaces.ps1'
    }
}

Describe 'Release security gate' {
    BeforeEach {
        $script:releaseFiles = @((Join-Path $TestDrive 'winutil-cn.ps1'), (Join-Path $TestDrive 'WinUtil-CN.exe'))
        $script:reportFile = Join-Path $TestDrive 'security-scan.json'
        foreach ($file in $script:releaseFiles) { Set-Content -LiteralPath $file -Value 'harmless test fixture' -Encoding ASCII }
        Mock Get-ReleaseDefenderPath { 'C:/Defender/MpCmdRun.exe' }
        Mock Get-MpComputerStatus {
            [pscustomobject]@{
                AMServiceEnabled = $true
                AntivirusEnabled = $true
                AntivirusSignatureVersion = '1.2.3.4'
                AMEngineVersion = '1.1.2.3'
                AntivirusSignatureLastUpdated = [DateTime]'2026-09-19T00:00:00Z'
                RealTimeProtectionEnabled = $true
            }
        }
        Mock Get-AuthenticodeSignature { [pscustomobject]@{ Status = 'NotSigned'; SignerCertificate = $null } }
        Mock Invoke-ReleaseDefenderScan { [pscustomobject]@{ ExitCode = 0; Output = 'Locale-independent success output' } }
    }

    It 'scans both artifacts without relying on English output and records evidence' {
        Test-ReleaseSecurity -Path $script:releaseFiles -ReportPath $script:reportFile
        $report = Get-Content -LiteralPath $script:reportFile -Raw | ConvertFrom-Json
        $report.Result | Should -Be 'Clean'
        $report.Files.Count | Should -Be 2
        $report.Defender.SignatureVersion | Should -Be '1.2.3.4'
        foreach ($entry in $report.Files) {
            $entry.SHA256 | Should -Match '^[A-F0-9]{64}$'
            $entry.AuthenticodeStatus | Should -Be 'NotSigned'
            $entry.DefenderExitCode | Should -Be 0
            $entry.ScanResult | Should -Be 'Clean'
        }
        Should -Invoke Invoke-ReleaseDefenderScan -Times 2 -Exactly
        { Assert-ReleaseSecurityReport -Path $script:releaseFiles -ReportPath $script:reportFile } | Should -Not -Throw
    }

    It 'blocks detections, scan errors and missing native exit codes even with reassuring output' -TestCases @(
        @{ Code = 2 }, @{ Code = -2147024891 }, @{ Code = $null }
    ) {
        param($Code)
        $script:scanCode = $Code
        Mock Invoke-ReleaseDefenderScan { [pscustomobject]@{ ExitCode = $script:scanCode; Output = 'found no threats' } }
        { Test-ReleaseSecurity -Path $script:releaseFiles -ReportPath $script:reportFile } | Should -Throw '*Release blocked*'
        $report = Get-Content -LiteralPath $script:reportFile -Raw | ConvertFrom-Json
        $report.Result | Should -Be 'Blocked'
        $report.Errors.Count | Should -Be 2
        $report.Files[0].ScanOutput | Should -Be 'found no threats'
        Should -Invoke Invoke-ReleaseDefenderScan -Times 2 -Exactly
    }

    It 'blocks when the scanner is missing and still saves failure evidence' {
        Mock Get-ReleaseDefenderPath { $null }
        { Test-ReleaseSecurity -Path $script:releaseFiles -ReportPath $script:reportFile } | Should -Throw '*MpCmdRun.exe is unavailable*'
        (Get-Content -LiteralPath $script:reportFile -Raw | ConvertFrom-Json).Result | Should -Be 'Blocked'
        Should -Invoke Invoke-ReleaseDefenderScan -Times 0
    }

    It 'blocks disabled antivirus instead of changing protection settings' {
        Mock Get-MpComputerStatus { [pscustomobject]@{ AMServiceEnabled = $false; AntivirusEnabled = $false } }
        { Test-ReleaseSecurity -Path $script:releaseFiles -ReportPath $script:reportFile } | Should -Throw '*service or signature information is unavailable*'
        Should -Invoke Invoke-ReleaseDefenderScan -Times 0
    }

    It 'blocks a missing release artifact but still scans the other artifact' {
        Remove-Item -LiteralPath $script:releaseFiles[0]
        { Test-ReleaseSecurity -Path $script:releaseFiles -ReportPath $script:reportFile } | Should -Throw '*Release blocked*'
        $report = Get-Content -LiteralPath $script:reportFile -Raw | ConvertFrom-Json
        $report.Files[0].ScanResult | Should -Be 'Blocked'
        $report.Files[1].ScanResult | Should -Be 'Clean'
        Should -Invoke Invoke-ReleaseDefenderScan -Times 1 -Exactly
    }

    It 'blocks an invalid signature and preserves the actual status' {
        Mock Get-AuthenticodeSignature { [pscustomobject]@{ Status = 'HashMismatch'; SignerCertificate = $null } }
        { Test-ReleaseSecurity -Path $script:releaseFiles -ReportPath $script:reportFile } | Should -Throw '*invalid or unverifiable Authenticode signature*'
        (Get-Content -LiteralPath $script:reportFile -Raw | ConvertFrom-Json).Files[0].AuthenticodeStatus | Should -Be 'HashMismatch'
        Should -Invoke Invoke-ReleaseDefenderScan -Times 0
    }

    It 'blocks changes made to an artifact during scanning' {
        Mock Invoke-ReleaseDefenderScan {
            param($ScannerPath, $FilePath)
            Add-Content -LiteralPath $FilePath -Value 'changed'
            [pscustomobject]@{ ExitCode = 0; Output = 'completed' }
        }
        { Test-ReleaseSecurity -Path $script:releaseFiles -ReportPath $script:reportFile } | Should -Throw '*changed during scanning*'
        (Get-Content -LiteralPath $script:reportFile -Raw | ConvertFrom-Json).Result | Should -Be 'Blocked'
    }

    It 'rejects changes after scanning before release attachments can be published' {
        Test-ReleaseSecurity -Path $script:releaseFiles -ReportPath $script:reportFile
        Add-Content -LiteralPath $script:releaseFiles[0] -Value 'changed after scan'
        { Assert-ReleaseSecurityReport -Path $script:releaseFiles -ReportPath $script:reportFile } | Should -Throw '*changed after scanning*'
    }

    It 'rejects a release list that omits an artifact or repeats a name' {
        Test-ReleaseSecurity -Path $script:releaseFiles -ReportPath $script:reportFile
        { Assert-ReleaseSecurityReport -Path @($script:releaseFiles[0]) -ReportPath $script:reportFile } | Should -Throw '*differs from the scanned list*'
        { Assert-ReleaseSecurityReport -Path @($script:releaseFiles[0], $script:releaseFiles[0]) -ReportPath $script:reportFile } | Should -Throw '*must be unique*'
    }

    It 'never overwrites an artifact with its own scan report' {
        $hash = (Get-FileHash -LiteralPath $script:releaseFiles[0]).Hash
        { Test-ReleaseSecurity -Path $script:releaseFiles -ReportPath $script:releaseFiles[0] } | Should -Throw '*cannot overwrite a release artifact*'
        (Get-FileHash -LiteralPath $script:releaseFiles[0]).Hash | Should -Be $hash
    }
}
