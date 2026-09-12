param([Parameter(Mandatory)][string]$LogRoot)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$env:LOCALAPPDATA=$LogRoot
$names=@('Get-WinUtilPackagePlan','Get-WinUtilPackageExitResult','Invoke-WinUtilPackageProcess','Install-WinUtilProgramWinget','Install-WinUtilProgramChoco','Invoke-WinUtilPackageBatch','Show-WinUtilPackageDialog','Invoke-WinUtilPackageOperation','Initialize-WinUtilPackageUiCallbacks','Invoke-WinUtilPackageUiAction','Show-WPFInstallAppBusy','Hide-WPFInstallAppBusy','Invoke-WPFUIThread','Invoke-WPFRunspace','Complete-WinUtilRunspaceJobs')
foreach($name in $names){$file=Get-ChildItem (Join-Path $root 'functions') -Recurse -Filter "$name.ps1" | Select-Object -First 1;. ([scriptblock]::Create((Get-Content $file.FullName -Raw -Encoding UTF8)))}
. ([scriptblock]::Create((Get-Content (Join-Path $root 'functions/private/Invoke-WinUtilPackageBatch.ps1') -Raw -Encoding UTF8).Replace("[Environment]::GetFolderPath('LocalApplicationData')", '$env:LOCALAPPDATA')))
$sync=[hashtable]::Synchronized(@{Form=(New-Object Windows.Window);ProcessRunning=$false;DialogCount=0;ProcessCalls=0;FailedAttempts=0;MainThread=[Threading.Thread]::CurrentThread.ManagedThreadId;preferences=@{packagemanager='Winget'}})
$sync.InstallAppAreaOverlay=New-Object Windows.Controls.Border
$sync.InstallAppAreaOverlayText=New-Object Windows.Controls.TextBlock
$sync.InstallAppAreaBorder=New-Object Windows.Controls.Border
$sync.InstallAppAreaScrollViewer=New-Object Windows.Controls.ScrollViewer
$sync.InstallAppAreaScrollViewer.Effect=New-Object Windows.Media.Effects.BlurEffect
function Set-WinUtilTaskbaritem {param($state,$overlay) $sync.TaskbarThread=[Threading.Thread]::CurrentThread.ManagedThreadId }
function Show-WinUtilPackageDialog {
 param($Title,$Description,$Details,$PrimaryLabel,$CloseLabel,$LogDirectory)
 $sync.DialogCount++;$sync.DialogThread=[Threading.Thread]::CurrentThread.ManagedThreadId
 if($sync.DialogCount -le 2){return 'Primary'}else{return 'Close'}
}
function Invoke-WinUtilPackageProcess {
 param($FilePath,$Arguments,$LogDirectory,$LogName)
 $sync.ProcessCalls++
 $exitCode=0
 if($Arguments[2] -eq 'Example.Failed'){$sync.FailedAttempts++;if($sync.FailedAttempts -eq 1){$exitCode=123}}
 [pscustomobject]@{ExitCode=$exitCode;OutputPath='mock-output';ErrorPath='mock-error'}
}
function Get-WinUtilPackageManagerPresence {return $true}
function Get-Command {
 param($Name,$CommandType,$ErrorAction)
 if($Name -in @('winget.exe','choco.exe')){[pscustomobject]@{Source='mock.exe'}}
 else {Microsoft.PowerShell.Core\Get-Command -Name $Name -ErrorAction SilentlyContinue}
}
$initial=[System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$initial.Variables.Add([System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('sync',$sync,''))
Get-ChildItem function:\ | Where-Object {$_.Name -match 'WinUtil|WPF' -or $_.Name -eq 'Get-Command'} | ForEach-Object {$initial.Commands.Add([System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($_.Name,$_.Definition))}
$sync.runspace=[runspacefactory]::CreateRunspacePool(1,1,$initial,$Host);$sync.runspace.Open()
$plan=@(Get-WinUtilPackagePlan -Packages @([pscustomobject]@{content='Good';winget='Example.Good'},[pscustomobject]@{content='Failed first';winget='Example.Failed'}))
Invoke-WinUtilPackageOperation -Plan $plan
$frame=New-Object Windows.Threading.DispatcherFrame
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromMilliseconds(50);$started=[datetime]::UtcNow
$timer.Add_Tick({if((-not $sync.ProcessRunning -and $sync.DialogCount -eq 3 -and @($sync.RunspaceJobs.Values | Where-Object { -not $_.Handle.IsCompleted }).Count -eq 0) -or ([datetime]::UtcNow-$started).TotalSeconds -gt 5){$frame.Continue=$false}})
$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame);$timer.Stop()
if($sync.ProcessRunning){throw 'Package worker timed out'}
if($sync.DialogCount -ne 3 -or $sync.ProcessCalls -ne 3 -or $sync.DialogThread -ne $sync.MainThread -or $sync.TaskbarThread -ne $sync.MainThread){throw ('Unexpected execution: '+($sync | Select-Object DialogCount,ProcessCalls,DialogThread,MainThread | ConvertTo-Json))}
if($sync.InstallAppAreaOverlay.Visibility -ne 'Collapsed' -or -not $sync.InstallAppAreaBorder.IsEnabled){throw 'Busy overlay was not released'}
if(@($sync.LastPackageResults | Where-Object Status -ne 'Succeeded').Count){throw 'Failed-only retry did not complete'}
Complete-WinUtilRunspaceJobs
$sync.runspace.Close();$sync.runspace.Dispose();$sync.Form.Close()
Write-Output "PowerShell $($PSVersionTable.PSVersion): package worker, real WPF dispatch, failed-only retry, thread identity and busy cleanup passed; native mock calls=$($sync.ProcessCalls)"
