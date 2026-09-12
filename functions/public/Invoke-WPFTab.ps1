function Invoke-WPFTab {
    <# .SYNOPSIS
        Navigate by stable control names, independent of translated tab captions.
    #>
    param([Parameter(Mandatory, Position = 0)][string]$ClickedTab)

    if ($ClickedTab -notmatch '^WPFTab([1-6])BT$') { return }
    $tabName = 'WPFTab' + $Matches[1]
    $target = $sync.Form.FindName($tabName)
    if (-not $target) { return }
    if ($sync[$ClickedTab] -and -not $sync[$ClickedTab].IsEnabled) { return }

    foreach ($number in 1..6) {
        $button = $sync["WPFTab${number}BT"]
        if ($button) { $button.IsChecked = ($ClickedTab -eq $button.Name) }
    }
    $target.IsSelected = $true
    $sync.currentTab = $tabName
    $sync.SearchBar.Text = ''
    $searchVisible = $tabName -in @('WPFTab1', 'WPFTab2')
    $visibility = if ($searchVisible) { 'Visible' } else { 'Collapsed' }
    $sync.SearchBar.Visibility = $visibility
    $sync.SearchBarClearButton.Visibility = 'Collapsed'
    $searchIcon = $sync.Form.FindName('WPFSearchIcon')
    if ($searchIcon) { $searchIcon.Visibility = $visibility }
    if ($tabName -eq 'WPFTab1') { Find-AppsByNameOrDescription -SearchString '' }
    if ($tabName -eq 'WPFTab2') { Find-TweaksByNameOrDescription -SearchString '' }
}
