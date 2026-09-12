$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$env:LOCALAPPDATA = Join-Path $env:TEMP ('winutil-tweak-runspace-' + [guid]::NewGuid().ToString('N'))
$names = @('Get-WinUtilTweakRegistryState','Get-WinUtilTweakHistory','Save-WinUtilTweakHistory','Restore-WinUtilTweakHistory','Set-WinUtilRegistry','Set-WinUtilService','Invoke-WinUtilTweaks','Invoke-WinUtilTweakBatch','Invoke-WPFTweakHistory','Invoke-WPFUIThread','Initialize-WinUtilTweakUiCallbacks')
foreach ($name in $names) {
    $file = Get-ChildItem (Join-Path $root 'functions') -Recurse -Filter "$name.ps1" | Select-Object -First 1
    . ([scriptblock]::Create((Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8)))
}
$sync = [hashtable]::Synchronized(@{
    Form = (New-Object Windows.Window); ProcessRunning = $true; WriterCalls = 0; DialogMessage = ''
    configs = @{ tweaks = @{ Example = [pscustomobject]@{ Content = '隔离设置'; registry = @([pscustomobject]@{ Path='HKCU:\MockOnly'; Name='Enabled'; Type='DWord'; Value=1; OriginalValue=0 }) } } }
})
function Get-WinUtilTweakRegistryState {
    param($Path,$Name)
    [pscustomobject]@{Kind='Registry';Path=$Path;Name=$Name;Exists=$true;ValueType='DWord';Value=0;State='Pending'}
}
function Set-WinUtilRegistry { param($Path,$Name,$Type,$Value); $sync.WriterCalls++ }
function Set-WinUtilProgressBar { param($Label,$Percent) }
function Set-WinUtilTaskbaritem { param($state) }
function Show-WinUtilTweakDialog { param($Title,$Message); $sync.DialogMessage=$Message; $sync.DialogThread=[Threading.Thread]::CurrentThread.ManagedThreadId }
Initialize-WinUtilTweakUiCallbacks
$initial = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$initial.Variables.Add((New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry('sync',$sync,'')))
Get-ChildItem function:\ | Where-Object Name -Match 'WinUtil|WPF' | ForEach-Object {
    $initial.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($_.Name,$_.Definition)))
}
$pool = [runspacefactory]::CreateRunspacePool(1,1,$initial,$Host)
$pool.Open()
$worker = [powershell]::Create()
$worker.RunspacePool=$pool
$null=$worker.AddScript('Invoke-WinUtilTweakBatch -Tweaks @("Example")')
$pending=$worker.BeginInvoke()
$frame=New-Object Windows.Threading.DispatcherFrame
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromMilliseconds(50)
$started=[datetime]::UtcNow
$timer.Add_Tick({ if(($pending.IsCompleted -and $sync.DialogMessage) -or ([datetime]::UtcNow-$started).TotalSeconds -gt 20){$frame.Continue=$false} })
$timer.Start()
[Windows.Threading.Dispatcher]::PushFrame($frame)
$timer.Stop()
if (-not $pending.IsCompleted) { $worker.Stop(); throw 'Worker UI callback timed out' }
$worker.EndInvoke($pending) | Out-Null
if ($worker.Streams.Error.Count) { throw ($worker.Streams.Error | Out-String) }
if ($sync.WriterCalls -ne 1 -or $sync.ProcessRunning -or $sync.LastTweakResults[0].Status -ne 'Success' -or $sync.DialogMessage -notlike '*隔离设置*') { throw 'Unexpected worker result' }
if ($sync.DialogThread -ne [Threading.Thread]::CurrentThread.ManagedThreadId) { throw 'Result dialog did not execute on UI thread' }
$worker.Dispose(); $pool.Dispose(); $sync.Form.Close()
Write-Output "PowerShell $($PSVersionTable.PSVersion): real worker dispatch and WPF dispatcher callback passed; mock writes=$($sync.WriterCalls)"
