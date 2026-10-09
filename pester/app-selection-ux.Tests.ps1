BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    foreach ($file in @(
        'private/Initialize-InstallAppArea.ps1', 'private/Initialize-InstallAppEntry.ps1',
        'private/Initialize-InstallCategoryAppList.ps1', 'private/Initialize-WinUtilAppFilterBar.ps1',
        'private/Initialize-WinUtilSelectedAppsPopup.ps1', 'private/Add-SelectedAppsMenuItem.ps1',
        'private/Initialize-WinUtilAppActions.ps1', 'private/Show-WinUtilAppActions.ps1',
        'private/Show-WPFInstallAppBusy.ps1', 'private/Hide-WPFInstallAppBusy.ps1',
        'private/Find-AppsByNameOrDescription.ps1', 'private/Reset-WinUtilAppFilter.ps1',
        'private/Update-WinUtilAppSelectionUi.ps1', 'private/Reset-WPFCheckBoxes.ps1',
        'private/Update-WinUtilSelections.ps1', 'public/Invoke-WPFSelectedCheckboxesUpdate.ps1',
        'public/Initialize-WPFUI.ps1', 'public/Invoke-WPFPresets.ps1',
        'private/Invoke-WinutilThemeChange.ps1', 'private/Invoke-WinUtilFontScaling.ps1',
        'private/Initialize-WinUtilWindowChrome.ps1', 'private/Set-WinUtilNavigationLayout.ps1'
    )) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:root "functions/$file"))))
    }
    function Set-Preferences { param([switch]$save) }
    function Invoke-WPFUIThread { param($ScriptBlock) & $ScriptBlock }
    function Invoke-TestClick($Button) {
        $Button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    }
}
Describe 'Software search and selected-list experience' {
    It 'keeps idle text sharp after repeated busy overlays' {
        $sync.InstallAppAreaScrollViewer.Effect | Should -BeNullOrEmpty
        foreach ($iteration in 1..2) {
            Show-WPFInstallAppBusy -text 'Test task'
            $sync.InstallAppAreaBorder.IsEnabled | Should -BeFalse
            $sync.InstallAppAreaScrollViewer.Effect.Radius | Should -Be 5
            Hide-WPFInstallAppBusy
            $sync.InstallAppAreaBorder.IsEnabled | Should -BeTrue
            $sync.InstallAppAreaScrollViewer.Effect | Should -BeNullOrEmpty
        }
    }
    BeforeEach {
        $text = [IO.File]::ReadAllText((Join-Path $script:root 'xaml/inputXML.xaml'))
        $xml = [xml]($text -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace '^<Win.*', '<Window')
        $reader = [Xml.XmlNodeReader]::new($xml)
        try { $form = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
        $script:sync = @{
            Form = $form; preferences = @{}; selectedApps = [Collections.Generic.List[string]]::new()
            selectedTweaks = [Collections.Generic.List[string]]::new()
            selectedFeatures = [Collections.Generic.List[string]]::new()
            selectedToggles = [Collections.Generic.List[string]]::new()
            configs = @{
                themes = Get-Content (Join-Path $script:root 'config/themes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
                applicationsHashtable = @{
                    WPFInstallAlpha = @{ Content='Alpha 浏览器'; Description='日常网页浏览'; winget='Vendor.Alpha'; choco='alpha-browser'; Category='浏览器' }
                    WPFInstallBeta = @{ Content='Beta 编辑器'; Description='文本编辑'; winget='Vendor.Beta'; choco='beta-editor'; Category='编辑器' }
                    WPFInstallLiteral = @{ Content='Tool [Stable]*'; Description='字面搜索示例'; winget='Vendor.Literal'; choco='literal-tool'; Category='编辑器' }
                }
            }
        }
        foreach ($node in $xml.SelectNodes('//*[@Name]')) { $script:sync[$node.Name] = $form.FindName($node.Name) }
        $sync.WPFselectedAppsButton = [Windows.Controls.Button]::new()
        Invoke-WinutilThemeChange -theme Dark
        Initialize-WinUtilWindowChrome
        Initialize-WPFUI -TargetGridName appscategory
        Initialize-WPFUI -TargetGridName appspanel
        $sync.WPFTab1.IsSelected = $true
    }
    AfterEach { $sync.selectedAppsPopup.IsOpen = $false; $form.Close() }

    It 'shows software and selected counts immediately without hiding the catalogue' {
        $sync.InstallFilterStatus.Text | Should -Be '显示 3 / 3 项    已选 0 项'
        $sync.InstallFilterEmpty.Visibility | Should -Be 'Collapsed'
        $sync.InstallClearFilter.IsEnabled | Should -BeFalse
    }
    It 'matches <Query> literally across labels, descriptions and package IDs' -ForEach @(
        @{ Query=' alpha '; Expected='WPFInstallAlpha' },
        @{ Query='网页'; Expected='WPFInstallAlpha' },
        @{ Query='vendor.beta'; Expected='WPFInstallBeta' },
        @{ Query='beta-editor'; Expected='WPFInstallBeta' },
        @{ Query='[Stable]*'; Expected='WPFInstallLiteral' }
    ) {
        Find-AppsByNameOrDescription -SearchString $Query
        $sync[$Expected].Parent.Visibility | Should -Be 'Visible'
        $sync.InstallFilterStatus.Text | Should -Be '显示 1 / 3 项    已选 0 项'
        $sync.selectedApps.Count | Should -Be 0
    }
    It 'combines selected-only and keyword filters without changing any selection' {
        $sync.WPFInstallAlpha.IsChecked = $true
        $sync.WPFInstallBeta.IsChecked = $true
        $sync.SearchBar.Text = 'alpha'
        $sync.InstallSelectedOnly.IsChecked = $true
        $sync.InstallFilterStatus.Text | Should -Be '显示 1 / 3 项    已选 2 项'
        [Windows.Automation.AutomationProperties]::GetName($sync.WPFselectedAppsButton) | Should -Be '已选应用: 2'
        $sync.WPFInstallBeta.Parent.Visibility | Should -Be 'Collapsed'
        $sync.WPFInstallBeta.IsChecked | Should -BeTrue
    }
    It 'refreshes the selected-only list after the checkbox selection changes' {
        $sync.InstallSelectedOnly.IsChecked = $true
        $sync.WPFInstallAlpha.IsChecked = $true
        $sync.InstallFilterStatus.Text | Should -Be '显示 1 / 3 项    已选 1 项'
        $sync.WPFInstallAlpha.IsChecked = $false
        $sync.InstallFilterStatus.Text | Should -Be '显示 0 / 3 项    已选 0 项'
        [Windows.Automation.AutomationProperties]::GetName($sync.WPFselectedAppsButton) | Should -Be '已选应用: 0'
        $sync.InstallFilterEmptyText.Text | Should -Match '还没有选择'
        $sync.SelectedAppsEmptyText.Visibility | Should -Be 'Visible'
    }
    It 'offers recovery for empty search results and clearing filters keeps selection' {
        $sync.WPFInstallBeta.IsChecked = $true
        $sync.SearchBar.Text = 'not-in-catalogue'
        $sync.InstallSelectedOnly.IsChecked = $true
        $sync.InstallFilterEmpty.Visibility | Should -Be 'Visible'
        $sync.InstallFilterEmptyText.Text | Should -Match '已有勾选会保留'
        Invoke-TestClick $sync.InstallClearFilter
        $sync.SearchBar.Text | Should -Be ''
        $sync.InstallSelectedOnly.IsChecked | Should -BeFalse
        $sync.WPFInstallBeta.IsChecked | Should -BeTrue
        $sync.InstallFilterStatus.Text | Should -Be '显示 3 / 3 项    已选 1 项'
        $sync.InstallFilterEmpty.Visibility | Should -Be 'Collapsed'
    }
    It 'restores pre-search collapsed categories after multiple searches and selection refreshes' {
        $category = $sync.WPFInstallAlpha.Parent.Parent.Parent
        $category.Children[0].Content = '+ 浏览器'
        $category.Children[1].Visibility = 'Collapsed'
        $sync.SearchBar.Text = 'Alpha'
        Find-AppsByNameOrDescription -SearchString 'Alpha'
        $category.Children[1].Visibility | Should -Be 'Visible'
        $sync.WPFInstallAlpha.IsChecked = $true
        Find-AppsByNameOrDescription -SearchString 'Beta'
        Reset-WinUtilAppFilter
        $category.Children[0].Content | Should -Be '+ 浏览器'
        $category.Children[1].Visibility | Should -Be 'Collapsed'
        $sync.WPFInstallAlpha.IsChecked | Should -BeTrue
    }
    It 'refreshes selection imported by the existing update-and-reset path even without checkbox changes' {
        Update-WinUtilSelections -flatJson @('WPFInstallBeta')
        Reset-WPFCheckBoxes -doToggles $false
        $sync.InstallSelectedOnly.IsChecked = $true
        $sync.InstallFilterStatus.Text | Should -Be '显示 1 / 3 项    已选 1 项'
        Reset-WPFCheckBoxes -doToggles $false
        $sync.selectedAppsstackPanel.Children.Count | Should -Be 1
        $sync.InstallFilterStatus.Text | Should -Be '显示 1 / 3 项    已选 1 项'
        Invoke-WPFPresets -preset $null -checkboxfilterpattern 'WPFInstall*'
        $sync.InstallFilterStatus.Text | Should -Be '显示 0 / 3 项    已选 0 项'
        $sync.selectedAppsstackPanel.Children.Count | Should -Be 0
        $sync.WPFInstallBeta.IsChecked | Should -BeFalse
    }
    It 'removes one selected item through the popup while preserving other selected items' {
        $sync.WPFInstallAlpha.IsChecked = $true
        $sync.WPFInstallBeta.IsChecked = $true
        $sync.InstallSelectedOnly.IsChecked = $true
        $remove = $sync.selectedAppsstackPanel.Children[0].Children[1]
        $key = $remove.Tag
        Invoke-TestClick $remove
        $sync[$key].IsChecked | Should -BeFalse
        $sync.selectedApps.Count | Should -Be 1
        $sync.selectedAppsstackPanel.Children.Count | Should -Be 1
        $sync.InstallFilterStatus.Text | Should -Be '显示 1 / 3 项    已选 1 项'
    }
    It 'keeps thirty selected rows within a scrolling viewport and exposes named remove buttons' {
        $sync.selectedAppsstackPanel.Children.Clear()
        1..30 | ForEach-Object { Add-SelectedAppsMenuItem -name ("很长的软件名称用于核对文字不会挤掉移除按钮 " + $_) -key ("WPFInstall" + $_) }
        $border = $sync.selectedAppsPopup.Child
        $border.Measure([Windows.Size]::new(320, 480))
        $border.Arrange([Windows.Rect]::new(0,0,320,$border.DesiredSize.Height))
        $border.UpdateLayout()
        $sync.SelectedAppsPopupScroll.ExtentHeight | Should -BeGreaterThan $sync.SelectedAppsPopupScroll.ViewportHeight
        $border.ActualHeight | Should -BeLessOrEqual 480
        $sync.SelectedAppsPopupScroll.HorizontalScrollBarVisibility | Should -Be 'Disabled'
        $row = $sync.selectedAppsstackPanel.Children[0]
        [Windows.Automation.AutomationProperties]::GetName($row.Children[1]) | Should -Match '从已选清单移除'
        $row.Children[0].TextTrimming | Should -Be 'CharacterEllipsis'
    }
    It 'wraps the toolbar within a narrow software panel at <Scale> scaling' -ForEach @(@{Scale=1.0}, @{Scale=1.5}) {
        Invoke-WinUtilFontScaling -ScaleFactor $Scale
        $panel = $sync.Form.FindName('appspanel')
        $panel.Measure([Windows.Size]::new(340,480))
        $panel.Arrange([Windows.Rect]::new(0,0,340,480))
        $panel.UpdateLayout()
        foreach ($control in @($sync.InstallFilterStatus, $sync.InstallSelectedOnly, $sync.InstallClearFilter)) {
            $point = $control.TranslatePoint([Windows.Point]::new(0,0),$panel)
            ($point.X + $control.ActualWidth) | Should -BeLessOrEqual 341
        }
    }

    It 'wraps long software names inside full-width rows at <Scale> scaling' -ForEach @(@{Scale=1.0}, @{Scale=1.5}) {
        $name = 'Beta 文本编辑器专业版 Very long application name that must remain readable without covering adjacent software'
        $sync.configs.applicationsHashtable.WPFInstallBeta.Content = $name
        Initialize-WPFUI -TargetGridName appspanel
        Invoke-WinUtilFontScaling -ScaleFactor $Scale
        $panel = $sync.Form.FindName('appspanel')
        $panel.Measure([Windows.Size]::new(340,480))
        $panel.Arrange([Windows.Rect]::new(0,0,340,480))
        $panel.UpdateLayout()
        $checkbox = $sync.WPFInstallBeta
        $border = $checkbox.Parent
        $label = $checkbox.Content.Children[0]
        $description = $checkbox.Content.Children[1]
        $label.TextWrapping | Should -Be 'Wrap'
        $label.ActualHeight | Should -BeGreaterThan ($label.FontSize * 2)
        $point = $label.TranslatePoint([Windows.Point]::new(0,0), $border)
        ($point.X + $label.ActualWidth) | Should -BeLessOrEqual ($border.ActualWidth + 1)
        ($point.Y + $label.ActualHeight) | Should -BeLessOrEqual ($border.ActualHeight + 1)
        $description.Text | Should -Be '文本编辑'
        $description.TextWrapping | Should -Be 'NoWrap'
        $description.TextTrimming | Should -Be 'CharacterEllipsis'
        $descriptionPoint = $description.TranslatePoint([Windows.Point]::new(0,0), $border)
        ($descriptionPoint.X + $description.ActualWidth) | Should -BeLessOrEqual ($border.ActualWidth + 1)
        ($descriptionPoint.Y + $description.ActualHeight) | Should -BeLessOrEqual ($border.ActualHeight + 1)
        $descriptionPoint.Y | Should -BeGreaterOrEqual ($point.Y + $label.ActualHeight)
        $nextBorder = $sync.WPFInstallLiteral.Parent
        $nextPoint = $nextBorder.TranslatePoint([Windows.Point]::new(0,0), $border)
        $nextPoint.Y | Should -BeGreaterOrEqual ($border.ActualHeight - 0.01)
        $label.ToolTip | Should -BeNullOrEmpty
        $checkbox.ToolTip | Should -BeNullOrEmpty
        $border.ToolTip.Content.Children[0].Text | Should -Be $name
        $border.ToolTip.Content.Children[1].Text | Should -Be '文本编辑'
        [Windows.Automation.AutomationProperties]::GetName($checkbox) | Should -Be $name
        [Windows.Automation.AutomationProperties]::GetHelpText($checkbox) | Should -Be '文本编辑'
        $checkbox.Focusable | Should -BeTrue
        $checkbox.IsTabStop | Should -BeTrue
    }
    It 'scales popup text and keeps the remove action reachable at 150 percent' {
        $sync.WPFInstallAlpha.IsChecked = $true
        $sync.WPFInstallBeta.IsChecked = $true
        Invoke-WinUtilFontScaling -ScaleFactor 1.5
        $border = $sync.selectedAppsPopup.Child
        $border.Measure([Windows.Size]::new(320,480))
        $border.Arrange([Windows.Rect]::new(0,0,320,$border.DesiredSize.Height))
        $border.UpdateLayout()
        $row = $sync.selectedAppsstackPanel.Children[0]
        $row.Children[0].FontSize | Should -Be 21
        $row.Children[1].FontSize | Should -Be 21
        $sync.SelectedAppsCloseButton.FontSize | Should -Be 21
        $sync.SelectedAppsEmptyText.FontSize | Should -Be 21
        $point = $row.Children[1].TranslatePoint([Windows.Point]::new(0,0), $border)
        ($point.X + $row.Children[1].ActualWidth) | Should -BeLessOrEqual 321
        $row.Children[1].ActualWidth | Should -BeGreaterThan 0
    }

    It 'fills the software area with equal-width rows at <Width> pixels and <Scale> scaling' -ForEach @(
        @{Width=800;Scale=1.0}, @{Width=800;Scale=1.5},
        @{Width=1280;Scale=1.0}, @{Width=1280;Scale=1.5}
    ) {
        $sync.configs.applicationsHashtable.WPFInstallBeta.Description = '提供文本编辑、搜索替换、语法高亮及多种扩展功能，适合编程与日常文档处理。' * 5
        Initialize-WPFUI -TargetGridName appspanel
        Invoke-WinUtilFontScaling -ScaleFactor $Scale
        Set-WinUtilNavigationLayout -AvailableWidth $Width
        $grid = $sync.Form.Content
        $grid.Measure([Windows.Size]::new($Width,600))
        $grid.Arrange([Windows.Rect]::new(0,0,$Width,600))
        $grid.UpdateLayout()
        $row = $sync.WPFInstallBeta.Parent
        $nextRow = $sync.WPFInstallLiteral.Parent
        $wrap = $row.Parent
        $row.ActualWidth | Should -BeGreaterThan 250
        [math]::Abs($row.ActualWidth - $wrap.ActualWidth) | Should -BeLessThan 1
        [math]::Abs($row.ActualWidth - $nextRow.ActualWidth) | Should -BeLessThan 1
        $nextPoint = $nextRow.TranslatePoint([Windows.Point]::new(0,0),$row)
        $nextPoint.X | Should -Be 0
        $nextPoint.Y | Should -BeGreaterOrEqual ($row.ActualHeight - 0.01)
        $name = $row.Child.Content.Children[0]
        $summary = $row.Child.Content.Children[1]
        $summary.TextTrimming | Should -Be 'CharacterEllipsis'
        $summary.ActualHeight | Should -BeLessThan ($summary.FontSize * 2)
        $summary.FontSize | Should -Be ([double]$sync.configs.themes.shared.AppEntryDescriptionFontSize * $Scale)
        foreach ($textBlock in @($name,$summary)) {
            $point = $textBlock.TranslatePoint([Windows.Point]::new(0,0),$row)
            ($point.X + $textBlock.ActualWidth) | Should -BeLessOrEqual ($row.ActualWidth + 1)
            ($point.Y + $textBlock.ActualHeight) | Should -BeLessOrEqual ($row.ActualHeight + 1)
        }
        $row.ToolTip.Content.Children[1].Text | Should -Be $summary.Text
    }
}
