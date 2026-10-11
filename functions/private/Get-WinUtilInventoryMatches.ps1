function Get-WinUtilInventoryMatches {
    <# Catalog combinations match only when every configured package is present. #>
    param(
        [Parameter(Mandatory)][ValidateSet('Winget', 'Choco')][string]$Manager,
        [AllowEmptyCollection()][object[]]$Programs = @(),
        [Parameter(Mandatory)]$Applications
    )
    $installed = @{}
    foreach ($program in $Programs) {
        if ($program.Manager -eq $Manager -and $program.Id) { $installed[[string]$program.Id] = $true }
    }
    $keys = if ($Applications -is [Collections.IDictionary]) { @($Applications.Keys) } else { @($Applications.PSObject.Properties.Name) }
    foreach ($key in ($keys | Sort-Object)) {
        if ([string]$key -notlike 'WPFInstall*') { continue }
        $entry = $Applications.$key
        $ids = @(([string]$entry.$Manager -split ';') | ForEach-Object { $_.Trim() })
        if (-not $ids.Count -or @($ids | Where-Object { $_ -eq 'na' -or $_ -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]*$' }).Count) { continue }
        if (@($ids | Where-Object { -not $installed.ContainsKey($_) }).Count -eq 0) { [string]$key }
    }
}
