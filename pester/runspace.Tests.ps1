BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    foreach ($path in @('functions/public/Invoke-WPFRunspace.ps1','functions/private/Complete-WinUtilRunspaceJobs.ps1')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root $path))))
    }
}
Describe 'Reusable background task pool' {
    It 'passes arrays intact and runs consecutive fast tasks without closing the pool' {
        $script:sync = [hashtable]::Synchronized(@{ Messages = [System.Collections.Concurrent.ConcurrentQueue[string]]::new() })
        $state = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $state.Variables.Add([System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('sync',$sync,$null))
        $sync.runspace = [runspacefactory]::CreateRunspacePool(1,2,$state,$Host)
        $sync.runspace.Open()
        try {
            foreach ($round in 1..3) {
                $handle = Invoke-WPFRunspace -ParameterList (, @('Names', @('one','two'))) -ScriptBlock {
                    param($Names)
                    $sync.Messages.Enqueue(($Names -join ','))
                }
                $handle | Should -BeOfType ([System.IAsyncResult])
                $handle.AsyncWaitHandle.WaitOne(5000) | Should -BeTrue
                Complete-WinUtilRunspaceJobs
                $sync.runspace.RunspacePoolStateInfo.State | Should -Be 'Opened'
                $sync.RunspaceJobs.Count | Should -Be 0
            }
            $sync.Messages.Count | Should -Be 3
            @($sync.Messages.ToArray() | Where-Object { $_ -eq 'one,two' }).Count | Should -Be 3
        } finally { $sync.runspace.Dispose() }
    }
}
