BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $script:compatTweaks = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'config/tweaks.json')) | ConvertFrom-Json

    function Get-CompatibilityCommand {
        param([string]$Tweak, [string]$Phase, [string]$Name, [int]$Index = 0)
        $source = $script:compatTweaks.$Tweak.$Phase -join "`n"
        $tokens = $null
        $parseErrors = $null
        $ast = [Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors.Count) { throw "Invalid configured script: $Tweak / $Phase" }
        $commands = @($ast.FindAll({
            param($node)
            $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq $Name
        }, $true))
        if ($Index -ge $commands.Count) { throw "Missing command: $Tweak / $Phase / $Name / $Index" }
        $commands[$Index].Extent.Text
    }

    function Invoke-CompatibilityCommand {
        param([string]$Text)
        # Execute only the extracted command, never a complete uninstall or tweak script.
        # Local shims capture arguments before any native ACL or process operation can run.
        $calls = [Collections.Generic.List[object]]::new()
        function icacls {
            $calls.Add([pscustomobject]@{ Name = 'icacls'; Arguments = @($args) })
        }
        function Start-Process {
            param([string]$FilePath, [string[]]$ArgumentList, [switch]$Wait)
            $calls.Add([pscustomobject]@{ Name = 'Start-Process'; FilePath = $FilePath; Arguments = $ArgumentList; Wait = [bool]$Wait })
        }
        $RazerPath = 'C:\Windows\Installer\Razer'
        & ([scriptblock]::Create($Text))
        $calls.ToArray()
    }
}

Describe 'Upstream localized Windows compatibility' {
    BeforeEach {
        $script:savedCompatibilityEnvironment = @{
            LocalAppData = $env:LocalAppData
            OneDrive = $env:OneDrive
            SystemRoot = $env:SystemRoot
        }
        $env:LocalAppData = 'TestDrive:\用户 张三\AppData\Local'
        $env:OneDrive = 'TestDrive:\用户 张三\OneDrive 文档'
    }

    AfterEach {
        $env:LocalAppData = $script:savedCompatibilityEnvironment.LocalAppData
        $env:OneDrive = $script:savedCompatibilityEnvironment.OneDrive
        $env:SystemRoot = $script:savedCompatibilityEnvironment.SystemRoot
    }

    It 'passes a language-independent principal for <Tweak> <Phase> command <Index>' -ForEach @(
        @{ Tweak = 'WPFTweaksDisableStoreSearch'; Phase = 'InvokeScript'; Index = 0; Operation = '/deny'; Principal = '*S-1-1-0:F'; Target = 'Store' }
        @{ Tweak = 'WPFTweaksDisableStoreSearch'; Phase = 'UndoScript'; Index = 0; Operation = '/grant'; Principal = '*S-1-1-0:F'; Target = 'Store' }
        @{ Tweak = 'WPFTweaksRemoveOneDrive'; Phase = 'InvokeScript'; Index = 0; Operation = '/deny'; Principal = '*S-1-5-32-544:(D,DC)'; Target = 'OneDrive' }
        @{ Tweak = 'WPFTweaksRemoveOneDrive'; Phase = 'InvokeScript'; Index = 1; Operation = '/grant'; Principal = '*S-1-5-32-544:(D,DC)'; Target = 'OneDrive' }
        @{ Tweak = 'WPFTweaksRazerBlock'; Phase = 'InvokeScript'; Index = 0; Operation = '/deny'; Principal = '*S-1-1-0:(W)'; Target = 'Razer' }
        @{ Tweak = 'WPFTweaksRazerBlock'; Phase = 'UndoScript'; Index = 0; Operation = '/remove:d'; Principal = '*S-1-1-0'; Target = 'Razer' }
    ) {
        $command = Get-CompatibilityCommand -Tweak $Tweak -Phase $Phase -Name 'icacls' -Index $Index
        $actual = @(Invoke-CompatibilityCommand -Text $command)
        $actual.Count | Should -Be 1
        $actual[0].Name | Should -Be 'icacls'
        $actual[0].Arguments.Count | Should -Be 3
        $actual[0].Arguments[1] | Should -Be $Operation
        $actual[0].Arguments[2] | Should -BeExactly $Principal
        $expectedPath = switch ($Target) {
            'Store' { "$env:LocalAppData\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db" }
            'OneDrive' { $env:OneDrive }
            'Razer' { 'C:\Windows\Installer\Razer' }
        }
        $actual[0].Arguments[0] | Should -BeExactly $expectedPath
    }

    It 'resolves the OneDrive uninstaller below configured system directory <SystemDirectory>' -ForEach @(
        @{ SystemDirectory = 'TestDrive:\Windows' }
        @{ SystemDirectory = 'TestDrive:\中文 系统目录' }
    ) {
        # TestDrive is a non-C filesystem drive created by Pester; no real OS files are needed.
        $env:SystemRoot = $SystemDirectory
        $command = Get-CompatibilityCommand -Tweak 'WPFTweaksRemoveOneDrive' -Phase 'InvokeScript' -Name 'Start-Process'
        $actual = @(Invoke-CompatibilityCommand -Text $command)
        $actual.Count | Should -Be 1
        $actual[0].Name | Should -Be 'Start-Process'
        $actual[0].FilePath | Should -BeExactly ($SystemDirectory + '\System32\OneDriveSetup.exe')
        $actual[0].Arguments.Count | Should -Be 1
        $actual[0].Arguments[0] | Should -BeExactly '/uninstall'
        $actual[0].Wait | Should -BeTrue
    }
}
