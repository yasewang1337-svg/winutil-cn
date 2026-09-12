function Invoke-WPFInstallUpgrade {
    param([switch]$NonInteractive)
    $preference = [string]$sync.preferences.packagemanager
    if ($preference -notin @('Winget', 'Choco')) { $preference = 'Winget' }
    $plan = @(Get-WinUtilPackagePlan -Preference $preference -Action UpgradeAll)
    Invoke-WinUtilPackageOperation -Plan $plan -NonInteractive:$NonInteractive
}
