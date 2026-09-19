BeforeAll {
    $script:startupPath = Join-Path $PSScriptRoot '../scripts/start.ps1'
    $script:startupSource = [IO.File]::ReadAllText($script:startupPath)
    $parseErrors = $null
    $script:startupAst = [Management.Automation.Language.Parser]::ParseInput($script:startupSource, [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count) { throw ($parseErrors | Out-String) }

    # Exercise only the nonadministrator branch. Never run the app, the identity
    # check, WPF loading, logging, or an elevated process during this suite.
    $relaunch = $script:startupAst.EndBlock.Statements | Where-Object {
        $_ -is [Management.Automation.Language.IfStatementAst] -and
        $_.Clauses[0].Item1.Extent.Text -match 'WindowsPrincipal'
    }
    if (@($relaunch).Count -ne 1) { throw 'Expected exactly one startup elevation branch.' }
    $body = $relaunch.Clauses[0].Item2.Extent.Text
    $script:startupBranch = [scriptblock]::Create(@'
param($InvocationPath, $InvocationParameters)
$PSCommandPath = $InvocationPath
$PSBoundParameters = $InvocationParameters
'@ + $body.Substring(1, $body.Length - 2))

    function Invoke-StartupBranch {
        param([string]$Path = 'C:\WinUtil CN\winutil-cn.ps1', [hashtable]$Parameters = @{})
        & $script:startupBranch $Path $Parameters | Out-Null
    }
}

Describe 'Local-only administrator startup' {
    BeforeEach {
        $script:lastLaunch = $null
        Mock Write-Warning {}
        Mock Start-Process {
            $script:lastLaunch = [pscustomobject]@{
                FilePath = $FilePath
                ArgumentList = [string]$ArgumentList
                Verb = $Verb
            }
        }
    }

    It 'returns with instructions for inline scripts without starting a process' {
        Invoke-StartupBranch -Path ''
        Should -Invoke Start-Process -Times 0 -Exactly
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match '下载本地版' }
    }

    It 'launches the current host by absolute path with a local file' {
        Invoke-StartupBranch
        $expectedName = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
        $script:lastLaunch.FilePath | Should -Be (Join-Path $PSHOME $expectedName)
        $script:lastLaunch.Verb | Should -Be 'RunAs'
        $script:lastLaunch.ArgumentList | Should -Be '-NoProfile -ExecutionPolicy RemoteSigned -File "C:\WinUtil CN\winutil-cn.ps1"'
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $ErrorAction -eq 'Stop' }
    }

    It 'does not forward an explicitly false switch' {
        Invoke-StartupBranch -Parameters @{ Offline = [System.Management.Automation.SwitchParameter]::new($false) }
        $script:lastLaunch.ArgumentList | Should -Not -Match '(?i)-Offline'
    }

    It 'handles a cancelled or failed elevation request without entering the app' {
        Mock Start-Process { throw 'UAC cancelled' }
        { Invoke-StartupBranch } | Should -Not -Throw
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match 'UAC cancelled' }
    }

    It 'does not use downloaded commands or bypass execution policies during relaunch' {
        $script:startupBranch.ToString() | Should -Not -Match '(?i)\b(Bypass|Invoke-Expression|Invoke-RestMethod|Invoke-WebRequest|irm|iex|iwr|EncodedCommand|Set-ExecutionPolicy)\b|-(?:Command|EncodedCommand)\b'
    }
}

Describe 'Startup arguments across Windows PowerShell and PowerShell 7' {
    BeforeAll {
        $script:argumentFixture = Join-Path $TestDrive "本地 WinUtil's fixture.ps1"
        [IO.File]::WriteAllText($script:argumentFixture, @'
param([string]$Config, [string]$Preset, [switch]$Offline)
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
[pscustomobject]@{ Config = $Config; Preset = $Preset; Offline = [bool]$Offline; ExtraArguments = @($args) } | ConvertTo-Json -Compress
'@, [Text.UTF8Encoding]::new($true))
        $script:availableHosts = @('powershell.exe', 'pwsh.exe') | ForEach-Object {
            $command = Get-Command $_ -ErrorAction SilentlyContinue
            if ($command) { $command.Source }
        }
        if (-not $script:availableHosts) { throw 'No Windows PowerShell host is available for the argument round trip.' }
    }

    BeforeEach {
        $script:capturedArguments = $null
        Mock Start-Process { $script:capturedArguments = [string]$ArgumentList }
    }

    It 'preserves <Label> as literal data through -File' -TestCases @(
        @{ Label = 'spaces, Chinese characters, and apostrophes'; Value = "C:\配置 文件\O'Brien.json" }
        @{ Label = 'PowerShell metacharacters'; Value = 'value;$(throw "must stay data") & echo literal' }
        @{ Label = 'double quotes and backslashes'; Value = 'C:\folder\"quoted"\' }
        @{ Label = 'trailing backslashes'; Value = 'C:\folder with space\\' }
        @{ Label = 'an empty value'; Value = '' }
        @{ Label = 'a leading hyphen'; Value = '-NoProfile' }
    ) {
        param($Label, $Value)
        Invoke-StartupBranch -Path $script:argumentFixture -Parameters @{ Config = $Value; Preset = 'Minimal'; Offline = $true }
        foreach ($hostPath in $script:availableHosts) {
            # Run a tiny echo fixture, never the application or the mocked RunAs
            # request. Direct ProcessStartInfo avoids Pester's Start-Process mock.
            $info = New-Object System.Diagnostics.ProcessStartInfo
            $info.FileName = $hostPath
            $info.Arguments = $script:capturedArguments
            $info.UseShellExecute = $false
            $info.CreateNoWindow = $true
            $info.RedirectStandardOutput = $true
            $info.RedirectStandardError = $true
            $info.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
            $process = [Diagnostics.Process]::Start($info)
            try {
                $completed = $process.WaitForExit(30000)
                if (-not $completed) { $process.Kill() }
                $completed | Should -BeTrue -Because "$hostPath should finish the harmless argument echo"
                $output = $process.StandardOutput.ReadToEnd()
                $errors = $process.StandardError.ReadToEnd()
                $process.ExitCode | Should -Be 0 -Because "$hostPath returned: $errors"
                $result = $output | ConvertFrom-Json
                $result.Config | Should -BeExactly $Value -Because "$hostPath must preserve Config"
                $result.Preset | Should -BeExactly 'Minimal'
                $result.Offline | Should -BeTrue
                @($result.ExtraArguments).Count | Should -Be 0
            } finally {
                $process.Dispose()
            }
        }
    }
}
