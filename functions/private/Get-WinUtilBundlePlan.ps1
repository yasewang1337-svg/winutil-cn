function Get-WinUtilBundlePlan {
    <#
    .SYNOPSIS
        Builds a read-only preview from a bundle, application catalog and optional install cache.
        Missing cache entries remain unknown: a WinGet list is not a complete inventory.
    #>
    param(
        [Parameter(Mandatory)]$Bundle,
        [Parameter(Mandatory)]$Applications,
        [string[]]$SelectedApps = @(),
        [object[]]$InstalledPrograms = @()
    )

    $seen = @{}
    foreach ($id in $Bundle.apps) {
        $id = [string]$id
        if ([string]::IsNullOrWhiteSpace($id) -or $seen.ContainsKey($id)) { continue }
        $seen[$id] = $true
        $app = $Applications.$id
        $valid = $id.StartsWith('WPFInstall') -and $null -ne $app
        $alreadySelected = $valid -and $SelectedApps -contains $id
        $installed = $null
        if ($valid -and $app.winget) {
            # The final package is the application; preceding IDs can be dependencies.
            $packageId = ([string]$app.winget -split ';')[-1].Trim()
            $installed = $InstalledPrograms | Where-Object {
                $_.Id -and ([string]$_.Id).Trim() -eq $packageId
            } | Select-Object -First 1
        }
        $purpose = if ($Bundle.purposes) { [string]$Bundle.purposes.$id } else { '' }
        $recommended = $valid -and $Bundle.defaultApps -contains $id
        [pscustomobject]@{
            Id = $id
            Name = if ($valid) { [string]$app.content } else { $id }
            Description = if ($valid) { [string]$app.description } else { '当前软件目录找不到此项，暂时无法选择。' }
            Purpose = $purpose
            IsAvailable = $valid
            AlreadySelected = $alreadySelected
            IsRecommended = $recommended
            IsSelected = $alreadySelected -or ($recommended -and $null -eq $installed)
            InstallState = if ($installed) { 'Installed' } else { 'Unknown' }
            InstalledVersion = if ($installed) { [string]$installed.Version } else { '' }
        }
    }
}
