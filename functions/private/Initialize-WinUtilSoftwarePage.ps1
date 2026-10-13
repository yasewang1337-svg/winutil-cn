function Initialize-WinUtilSoftwarePage {
    <# .SYNOPSIS Builds the software page once, preserving selections made before it opens. #>
    if (-not $sync.SoftwarePageDeferred) { return }
    if ($sync.SoftwarePageInitializing) { return }
    $sync.SoftwarePageInitializing = $true
    $previousCursor = [Windows.Input.Mouse]::OverrideCursor
    try {
        [Windows.Input.Mouse]::OverrideCursor = [Windows.Input.Cursors]::Wait
        Initialize-WPFUI -TargetGridName 'appspanel' -ReuseContainer
        # Mark ready only after successful construction. A failed attempt can
        # be retried; the catalog builder clears its previous categories.
        $sync.SoftwarePageDeferred = $false
    } finally {
        [Windows.Input.Mouse]::OverrideCursor = $previousCursor
        $sync.SoftwarePageInitializing = $false
    }
}
