BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    $script:fixture = Join-Path $TestDrive 'localized-iso'
    $script:isoFiles = @('Invoke-WinUtilISO.ps1', 'Invoke-WinUtilISOUSB.ps1', 'Invoke-WinUtilISOScript.ps1')
    $null = New-Item -ItemType Directory -Path (Join-Path $script:fixture 'functions/private'), (Join-Path $script:fixture '汉化') -Force
    foreach ($file in $script:isoFiles) {
        Copy-Item -LiteralPath (Join-Path $script:root "functions/private/$file") -Destination (Join-Path $script:fixture 'functions/private')
    }
    foreach ($file in @('apply-functions.ps1', 'i18n-functions.json')) {
        Copy-Item -LiteralPath (Join-Path $script:root "汉化/$file") -Destination (Join-Path $script:fixture '汉化')
    }

    # This fixture-only sentinel proves the real translation table still replaces
    # quoted Error strings, which previously corrupted MessageBox icon arguments.
    $script:isoCopy = Join-Path $script:fixture 'functions/private/Invoke-WinUtilISO.ps1'
    [IO.File]::AppendAllText($script:isoCopy, "`r`nfunction Get-ISOTranslationSentinel { `"Error`" }`r`n", [Text.UTF8Encoding]::new($true))
    & (Join-Path $script:fixture '汉化/apply-functions.ps1') 3>$null | Out-Null

    $script:asts = @{}
    $script:parseErrors = @{}
    foreach ($file in $script:isoFiles) {
        $errors = $null
        $path = Join-Path $script:fixture "functions/private/$file"
        # Localized source is UTF-8 without BOM; match Compile.ps1 instead of
        # letting Windows PowerShell 5.1 use the runner's ANSI code page.
        $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
        $script:asts[$file] = [Management.Automation.Language.Parser]::ParseInput(
            $text, $path, [ref]$null, [ref]$errors)
        $script:parseErrors[$file] = @($errors)
    }

    function Get-ISOMessageBoxCalls([string]$File) {
        @($script:asts[$File].FindAll({
            param($node)
            $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
            $node.Static -and $node.Member.Value -eq 'Show' -and
            $node.Expression -is [Management.Automation.Language.TypeExpressionAst] -and
            $node.Expression.TypeName.FullName -match '^(System\.)?Windows\.MessageBox$'
        }, $true))
    }

    function Get-ISOMessageBoxIcon($Call) {
        if ($Call.Arguments.Count -lt 4) { throw "MessageBox icon missing at $($Call.Extent.StartLineNumber)." }
        $argument = $Call.Arguments[3]
        if ($argument -is [Management.Automation.Language.MemberExpressionAst] -and
            $argument.Static -and $argument.Expression -is [Management.Automation.Language.TypeExpressionAst] -and
            $argument.Expression.TypeName.FullName -match '^(System\.)?Windows\.MessageBoxImage$') {
            $name = $argument.Member.Value
        } elseif ($argument -is [Management.Automation.Language.StringConstantExpressionAst]) {
            $name = $argument.Value
        } else {
            throw "Unsupported icon expression at $($Call.Extent.StartLineNumber): $($argument.Extent.Text)"
        }
        # Do not invoke Show, the callback, or any production function.
        $icon = [Enum]::Parse([Windows.MessageBoxImage], $name, $false)
        if (-not [Enum]::IsDefined([Windows.MessageBoxImage], $icon)) { throw "Undefined icon: $name" }
        return $icon
    }

    function Get-ISOMessageBoxByTitle([string]$File, [string]$Title) {
        @(Get-ISOMessageBoxCalls $File | Where-Object {
            $_.Arguments.Count -ge 2 -and
            $_.Arguments[1] -is [Management.Automation.Language.StringConstantExpressionAst] -and
            $_.Arguments[1].Value -eq $Title
        })
    }
}

Describe 'ISO dialogs remain valid after the actual localization stage' {
    It 'applies the real Error translation to fixture text' {
        $sentinel = $script:asts['Invoke-WinUtilISO.ps1'].Find({
            param($node)
            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-ISOTranslationSentinel'
        }, $true)
        $value = $sentinel.Body.Find({ param($node) $node -is [Management.Automation.Language.StringConstantExpressionAst] }, $true)
        $value.Value | Should -Be '错误'
    }

    It 'parses all three translated ISO files' {
        foreach ($file in $script:isoFiles) {
            @($script:parseErrors[$file]).Count | Should -Be 0 -Because $file
        }
    }

    It 'resolves every translated dialog icon to a defined WPF enum' {
        $calls = @(foreach ($file in $script:isoFiles) { Get-ISOMessageBoxCalls $file })
        $calls.Count | Should -BeGreaterThan 0
        foreach ($call in $calls) {
            { Get-ISOMessageBoxIcon $call } | Should -Not -Throw -Because $call.Extent.Text
        }
    }

    It 'keeps ISO export success and both failure branches displayable' {
        foreach ($case in @(
            @{ Title = '导出完成'; Icon = 'Information' },
            @{ Title = '导出错误'; Icon = 'Error' },
            @{ Title = '错误'; Icon = 'Error' }
        )) {
            $calls = @(Get-ISOMessageBoxByTitle 'Invoke-WinUtilISO.ps1' $case.Title)
            $calls.Count | Should -Be 1 -Because $case.Title
            Get-ISOMessageBoxIcon $calls[0] | Should -Be ([Enum]::Parse([Windows.MessageBoxImage], $case.Icon))
        }
    }

    It 'keeps USB success and failure branches displayable' {
        foreach ($case in @(
            @{ Title = 'U 盘已就绪'; Icon = 'Information' },
            @{ Title = 'U 盘写入错误'; Icon = 'Error' }
        )) {
            $calls = @(Get-ISOMessageBoxByTitle 'Invoke-WinUtilISOUSB.ps1' $case.Title)
            $calls.Count | Should -Be 1 -Because $case.Title
            Get-ISOMessageBoxIcon $calls[0] | Should -Be ([Enum]::Parse([Windows.MessageBoxImage], $case.Icon))
        }
    }
}
