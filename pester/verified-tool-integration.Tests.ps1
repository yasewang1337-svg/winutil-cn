BeforeAll {
    $script:integrationRoot = Split-Path $PSScriptRoot -Parent
    $script:syncTemplateScript = Join-Path $script:integrationRoot 'tools/Sync-VerifiedToolTemplate.ps1'
    $script:toolSourcePath = Join-Path $script:integrationRoot 'functions/private/Invoke-WinUtilVerifiedTool.ps1'
    $script:toolTemplatePath = Join-Path $script:integrationRoot 'tools/autounattend.xml'
    $script:tweakEntry = (Get-Content (Join-Path $script:integrationRoot 'config/tweaks.json') -Raw -Encoding UTF8 | ConvertFrom-Json).WPFTweaksRevertStartMenu
    $script:templateDocument = [xml](Get-Content $script:toolTemplatePath -Raw -Encoding UTF8)
    $firstLogonSource = $script:templateDocument.SelectSingleNode('//*[local-name()="File" and @path="C:\Windows\Setup\Scripts\FirstLogon.ps1"]').InnerText
    $errors = $null
    $firstLogonAst = [Management.Automation.Language.Parser]::ParseInput($firstLogonSource, [ref]$null, [ref]$errors)
    if ($errors.Count) { throw 'FirstLogon template has syntax errors.' }
    $viveBlocks = @($firstLogonAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.ScriptBlockExpressionAst] -and
            $node.Extent.Text -match 'Invoke-WinUtilVerifiedTool'
    }, $true))
    if ($viveBlocks.Count -ne 1) { throw 'Expected one actual ViVeTool block in FirstLogon.' }
    $script:viveBlockSource = $viveBlocks[0].ScriptBlock.EndBlock.Extent.Text
    $runnerBlocks = @($firstLogonAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.ScriptBlockExpressionAst] -and
            $node.Extent.Text -match 'Running scripts to finalize your Windows installation'
    }, $true))
    if ($runnerBlocks.Count -ne 1) { throw 'Expected one FirstLogon step runner.' }
    $script:firstLogonRunner = [scriptblock]::Create($runnerBlocks[0].ScriptBlock.EndBlock.Extent.Text)

    # Never load the actual verifier for these integration tests. All tool actions
    # are mocked; the real download/integrity behavior has its own focused tests.
    function Invoke-WinUtilVerifiedTool {
        [CmdletBinding()]
        param([string]$Tool, [string]$Action)
        throw 'Tests must mock verified tool execution.'
    }
}

Describe 'Start menu configuration uses the verified tool entry point' {
    BeforeEach {
        Mock Invoke-WinUtilVerifiedTool { [pscustomobject]@{ Tool = 'ViVeTool'; ExitCode = 0 } }
        Mock Write-Host {}
        Mock Invoke-WebRequest { throw 'Tests must not download tools.' }
        Mock Expand-Archive { throw 'Tests must not extract tools.' }
        Mock Start-Process { throw 'Tests must not launch tools.' }
    }

    It 'applies the old menu only through Disable and announces success after it returns' {
        $result = Invoke-Command -ScriptBlock ([scriptblock]::Create($script:tweakEntry.InvokeScript[0])) -ErrorAction Stop
        $result | Should -BeNullOrEmpty
        Should -Invoke Invoke-WinUtilVerifiedTool -Times 1 -Exactly -ParameterFilter { $Tool -eq 'ViVeTool' -and $Action -eq 'Disable' -and $ErrorAction -eq 'Stop' }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match '已应用恢复旧版开始菜单设置.*重启' }
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        Should -Invoke Expand-Archive -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'preserves Enable for the undo script without exposing the internal result object' {
        $result = Invoke-Command -ScriptBlock ([scriptblock]::Create($script:tweakEntry.UndoScript[0])) -ErrorAction Stop
        $result | Should -BeNullOrEmpty
        Should -Invoke Invoke-WinUtilVerifiedTool -Times 1 -Exactly -ParameterFilter { $Tool -eq 'ViVeTool' -and $Action -eq 'Enable' }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match '已应用新版开始菜单设置.*重启' }
    }

    It 'propagates an apply failure and does not announce success' {
        Mock Invoke-WinUtilVerifiedTool { throw 'simulated integrity failure' }
        { Invoke-Command -ScriptBlock ([scriptblock]::Create($script:tweakEntry.InvokeScript[0])) -ErrorAction Stop } | Should -Throw '*simulated integrity failure*'
        Should -Invoke Write-Host -Times 0 -Exactly
    }

    It 'propagates an undo failure and does not announce success' {
        Mock Invoke-WinUtilVerifiedTool { throw 'simulated child exit failure' }
        { Invoke-Command -ScriptBlock ([scriptblock]::Create($script:tweakEntry.UndoScript[0])) -ErrorAction Stop } | Should -Throw '*simulated child exit failure*'
        Should -Invoke Write-Host -Times 0 -Exactly
    }
}

Describe 'Unattended installation follows the same verified path' {
    BeforeEach {
        $script:blockRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:blockRoot
        $script:blockPath = Join-Path $script:blockRoot 'FirstLogon-ViVe-only.ps1'
        [IO.File]::WriteAllText($script:blockPath, $script:viveBlockSource, [Text.UTF8Encoding]::new($true))
        # Satisfy the actual dot-source statement without loading production code.
        [IO.File]::WriteAllText((Join-Path $script:blockRoot 'WinUtilVerifiedTool.ps1'), '# The verifier is mocked by Pester.', [Text.UTF8Encoding]::new($true))
        Mock Invoke-WinUtilVerifiedTool { [pscustomobject]@{ Tool = 'ViVeTool'; ExitCode = 0 } }
        Mock Invoke-WebRequest { throw 'Tests must not download tools.' }
        Mock Expand-Archive { throw 'Tests must not extract tools.' }
        Mock Start-Process { throw 'Tests must not launch tools.' }
        Mock Write-Progress {}
    }

    It 'runs the real ViVe block with the shared verifier and emits success only after completion' {
        $result = @(& $script:blockPath)
        $result.Count | Should -Be 1
        $result[0] | Should -Match '已应用恢复旧版开始菜单设置.*重启'
        Should -Invoke Invoke-WinUtilVerifiedTool -Times 1 -Exactly -ParameterFilter { $Tool -eq 'ViVeTool' -and $Action -eq 'Disable' -and $ErrorAction -eq 'Stop' }
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        Should -Invoke Expand-Archive -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'stops the actual ViVe block on verification failure before success output' {
        Mock Invoke-WinUtilVerifiedTool { throw 'simulated signature failure' }
        $script:capturedOutput = @()
        { & $script:blockPath | ForEach-Object { $script:capturedOutput += $_ } } | Should -Throw '*simulated signature failure*'
        $script:capturedOutput | Should -BeNullOrEmpty
    }

    It 'stops before tool invocation when the bundled verifier is absent' {
        Remove-Item -LiteralPath (Join-Path $script:blockRoot 'WinUtilVerifiedTool.ps1')
        { & $script:blockPath } | Should -Throw
        Should -Invoke Invoke-WinUtilVerifiedTool -Times 0 -Exactly
    }

    It 'logs a failed step separately and continues independent FirstLogon steps' {
        $script:loggedErrors = @()
        Mock Write-Error { param($Message) $script:loggedErrors += $Message }
        $scripts = @({ throw 'simulated verification failure' }; { 'independent step completed' })
        $messages = @(& $script:firstLogonRunner)
        ($messages -join "`n") | Should -Match 'independent step completed'
        @($messages | Where-Object { $_ -match '^\*\*\* Finished executing command' }).Count | Should -Be 1
        @($script:loggedErrors | Where-Object { $_ -match 'FAILED: simulated verification failure' }).Count | Should -Be 1
        @($script:loggedErrors | Where-Object { $_ -match 'FirstLogon 部分步骤失败' }).Count | Should -Be 1
    }

    It 'embeds exactly the current source and contains valid PowerShell' {
        { & $script:syncTemplateScript -Check } | Should -Not -Throw
        $helper = $script:templateDocument.SelectSingleNode('//*[local-name()="File" and @path="C:\Windows\Setup\Scripts\WinUtilVerifiedTool.ps1"]').InnerText
        $parseErrors = $null
        $null = [Management.Automation.Language.Parser]::ParseInput($helper, [ref]$null, [ref]$parseErrors)
        $parseErrors.Count | Should -Be 0
    }
}

Describe 'Verifier template synchronization and build drift guard' {
    BeforeEach {
        $script:fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        foreach ($directory in @('scripts', 'functions/private', 'config', 'xaml', 'tools')) {
            $null = New-Item -ItemType Directory -Path (Join-Path $script:fixtureRoot $directory) -Force
        }
        $script:fixtureSource = Join-Path $script:fixtureRoot 'functions/private/Invoke-WinUtilVerifiedTool.ps1'
        $script:fixtureTemplate = Join-Path $script:fixtureRoot 'tools/autounattend.xml'
        $script:fixtureCompile = Join-Path $script:fixtureRoot 'Compile.ps1'
        $script:fixtureOutput = Join-Path $script:fixtureRoot 'winutil.ps1'
        $script:harmlessSource = 'function Invoke-WinUtilVerifiedTool { ''harmless <&> 中文'' }'
        [IO.File]::WriteAllText($script:fixtureSource, $script:harmlessSource, [Text.UTF8Encoding]::new($true))
        [IO.File]::WriteAllText($script:fixtureTemplate, "<unattend>`r`n    <Extensions>`r`n    </Extensions>`r`n</unattend>", [Text.UTF8Encoding]::new($false))
        Copy-Item -LiteralPath (Join-Path $script:integrationRoot 'Compile.ps1') -Destination $script:fixtureCompile
        Set-Content -LiteralPath (Join-Path $script:fixtureRoot 'scripts/start.ps1') -Value '$sync = @{ configs = @{} }' -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $script:fixtureRoot 'scripts/main.ps1') -Value '# Harmless fixture; never run compiled output.' -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $script:fixtureRoot 'config/applications.json') -Value '{}' -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $script:fixtureRoot 'xaml/inputXML.xaml') -Value '<Window />' -Encoding UTF8
    }

    It 'copies and escapes source as text without executing it' {
        $harmlessTopLevel = 'throw ''The sync tool must not execute source text.'''
        [IO.File]::WriteAllText($script:fixtureSource, $script:harmlessSource + "`r`n" + $harmlessTopLevel, [Text.UTF8Encoding]::new($true))
        { & $script:syncTemplateScript -SourcePath $script:fixtureSource -TemplatePath $script:fixtureTemplate } | Should -Not -Throw
        $document = [xml](Get-Content $script:fixtureTemplate -Raw -Encoding UTF8)
        $document.unattend.Extensions.File.InnerText.Trim().Replace("`r`n", "`n") | Should -Be ($script:harmlessSource + "`n" + $harmlessTopLevel)
        (Get-Content $script:fixtureTemplate -Raw -Encoding UTF8) | Should -Match '&lt;&amp;&gt;'
        $before = (Get-FileHash -LiteralPath $script:fixtureTemplate).Hash
        & $script:syncTemplateScript -SourcePath $script:fixtureSource -TemplatePath $script:fixtureTemplate -Check
        (Get-FileHash -LiteralPath $script:fixtureTemplate).Hash | Should -Be $before
    }

    It 'detects missing and stale embedded source without rewriting it in check mode' {
        { & $script:syncTemplateScript -SourcePath $script:fixtureSource -TemplatePath $script:fixtureTemplate -Check } | Should -Throw '*缺失或与源码不同*'
        & $script:syncTemplateScript -SourcePath $script:fixtureSource -TemplatePath $script:fixtureTemplate
        $before = (Get-FileHash -LiteralPath $script:fixtureTemplate).Hash
        [IO.File]::AppendAllText($script:fixtureSource, "`r`n# later change")
        { & $script:syncTemplateScript -SourcePath $script:fixtureSource -TemplatePath $script:fixtureTemplate -Check } | Should -Throw '*缺失或与源码不同*'
        (Get-FileHash -LiteralPath $script:fixtureTemplate).Hash | Should -Be $before
        & $script:syncTemplateScript -SourcePath $script:fixtureSource -TemplatePath $script:fixtureTemplate
        { & $script:syncTemplateScript -SourcePath $script:fixtureSource -TemplatePath $script:fixtureTemplate -Check } | Should -Not -Throw
    }

    It 'rejects a production-helper build when its template entry is absent' {
        { & $script:fixtureCompile } | Should -Throw '*缺少唯一的工具校验脚本*'
        Test-Path -LiteralPath $script:fixtureOutput | Should -BeFalse
    }

    It 'builds matching source and rejects drift without replacing the last output' {
        & $script:syncTemplateScript -SourcePath $script:fixtureSource -TemplatePath $script:fixtureTemplate
        & $script:fixtureCompile
        $before = (Get-FileHash -LiteralPath $script:fixtureOutput).Hash
        [IO.File]::AppendAllText($script:fixtureSource, "`r`n# later change")
        { & $script:fixtureCompile } | Should -Throw '*工具校验脚本与源码不同*'
        (Get-FileHash -LiteralPath $script:fixtureOutput).Hash | Should -Be $before
    }
}
