function Show-WinUtilPackageDialog {
    <# Scrollable, keyboard-accessible review/results. Call on the UI thread. #>
    param(
        [string]$Title, [string]$Description, [string]$Details,
        [string]$PrimaryLabel = '开始执行', [string]$CloseLabel = '取消', [string]$LogDirectory,
        [AllowEmptyCollection()][object[]]$Results,
        [switch]$CreateOnly
    )
    $dialog = New-Object Windows.Window
    $dialog.Title = $Title
    if ($sync.form -is [Windows.Window] -and $sync.form.IsVisible) {
        $dialog.Owner = $sync.form; $dialog.WindowStartupLocation = 'CenterOwner'
    } else { $dialog.WindowStartupLocation = 'CenterScreen' }
    $dialog.Width = [Math]::Min(820, [System.Windows.SystemParameters]::WorkArea.Width - 32)
    $dialog.Height = [Math]::Min(610, [System.Windows.SystemParameters]::WorkArea.Height - 32)
    $dialog.MaxHeight = [System.Windows.SystemParameters]::WorkArea.Height - 32
    $dialog.MinWidth = 360; $dialog.MinHeight = 260; $dialog.FontSize = 15
    $dialog.FontFamily = 'Microsoft YaHei UI'; $dialog.Tag = 'Close'
    $dialog.Background = [Windows.Media.Brushes]::White
    $dialog.Foreground = [Windows.Media.Brushes]::Black
    if ($sync.form -is [Windows.Window]) {
        $background = $sync.form.TryFindResource('MainBackgroundColor')
        $foreground = $sync.form.TryFindResource('MainForegroundColor')
        $fontSize = $sync.form.TryFindResource('FontSize')
        $fontFamily = $sync.form.TryFindResource('FontFamily')
        if ($background) { $dialog.Background = $background }
        if ($foreground) { $dialog.Foreground = $foreground }
        if ($fontSize) { $dialog.FontSize = [Math]::Max(14, [double]$fontSize) }
        if ($fontFamily) { $dialog.FontFamily = $fontFamily }
    }
    $layout = New-Object Windows.Controls.DockPanel
    $layout.Margin = 20; $layout.Background = $dialog.Background; $dialog.Content = $layout
    $intro = New-Object Windows.Controls.TextBlock
    $intro.Text = $Description; $intro.TextWrapping = 'Wrap'; $intro.Margin = '0,0,0,14'
    $introScroll = New-Object Windows.Controls.ScrollViewer
    $introScroll.Content = $intro; $introScroll.VerticalScrollBarVisibility = 'Auto'
    $introScroll.HorizontalScrollBarVisibility = 'Disabled'; $introScroll.MaxHeight = $dialog.Height * 0.28
    [Windows.Controls.DockPanel]::SetDock($introScroll, 'Top')
    $null = $layout.Children.Add($introScroll)
    $dialog.Add_SizeChanged({ $introScroll.MaxHeight = [Math]::Max(48, $dialog.ActualHeight * 0.28) }.GetNewClosure())
    $buttons = New-Object Windows.Controls.WrapPanel
    $buttons.Orientation = 'Horizontal'; $buttons.HorizontalAlignment = 'Right'; $buttons.Margin = '0,14,0,0'
    [Windows.Controls.DockPanel]::SetDock($buttons, 'Bottom')
    $null = $layout.Children.Add($buttons)
    if ($LogDirectory -and (Test-Path -LiteralPath $LogDirectory -PathType Container)) {
        $logButton = New-Object Windows.Controls.Button
        $logButton.Content = '打开日志文件夹'; $logButton.Padding = '12,8'; $logButton.Margin = '0,0,8,0'
        $logButton.Background = $dialog.Background; $logButton.Foreground = $dialog.Foreground
        $logButton.Add_Click({
            try { Start-Process -FilePath explorer.exe -ArgumentList ('"{0}"' -f $LogDirectory) -ErrorAction Stop | Out-Null }
            catch { $null = [Windows.MessageBox]::Show("无法打开日志文件夹：$LogDirectory", 'WinUtil CN') }
        }.GetNewClosure())
        $null = $buttons.Children.Add($logButton)
    }
    $close = New-Object Windows.Controls.Button
    $close.Content = $CloseLabel; $close.Padding = '16,8'; $close.Margin = '0,0,8,0'; $close.IsCancel = $true
    $close.Background = $dialog.Background; $close.Foreground = $dialog.Foreground
    $close.Add_Click({ $dialog.Close() }.GetNewClosure())
    $null = $buttons.Children.Add($close)
    if ($PrimaryLabel) {
        $primary = New-Object Windows.Controls.Button
        $primary.Content = $PrimaryLabel; $primary.Padding = '16,8'
        $primary.Background = $dialog.Background; $primary.Foreground = $dialog.Foreground
        $primary.Add_Click({ $dialog.Tag = 'Primary'; $dialog.Close() }.GetNewClosure())
        $null = $buttons.Children.Add($primary)
    }
    if ($PSBoundParameters.ContainsKey('Results')) {
        # All handlers are created on the UI thread and only retain this window's controls.
        # No worker-runspace scriptblock or mutable shared batch state is used here.
        $resultLayout = New-Object Windows.Controls.Grid
        $resultLayout.Name = 'PackageResultsLayout'
        foreach ($height in @('Auto', '2*', 'Auto', '3*', 'Auto')) {
            $row = New-Object Windows.Controls.RowDefinition
            $row.Height = [Windows.GridLengthConverter]::new().ConvertFromString($height)
            $null = $resultLayout.RowDefinitions.Add($row)
        }
        $filterBar = New-Object Windows.Controls.WrapPanel
        $filterBar.Margin = '0,0,0,8'
        $filter = New-Object Windows.Controls.CheckBox
        $filter.Name = 'PackageResultsFilter'; $filter.Content = '只看未成功项'
        $filter.ToolTip = '显示失败、已跳过、需重启及未知结果；只隐藏明确成功的项目。'
        $filter.Foreground = $dialog.Foreground; $filter.VerticalContentAlignment = 'Center'
        $filter.Margin = '0,0,16,4'
        [Windows.Automation.AutomationProperties]::SetName($filter, '只看未成功项')
        $null = $filterBar.Children.Add($filter)
        $count = New-Object Windows.Controls.TextBlock
        $count.Name = 'PackageResultsCount'; $count.TextWrapping = 'Wrap'
        $null = $filterBar.Children.Add($count)
        $null = $resultLayout.Children.Add($filterBar)

        $resultList = New-Object Windows.Controls.ListBox
        $resultList.Name = 'PackageResultsList'; $resultList.SelectionMode = 'Single'
        $resultList.Background = $dialog.Background; $resultList.Foreground = $dialog.Foreground
        $resultList.BorderBrush = [Windows.SystemColors]::GrayTextBrush
        [Windows.Controls.ScrollViewer]::SetHorizontalScrollBarVisibility($resultList, 'Disabled')
        [Windows.Controls.ScrollViewer]::SetVerticalScrollBarVisibility($resultList, 'Auto')
        [Windows.Automation.AutomationProperties]::SetName($resultList, '软件操作结果，失败项优先。使用上下方向键选择软件查看详情。')
        $itemStyle = New-Object Windows.Style ([Windows.Controls.ListBoxItem])
        # Native themes otherwise paint an inactive selection over the custom
        # foreground, which can leave white text on a pale background.
        $itemTemplate = [Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="ListBoxItem">
    <Border Name="SelectionBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
        <ContentPresenter Margin="{TemplateBinding Padding}" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="{TemplateBinding VerticalContentAlignment}" />
    </Border>
</ControlTemplate>
'@)
        $null = $itemStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::TemplateProperty, $itemTemplate))
        $null = $itemStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::HorizontalContentAlignmentProperty, [Windows.HorizontalAlignment]::Stretch))
        $null = $itemStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::PaddingProperty, [Windows.Thickness]::new(10, 8, 10, 8)))
        $selectedStyle = New-Object Windows.Trigger
        $selectedStyle.Property = [Windows.Controls.ListBoxItem]::IsSelectedProperty; $selectedStyle.Value = $true
        $null = $selectedStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::BackgroundProperty, [Windows.SystemColors]::HighlightBrush))
        $null = $selectedStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::ForegroundProperty, [Windows.SystemColors]::HighlightTextBrush))
        $null = $itemStyle.Triggers.Add($selectedStyle)
        $resultList.ItemContainerStyle = $itemStyle
        [Windows.Controls.Grid]::SetRow($resultList, 1)
        $null = $resultLayout.Children.Add($resultList)

        $detailBar = New-Object Windows.Controls.DockPanel
        $detailBar.Margin = '0,10,0,6'
        $copy = New-Object Windows.Controls.Button
        $copy.Name = 'PackageResultCopy'; $copy.Content = '复制所选详情'; $copy.Padding = '10,5'
        $copy.Background = $dialog.Background; $copy.Foreground = $dialog.Foreground
        $copy.IsEnabled = $false
        [Windows.Controls.DockPanel]::SetDock($copy, 'Right')
        $null = $detailBar.Children.Add($copy)
        $detailTitle = New-Object Windows.Controls.TextBlock
        $detailTitle.Text = '原因与详情'; $detailTitle.TextWrapping = 'Wrap'
        $detailTitle.VerticalAlignment = 'Center'; $detailTitle.Margin = '0,0,8,0'
        $null = $detailBar.Children.Add($detailTitle)
        [Windows.Controls.Grid]::SetRow($detailBar, 2)
        $null = $resultLayout.Children.Add($detailBar)
        $textBox = New-Object Windows.Controls.TextBox
        $textBox.Name = 'PackageResultDetails'; $textBox.IsReadOnly = $true; $textBox.TextWrapping = 'Wrap'
        $textBox.Background = $dialog.Background; $textBox.Foreground = $dialog.Foreground
        $textBox.VerticalScrollBarVisibility = 'Auto'; $textBox.HorizontalScrollBarVisibility = 'Disabled'
        $textBox.Padding = 10
        [Windows.Automation.AutomationProperties]::SetName($textBox, '所选软件的原因、包管理器、退出码和日志路径')
        [Windows.Controls.Grid]::SetRow($textBox, 3)
        $null = $resultLayout.Children.Add($textBox)
        $feedback = New-Object Windows.Controls.TextBlock
        $feedback.Name = 'PackageResultFeedback'; $feedback.TextWrapping = 'Wrap'; $feedback.Margin = '0,5,0,0'
        $feedback.Visibility = 'Collapsed'
        [Windows.Automation.AutomationProperties]::SetLiveSetting($feedback, [Windows.Automation.AutomationLiveSetting]::Polite)
        [Windows.Controls.Grid]::SetRow($feedback, 4)
        $null = $resultLayout.Children.Add($feedback)

        $labels = @{ Failed = '失败'; RebootRequired = '需重启'; Skipped = '已跳过'; Succeeded = '成功' }
        $ranks = @{ Failed = 0; RebootRequired = 2; Skipped = 3; Succeeded = 4 }
        $rows = @(); $index = 0
        foreach ($result in @($Results)) {
            if ($null -eq $result) { continue }
            $status = [string]$result.Status
            $statusText = '结果未知'; $rank = 1
            if ($labels.ContainsKey($status)) { $statusText = $labels[$status]; $rank = $ranks[$status] }
            $name = [string]$result.Name
            if (-not $name) { $name = [string]$result.PackageId }
            if (-not $name) { $name = '未命名软件' }
            $reason = [string]$result.Reason
            if (-not $reason) { $reason = '未提供详细原因，请查看日志确认。' }
            $manager = [string]$result.Manager
            if ($manager -eq 'Choco') { $manager = 'Chocolatey' }
            if (-not $manager) { $manager = '未提供' }
            $packageId = [string]$result.PackageId
            if (-not $packageId) { $packageId = '未提供' }
            $actionText = switch ([string]$result.Action) {
                'Install' { '安装/升级' }
                'Uninstall' { '卸载' }
                'UpgradeAll' { '更新全部' }
                default { '未提供' }
            }
            $exitText = '未取得'
            if ($null -ne $result.ExitCode -and [string]$result.ExitCode -ne '') {
                $exitText = [string]$result.ExitCode
                if ($result.ExitCodeHex) { $exitText += " / $($result.ExitCodeHex)" }
            }
            $lines = @("原因：$reason", '', "软件：$name", "操作：$actionText", "状态：$statusText", "包管理器：$manager", "包 ID：$packageId", "退出码：$exitText")
            if ($result.NeedsReboot) { $lines += '重启提示：请先保存工作，再重启电脑；失败项请在重启后确认是否需要重试。' }
            if ($result.OutputPath) { $lines += "输出日志：$($result.OutputPath)" }
            if ($result.ErrorPath) { $lines += "错误日志：$($result.ErrorPath)" }
            if ($LogDirectory) { $lines += "最近一轮日志文件夹：$LogDirectory" }
            if (-not $result.OutputPath -and -not $result.ErrorPath -and -not $LogDirectory) { $lines += '日志：没有可用的日志路径。' }
            $item = New-Object Windows.Controls.ListBoxItem
            $item.Tag = [pscustomobject]@{ Rank = $rank; Index = $index; Status = $status; Detail = ($lines -join "`r`n") }
            [Windows.Automation.AutomationProperties]::SetName($item, "$name，$statusText")
            $rowLayout = New-Object Windows.Controls.DockPanel
            $statusLabel = New-Object Windows.Controls.TextBlock
            $statusLabel.Text = $statusText; $statusLabel.Margin = '12,0,0,0'; $statusLabel.FontWeight = 'SemiBold'
            [Windows.Controls.DockPanel]::SetDock($statusLabel, 'Right')
            $null = $rowLayout.Children.Add($statusLabel)
            $nameLabel = New-Object Windows.Controls.TextBlock
            $nameLabel.Text = $name; $nameLabel.TextWrapping = 'Wrap'
            $null = $rowLayout.Children.Add($nameLabel)
            $item.Content = $rowLayout
            $rows += $item; $index++
        }
        $rows = @($rows | Sort-Object { $_.Tag.Rank }, { $_.Tag.Index })
        $resultList.Add_SelectionChanged({
            $feedback.Text = ''; $feedback.Visibility = 'Collapsed'
            $copy.IsEnabled = $null -ne $resultList.SelectedItem
            if ($resultList.SelectedItem) { $textBox.Text = $resultList.SelectedItem.Tag.Detail }
            else { $textBox.Text = '选择上方软件查看详情。' }
        }.GetNewClosure())
        $refreshResults = {
            $selected = $resultList.SelectedItem
            $resultList.Items.Clear()
            foreach ($item in $rows) {
                if (-not $filter.IsChecked -or $item.Tag.Status -ne 'Succeeded') { $null = $resultList.Items.Add($item) }
            }
            $count.Text = "显示 $($resultList.Items.Count) / $($rows.Count) 项 · 失败优先"
            if ($selected -and $resultList.Items.Contains($selected)) { $resultList.SelectedItem = $selected }
            elseif ($resultList.Items.Count) { $resultList.SelectedIndex = 0 }
            else {
                $copy.IsEnabled = $false; $feedback.Text = ''; $feedback.Visibility = 'Collapsed'
                $textBox.Text = if ($rows.Count) { '没有未成功项，所有软件均已报告成功。取消筛选可查看全部详情。' } else { '没有收到软件操作结果，无法确认是否完成。请查看日志。' }
            }
        }.GetNewClosure()
        $filter.Add_Checked($refreshResults); $filter.Add_Unchecked($refreshResults)
        $copy.Add_Click({
            if (-not $resultList.SelectedItem) { return }
            $feedback.Visibility = 'Visible'
            try {
                Set-Clipboard -Value $textBox.Text -ErrorAction Stop
                $feedback.Text = '已复制所选软件详情。分享前请检查日志路径中的个人信息。'
            } catch {
                $feedback.Text = '复制失败，剪贴板可能正被其他程序占用。请在详情框中按 Ctrl+A、Ctrl+C 手动复制。'
            }
        }.GetNewClosure())
        $dialog.Add_ContentRendered({ $null = $resultList.Focus() }.GetNewClosure())
        & $refreshResults
        $null = $layout.Children.Add($resultLayout)
    } else {
        $textBox = New-Object Windows.Controls.TextBox
        $textBox.Text = $Details; $textBox.IsReadOnly = $true; $textBox.TextWrapping = 'Wrap'
        $textBox.Background = $dialog.Background; $textBox.Foreground = $dialog.Foreground
        $textBox.VerticalScrollBarVisibility = 'Auto'; $textBox.Padding = 12
        $null = $layout.Children.Add($textBox)
    }
    if ($CreateOnly) { return $dialog }
    $null = $dialog.ShowDialog()
    return [string]$dialog.Tag
}
