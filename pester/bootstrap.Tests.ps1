BeforeAll {
    $script:bootstrapRoot = Split-Path $PSScriptRoot -Parent
    foreach ($name in @(
        'Install-WinUtilChoco', 'Test-WinUtilPackageManager', 'Invoke-WinUtilInstallPSProfile',
        'Invoke-WinUtilPackageOperation', 'Invoke-WinUtilPackageBatch', 'Get-WinUtilPackagePlan',
        'Get-WinUtilPackageExitResult', 'Install-WinUtilWinget', 'Install-WinUtilProgramWinget',
        'Install-WinUtilProgramChoco', 'Show-WinUtilPackageDialog'
    )) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:bootstrapRoot "functions/private/$name.ps1"))))
    }
    # Guard old dependency-launch paths too: no regression may run native tools.
    function winget { throw 'Tests must not run winget.' }
    function wt { throw 'Tests must not run Windows Terminal.' }
    function pwsh { throw 'Tests must not launch PowerShell.' }
    function Initialize-WinUtilPackageUiCallbacks { throw 'Tests must not initialize UI callbacks.' }
    function Invoke-WPFRunspace { throw 'Tests must not dispatch application work.' }
}

Describe 'Optional bootstrap entry points' {
    BeforeEach {
        Mock Invoke-WebRequest { throw 'Tests must not download remote content.' }
        Mock Invoke-RestMethod { throw 'Tests must not download remote content.' }
        Mock Invoke-Expression { throw 'Tests must not execute command text.' }
        Mock Start-Process {}
        Mock Install-WinUtilWinget { throw 'Tests must not install dependencies.' }
        Mock Test-WinUtilPackageManager { 'not-installed' }
    }

    It 'keeps an existing Chocolatey installation usable without side effects' {
        Mock Test-WinUtilPackageManager { 'installed' }
        { Install-WinUtilChoco } | Should -Not -Throw
        Should -Invoke Test-WinUtilPackageManager -Times 1 -Exactly -ParameterFilter { $choco }
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        Should -Invoke Invoke-Expression -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'reports missing Chocolatey with manual instructions and never opens repeated browser tabs' {
        1..2 | ForEach-Object {
            { Install-WinUtilChoco } | Should -Throw '*手动安装*https://chocolatey.org/install*WinGet*'
        }
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        Should -Invoke Invoke-Expression -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
        Should -Invoke Install-WinUtilWinget -Times 0 -Exactly
    }

    It 'opens only the official PowerShell profile guide' {
        Invoke-WinUtilInstallPSProfile
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'https://github.com/ChrisTitusTech/powershell-profile' -and
            -not $ArgumentList -and $ErrorAction -eq 'Stop'
        }
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        Should -Invoke Invoke-Expression -Times 0 -Exactly
        Should -Invoke Install-WinUtilWinget -Times 0 -Exactly
    }

    It 'keeps the guide address available when opening the browser fails' {
        Mock Start-Process { throw 'No browser association' }
        { Invoke-WinUtilInstallPSProfile } | Should -Throw '*手动访问*https://github.com/ChrisTitusTech/powershell-profile*No browser association*'
    }

    It 'labels the profile button and its translation as a guide' {
        $features = Get-Content (Join-Path $script:bootstrapRoot 'config/feature.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $translations = Get-Content (Join-Path $script:bootstrapRoot '汉化/i18n-borrowed.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $entry = $features.WPFWinUtilInstallPSProfile
        $entry.Content | Should -Be '查看 CTT PowerShell 配置指南'
        $entry.Description | Should -Match '打开.*官方项目指南'
        $entry.link | Should -Be 'https://github.com/ChrisTitusTech/powershell-profile'
        $translations.feature.WPFWinUtilInstallPSProfile.Content | Should -Be $entry.Content
        $translations.feature.WPFWinUtilInstallPSProfile.Description | Should -Be $entry.Description
    }
}

Describe 'Missing optional manager in software plans' {
    BeforeEach {
        Mock Write-Host {}
        Mock Invoke-WebRequest { throw 'Tests must not download remote content.' }
        Mock Invoke-RestMethod { throw 'Tests must not download remote content.' }
        Mock Invoke-Expression { throw 'Tests must not execute command text.' }
        Mock Start-Process { throw 'Tests must not start native processes or browsers.' }
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'choco.exe' }
        Mock Get-Command { [pscustomobject]@{ Source = 'simulated-winget.exe' } } -ParameterFilter { $Name -eq 'winget.exe' }
        Mock Test-WinUtilPackageManager { 'not-installed' }
        Mock Install-WinUtilWinget { throw 'Tests must not install a manager.' }
        Mock Install-WinUtilProgramChoco { throw 'Tests must not run Chocolatey.' }
        Mock Install-WinUtilProgramWinget { [pscustomobject]@{ ExitCode = 0; OutputPath = ''; ErrorPath = '' } }
        $script:bootstrapPlan = @(Get-WinUtilPackagePlan -Preference Choco -Packages @(
            [pscustomobject]@{ content = 'First Chocolatey app'; winget = 'Example.First'; choco = 'first-app' },
            [pscustomobject]@{ content = 'WinGet app'; winget = 'Example.Winget'; choco = 'na' },
            [pscustomobject]@{ content = 'Second Chocolatey app'; winget = 'Example.Second'; choco = 'second-app' }
        ))
    }

    It 'fails only Chocolatey items and continues the available WinGet item' {
        $batch = Invoke-WinUtilPackageBatch -Plan $script:bootstrapPlan -PrepareManagers -LogRoot $TestDrive
        ($batch.Results.Status -join ',') | Should -Be 'Failed,Succeeded,Failed'
        $batch.Results[0].Reason | Should -Match '手动安装.*https://chocolatey.org/install.*WinGet'
        $batch.Results[2].Reason | Should -Be $batch.Results[0].Reason
        Should -Invoke Test-WinUtilPackageManager -Times 1 -Exactly -ParameterFilter { $choco }
        Should -Invoke Install-WinUtilProgramChoco -Times 0 -Exactly
        Should -Invoke Install-WinUtilProgramWinget -Times 1 -Exactly
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        Should -Invoke Invoke-Expression -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'explains manual Chocolatey installation separately from WinGet preparation before confirmation' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'winget.exe' }
        Mock Show-WinUtilPackageDialog { 'Close' }
        Mock Invoke-WinUtilPackageBatch { throw 'A cancelled plan must not run.' }
        $script:sync = @{ ProcessRunning = $false; form = [pscustomobject]@{} }
        Invoke-WinUtilPackageOperation -Plan $script:bootstrapPlan
        Should -Invoke Show-WinUtilPackageDialog -Times 1 -Exactly -ParameterFilter {
            $Description -match '首次使用将先联网准备 WinGet' -and
            $Description -match 'Chocolatey 未安装.*手动安装.*默认 WinGet' -and
            $Description -match '依赖 Chocolatey 的软件将报告失败'
        }
        Should -Invoke Invoke-WinUtilPackageBatch -Times 0 -Exactly
        Should -Invoke Install-WinUtilWinget -Times 0 -Exactly
        $script:sync.ProcessRunning | Should -BeFalse
    }
}
