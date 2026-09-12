# Test cases must be discovered before BeforeAll runs (Pester 5).
Describe 'PowerShell source syntax' -ForEach @(
    Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '../functions') -Filter '*.ps1' -File -Recurse |
        ForEach-Object { @{ SourcePath = $_.FullName; SourceName = $_.Name } }
) {
    It '<SourceName> parses without errors' {
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($SourcePath, [ref]$null, [ref]$errors)
        @($errors).Count | Should -Be 0 -Because ($errors | Out-String)
        @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)).Count | Should -BeGreaterThan 0
    }
}
