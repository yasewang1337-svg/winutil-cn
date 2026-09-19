<#
.NOTES
    Author         : Chris Titus @christitustech
    Runspace Author: @DeveloperDurp
    GitHub         : https://github.com/ChrisTitusTech
    Version        : #{replaceme}
#>

param (
    [string]$Config,
    [ValidateSet("Standard", "Minimal", "Advanced", "")]
    [string]$Preset,
    [switch]$Offline
)

$PARAM_OFFLINE = $false
if ($Offline) {
    $PARAM_OFFLINE = $true
}

if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host "WinUtil is unable to run on your system. PowerShell execution is restricted by security policies." -ForegroundColor Red
    return
}

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if (-not $PSCommandPath) {
        Write-Warning "请从项目发布页下载本地版 WinUtil-CN，再右键选择以管理员身份运行。当前在线脚本调用不会自动下载或提权。"
        return
    }

    # Start-Process joins ArgumentList into a Windows command line. Quote each
    # value using the native argument rules, never as executable PowerShell text.
    function ConvertTo-WinUtilStartupArgument {
        param([AllowEmptyString()][string]$Value)
        '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
    }

    $powershellName = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
    $powershellPath = Join-Path $PSHOME $powershellName
    $argList = @('-NoProfile', '-ExecutionPolicy', 'RemoteSigned', '-File', (ConvertTo-WinUtilStartupArgument $PSCommandPath))
    foreach ($name in @('Config', 'Preset')) {
        if ($PSBoundParameters.ContainsKey($name)) {
            $argList += "-$name"
            $argList += ConvertTo-WinUtilStartupArgument ([string]$PSBoundParameters[$name])
        }
    }
    if ($PSBoundParameters.ContainsKey('Offline') -and $PSBoundParameters['Offline']) {
        $argList += '-Offline'
    }

    Write-Output "WinUtil 需要管理员权限，正在请求启动本地脚本。"
    try {
        Start-Process -FilePath $powershellPath -ArgumentList ($argList -join ' ') -Verb RunAs -ErrorAction Stop
    } catch {
        Write-Warning "未能以管理员身份启动 WinUtil。请确认启动请求并检查文件权限或系统策略。$($_.Exception.Message)"
    }
    return
}

# Load DLLs
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Variable to sync between runspaces
$sync = [Hashtable]::Synchronized(@{})
$sync.PSScriptRoot = $PSScriptRoot
$sync.version = "#{replaceme}"
$sync.configs = @{}
$sync.Buttons = [System.Collections.Generic.List[PSObject]]::new()
$sync.preferences = @{}
$sync.ProcessRunning = $false
$sync.RunspaceJobs = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::new()
$sync.selectedApps = [System.Collections.Generic.List[string]]::new()
$sync.selectedTweaks = [System.Collections.Generic.List[string]]::new()
$sync.selectedToggles = [System.Collections.Generic.List[string]]::new()
$sync.selectedFeatures = [System.Collections.Generic.List[string]]::new()
$sync.currentTab = "WPFTab6"
$sync.selectedAppsStackPanel
$sync.selectedAppsPopup

$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Set the path for the winutil directory
$winutildir = "$env:LocalAppData\winutil"
New-Item $winutildir -ItemType Directory -Force | Out-Null

$logdir = "$winutildir\logs"
New-Item $logdir -ItemType Directory -Force | Out-Null
Start-Transcript -Path "$logdir\winutil_$dateTime.log" -Append -NoClobber | Out-Null

# Set PowerShell window title
$Host.UI.RawUI.WindowTitle = "WinUtil (Admin)"
clear-host
