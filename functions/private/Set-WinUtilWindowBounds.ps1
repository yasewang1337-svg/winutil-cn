function Set-WinUtilWindowBounds {
    <# .SYNOPSIS
        Fit the initial window in WPF device-independent units, including high DPI desktops.
    #>
    param(
        [Parameter(Mandatory)]$Window,
        $WorkArea = [System.Windows.SystemParameters]::WorkArea
    )
    $Window.MinWidth = [Math]::Min(800, $WorkArea.Width)
    $Window.MinHeight = [Math]::Min(600, $WorkArea.Height)
    $Window.Width = [Math]::Min(1100, $WorkArea.Width)
    $Window.Height = [Math]::Min(760, $WorkArea.Height)
}
