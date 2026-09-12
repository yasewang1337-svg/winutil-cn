function Invoke-WPFRunspace {
    <# .SYNOPSIS Dispatches a task and retains its pipeline until completion without closing the shared pool. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock]$ScriptBlock, $ArgumentList, $ParameterList)
    if (-not $sync.RunspaceJobs) {
        $sync.RunspaceJobs = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::new()
    }
    Complete-WinUtilRunspaceJobs
    $pipeline = [powershell]::Create()
    try {
        $null = $pipeline.AddScript($ScriptBlock)
        if ($PSBoundParameters.ContainsKey('ArgumentList')) { $null = $pipeline.AddArgument($ArgumentList) }
        foreach ($parameter in $ParameterList) {
            if ($parameter.Count -ne 2) { throw '后台任务参数应包含名称和值。' }
            $null = $pipeline.AddParameter([string]$parameter[0], $parameter[1])
        }
        $pipeline.RunspacePool = $sync.runspace
        $handle = $pipeline.BeginInvoke()
        $id = [guid]::NewGuid().ToString('N')
        $sync.RunspaceJobs[$id] = [pscustomobject]@{ Id=$id; Pipeline=$pipeline; Handle=$handle }
        return $handle
    } catch {
        $pipeline.Dispose()
        throw
    }
}
