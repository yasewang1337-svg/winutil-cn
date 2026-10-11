[CmdletBinding(DefaultParameterSetName = 'Request')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Request')][string]$InputPath,
    [Parameter(Mandatory = $true, ParameterSetName = 'Request')][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedSha256,
    [Parameter(Mandatory = $true, ParameterSetName = 'Restore')][string]$RestoreBackupId,
    [Parameter(ParameterSetName = 'Request')][switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding
try {
    . (Join-Path $PSScriptRoot 'worker-core.ps1')
    if ($PSCmdlet.ParameterSetName -eq 'Restore') {
        $result = Restore-WinUtilMcpBackup $RestoreBackupId
    } else {
        $file = Get-Item -LiteralPath $InputPath -ErrorAction Stop
        if ($file.Length -gt 2MB -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'INVALID_REQUEST: 文件过大或为重解析点。' }
        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
        if ($hash -cne $ExpectedSha256.ToLowerInvariant()) { throw 'REQUEST_CHANGED: 请求内容与宿主预览不匹配。' }
        $request = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop
        if ($ValidateOnly) {
            Assert-WinUtilMcpRequest $request
            $result = [pscustomobject]@{ schemaVersion = 1; status = 'completed'; results = @(); validationOnly = $true }
        } else { $result = Invoke-WinUtilMcpRequest $request -ReportProgress }
    }
} catch {
    $result = [pscustomobject]@{ schemaVersion = 1; status = 'failed'; results = @(); code = 'WORKER_FAILED'; message = $_.Exception.Message }
}
$result | ConvertTo-Json -Depth 40 -Compress | Write-Output
if ($result.status -eq 'completed') { exit 0 } else { exit 1 }
