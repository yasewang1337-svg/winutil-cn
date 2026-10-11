function Invalidate-WinUtilInventory {
    <# Keep historical evidence, but never use it for current installed-state decisions. #>
    param([string]$Reason = '软件状态可能已变化，')
    if ($null -eq $sync) { return }
    if ($sync.SoftwareInventory) {
        $sync.SoftwareInventory | Add-Member -MemberType NoteProperty -Name IsStale -Value $true -Force
    }
    $sync.InventoryInvalidationReason = $Reason
    $sync.InventoryOperationError = ''
    Update-WinUtilInventoryUi
}
