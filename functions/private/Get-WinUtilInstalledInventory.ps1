function Get-WinUtilInstalledInventory {
    <# Reads installed packages without installing managers, packages or altering selections. #>
    param(
        [Parameter(Mandatory)][ValidateSet('Winget', 'Choco')][string]$Manager,
        [ValidateRange(1, 300)][int]$TimeoutSeconds = 60,
        $Applications
    )
    if ($null -eq $Applications -and $null -ne $sync) {
        $Applications = $sync.configs.applicationsHashtable
        if ($null -eq $Applications) { $Applications = $sync.configs.applications }
    }
    if ($null -eq $Applications) { throw '软件目录尚未加载，无法检测已安装软件。' }
    $diagnostics = [Collections.Generic.List[object]]::new()
    $temporaryFile = $null
    try {
        if ($Manager -eq 'Winget') {
            $temporaryFile = Join-Path ([IO.Path]::GetTempPath()) ("winutil-inventory-{0}.json" -f [guid]::NewGuid().ToString('N'))
            $query = Invoke-WinUtilInventoryQuery -FilePath 'winget.exe' -Arguments @(
                'export', '--source', 'winget', '--include-versions', '--output', $temporaryFile,
                '--disable-interactivity', '--accept-source-agreements'
            ) -TimeoutSeconds $TimeoutSeconds
            $diagnostics.Add($query)
            if ($query.TimedOut) { throw "WinGet 检测超过 $TimeoutSeconds 秒，已停止本次查询。请检查软件源后重试。" }
            if ($null -eq $query.ExitCode -or $query.ExitCode -ne 0) { throw "WinGet 检测失败（退出码 $($query.ExitCode)），本次结果未采用。" }
            if (-not (Test-Path -LiteralPath $temporaryFile -PathType Leaf)) { throw 'WinGet 未生成检测清单，本次结果未采用。' }
            $data = [IO.File]::ReadAllText($temporaryFile, [Text.UTF8Encoding]::new($false, $true))
            $programs = @(ConvertFrom-WinUtilInventoryData -Manager Winget -Text $data)
        } else {
            $versionQuery = Invoke-WinUtilInventoryQuery -FilePath 'choco.exe' -Arguments @('--version', '--no-color') -TimeoutSeconds $TimeoutSeconds
            $diagnostics.Add($versionQuery)
            if ($versionQuery.TimedOut) { throw 'Chocolatey 版本检测超时，已停止本次查询。' }
            if ($null -eq $versionQuery.ExitCode -or $versionQuery.ExitCode -ne 0 -or
                ([string]$versionQuery.StandardOutput).Trim() -notmatch '^(\d+)\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$') {
                throw '无法确认 Chocolatey 版本，未查询软件清单。请检查包管理器和输出日志。'
            }
            if ([int]$Matches[1] -lt 2) { throw '已安装的 Chocolatey 低于 2.0。请先升级 Chocolatey，或切换为 WinGet；本次没有查询远程软件目录。' }
            $query = Invoke-WinUtilInventoryQuery -FilePath 'choco.exe' -Arguments @('list', '--limit-output', '--no-color') -TimeoutSeconds $TimeoutSeconds
            $diagnostics.Add($query)
            if ($query.TimedOut) { throw "Chocolatey 检测超过 $TimeoutSeconds 秒，已停止本次查询。" }
            # Chocolatey's optional enhanced exit code 2 means no results.
            $emptyResult = $query.ExitCode -eq 2 -and [string]::IsNullOrWhiteSpace($query.StandardOutput) -and [string]::IsNullOrWhiteSpace($query.StandardError)
            if ($null -eq $query.ExitCode -or ($query.ExitCode -ne 0 -and -not $emptyResult)) {
                throw "Chocolatey 检测失败（退出码 $($query.ExitCode)），本次结果未采用。"
            }
            $programs = @(ConvertFrom-WinUtilInventoryData -Manager Choco -Text $query.StandardOutput)
        }
        [pscustomobject]@{
            Manager = $Manager
            Programs = $programs
            MatchedKeys = [string[]]@(Get-WinUtilInventoryMatches -Manager $Manager -Programs $programs -Applications $Applications)
            CompletedAt = [datetime]::Now
            PackageCount = $programs.Count
            Diagnostics = $diagnostics.ToArray()
        }
    } catch {
        # Preserve complete streams for support while keeping the on-screen error concise.
        $_.Exception.Data['InventoryDiagnostics'] = $diagnostics.ToArray()
        $lastQuery = $diagnostics | Select-Object -Last 1
        if ($lastQuery) {
            $_.Exception.Data['StandardOutput'] = $lastQuery.StandardOutput
            $_.Exception.Data['StandardError'] = $lastQuery.StandardError
        }
        throw
    } finally {
        # Delete only the exact unique file owned by this query; never recurse.
        if ($temporaryFile -and (Test-Path -LiteralPath $temporaryFile -PathType Leaf)) {
            Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
        }
    }
}
