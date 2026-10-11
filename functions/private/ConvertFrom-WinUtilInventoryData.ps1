function ConvertFrom-WinUtilInventoryData {
    <# Parses a complete machine-readable inventory. Never treats unknown text as an empty inventory. #>
    param(
        [Parameter(Mandatory)][ValidateSet('Winget', 'Choco')][string]$Manager,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    $programs = [Collections.Generic.List[object]]::new()
    $seen = @{}
    if ($Manager -eq 'Winget') {
        try { $document = ConvertFrom-Json -InputObject $Text -ErrorAction Stop }
        catch { throw 'WinGet 导出的清单不是完整的 JSON，本次检测结果未采用。' }
        if ($null -eq $document -or $document -is [array] -or
            $null -eq $document.PSObject.Properties['Sources'] -or
            $document.Sources -isnot [array]) {
            throw 'WinGet 导出清单缺少有效的 Sources 数组，本次检测结果未采用。'
        }
        foreach ($source in $document.Sources) {
            if ($null -eq $source -or $null -eq $source.SourceDetails -or
                $source.SourceDetails.Name -cne 'winget' -or
                $source.SourceDetails.Identifier -cne 'Microsoft.Winget.Source_8wekyb3d8bbwe' -or
                $source.SourceDetails.Type -cne 'Microsoft.PreIndexed.Package' -or
                $source.SourceDetails.Argument -isnot [string] -or
                [string]::IsNullOrWhiteSpace($source.SourceDetails.Argument)) {
                throw 'WinGet 导出清单含有非官方 winget 来源，本次检测结果未采用。'
            }
            if ($null -eq $source.PSObject.Properties['Packages'] -or $source.Packages -isnot [array] -or $source.Packages.Count -eq 0) {
                throw 'WinGet 导出清单缺少有效的 Packages 数组，本次检测结果未采用。'
            }
            foreach ($package in $source.Packages) {
                if ($null -eq $package -or $package.PackageIdentifier -isnot [string] -or
                    $package.PackageIdentifier.Length -gt 128 -or
                    $package.PackageIdentifier -notmatch '^[^.\s\\/:*?"<>|\x00-\x1f]{1,32}(\.[^.\s\\/:*?"<>|\x00-\x1f]{1,32}){1,7}$' -or
                    $package.PackageIdentifier -match '…|\.\.\.' -or
                    ($null -ne $package.PSObject.Properties['Version'] -and $package.Version -isnot [string])) {
                    throw 'WinGet 清单含有损坏或截断的软件编号/版本，本次检测结果未采用。'
                }
                $id = [string]$package.PackageIdentifier
                $version = [string]$package.Version
                # Parallel versions/user and machine installations can share an ID.
                $fingerprint = "$id`0$version"
                if ($seen.ContainsKey($fingerprint)) { continue }
                $seen[$fingerprint] = $true
                $programs.Add([pscustomobject]@{ Id = $id; Version = $version; Manager = 'Winget' })
            }
        }
    } else {
        foreach ($line in ($Text -split '\r?\n')) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line -notmatch '^([A-Za-z0-9][A-Za-z0-9._+-]*)\|([^|\s]+)\s*$') {
                throw 'Chocolatey 返回了无法识别的清单行，本次检测结果未采用。'
            }
            $id = $Matches[1]; $version = $Matches[2]
            $fingerprint = "$id`0$version"
            if ($seen.ContainsKey($fingerprint)) { continue }
            $seen[$fingerprint] = $true
            $programs.Add([pscustomobject]@{ Id = $id; Version = $version; Manager = 'Choco' })
        }
    }
    return $programs.ToArray()
}
