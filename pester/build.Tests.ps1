BeforeAll {
    $script:compileSource = Join-Path $PSScriptRoot '../Compile.ps1'
}

Describe 'Validated build output' {
    BeforeEach {
        $script:fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        foreach ($dir in @('scripts', 'functions', 'config', 'xaml', 'tools')) {
            $null = New-Item -ItemType Directory -Path (Join-Path $script:fixture $dir) -Force
        }
        Copy-Item -LiteralPath $script:compileSource -Destination (Join-Path $script:fixture 'Compile.ps1')
        Set-Content (Join-Path $script:fixture 'scripts/start.ps1') '$sync = @{ configs = @{} }' -Encoding UTF8
        Set-Content (Join-Path $script:fixture 'scripts/main.ps1') '# 中文 entry point' -Encoding UTF8
        Set-Content (Join-Path $script:fixture 'functions/example.ps1') 'function Test-Example { "ok" }' -Encoding UTF8
        Set-Content (Join-Path $script:fixture 'config/applications.json') '{"example":{"content":"中文"}}' -Encoding UTF8
        Set-Content (Join-Path $script:fixture 'xaml/inputXML.xaml') '<Window />' -Encoding UTF8
        Set-Content (Join-Path $script:fixture 'tools/autounattend.xml') '<unattend />' -Encoding UTF8
        $script:buildScript = Join-Path $script:fixture 'Compile.ps1'
        $script:buildOutput = Join-Path $script:fixture 'winutil.ps1'
    }

    It 'builds outside the working directory, with BOM and complete function boundaries' {
        & $script:buildScript
        $bytes = [IO.File]::ReadAllBytes($script:buildOutput)
        ($bytes[0..2] -join ',') | Should -Be '239,187,191'
        $content = Get-Content $script:buildOutput -Raw -Encoding UTF8
        $content | Should -Match 'WPFInstallexample'
        $content | Should -Match '中文'
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
        $hash = (Get-FileHash $script:buildOutput).Hash
        & $script:buildScript
        (Get-FileHash $script:buildOutput).Hash | Should -Be $hash
    }

    It 'rejects malformed PowerShell without replacing a previous successful build' {
        & $script:buildScript
        $hash = (Get-FileHash $script:buildOutput).Hash
        Set-Content (Join-Path $script:fixture 'functions/example.ps1') 'function Broken {'
        { & $script:buildScript } | Should -Throw
        (Get-FileHash $script:buildOutput).Hash | Should -Be $hash
    }

    It 'rejects unreadable/missing required input instead of publishing a partial script' {
        Remove-Item (Join-Path $script:fixture 'scripts/main.ps1')
        { & $script:buildScript } | Should -Throw
        Test-Path $script:buildOutput | Should -BeFalse
    }

    It 'rejects malformed JSON before writing output' {
        Set-Content (Join-Path $script:fixture 'config/applications.json') '{broken'
        { & $script:buildScript } | Should -Throw
        Test-Path $script:buildOutput | Should -BeFalse
    }

    It 'rejects malformed XAML before writing output' {
        Set-Content (Join-Path $script:fixture 'xaml/inputXML.xaml') '<Window>'
        { & $script:buildScript } | Should -Throw
        Test-Path $script:buildOutput | Should -BeFalse
    }
}
