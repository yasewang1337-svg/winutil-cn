BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    foreach ($name in @('Invoke-WinUtilInventoryQuery', 'ConvertFrom-WinUtilInventoryData', 'Get-WinUtilInventoryMatches', 'Get-WinUtilInstalledInventory', 'Invoke-WinUtilCurrentSystem')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root "functions/private/$name.ps1"), [Text.Encoding]::UTF8)))
    }
    function New-TestInventoryExport {
        param([object[]]$Packages = @([pscustomobject]@{ PackageIdentifier = 'Vendor.Editor'; Version = '1.2' }))
        [ordered]@{
            Sources = @([ordered]@{
                SourceDetails = @{ Name = 'winget'; Identifier = 'Microsoft.Winget.Source_8wekyb3d8bbwe'; Type = 'Microsoft.PreIndexed.Package'; Argument = 'https://cdn.winget.microsoft.com/cache' }
                Packages = $Packages
            })
        } | ConvertTo-Json -Depth 8
    }
}

Describe 'Machine-readable inventory validation' {
    It 'reads exact WinGet identifiers and versions without relying on console tables or language' {
        $text = New-TestInventoryExport -Packages @(
            @{ PackageIdentifier = 'Tencent.WeChat'; Version = '4.1.2' },
            @{ PackageIdentifier = 'Very.Long.Application.Identifier'; Version = 'Unknown' },
            @{ PackageIdentifier = 'Vendor.NoVersion' },
            @{ PackageIdentifier = '示例.编辑器'; Version = '1.0' }
        )
        $rows = @(ConvertFrom-WinUtilInventoryData -Manager Winget -Text $text)
        $rows.Count | Should -Be 4
        $rows[0].Id | Should -Be 'Tencent.WeChat'
        $rows[1].Id | Should -Be 'Very.Long.Application.Identifier'
        $rows[1].Version | Should -Be 'Unknown'
        $rows[2].Version | Should -Be ''
        $rows[3].Id | Should -Be '示例.编辑器'
        @($rows.Manager | Select-Object -Unique) | Should -Be @('Winget')
    }
    It 'accepts a valid empty WinGet export but rejects missing, null or incorrectly typed Sources' {
        @(ConvertFrom-WinUtilInventoryData -Manager Winget -Text '{"Sources":[]}').Count | Should -Be 0
        foreach ($text in @('', '{}', 'null', '[]', '{"Sources":null}', '{"Sources":{}}', '{"Sources":[')) {
            { ConvertFrom-WinUtilInventoryData -Manager Winget -Text $text } | Should -Throw
        }
    }
    It 'rejects an unexpected source even when its packages look valid' {
        foreach ($property in @('Name', 'Identifier', 'Type')) {
            $document = New-TestInventoryExport | ConvertFrom-Json
            $document.Sources[0].SourceDetails.$property = 'other-source'
            { ConvertFrom-WinUtilInventoryData -Manager Winget -Text ($document | ConvertTo-Json -Depth 8) } | Should -Throw '*来源*'
        }
    }
    It 'rejects malformed package arrays, IDs and versions rather than accepting a partial inventory' {
        foreach ($badPackage in @(@{ PackageIdentifier = 'Vendor…' }, @{ PackageIdentifier = '--switch' }, @{ PackageIdentifier = 'all apps' }, @{ PackageIdentifier = 'Vendor.App'; Version = 42 }, $null)) {
            $text = New-TestInventoryExport -Packages @(@{ PackageIdentifier = 'Good.App'; Version = '1' }, $badPackage)
            { ConvertFrom-WinUtilInventoryData -Manager Winget -Text $text } | Should -Throw
        }
        $document = New-TestInventoryExport | ConvertFrom-Json
        $document.Sources[0].Packages = $null
        { ConvertFrom-WinUtilInventoryData -Manager Winget -Text ($document | ConvertTo-Json -Depth 8) } | Should -Throw '*Packages*'
    }
    It 'deduplicates identical rows while preserving parallel installed versions' {
        $text = New-TestInventoryExport -Packages @(@{ PackageIdentifier = 'Vendor.App'; Version = '1' }, @{ PackageIdentifier = 'vendor.app'; Version = '1' })
        @(ConvertFrom-WinUtilInventoryData -Manager Winget -Text $text).Count | Should -Be 1
        $parallel = New-TestInventoryExport -Packages @(@{ PackageIdentifier = 'Vendor.App'; Version = '1' }, @{ PackageIdentifier = 'Vendor.App'; Version = '2' })
        @(ConvertFrom-WinUtilInventoryData -Manager Winget -Text $parallel).Version | Should -Be @('1', '2')
        @(ConvertFrom-WinUtilInventoryData -Manager Choco -Text "git|1`ngit|2").Count | Should -Be 2
    }
    It 'reads Chocolatey machine output and accepts an explicitly empty list' {
        $rows = @(ConvertFrom-WinUtilInventoryData -Manager Choco -Text "git|2.51.0`r`ngithub-desktop|3.5.1`r`n")
        $rows.Count | Should -Be 2
        $rows[1].Id | Should -Be 'github-desktop'
        $rows[1].Manager | Should -Be 'Choco'
        @(ConvertFrom-WinUtilInventoryData -Manager Choco -Text '').Count | Should -Be 0
    }
    It 'rejects Chocolatey human output, warnings and truncated rows' {
        foreach ($text in @('Chocolatey v2.5.0', 'git 2.51.0', 'git|', 'git|1|extra', "git|1`nAccess denied")) {
            { ConvertFrom-WinUtilInventoryData -Manager Choco -Text $text } | Should -Throw '*无法识别*'
        }
    }
}

Describe 'Catalog inventory matching' {
    BeforeEach {
        $script:catalog = @{
            WPFInstallgit = @{ choco = 'git'; winget = 'Git.Git' }
            WPFInstalldesktop = @{ choco = 'git; github-desktop'; winget = 'Git.Git;GitHub.GitHubDesktop' }
            WPFInstallunavailable = @{ choco = 'na'; winget = 'Vendor.App' }
            WPFInstallblank = @{ choco = ''; winget = '' }
            WPFInstallbroken = @{ choco = 'git;'; winget = 'Git.Git;' }
            OtherGroup = @{ choco = 'git'; winget = 'Git.Git' }
        }
    }
    It 'matches a combination only when all dependencies are installed' {
        $both = @(ConvertFrom-WinUtilInventoryData Choco "git|2.51.0`ngithub-desktop|3.5.1")
        @(Get-WinUtilInventoryMatches -Manager Choco -Programs $both -Applications $catalog) | Should -Be @('WPFInstalldesktop', 'WPFInstallgit')
        $dependency = @(ConvertFrom-WinUtilInventoryData Choco 'git|2.51.0')
        @(Get-WinUtilInventoryMatches -Manager Choco -Programs $dependency -Applications $catalog) | Should -Be @('WPFInstallgit')
        $mainOnly = @(ConvertFrom-WinUtilInventoryData Choco 'github-desktop|3.5.1')
        @(Get-WinUtilInventoryMatches -Manager Choco -Programs $mainOnly -Applications $catalog).Count | Should -Be 0
    }
    It 'does not mix source identities or mistake a missing catalog ID for installed' {
        $rows = @([pscustomobject]@{ Id = 'git'; Manager = 'Winget'; Version = '1' })
        @(Get-WinUtilInventoryMatches -Manager Choco -Programs $rows -Applications $catalog).Count | Should -Be 0
        @(Get-WinUtilInventoryMatches -Manager Winget -Programs @() -Applications ([pscustomobject]$catalog)).Count | Should -Be 0
    }
}

Describe 'Read-only inventory query orchestration' {
    BeforeEach {
        $script:sync = [hashtable]::Synchronized(@{
            configs = @{ applicationsHashtable = @{ WPFInstallEditor = @{ winget = 'Vendor.Editor'; choco = 'editor' } }; applications = @{ WPFInstallWrong = @{ winget = 'Vendor.Editor' } } }
            SoftwareInventory = [pscustomobject]@{ Manager = 'Winget'; PackageCount = 1; CompletedAt = [datetime]::Now.AddDays(-1) }
            InstalledPrograms = @([pscustomobject]@{ Id = 'Old.App'; Version = '9'; Manager = 'Winget' })
        })
        $script:queryExit = 0
        $script:queryTimeout = $false
        $script:queryError = ''
        $script:queryOutput = 'fixture stdout'
        $script:exportText = New-TestInventoryExport
        $script:exportPath = $null
        $script:writeExport = $true
        $script:chocoVersion = '2.5.0'
        $script:chocoText = 'editor|1.2'
        Mock Invoke-WinUtilInventoryQuery {
            if ($FilePath -eq 'winget.exe') {
                $script:exportPath = $Arguments[[array]::IndexOf($Arguments, '--output') + 1]
                if ($script:writeExport) { [IO.File]::WriteAllText($script:exportPath, $script:exportText, [Text.UTF8Encoding]::new($false)) }
                return [pscustomobject]@{ ExitCode = $script:queryExit; StandardOutput = $script:queryOutput; StandardError = $script:queryError; TimedOut = $script:queryTimeout }
            }
            $output = if ($Arguments[0] -eq '--version') { $script:chocoVersion } else { $script:chocoText }
            [pscustomobject]@{ ExitCode = $script:queryExit; StandardOutput = $output; StandardError = $script:queryError; TimedOut = $script:queryTimeout }
        }
        Mock Start-Process { throw 'Real package commands are forbidden.' }
    }
    It 'exports only the official source without interactive prompts and removes its temporary file' {
        $inventory = Get-WinUtilInstalledInventory -Manager Winget
        $inventory.Manager | Should -Be 'Winget'
        $inventory.PackageCount | Should -Be 1
        $inventory.MatchedKeys | Should -Be @('WPFInstallEditor')
        $inventory.CompletedAt | Should -BeOfType ([datetime])
        $inventory.Diagnostics[0].StandardOutput | Should -Be 'fixture stdout'
        Test-Path -LiteralPath $script:exportPath | Should -BeFalse
        Should -Invoke Invoke-WinUtilInventoryQuery -Times 1 -Exactly -ParameterFilter {
            $Arguments[0] -eq 'export' -and '--include-versions' -in $Arguments -and
            '--disable-interactivity' -in $Arguments -and '--accept-source-agreements' -in $Arguments -and
            $Arguments[[array]::IndexOf($Arguments, '--source') + 1] -eq 'winget'
        }
        $sync.InstalledPrograms[0].Id | Should -Be 'Old.App'
    }
    It 'rejects nonzero exit codes and retains both output streams as evidence' {
        $script:queryExit = 5; $script:queryError = 'Access denied'
        $caught = $null
        try { Get-WinUtilInstalledInventory -Manager Winget } catch { $caught = $_ }
        $caught.Exception.Message | Should -Match '退出码 5'
        $caught.Exception.Data['StandardOutput'] | Should -Be 'fixture stdout'
        $caught.Exception.Data['StandardError'] | Should -Be 'Access denied'
        Test-Path -LiteralPath $script:exportPath | Should -BeFalse
    }
    It 'rejects timed out, missing and malformed exports and cleans up on each failure' {
        $script:queryTimeout = $true
        { Get-WinUtilInstalledInventory -Manager Winget -TimeoutSeconds 3 } | Should -Throw '*超过 3 秒*'
        Test-Path -LiteralPath $script:exportPath | Should -BeFalse
        $script:queryTimeout = $false; $script:writeExport = $false
        { Get-WinUtilInstalledInventory -Manager Winget } | Should -Throw '*未生成*'
        $script:writeExport = $true; $script:exportText = '{"Sources":['
        { Get-WinUtilInstalledInventory -Manager Winget } | Should -Throw '*JSON*'
        Test-Path -LiteralPath $script:exportPath | Should -BeFalse
    }
    It 'checks Chocolatey 2+ before querying the local-only list' {
        $inventory = Get-WinUtilInstalledInventory -Manager Choco
        $inventory.Programs[0].Id | Should -Be 'editor'
        $inventory.MatchedKeys | Should -Be @('WPFInstallEditor')
        Should -Invoke Invoke-WinUtilInventoryQuery -Times 1 -Exactly -ParameterFilter { $Arguments[0] -eq '--version' }
        Should -Invoke Invoke-WinUtilInventoryQuery -Times 1 -Exactly -ParameterFilter {
            $Arguments[0] -eq 'list' -and '--limit-output' -in $Arguments -and '--no-color' -in $Arguments -and '--local-only' -notin $Arguments
        }
    }
    It 'never invokes list for Chocolatey 1.x or unrecognized versions' {
        foreach ($version in @('1.4.0', '0.12.1', 'Chocolatey v2.5.0', 'bad-version')) {
            $script:chocoVersion = $version
            { Get-WinUtilInstalledInventory -Manager Choco } | Should -Throw
        }
        Should -Invoke Invoke-WinUtilInventoryQuery -Times 0 -Exactly -ParameterFilter { $Arguments[0] -eq 'list' }
    }
    It 'distinguishes Chocolatey enhanced no-results from failures with output' {
        Mock Invoke-WinUtilInventoryQuery {
            if ($Arguments[0] -eq '--version') { return [pscustomobject]@{ ExitCode = 0; StandardOutput = '2.5.0'; StandardError = ''; TimedOut = $false } }
            [pscustomobject]@{ ExitCode = 2; StandardOutput = $script:chocoText; StandardError = $script:queryError; TimedOut = $false }
        }
        $script:chocoText = ''
        (Get-WinUtilInstalledInventory -Manager Choco).PackageCount | Should -Be 0
        $script:queryError = 'failed metadata read'
        { Get-WinUtilInstalledInventory -Manager Choco } | Should -Throw '*退出码 2*'
    }
    It 'publishes a complete inventory and compatibility cache only after successful validation' {
        @(Invoke-WinUtilCurrentSystem -CheckBox winget) | Should -Be @('WPFInstallEditor')
        $sync.SoftwareInventory.PackageCount | Should -Be 1
        $sync.InstalledPrograms[0].Id | Should -Be 'Vendor.Editor'
        $sync.InstalledPrograms[0].Manager | Should -Be 'Winget'
        $beforeInventory = $sync.SoftwareInventory
        $beforePrograms = $sync.InstalledPrograms
        $script:queryExit = 5
        { Invoke-WinUtilCurrentSystem -CheckBox winget } | Should -Throw
        [object]::ReferenceEquals($sync.SoftwareInventory, $beforeInventory) | Should -BeTrue
        [object]::ReferenceEquals($sync.InstalledPrograms, $beforePrograms) | Should -BeTrue
    }
}

Describe 'Bounded native query transport without package or system changes' {
    It 'captures a harmless child failure and both streams, including Unicode and quoted text' {
        $result = Invoke-WinUtilInventoryQuery -FilePath powershell.exe -Arguments @(
            '-NoProfile', '-NonInteractive', '-Command',
            '[Console]::OutputEncoding=[Text.Encoding]::UTF8; [Console]::Out.WriteLine(''中文 "quoted" C:\path with spaces\''); [Console]::Error.WriteLine(''stderr-evidence''); exit 23'
        )
        $result.ExitCode | Should -Be 23
        $result.StandardOutput | Should -Match '中文 "quoted" C:\\path with spaces\\'
        $result.StandardError | Should -Match 'stderr-evidence'
        $result.TimedOut | Should -BeFalse
    }
    It 'stops only its harmless waiting child within a finite deadline and retains early output' {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $result = Invoke-WinUtilInventoryQuery -FilePath powershell.exe -TimeoutSeconds 1 -Arguments @(
            '-NoProfile', '-NonInteractive', '-Command', '[Console]::Out.WriteLine(''before-timeout''); [Threading.Thread]::Sleep(30000)'
        )
        $watch.Stop()
        $result.TimedOut | Should -BeTrue
        $result.StandardOutput | Should -Match 'before-timeout'
        $watch.Elapsed.TotalSeconds | Should -BeLessThan 12
    }
    It 'returns an actionable error for a nonexistent manager executable' {
        { Invoke-WinUtilInventoryQuery -FilePath 'winutil-fixture-never-exists.exe' -Arguments @('--version') } | Should -Throw '*找不到*'
    }
}
