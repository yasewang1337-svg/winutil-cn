function Find-AppsByNameOrDescription {
    <# .SYNOPSIS Filters software without changing the selection or saved category layout. #>
    param([string]$SearchString = '')
    if ($null -eq $sync -or $null -eq $sync.ItemsControl -or
        $null -eq $sync.configs -or $null -eq $sync.configs.applicationsHashtable) { return }
    $searchTerm = $SearchString.Trim()
    $sync.InstallSearchText = $SearchString
    $onlySelected = $null -ne $sync.InstallSelectedOnly -and $sync.InstallSelectedOnly.IsChecked -eq $true
    $filterActive = $onlySelected -or $searchTerm.Length -gt 0
    $selected = @($sync.selectedApps)
    $matchCount = 0
    $totalCount = 0

    # Keep the pre-filter category layout through repeated searches/selection changes.
    if ($filterActive -and $null -eq $sync.InstallCategoryCollapseState) {
        $sync.InstallCategoryCollapseState = @{}
        foreach ($category in $sync.ItemsControl.Items) {
            if ($category.Children.Count -ge 2) {
                $sync.InstallCategoryCollapseState[$category] = $category.Children[1].Visibility -eq 'Collapsed'
            }
        }
    }
    foreach ($category in $sync.ItemsControl.Items) {
        if ($category.Children.Count -lt 2) { continue }
        $label = $category.Children[0]
        $wrap = $category.Children[1]
        $categoryMatches = 0
        foreach ($border in $wrap.Children) {
            $key = [string]$border.Tag
            $entry = $sync.configs.applicationsHashtable[$key]
            if ($null -eq $entry) { $border.Visibility = 'Collapsed'; continue }
            $totalCount++
            $matchesText = $searchTerm.Length -eq 0
            if (-not $matchesText) {
                foreach ($value in @($entry.Content, $entry.Description, $entry.winget, $entry.choco)) {
                    if ($null -ne $value -and ([string]$value).IndexOf($searchTerm, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        $matchesText = $true
                        break
                    }
                }
            }
            if ($matchesText -and (-not $onlySelected -or $selected -contains $key)) {
                $border.Visibility = 'Visible'
                $categoryMatches++
                $matchCount++
            } else { $border.Visibility = 'Collapsed' }
        }
        $label.Visibility = 'Visible'
        if ($filterActive) {
            $category.Visibility = if ($categoryMatches -gt 0) { 'Visible' } else { 'Collapsed' }
            $wrap.Visibility = 'Visible'
            $label.Content = ([string]$label.Content) -replace '^\+ ', '- '
        } else {
            $category.Visibility = 'Visible'
            if ($null -ne $sync.InstallCategoryCollapseState -and $sync.InstallCategoryCollapseState.ContainsKey($category)) {
                $collapsed = $sync.InstallCategoryCollapseState[$category]
                $wrap.Visibility = if ($collapsed) { 'Collapsed' } else { 'Visible' }
                $label.Content = (([string]$label.Content) -replace '^[+-] ', '')
                $label.Content = if ($collapsed) { '+ ' + $label.Content } else { '- ' + $label.Content }
            }
        }
    }
    if (-not $filterActive) { $sync.InstallCategoryCollapseState = $null }
    if ($sync.InstallFilterStatus) { $sync.InstallFilterStatus.Text = "显示 $matchCount / $totalCount 项    已选 $($selected.Count) 项" }
    if ($sync.InstallClearFilter) { $sync.InstallClearFilter.IsEnabled = $filterActive }
    if ($sync.InstallFilterEmpty) {
        $sync.InstallFilterEmpty.Visibility = if ($matchCount -eq 0) { 'Visible' } else { 'Collapsed' }
        $sync.InstallFilterEmptyText.Text = if ($onlySelected -and $selected.Count -eq 0) {
            '还没有选择软件。关闭“仅看已选”，从列表勾选想安装的软件。'
        } elseif ($onlySelected) {
            '已选软件中没有匹配项。换个关键词，或清除筛选查看全部软件；已有勾选会保留。'
        } else {
            '没有找到匹配的软件。可搜索名称、用途或包 ID，或清除筛选查看全部软件。'
        }
    }
}