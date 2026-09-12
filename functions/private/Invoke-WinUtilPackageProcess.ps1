function Invoke-WinUtilPackageProcess {
    <# Run one native command and keep both streams. Never launches a shell. #>
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$LogDirectory,
        [Parameter(Mandatory)][string]$LogName
    )
    $command = Get-Command -Name $FilePath -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $stdout = Join-Path $LogDirectory "$LogName.stdout.log"
    $stderr = Join-Path $LogDirectory "$LogName.stderr.log"
    $process = $null
    try {
        # Keep the handle before waiting, so ExitCode remains available in Windows PowerShell 5.1.
        $process = Start-Process -FilePath $command.Source -ArgumentList $Arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -ErrorAction Stop
        $null = $process.Handle
        $process.WaitForExit()
        $process.Refresh()
        [pscustomobject]@{ ExitCode = $process.ExitCode; OutputPath = $stdout; ErrorPath = $stderr }
    } finally {
        if ($null -ne $process) { $process.Dispose() }
    }
}
