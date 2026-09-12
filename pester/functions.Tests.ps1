# Test cases must be discovered before BeforeAll runs (Pester 5).
Describe 'PowerShell source syntax' -ForEach @(
    Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '../functions') -Filter '*.ps1' -File -Recurse |
        ForEach-Object { @{ SourcePath = $_.FullName; SourceName = $_.Name } }
) {
    It '<SourceName> parses without errors' {
        $errors = $null
        # Source files are UTF-8; only the standalone release requires a BOM.
        # Match Compile.ps1 instead of letting PS 5.1 guess the system ANSI page.
        $source = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($source, $SourcePath, [ref]$null, [ref]$errors)
        @($errors).Count | Should -Be 0 -Because ($errors | Out-String)
        @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)).Count | Should -BeGreaterThan 0
    }
}
