function Invoke-WPFInstall {
    param(
        [object[]]$PackagesToInstall = @($sync.selectedApps | ForEach-Object { $sync.configs.applicationsHashtable.$_ }),
        [switch]$NonInteractive
    )
    $preference = [string]$sync.preferences.packagemanager
    if ($preference -notin @('Winget', 'Choco')) { $preference = 'Winget' }
    $plan = @(Get-WinUtilPackagePlan -Packages $PackagesToInstall -Preference $preference -Action Install)
    Invoke-WinUtilPackageOperation -Plan $plan -NonInteractive:$NonInteractive
}
