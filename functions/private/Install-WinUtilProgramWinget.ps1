Function Install-WinUtilProgramWinget {
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
        $arguments = @($Action.ToLowerInvariant(), '--id', $program, '--exact', '--source', 'winget', '--silent', '--accept-source-agreements', '--disable-interactivity')
        if ($Action -eq 'Install') { $arguments += '--accept-package-agreements' }
        if ($Action -eq 'UpgradeAll') {
            $arguments = @('upgrade', '--all', '--source', 'winget', '--silent', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')
        }
        Invoke-WinUtilPackageProcess -FilePath 'winget.exe' -Arguments $arguments -LogDirectory $LogDirectory -LogName ('winget-' + $program)
    }
}
