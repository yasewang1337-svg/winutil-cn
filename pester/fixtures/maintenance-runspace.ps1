$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
foreach ($relative in @(
    'functions/public/Invoke-WPFFeatureInstall.ps1',
    'functions/public/Invoke-WPFGetInstalled.ps1',
    'functions/public/Invoke-WPFRunspace.ps1',
    'functions/private/Complete-WinUtilRunspaceJobs.ps1'
)) {
    . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root $relative))))
}
$sync = [hashtable]::Synchronized(@{
    Form = [Windows.Window]::new()
    ProcessRunning = $false
    MainThread = [Threading.Thread]::CurrentThread.ManagedThreadId
    preferences = @{ packagemanager = 'Winget' }
    selectedFeatures = @('Feature.One', 'Feature.Two')
    WPFInstallExample = [Windows.Controls.CheckBox]::new()
    Events = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
    Scenario = ''
    FailOperation = $false
})

# Only these harmless stubs cross into the worker. No installer or inventory provider is loaded.
function Add-WinUtilFixtureEvent {
    param($Kind, $Value)
    $sync.Events.Enqueue([pscustomobject]@{
        Scenario = $sync.Scenario; Kind = $Kind; Value = $Value
        Thread = [Threading.Thread]::CurrentThread.ManagedThreadId
        Busy = $sync.ProcessRunning
    })
}
function Invoke-WinUtilFeatureInstall {
    param($CheckBox)
    Add-WinUtilFixtureEvent 'FeatureWorker' $CheckBox
    if ($sync.FailOperation) { throw 'simulated feature failure' }
}
function Invoke-WinUtilCurrentSystem {
    param($CheckBox)
    Add-WinUtilFixtureEvent 'InventoryWorker' $CheckBox
    if ($sync.FailOperation) { throw 'simulated inventory failure' }
    'WPFInstallExample'
}
function Test-WinUtilPackageManager { param([switch]$winget); 'installed' }
function Set-WinUtilTaskbaritem {
    param($state, $value, $overlay)
    Add-WinUtilFixtureEvent 'Taskbar' "$state/$overlay/$value"
}
function Show-WinUtilTweakDialog {
    param($Title, $Message)
    Add-WinUtilFixtureEvent 'Dialog' $Message
}
$sync.WPFInstallExample.Add_Checked({ Add-WinUtilFixtureEvent 'Checkbox' 'checked' })

$initial = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$initial.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('sync', $sync, ''))
# An explicit allowlist makes accidental execution of a real system-operation function impossible.
foreach ($name in @('Add-WinUtilFixtureEvent', 'Invoke-WinUtilFeatureInstall', 'Invoke-WinUtilCurrentSystem')) {
    $definition = (Get-Command $name -CommandType Function).Definition
    $initial.Commands.Add([Management.Automation.Runspaces.SessionStateFunctionEntry]::new($name, $definition))
}
$sync.runspace = [runspacefactory]::CreateRunspacePool(1, 1, $initial, $Host)
$sync.runspace.Open()
$timer = [Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(25)
$timer.Add_Tick({
    $pending = @($sync.RunspaceJobs.Values | Where-Object { -not $_.Handle.IsCompleted }).Count
    if (($pending -eq 0 -and -not $sync.ProcessRunning) -or [DateTime]::UtcNow -gt $sync.WaitDeadline) {
        $sync.WaitFrame.Continue = $false
    }
})
try {
    # Success after failure exercises dispatch reuse rather than only first-call initialization.
    foreach ($scenario in @('InventorySuccess', 'InventoryFailure', 'InventoryRetry', 'FeatureSuccess', 'FeatureFailure', 'FeatureRetry')) {
        $sync.Scenario = $scenario
        $sync.FailOperation = $scenario -match 'Failure$'
        $sync.WPFInstallExample.IsChecked = $false
        if ($scenario -like 'Inventory*') { Invoke-WPFGetInstalled -checkbox winget }
        else { Invoke-WPFFeatureInstall }
        if (-not $sync.ProcessRunning) { throw "$scenario did not reserve busy before returning to the UI" }
        $jobs = @($sync.RunspaceJobs.Values)
        $sync.WaitFrame = [Windows.Threading.DispatcherFrame]::new()
        $sync.WaitDeadline = [DateTime]::UtcNow.AddSeconds(5)
        $timer.Start()
        [Windows.Threading.Dispatcher]::PushFrame($sync.WaitFrame)
        $timer.Stop()
        if ($sync.ProcessRunning -or @($jobs | Where-Object { -not $_.Handle.IsCompleted }).Count) {
            throw "$scenario worker or UI callback timed out"
        }
        foreach ($job in $jobs) {
            if ($job.Pipeline.Streams.Error.Count) { throw "$scenario worker error: $($job.Pipeline.Streams.Error -join '; ')" }
        }
        $events = @($sync.Events.ToArray() | Where-Object Scenario -eq $scenario)
        $workers = @($events | Where-Object { $_.Kind -like '*Worker' })
        $uiEvents = @($events | Where-Object { $_.Kind -notlike '*Worker' })
        $expectedWorkerCount = if ($scenario -like 'Feature*' -and -not $sync.FailOperation) { 2 } else { 1 }
        if ($workers.Count -ne $expectedWorkerCount -or @($workers | Where-Object Thread -eq $sync.MainThread).Count) {
            throw "$scenario did not execute the harmless task on a worker thread"
        }
        if (-not $uiEvents.Count -or @($uiEvents | Where-Object Thread -ne $sync.MainThread).Count) {
            throw "$scenario callbacks did not execute on the UI thread"
        }
        if (@($events | Where-Object { -not $_.Busy }).Count) { throw "$scenario released busy before a task/callback finished" }
        $dialogs = @($events | Where-Object Kind -eq 'Dialog')
        if ($sync.FailOperation) {
            if ($dialogs.Count -ne 1 -or $dialogs[0].Value -notmatch 'simulated .* failure') { throw "$scenario did not present the error on the UI thread" }
            if (@($events | Where-Object { $_.Kind -eq 'Taskbar' -and $_.Value -match 'checkmark' }).Count) { throw "$scenario reported false success" }
        } else {
            if ($dialogs.Count) { throw "$scenario unexpectedly opened an error dialog" }
            if ($scenario -like 'Inventory*' -and (-not $sync.WPFInstallExample.IsChecked -or @($events | Where-Object Kind -eq 'Checkbox').Count -ne 1)) {
                throw "$scenario did not apply the checkbox through the UI dispatcher"
            }
        }
        Complete-WinUtilRunspaceJobs
        if ($sync.RunspaceJobs.Count -ne 0) { throw "$scenario did not release completed pipelines" }
    }
} finally {
    $timer.Stop()
    # The parent test also enforces a hard process deadline if a broken dispatcher prevents teardown.
    foreach ($job in @($sync.RunspaceJobs.Values)) {
        if (-not $job.Handle.IsCompleted) { $null = $job.Pipeline.BeginStop($null, $null) }
    }
    $sync.Form.Dispatcher.InvokeShutdown()
    foreach ($job in @($sync.RunspaceJobs.Values)) { $job.Pipeline.Dispose() }
    $sync.runspace.Close()
    $sync.runspace.Dispose()
    $sync.Form.Close()
}
Write-Output "PowerShell $($PSVersionTable.PSVersion): maintenance worker and real WPF dispatcher passed; scenarios=6; callbacks kept busy; no system commands"
