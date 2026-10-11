function Invoke-WinUtilInventoryQuery {
    <# Runs one read-only inventory command with a deadline and captures both streams. #>
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [ValidateRange(1, 300)][int]$TimeoutSeconds = 60
    )
    try {
        $command = Get-Command -Name $FilePath -CommandType Application -ErrorAction Stop | Select-Object -First 1
    } catch { throw "找不到 $FilePath，无法检测已安装软件。请检查所选包管理器是否已安装。" }
    $process = [Diagnostics.Process]::new()
    try {
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $command.Source
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
        $start.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
        # ProcessStartInfo.ArgumentList is unavailable in Windows PowerShell 5.1.
        # Quote each Windows argv value, including trailing backslashes and quotes.
        $start.Arguments = (@($Arguments | ForEach-Object {
            '"' + (($_ -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
        })) -join ' '
        $process.StartInfo = $start
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) {
            # Only this query process is owned by the scan. Never kill installers.
            try { $process.Kill() } catch { }
            if (-not $process.WaitForExit(5000)) { throw '检测命令超时，无法结束该查询进程。请稍后重试。' }
        }
        # Async reads prevent a full stderr pipe from blocking stdout or exit.
        if (-not $stdout.Wait(5000) -or -not $stderr.Wait(5000)) {
            throw '检测进程已经结束，但输出未能读取完整；本次结果未采用。'
        }
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            StandardOutput = $stdout.Result
            StandardError = $stderr.Result
            TimedOut = $timedOut
        }
    } finally { $process.Dispose() }
}
