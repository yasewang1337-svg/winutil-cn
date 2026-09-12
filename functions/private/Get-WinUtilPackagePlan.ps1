function Get-WinUtilPackagePlan {
    <# Creates a stable, deduplicated plan without changing the computer. #>
    param(
        [AllowEmptyCollection()][object[]]$Packages = @(),
        [ValidateSet('Winget', 'Choco')][string]$Preference = 'Winget',
        [ValidateSet('Install', 'Uninstall', 'UpgradeAll')][string]$Action = 'Install'
    )

    if ($Action -eq 'UpgradeAll') {
        return [pscustomobject]@{
            Id = "${Preference}:all"; PackageId = 'all'; Manager = $Preference
            Name = "$Preference 可识别的所有软件"; Action = $Action; InvalidReason = ''
        }
    }

    $seen = @{}
    $index = 0
    foreach ($package in $Packages) {
        if ($null -eq $package) { continue }
        $index++
        $manager = $Preference
        $packageId = [string]$package.$Preference
        if ($Preference -eq 'Choco' -and ([string]::IsNullOrWhiteSpace($packageId) -or $packageId -eq 'na')) {
            $manager = 'Winget'
            $packageId = [string]$package.winget
        }
        $name = [string]$package.content
        if ([string]::IsNullOrWhiteSpace($name)) { $name = [string]$package.Name }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = $packageId }
        # The catalog uses a semicolon-separated Chocolatey list for GitHub Desktop.
        # Expand it into independent reviewed entries; never pass delimiters to a shell.
        $packageIds = @($packageId)
        if ($manager -eq 'Choco') { $packageIds = @($packageId -split ';') }
        foreach ($candidate in $packageIds) {
            $candidate = $candidate.Trim()
            $invalidReason = ''
            if ($candidate -eq 'na' -or $candidate -eq 'all' -or $candidate -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]*$') {
                $invalidReason = '此软件缺少有效的软件包编号，未执行。请更新软件目录后重试。'
            }
            $id = "${manager}:$candidate"
            if ($invalidReason) { $id = "Unavailable:${index}:${name}:$candidate" }
            if ($seen.ContainsKey($id)) { continue }
            $seen[$id] = $true
            $entryName = $name
            if ($packageIds.Count -gt 1) { $entryName = "$name（$candidate）" }
            [pscustomobject]@{
                Id = $id; PackageId = $candidate; Manager = $manager; Name = $entryName
                Action = $Action; InvalidReason = $invalidReason
            }
        }
    }
}
