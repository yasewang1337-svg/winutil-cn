function Install-WinUtilProgramChoco {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("Install", "Uninstall", "UpgradeAll")]
        [string]$Action,

        [Parameter(Mandatory=$true)]
        [string[]]$Programs,

        [Parameter(Mandatory=$true)][string]$LogDirectory
    )

    foreach ($program in $Programs) {
        if ($program -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]*$' -or ($program -eq 'all' -and $Action -ne 'UpgradeAll')) {
            throw '无效的软件包编号。'
        }
        $verb = $Action.ToLowerInvariant()
        if ($Action -eq 'UpgradeAll') { $verb = 'upgrade'; $program = 'all' }
        $arguments = @($verb, $program, '-y', '--no-progress', '--use-package-exit-codes')
        Invoke-WinUtilPackageProcess -FilePath 'choco.exe' -Arguments $arguments -LogDirectory $LogDirectory -LogName ('choco-' + $program)
    }
}
