function Initialize-WinUtilRunspacePool {
    <# .SYNOPSIS Creates the shared worker pool only when an operation needs it. #>
    [CmdletBinding()]
    param()

    [Threading.Monitor]::Enter($sync.SyncRoot)
    try {
        if ($sync.RunspaceShuttingDown) { throw 'WinUtil is closing; no new background task can start.' }
        if ($sync.runspace) {
            if ($sync.runspace.RunspacePoolStateInfo.State -ne 'Opened') {
                throw 'The background task pool is not available.'
            }
            return
        }

        $state = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $state.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('sync', $sync, $null))
        $offline = [bool](Get-Variable PARAM_OFFLINE -ValueOnly -ErrorAction SilentlyContinue)
        $state.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('PARAM_OFFLINE', $offline, $null))
        foreach ($function in Get-ChildItem function:\ | Where-Object { $_.Name -imatch 'winutil|WPF' }) {
            $state.Commands.Add([Management.Automation.Runspaces.SessionStateFunctionEntry]::new($function.Name, $function.Definition))
        }

        # Background operations are primarily I/O-bound. Do not grow the pool
        # to every logical processor on large desktop machines.
        $maximum = [math]::Min(4, [math]::Max(1, [Environment]::ProcessorCount))
        $pool = [runspacefactory]::CreateRunspacePool(1, $maximum, $state, $Host)
        try {
            $pool.Open()
            $sync.runspace = $pool
        } catch {
            $pool.Dispose()
            throw
        }
    } finally { [Threading.Monitor]::Exit($sync.SyncRoot) }
}
