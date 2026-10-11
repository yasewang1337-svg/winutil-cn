function Test-WinUtilInventoryCurrent {
    <# A snapshot is usable only for its source and until the next package operation. #>
    param($Inventory, [ValidateSet('Winget', 'Choco')][string]$Manager = 'Winget')
    return $null -ne $Inventory -and $Inventory.Manager -eq $Manager -and
        $null -ne $Inventory.CompletedAt -and -not $Inventory.IsStale
}
