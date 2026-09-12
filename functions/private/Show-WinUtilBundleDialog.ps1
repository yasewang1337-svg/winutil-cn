function Show-WinUtilBundleDialog {
    <# .SYNOPSIS
        Returns the user's bundle selection. Closing or cancelling never returns selected apps.
    #>
    param(
        [Parameter(Mandatory)]$Bundle,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Plan,
        $Owner
    )
    $dialog = New-WinUtilBundleDialog -Bundle $Bundle -Plan $Plan -Owner $Owner
    $confirmed = $dialog.ShowDialog() -eq $true
    $selected = @()
    if ($confirmed) {
        $selected = @($dialog.Tag.Choices | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
    }
    [pscustomobject]@{ Confirmed = $confirmed; Apps = $selected }
}
