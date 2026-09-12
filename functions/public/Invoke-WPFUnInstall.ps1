function Invoke-WPFUnInstall {
    param(
        [object[]]$PackagesToUninstall = @($sync.selectedApps | ForEach-Object { $sync.configs.applicationsHashtable.$_ }),
        [switch]$NonInteractive
    )
    $preference = [string]$sync.preferences.packagemanager
    if ($preference -notin @('Winget', 'Choco')) { $preference = 'Winget' }
    $plan = @(Get-WinUtilPackagePlan -Packages $PackagesToUninstall -Preference $preference -Action Uninstall)
    Invoke-WinUtilPackageOperation -Plan $plan -NonInteractive:$NonInteractive
}
