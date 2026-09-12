function Invoke-WinUtilPackageBatch {
    <# Executes an already reviewed plan. UI-free, so tests never need to install software. #>
    param(
        [Parameter(Mandatory)][object[]]$Plan,
        [string]$LogRoot = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'WinUtil-CN\Logs\Packages'),
        [switch]$PrepareManagers,
        [scriptblock]$OnProgress
    )
    $runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $batch = [pscustomobject]@{
        RunId = $runId; StartedAt = (Get-Date).ToString('o'); CompletedAt = $null
        Results = @(); LogDirectory = (Join-Path $LogRoot $runId); SummaryPath = ''; LogWarning = ''
    }
    $logError = ''
    try {
        $null = New-Item -Path $batch.LogDirectory -ItemType Directory -Force -ErrorAction Stop
        $batch.SummaryPath = Join-Path $batch.LogDirectory 'results.json'
    } catch {
        $logError = "无法创建操作日志，本次未执行任何软件操作：$($_.Exception.Message)"
        $batch.LogWarning = $logError
    }
    $managerErrors = @{}
    $preparedManagers = @{}
    $results = [System.Collections.Generic.List[object]]::new()
    $position = 0
    foreach ($item in $Plan) {
        $position++
        if ($OnProgress) { & $OnProgress $item $position $Plan.Count }
        $startedAt = (Get-Date).ToString('o')
        $exitCode = $null
        $outputPath = ''; $errorPath = ''; $failure = $logError
        if (-not $failure -and $item.InvalidReason) { $failure = $item.InvalidReason }
        if (-not $failure) {
            try {
                if (-not $preparedManagers.ContainsKey($item.Manager)) {
                    $preparedManagers[$item.Manager] = $true
                    $executable = if ($item.Manager -eq 'Choco') { 'choco.exe' } else { 'winget.exe' }
                    if (-not (Get-Command $executable -CommandType Application -ErrorAction SilentlyContinue)) {
                        if ($PrepareManagers -and $item.Action -ne 'Uninstall') {
                            if ($OnProgress) { & $OnProgress ([pscustomobject]@{ Name = "准备 $($item.Manager)，首次使用可能需要几分钟"; Action = $item.Action }) $position $Plan.Count }
                            $previousErrorPreference = $ErrorActionPreference
                            try {
                                $ErrorActionPreference = 'Stop'
                                if ($item.Manager -eq 'Choco') { Install-WinUtilChoco | Out-Null } else { Install-WinUtilWinget | Out-Null }
                            } finally { $ErrorActionPreference = $previousErrorPreference }
                        }
                        if (-not (Get-Command $executable -CommandType Application -ErrorAction SilentlyContinue)) {
                            throw "未找到 $($item.Manager)。请先安装该软件包管理器，或重启 WinUtil 后再试。"
                        }
                    }
                }
            } catch { $managerErrors[$item.Manager] = "无法准备 $($item.Manager)：$($_.Exception.Message)" }
            if ($managerErrors.ContainsKey($item.Manager)) { $failure = $managerErrors[$item.Manager] }
        }
        if (-not $failure) {
            try {
                if ($OnProgress) { & $OnProgress $item $position $Plan.Count }
                if ($item.Manager -eq 'Choco') {
                    $native = Install-WinUtilProgramChoco -Action $item.Action -Programs @($item.PackageId) -LogDirectory $batch.LogDirectory
                } else {
                    $native = Install-WinUtilProgramWinget -Action $item.Action -Programs @($item.PackageId) -LogDirectory $batch.LogDirectory
                }
                $exitCode = $native.ExitCode
                $outputPath = $native.OutputPath
                $errorPath = $native.ErrorPath
            } catch { $failure = "未能完成此项操作：$($_.Exception.Message)" }
        }
        $exitResult = Get-WinUtilPackageExitResult -Manager $item.Manager -Action $item.Action -ExitCode $exitCode
        if ($failure) { $exitResult.Status = 'Failed'; $exitResult.StatusText = '失败'; $exitResult.Reason = $failure }
        $result = [pscustomobject]@{
            Id = $item.Id; PackageId = $item.PackageId; Name = $item.Name; Manager = $item.Manager; Action = $item.Action
            Status = $exitResult.Status; StatusText = $exitResult.StatusText; Reason = $exitResult.Reason
            NeedsReboot = $exitResult.NeedsReboot; ExitCode = $exitCode; ExitCodeHex = $exitResult.ExitCodeHex
            StartedAt = $startedAt; CompletedAt = (Get-Date).ToString('o')
            OutputPath = $outputPath; ErrorPath = $errorPath; Plan = $item
        }
        $results.Add($result)
        $batch.Results = @($results.ToArray())
        Write-Host "[$($result.StatusText)] $($result.Name)：$($result.Reason)"
        if ($batch.SummaryPath) {
            try { [IO.File]::WriteAllText($batch.SummaryPath, ($batch | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($true)) }
            catch { $batch.LogWarning = "结果日志保存失败：$($_.Exception.Message)" }
        }
    }
    $batch.CompletedAt = (Get-Date).ToString('o')
    if ($batch.SummaryPath) {
        try { [IO.File]::WriteAllText($batch.SummaryPath, ($batch | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($true)) }
        catch { $batch.LogWarning = "结果日志保存失败：$($_.Exception.Message)" }
    }
    return $batch
}
