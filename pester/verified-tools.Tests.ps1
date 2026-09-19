BeforeAll {
    $script:toolRoot = Split-Path $PSScriptRoot -Parent
    . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:toolRoot 'functions/private/Invoke-WinUtilVerifiedTool.ps1'))))
    Add-Type -AssemblyName System.IO.Compression
    function New-ToolArchiveFixture {
        param([string]$Path, [string[]]$Names = @('Albacore.ViVe.dll', 'FeatureDictionary.pfs', 'Newtonsoft.Json.dll', 'ViVeTool.exe'))
        $stream = [IO.File]::Open($Path, 'Create', 'ReadWrite', 'None')
        $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($name in $Names) {
                $entry = $zip.CreateEntry($name)
                $writer = [IO.StreamWriter]::new($entry.Open())
                try { $writer.Write('Harmless fixture: ' + $name) } finally { $writer.Dispose() }
            }
        } finally { $zip.Dispose(); $stream.Dispose() }
    }
}

Describe 'Verified third-party tool execution' {
    BeforeEach {
        $script:oldArchitecture = $env:PROCESSOR_ARCHITECTURE
        $script:oldWowArchitecture = $env:PROCESSOR_ARCHITEW6432
        $env:PROCESSOR_ARCHITECTURE = 'AMD64'
        $env:PROCESSOR_ARCHITEW6432 = ''
        $script:testToolRoot = $TestDrive
        $script:workspaces = [Collections.Generic.List[string]]::new()
        $script:fixtureZip = Join-Path $TestDrive 'fixture.zip'
        New-ToolArchiveFixture -Path $script:fixtureZip
        $script:signatureStatus = 'Valid'
        $script:publisher = 'O&O Software GmbH'
        $script:exitCode = 0
        Mock New-WinUtilToolWorkspace {
            $path = Join-Path $script:testToolRoot ('WinUtil-Tool-' + [guid]::NewGuid().ToString('N'))
            $null = New-Item -ItemType Directory -Path $path
            $script:workspaces.Add($path)
            $path
        }
        Mock Remove-WinUtilToolWorkspace {
            if ($Path -notin $script:workspaces) { throw 'Unexpected cleanup target' }
            # Only this test's known flat directory is removed; locked handles must already be closed.
            Get-ChildItem -LiteralPath $Path -File | Remove-Item -Force -ErrorAction Stop
            Remove-Item -LiteralPath $Path -ErrorAction Stop
        }
        Mock Invoke-WebRequest {
            if ($Uri -like '*ViVeTool*') { Copy-Item -LiteralPath $script:fixtureZip -Destination $OutFile }
            else { [IO.File]::WriteAllText($OutFile, 'Harmless O&O fixture') }
        }
        Mock Get-FileHash {
            # Only replace the release ZIP pin; extraction checks hash real fixture streams.
            if ($InputStream -is [IO.FileStream] -and $InputStream.Name.EndsWith('ViVeTool.zip')) {
                $hash = 'CC27F073F3FE5DD2C3D947FAF558FD4B2F8E34454F812689B0D65EE8A52E4147'
                if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
                    $hash = '30AD9A4912686355BFCE60E1D7BEF608735475B7E2160D67418EED8F5E3BA8C7'
                }
                [pscustomobject]@{ Hash = $hash }
            } else { $hasher = [Security.Cryptography.SHA256]::Create(); try { [pscustomobject]@{ Hash = ([BitConverter]::ToString($hasher.ComputeHash($InputStream))).Replace('-', '') } } finally { $hasher.Dispose() } }
        }
        Mock Get-AuthenticodeSignature {
            $certificate = [pscustomobject]@{ Publisher = $script:publisher }
            $certificate | Add-Member -MemberType ScriptMethod -Name GetNameInfo -Value { param($type, $issuer) $this.Publisher }
            [pscustomobject]@{ Status = $script:signatureStatus; SignerCertificate = $certificate }
        }
        Mock Start-Process {
            if ($RedirectStandardOutput) {
                [IO.File]::WriteAllText($RedirectStandardOutput, "ViVeTool v0.3.4 - Windows feature configuration tool`r`nSuccessfully set feature configuration(s)`r`n")
                [IO.File]::WriteAllText($RedirectStandardError, '')
            }
            [pscustomobject]@{ ExitCode = $script:exitCode }
        }
    }

    AfterEach {
        $env:PROCESSOR_ARCHITECTURE = $script:oldArchitecture
        $env:PROCESSOR_ARCHITEW6432 = $script:oldWowArchitecture
    }

    It 'verifies and locks every ViVe file until process completion, then removes only its own workspace' {
        Mock Start-Process {
            $files = @(Get-ChildItem -LiteralPath $WorkingDirectory -File)
            $files.Count | Should -Be 5
            foreach ($file in $files) {
                { [IO.File]::WriteAllText($file.FullName, 'tamper') } | Should -Throw
                { [IO.File]::Move($file.FullName, $file.FullName + '.moved') } | Should -Throw
                { [IO.File]::Delete($file.FullName) } | Should -Throw
                [IO.File]::ReadAllBytes($file.FullName).Length | Should -BeGreaterThan 0
            }
            [IO.File]::WriteAllText($RedirectStandardOutput, "ViVeTool v0.3.4 - Windows feature configuration tool`r`nSuccessfully set feature configuration(s)`r`n")
            [IO.File]::WriteAllText($RedirectStandardError, '')
            [pscustomobject]@{ ExitCode = 0 }
        }
        $result = Invoke-WinUtilVerifiedTool -Tool ViVeTool -Action Disable
        $result.ExitCode | Should -Be 0
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $Wait -and $PassThru -and $NoNewWindow -and $ErrorAction -eq 'Stop' -and
            ($ArgumentList -join ' ') -eq '/disable /id:47205210' -and
            [IO.Path]::IsPathRooted($FilePath) -and (Split-Path $FilePath) -eq $WorkingDirectory
        }
        Test-Path -LiteralPath $script:workspaces[0] | Should -BeFalse
    }

    It 'uses a distinct directory every time and leaves stale tool files untouched' {
        $stale = Join-Path $TestDrive 'ooshutup10.exe'
        [IO.File]::WriteAllText($stale, 'old file')
        $null = Invoke-WinUtilVerifiedTool -Tool OOSU
        $null = Invoke-WinUtilVerifiedTool -Tool OOSU
        $script:workspaces[0] | Should -Not -Be $script:workspaces[1]
        [IO.File]::ReadAllText($stale) | Should -Be 'old file'
        foreach ($path in $script:workspaces) { Test-Path -LiteralPath $path | Should -BeFalse }
    }

    It 'holds the O&O file lock during signature verification and execution' {
        Mock Get-AuthenticodeSignature {
            { [IO.File]::WriteAllText($LiteralPath, 'tamper') } | Should -Throw
            $cert = [pscustomobject]@{}
            $cert | Add-Member ScriptMethod GetNameInfo { 'O&O Software GmbH' }
            [pscustomobject]@{ Status = 'Valid'; SignerCertificate = $cert }
        }
        Mock Start-Process {
            { [IO.File]::Delete($FilePath) } | Should -Throw
            [pscustomobject]@{ ExitCode = 0 }
        }
        $null = Invoke-WinUtilVerifiedTool -Tool OOSU
        Should -Invoke Get-AuthenticodeSignature -Times 1 -Exactly
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $Wait -and $PassThru -and -not $ArgumentList }
    }

    It 'stops after a nonterminating download error for <Tool>' -ForEach @(@{ Tool = 'OOSU' }, @{ Tool = 'ViVeTool' }) {
        Mock Invoke-WebRequest { Write-Error 'fixture download failed' }
        { Invoke-WinUtilVerifiedTool -Tool $Tool } | Should -Throw '*下载*fixture download failed*'
        Should -Invoke Start-Process -Times 0 -Exactly
        Should -Invoke Get-AuthenticodeSignature -Times 0 -Exactly
        Test-Path -LiteralPath $script:workspaces[0] | Should -BeFalse
    }

    It 'rejects a changed archive before extraction or execution' {
        Mock Get-FileHash { [pscustomobject]@{ Hash = 'INVALID' } }
        { Invoke-WinUtilVerifiedTool -Tool ViVeTool } | Should -Throw '*可信哈希不符*'
        Should -Invoke Start-Process -Times 0 -Exactly
        Test-Path -LiteralPath $script:workspaces[0] | Should -BeFalse
    }

    It 'stops when extraction cannot open the archive' {
        [IO.File]::WriteAllText($script:fixtureZip, 'not a ZIP')
        { Invoke-WinUtilVerifiedTool -Tool ViVeTool } | Should -Throw '*解压*失败*'
        Should -Invoke Start-Process -Times 0 -Exactly
        Test-Path -LiteralPath $script:workspaces[0] | Should -BeFalse
    }

    It 'rejects archive traversal entries without writing outside its directory' {
        New-ToolArchiveFixture -Path $script:fixtureZip -Names @('../outside.exe', 'FeatureDictionary.pfs', 'Newtonsoft.Json.dll', 'ViVeTool.exe')
        { Invoke-WinUtilVerifiedTool -Tool ViVeTool } | Should -Throw '*异常文件*'
        Should -Invoke Start-Process -Times 0 -Exactly
        Test-Path (Join-Path $TestDrive 'outside.exe') | Should -BeFalse
    }

    It 'rejects extracted bytes differing from the verified ZIP entry' {
        Mock Get-FileHash { [pscustomobject]@{ Hash = 'CHANGED' } } -ParameterFilter {
            $InputStream -is [IO.FileStream] -and $InputStream.Name.EndsWith('.dll')
        }
        { Invoke-WinUtilVerifiedTool -Tool ViVeTool } | Should -Throw '*解压后的文件校验失败*'
        Should -Invoke Start-Process -Times 0 -Exactly
        Test-Path -LiteralPath $script:workspaces[0] | Should -BeFalse
    }

    It 'rejects O&O signature status <Status>' -ForEach @(@{ Status = 'NotSigned' }, @{ Status = 'HashMismatch' }, @{ Status = 'UnknownError' }) {
        $script:signatureStatus = $Status
        { Invoke-WinUtilVerifiedTool -Tool OOSU } | Should -Throw '*数字签名无效*'
        Should -Invoke Start-Process -Times 0 -Exactly
        Test-Path -LiteralPath $script:workspaces[0] | Should -BeFalse
    }

    It 'rejects a valid signature from a different publisher' {
        $script:publisher = 'Unrelated Publisher'
        { Invoke-WinUtilVerifiedTool -Tool OOSU } | Should -Throw '*发布者不是 O&O Software GmbH*'
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'reports nonzero exit codes for <Tool> and releases all files' -ForEach @(@{ Tool = 'OOSU' }, @{ Tool = 'ViVeTool' }) {
        $script:exitCode = 19
        { Invoke-WinUtilVerifiedTool -Tool $Tool } | Should -Throw '*退出码：19*'
        Test-Path -LiteralPath $script:workspaces[0] | Should -BeFalse
    }

    It 'reports process launch failure instead of success and still cleans up' {
        Mock Start-Process { throw 'fixture launch failed' }
        { Invoke-WinUtilVerifiedTool -Tool OOSU } | Should -Throw '*运行*fixture launch failed*'
        Test-Path -LiteralPath $script:workspaces[0] | Should -BeFalse
    }

    It 'rejects a missing exit code' {
        Mock Start-Process { $null }
        { Invoke-WinUtilVerifiedTool -Tool ViVeTool } | Should -Throw '*未取得工具退出码*'
    }

    It 'rejects ViVe exit zero without its success marker' {
        Mock Start-Process {
            [IO.File]::WriteAllText($RedirectStandardOutput, 'An error occurred while setting feature configurations in the Boot store (Access is denied), configurations will revert after reboot')
            [IO.File]::WriteAllText($RedirectStandardError, '')
            [pscustomobject]@{ ExitCode = 0 }
        }
        { Invoke-WinUtilVerifiedTool -Tool ViVeTool } | Should -Throw '*未确认设置成功*Access is denied*'
        Test-Path -LiteralPath $script:workspaces[0] | Should -BeFalse
    }

    It 'rejects unexpected standard error even with the success marker' {
        Mock Start-Process {
            [IO.File]::WriteAllText($RedirectStandardOutput, "ViVeTool v0.3.4 - Windows feature configuration tool`r`nSuccessfully set feature configuration(s)`r`n")
            [IO.File]::WriteAllText($RedirectStandardError, 'Unexpected failure')
            [pscustomobject]@{ ExitCode = 0 }
        }
        { Invoke-WinUtilVerifiedTool -Tool ViVeTool } | Should -Throw '*未确认设置成功*Unexpected failure*'
    }

    It 'rejects stdout warnings even if ViVe prints its success marker and exits zero' {
        Mock Start-Process {
            [IO.File]::WriteAllText($RedirectStandardOutput, "ViVeTool v0.3.4 - Windows feature configuration tool`r`nAn error occurred while updating the last known good rollback data`r`nSuccessfully set feature configuration(s)`r`n")
            [IO.File]::WriteAllText($RedirectStandardError, '')
            [pscustomobject]@{ ExitCode = 0 }
        }
        { Invoke-WinUtilVerifiedTool -Tool ViVeTool } | Should -Throw '*未确认设置成功*last known good*'
    }

    It 'selects the pinned ARM64 archive under x64 emulation' {
        $env:PROCESSOR_ARCHITEW6432 = 'ARM64'
        $null = Invoke-WinUtilVerifiedTool -Tool ViVeTool -Action Enable
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*SnapdragonArm64.zip' -and $ErrorAction -eq 'Stop' }
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { ($ArgumentList -join ' ') -eq '/enable /id:47205210' }
    }

    It 'selects the O&O ARM64 download and still validates its publisher' {
        $env:PROCESSOR_ARCHITECTURE = 'ARM64'
        $null = Invoke-WinUtilVerifiedTool -Tool OOSU
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*OOSU10-arm64.exe' }
        Should -Invoke Get-AuthenticodeSignature -Times 1 -Exactly
    }

    It 'preserves caller progress preference after failure' {
        $ProgressPreference = 'Continue'
        Mock Invoke-WebRequest { throw 'fixture download failed' }
        { Invoke-WinUtilVerifiedTool -Tool OOSU } | Should -Throw
        $ProgressPreference | Should -Be 'Continue'
    }
}

Describe 'Tool workspace cleanup boundary' {
    It 'refuses to delete unrelated directories' {
        $keep = Join-Path $TestDrive 'keep.txt'
        [IO.File]::WriteAllText($keep, 'keep')
        { Remove-WinUtilToolWorkspace -Path $TestDrive } | Should -Throw '*不在允许清理的范围*'
        [IO.File]::ReadAllText($keep) | Should -Be 'keep'
    }
}
