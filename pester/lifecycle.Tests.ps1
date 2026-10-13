BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:lifecycleRoot = Split-Path $PSScriptRoot -Parent
    foreach ($path in @(
        'functions/private/Initialize-WinUtilRunspacePool.ps1',
        'functions/private/Close-WinUtilRunspacePool.ps1',
        'functions/private/Complete-WinUtilRunspaceJobs.ps1',
        'functions/public/Invoke-WPFRunspace.ps1'
    )) { . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:lifecycleRoot $path)))) }
    function Get-WinUtilLifecycleProbe { 'worker:' + $PARAM_OFFLINE }
    function Wait-LifecycleWorkerStarted {
        $deadline = [DateTime]::UtcNow.AddSeconds(5)
        while (-not $sync.WorkerStarted -and [DateTime]::UtcNow -lt $deadline) { [Threading.Thread]::Sleep(5) }
        $sync.WorkerStarted | Should -BeTrue
    }
    $tokens = $null
    $parseErrors = $null
    $script:lifecycleMainAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:lifecycleRoot 'scripts/main.ps1'), [ref]$tokens, [ref]$parseErrors)
    $closingRegistration = @($script:lifecycleMainAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $node.Member.Value -eq 'Add_Closing'
    }, $true))
    if ($closingRegistration.Count -ne 1) { throw 'Expected exactly one main window Closing registration.' }
    $closingSource = $closingRegistration[0].Arguments[0].ScriptBlock.Extent.Text
    # Exercise the actual main event handler. Only the blocking message box is
    # replaced by a counter; no window is ever shown and no operation is run.
    $script:lifecycleClosingBody = $closingSource.Substring(1, $closingSource.Length - 2).Replace('[Windows.MessageBox]', '[WinUtilLifecycleDialogFixture]')
    if (-not ('WinUtilLifecycleDialogFixture' -as [type])) {
        Add-Type @'
public static class WinUtilLifecycleDialogFixture {
    public static int Count;
    public static int Show(string message, string title) { Count++; return 0; }
}
'@
    }
}

Describe 'Background pool lifecycle without startup inventory or forced collection' {
    BeforeEach {
        $script:PARAM_OFFLINE = $true
        $script:sync = [hashtable]::Synchronized(@{
            ProcessRunning = $false
            RunspaceJobs = [Collections.Concurrent.ConcurrentDictionary[string,object]]::new()
            Results = [Collections.Concurrent.ConcurrentQueue[string]]::new()
        })
    }
    AfterEach { $null = Close-WinUtilRunspacePool -Wait }

    It 'does not create a pool when an unused window is closed' {
        $sync.runspace | Should -BeNullOrEmpty
        Close-WinUtilRunspacePool | Should -BeTrue
        $sync.runspace | Should -BeNullOrEmpty
        Close-WinUtilRunspacePool | Should -BeTrue
    }

    It 'initializes once at first dispatch and preserves shared data and function dependencies' {
        $sync.runspace | Should -BeNullOrEmpty
        $first = Invoke-WPFRunspace -ScriptBlock { $sync.Results.Enqueue((Get-WinUtilLifecycleProbe)) }
        $first.AsyncWaitHandle.WaitOne(5000) | Should -BeTrue
        $pool = $sync.runspace
        $pool.GetMinRunspaces() | Should -Be 1
        $pool.GetMaxRunspaces() | Should -BeGreaterOrEqual 1
        $pool.GetMaxRunspaces() | Should -BeLessOrEqual 4
        $second = Invoke-WPFRunspace -ScriptBlock { $sync.Results.Enqueue('second') }
        $second.AsyncWaitHandle.WaitOne(5000) | Should -BeTrue
        [object]::ReferenceEquals($pool, $sync.runspace) | Should -BeTrue
        Complete-WinUtilRunspaceJobs
        $sync.Results.ToArray() | Should -Be @('worker:True', 'second')
        $sync.RunspaceJobs.Count | Should -Be 0
    }

    It 'declines to close an active task even when the action did not set ProcessRunning' {
        $handle = Invoke-WPFRunspace -ScriptBlock {
            $sync.WorkerStarted = $true
            [Threading.Thread]::Sleep(300)
            $sync.Results.Enqueue('completed normally')
        }
        Wait-LifecycleWorkerStarted
        $sync.ProcessRunning | Should -BeFalse
        Close-WinUtilRunspacePool | Should -BeFalse
        $sync.RunspaceShuttingDown | Should -Not -BeTrue
        $sync.runspace.RunspacePoolStateInfo.State | Should -Be 'Opened'
        $handle.AsyncWaitHandle.WaitOne(5000) | Should -BeTrue
        Close-WinUtilRunspacePool | Should -BeTrue
        $sync.Results.ToArray() | Should -Contain 'completed normally'
        $sync.RunspaceJobs.Count | Should -Be 0
    }

    It 'shares one lazily created pool when two callers dispatch at the same time' {
        $state = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $state.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('sync', $sync, $null))
        foreach ($name in @('Initialize-WinUtilRunspacePool', 'Invoke-WPFRunspace', 'Complete-WinUtilRunspaceJobs')) {
            $state.Commands.Add([Management.Automation.Runspaces.SessionStateFunctionEntry]::new($name, (Get-Command $name).Definition))
        }
        $sync.DispatchGate = [Threading.ManualResetEventSlim]::new($false)
        $sync.PoolIds = [Collections.Concurrent.ConcurrentQueue[string]]::new()
        $callers = [runspacefactory]::CreateRunspacePool(1, 2, $state, $Host)
        $requests = @()
        try {
            $callers.Open()
            foreach ($index in 1..2) {
                $pipeline = [powershell]::Create()
                $pipeline.RunspacePool = $callers
                $null = $pipeline.AddScript({
                    $sync.DispatchGate.Wait()
                    $null = Invoke-WPFRunspace -ScriptBlock { $sync.Results.Enqueue('parallel completion') }
                    $sync.PoolIds.Enqueue($sync.runspace.InstanceId.ToString())
                })
                $requests += @{Pipeline=$pipeline; Handle=$pipeline.BeginInvoke()}
            }
            $sync.DispatchGate.Set()
            foreach ($request in $requests) {
                $request.Handle.AsyncWaitHandle.WaitOne(5000) | Should -BeTrue
                $null = $request.Pipeline.EndInvoke($request.Handle)
                $request.Pipeline.HadErrors | Should -BeFalse
            }
            Close-WinUtilRunspacePool -Wait | Should -BeTrue
            $sync.Results.Count | Should -Be 2
            @($sync.PoolIds.ToArray() | Select-Object -Unique).Count | Should -Be 1
        } finally {
            $sync.DispatchGate.Set()
            foreach ($request in $requests) { $request.Pipeline.Dispose() }
            $callers.Dispose()
            $sync.DispatchGate.Dispose()
        }
    }

    It 'also protects an active pipeline missing from the bookkeeping dictionary' {
        Initialize-WinUtilRunspacePool
        $pipeline = [powershell]::Create()
        try {
            $pipeline.RunspacePool = $sync.runspace
            $null = $pipeline.AddScript('$sync.WorkerStarted=$true; [Threading.Thread]::Sleep(300); $sync.Results.Enqueue("untracked completed")')
            $handle = $pipeline.BeginInvoke()
            Wait-LifecycleWorkerStarted
            $sync.RunspaceJobs.Count | Should -Be 0
            Close-WinUtilRunspacePool | Should -BeFalse
            $handle.AsyncWaitHandle.WaitOne(5000) | Should -BeTrue
            $null = $pipeline.EndInvoke($handle)
            Close-WinUtilRunspacePool | Should -BeTrue
            $sync.Results.ToArray() | Should -Contain 'untracked completed'
        } finally { $pipeline.Dispose() }
    }

    It 'waits for natural completion only when noninteractive cleanup explicitly requests it' {
        $null = Invoke-WPFRunspace -ScriptBlock {
            $sync.WorkerStarted = $true
            [Threading.Thread]::Sleep(100)
            $sync.Results.Enqueue('wait completed')
        }
        Close-WinUtilRunspacePool -Wait | Should -BeTrue
        $sync.Results.ToArray() | Should -Contain 'wait completed'
        $sync.runspace | Should -BeNullOrEmpty
        $sync.RunspaceJobs.Count | Should -Be 0
    }

    It 'does not reopen a pool or enqueue work after shutdown has begun' {
        Close-WinUtilRunspacePool | Should -BeTrue
        { Invoke-WPFRunspace -ScriptBlock { throw 'must never run' } } | Should -Throw '*closing*'
        { Initialize-WinUtilRunspacePool } | Should -Throw '*closing*'
        $sync.runspace | Should -BeNullOrEmpty
        $sync.RunspaceJobs.Count | Should -Be 0
    }

    It 'releases failed task pipelines without preventing later jobs or idle shutdown' {
        $handle = Invoke-WPFRunspace -ScriptBlock { throw 'fixture failure' }
        $handle.AsyncWaitHandle.WaitOne(5000) | Should -BeTrue
        Complete-WinUtilRunspaceJobs -WarningAction SilentlyContinue
        $sync.RunspaceJobs.Count | Should -Be 0
        $next = Invoke-WPFRunspace -ScriptBlock { $sync.Results.Enqueue('recovered') }
        $next.AsyncWaitHandle.WaitOne(5000) | Should -BeTrue
        Close-WinUtilRunspacePool | Should -BeTrue
        $sync.Results.ToArray() | Should -Contain 'recovered'
    }

    It 'keeps expensive unused inventory, eager pool opening and forced collection out of startup' {
        $main = [IO.File]::ReadAllText((Join-Path $script:lifecycleRoot 'scripts/main.ps1'))
        $main | Should -Not -Match '\bGet-ComputerInfo\b'
        $main | Should -Not -Match '\bCreateRunspacePool\b|\$sync\.runspace\.Open\('
        $main | Should -Not -Match '\[System\.GC\]::Collect\('
        $main | Should -Match 'Close-WinUtilRunspacePool'
    }
}

Describe 'Actual main window closing and automation routes' {
    BeforeEach {
        $script:sync = [hashtable]::Synchronized(@{
            ProcessRunning=$false
            RunspaceJobs=[Collections.Concurrent.ConcurrentDictionary[string,object]]::new()
            Results=[Collections.Concurrent.ConcurrentQueue[string]]::new()
        })
        $script:runspaceCleanupTimer = [Windows.Threading.DispatcherTimer]::new()
        $script:searchBarTimer = [Windows.Threading.DispatcherTimer]::new()
        foreach ($timer in @($runspaceCleanupTimer, $searchBarTimer)) {
            $timer.Interval = [TimeSpan]::FromHours(1)
            $timer.Start()
        }
        [WinUtilLifecycleDialogFixture]::Count = 0
        $script:lifecycleForm = [Windows.Window]::new()
        $sync.Form = $lifecycleForm
        $script:lifecycleClosingHandler = [ComponentModel.CancelEventHandler][scriptblock]::Create($script:lifecycleClosingBody)
        $script:lifecycleClosingObserver = [ComponentModel.CancelEventHandler]{ param($sender, $eventArgs) $sync.LastClosingCancelled = $eventArgs.Cancel }
        $lifecycleForm.Add_Closing($lifecycleClosingHandler)
        $lifecycleForm.Add_Closing($lifecycleClosingObserver)
    }
    AfterEach {
        $lifecycleForm.Remove_Closing($lifecycleClosingHandler)
        $lifecycleForm.Remove_Closing($lifecycleClosingObserver)
        $null = Close-WinUtilRunspacePool -Wait
        $runspaceCleanupTimer.Stop()
        $searchBarTimer.Stop()
        $lifecycleForm.Close()
    }

    It 'retains <BusyFlag> protection and keeps timers available when closing is cancelled' -ForEach @(
        @{BusyFlag='OOSURunning'}, @{BusyFlag='ProcessRunning'}, @{BusyFlag='Win11ISOModifying'},
        @{BusyFlag='Win11ISOExporting'}, @{BusyFlag='Win11ISOWritingUSB'}, @{BusyFlag='Win11ISOCleaning'}
    ) {
        $sync[$BusyFlag] = $true
        $lifecycleForm.Close()
        $sync.LastClosingCancelled | Should -BeTrue
        [WinUtilLifecycleDialogFixture]::Count | Should -Be 1
        $runspaceCleanupTimer.IsEnabled | Should -BeTrue
        $searchBarTimer.IsEnabled | Should -BeTrue
        $sync.RunspaceShuttingDown | Should -Not -BeTrue
        $lifecycleForm.IsVisible | Should -BeFalse
    }

    It 'stops both window timers when an unused home window can close' {
        $lifecycleForm.Close()
        $sync.LastClosingCancelled | Should -BeFalse
        [WinUtilLifecycleDialogFixture]::Count | Should -Be 0
        $runspaceCleanupTimer.IsEnabled | Should -BeFalse
        $searchBarTimer.IsEnabled | Should -BeFalse
        $sync.runspace | Should -BeNullOrEmpty
        $lifecycleForm.IsVisible | Should -BeFalse
    }

    It 'cancels the real close event for an unmarked worker then closes after its natural completion' {
        $handle = Invoke-WPFRunspace -ScriptBlock {
            $sync.WorkerStarted = $true
            [Threading.Thread]::Sleep(300)
            $sync.Results.Enqueue('finished before closing')
        }
        Wait-LifecycleWorkerStarted
        $lifecycleForm.Close()
        $sync.LastClosingCancelled | Should -BeTrue
        $runspaceCleanupTimer.IsEnabled | Should -BeTrue
        $searchBarTimer.IsEnabled | Should -BeTrue
        $handle.AsyncWaitHandle.WaitOne(5000) | Should -BeTrue
        $lifecycleForm.Close()
        $sync.LastClosingCancelled | Should -BeFalse
        $runspaceCleanupTimer.IsEnabled | Should -BeFalse
        $searchBarTimer.IsEnabled | Should -BeFalse
        $sync.Results.ToArray() | Should -Contain 'finished before closing'
        $sync.runspace | Should -BeNullOrEmpty
    }

    It 'keeps the actual <Mode> branch waiting for requested work before ending the transcript' -ForEach @(@{Mode='Preset'}, @{Mode='Config'}) {
        $sync.Form = $null
        $sync.configs = @{preset=@{Minimal=@('fixture')}}
        $Preset = if ($Mode -eq 'Preset') { 'Minimal' } else { $null }
        $Config = if ($Mode -eq 'Config') { 'fixture.json' } else { $null }
        function Update-WinUtilSelections { param($flatJson) }
        function Invoke-WPFImpex { param($type, $Config) }
        function Invoke-WinUtilAutoRun {
            $null = Invoke-WPFRunspace -ScriptBlock { [Threading.Thread]::Sleep(50); $sync.Results.Enqueue('automation done') }
        }
        function Stop-Transcript {
            if ($sync.runspace -or $sync.Results.Count -ne 1) { throw 'Transcript ended before cleanup completed.' }
            $sync.TranscriptStopped = $true
        }
        $branch = @($script:lifecycleMainAst.EndBlock.Statements | Where-Object {
            $_ -is [Management.Automation.Language.IfStatementAst] -and $_.Clauses[0].Item1.Extent.Text -eq ('$' + $Mode)
        })
        $branch.Count | Should -Be 1
        & ([scriptblock]::Create($branch[0].Extent.Text))
        $sync.TranscriptStopped | Should -BeTrue
        $sync.Results.ToArray() | Should -Contain 'automation done'
        $sync.runspace | Should -BeNullOrEmpty
    }
}
