[CmdletBinding()]
param (
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
$parts = [System.Collections.Generic.List[string]]::new()
$startScript = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'scripts/start.ps1') -Raw -Encoding UTF8) -replace '#{replaceme}', (Get-Date -Format 'yy.MM.dd')
$parts.Add($startScript)

# Stable ordering and explicit file types keep builds reproducible and prevent
# editor notes or temporary files from being included as executable code.
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'functions') -Recurse -File -Filter '*.ps1' |
    Sort-Object FullName | ForEach-Object {
        $parts.Add((Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8))
    }

Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'config') -File -Filter '*.json' |
    Sort-Object Name | ForEach-Object {
        $obj = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($_.Name -eq 'applications.json') {
            $fixed = [ordered]@{}
            foreach ($p in $obj.PSObject.Properties) {
                $fixed["WPFInstall$($p.Name)"] = $p.Value
            }
            $obj = [pscustomobject]$fixed
        }
        $json = $obj | ConvertTo-Json -Depth 100
        $parts.Add("`$sync.configs.$($_.BaseName) = @'`r`n$json`r`n'@ | ConvertFrom-Json")
    }

$xaml = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'xaml/inputXML.xaml') -Raw -Encoding UTF8
$null = [xml]$xaml
$parts.Add("`$inputXML = @'`r`n$xaml`r`n'@")
$autounattendXml = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tools/autounattend.xml') -Raw -Encoding UTF8
$null = [xml]$autounattendXml
$parts.Add("`$WinUtilAutounattendXml = @'`r`n$autounattendXml`r`n'@")
$parts.Add((Get-Content -LiteralPath (Join-Path $PSScriptRoot 'scripts/main.ps1') -Raw -Encoding UTF8))
$script = $parts -join "`r`n"

$syntaxErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseInput($script, [ref]$null, [ref]$syntaxErrors)
if ($syntaxErrors.Count) {
    throw "构建产物存在语法错误：`n$($syntaxErrors | Out-String)"
}

# Only replace the last successful build after validation. BOM supports PS 5.1.
$outputPath = Join-Path $PSScriptRoot 'winutil.ps1'
$temporaryPath = "$outputPath.$([guid]::NewGuid().ToString('N')).tmp"
try {
    [IO.File]::WriteAllText($temporaryPath, $script, [System.Text.UTF8Encoding]::new($true))
    if (Test-Path -LiteralPath $outputPath) {
        [IO.File]::Replace($temporaryPath, $outputPath, [NullString]::Value)
    } else {
        [IO.File]::Move($temporaryPath, $outputPath)
    }
} finally {
    if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force }
}
Write-Output "构建完成：$outputPath（UTF-8 BOM，语法检查通过）"
if ($Run) { & $outputPath }
