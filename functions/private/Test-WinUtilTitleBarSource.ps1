function Test-WinUtilTitleBarSource {
    <# .SYNOPSIS Allows dragging the title and empty title-bar space without stealing control input. #>
    param([Windows.DependencyObject]$Source)
    $titleBar = $sync.Form.FindName('GridBesideNavDockPanel')
    while ($null -ne $Source) {
        if ($Source -is [Windows.Controls.Primitives.ButtonBase] -or
            $Source -is [Windows.Controls.MenuItem] -or
            $Source -is [Windows.Controls.Primitives.TextBoxBase]) { return $false }
        if ($Source -eq $titleBar) { return $true }
        if ($Source -is [Windows.Media.Visual] -or $Source -is [Windows.Media.Media3D.Visual3D]) {
            $Source = [Windows.Media.VisualTreeHelper]::GetParent($Source)
        } else { $Source = [Windows.LogicalTreeHelper]::GetParent($Source) }
    }
    return $false
}
