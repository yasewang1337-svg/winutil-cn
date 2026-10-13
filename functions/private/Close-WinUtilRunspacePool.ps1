function Close-WinUtilRunspacePool {
    <#
    .SYNOPSIS Closes an idle worker pool without interrupting running operations.
    .DESCRIPTION
    Returns false immediately while a tracked or untracked pipeline is active.
    The optional Wait switch is only for noninteractive cleanup after an
    explicitly requested operation; it waits for natural completion, never Stop.
    #>
    [CmdletBinding()]
    param([switch]$Wait)

    do {
        [Threading.Monitor]::Enter($sync.SyncRoot)
        try {
            Complete-WinUtilRunspaceJobs
            $pending = @($sync.RunspaceJobs.Values | Where-Object { -not $_.Handle.IsCompleted })
            $pool = $sync.runspace
            $poolBusy = $pool -and $pool.RunspacePoolStateInfo.State -eq 'Opened' -and
                $pool.GetAvailableRunspaces() -lt $pool.GetMaxRunspaces()
            if ($pending.Count -eq 0 -and -not $poolBusy) {
                $sync.RunspaceShuttingDown = $true
                if ($pool) {
                    try { $pool.Close() }
                    finally { $pool.Dispose(); $sync.runspace = $null }
                }
                return $true
            }
            if (-not $Wait) { return $false }
        } finally { [Threading.Monitor]::Exit($sync.SyncRoot) }

        # Never hold SyncRoot while waiting: completing workers may need it to
        # publish their results or dispatch a final follow-up task.
        [Threading.Thread]::Sleep(25)
    } while ($Wait)
}
