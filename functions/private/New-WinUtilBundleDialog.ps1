function New-WinUtilBundleDialog {
    <#
    .SYNOPSIS
        Creates a bundle preview window without displaying it or changing application selections.
        Content scrolls while confirmation controls remain visible on smaller displays.
    #>
    param(
        [Parameter(Mandatory)]$Bundle,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Plan,
        $Owner
    )

    $dialog = New-Object Windows.Window
    $dialog.Title = "选择装机软件 · $($Bundle.name)"
    $dialog.ShowInTaskbar = $false
    $dialog.ResizeMode = 'CanResize'
    $dialog.WindowStartupLocation = 'CenterScreen'
    $dialog.Width = [Math]::Min(720, [Windows.SystemParameters]::WorkArea.Width - 32)
    $dialog.Height = [Math]::Min(650, [Windows.SystemParameters]::WorkArea.Height - 32)
    $dialog.MinWidth = 320
    $dialog.MinHeight = 240
    $dialog.FontFamily = New-Object Windows.Media.FontFamily('Microsoft YaHei UI, Segoe UI')
    $dialog.FontSize = 14
    $dialog.Background = [Windows.SystemColors]::WindowBrush
    $dialog.Foreground = [Windows.SystemColors]::WindowTextBrush
    if ($Owner -is [Windows.Window]) {
        if ($Owner.IsVisible) {
            $dialog.Owner = $Owner
            $dialog.WindowStartupLocation = 'CenterOwner'
        }
        foreach ($property in @('Background', 'Foreground')) {
            $brush = $Owner.TryFindResource("Main${property}Color")
            if ($brush -is [Windows.Media.Brush]) { $dialog.$property = $brush }
        }
        $fontSize = $Owner.TryFindResource('FontSize')
        if ($fontSize) { $dialog.FontSize = [Math]::Max(14, [double]$fontSize) }
    }

    $grid = New-Object Windows.Controls.Grid
    $grid.Margin = '16'
    $bodyRow = New-Object Windows.Controls.RowDefinition
    $bodyRow.Height = '*'
    $footerRow = New-Object Windows.Controls.RowDefinition
    $footerRow.Height = 'Auto'
    $null = $grid.RowDefinitions.Add($bodyRow)
    $null = $grid.RowDefinitions.Add($footerRow)
    $dialog.Content = $grid

    $scroll = New-Object Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'
    $scroll.Padding = '0,0,8,0'
    $null = $grid.Children.Add($scroll)
    $content = New-Object Windows.Controls.StackPanel
    $scroll.Content = $content

    $heading = New-Object Windows.Controls.TextBlock
    $heading.Text = "$($Bundle.region) · $($Bundle.name)"
    $heading.FontSize = $dialog.FontSize + 5
    $heading.FontWeight = 'SemiBold'
    $heading.TextWrapping = 'Wrap'
    $heading.Margin = '0,0,0,8'
    $null = $content.Children.Add($heading)
    $intro = New-Object Windows.Controls.TextBlock
    $intro.Text = "$($Bundle.desc)`n确认只加入清单，不会立即安装。"
    $intro.TextWrapping = 'Wrap'
    $intro.Margin = '0,0,0,12'
    $null = $content.Children.Add($intro)

    $choices = [System.Collections.Generic.List[object]]::new()
    foreach ($app in $Plan) {
        $row = New-Object Windows.Controls.Border
        $row.BorderBrush = $dialog.Foreground
        $row.BorderThickness = '0,0,0,0.5'
        $row.Padding = '0,8,0,10'
        $row.Margin = '0,0,0,6'
        $stack = New-Object Windows.Controls.StackPanel
        $row.Child = $stack
        $check = New-Object Windows.Controls.CheckBox
        $check.Tag = $app.Id
        $check.IsChecked = $app.IsSelected
        $check.IsEnabled = $app.IsAvailable -and -not $app.AlreadySelected
        $check.Foreground = $dialog.Foreground
        $label = New-Object Windows.Controls.TextBlock
        $label.Text = $app.Name
        $label.TextWrapping = 'Wrap'
        $label.FontWeight = 'SemiBold'
        $check.Content = $label
        $check.SetValue([Windows.Automation.AutomationProperties]::NameProperty, $app.Name)
        $null = $stack.Children.Add($check)
        $details = New-Object Windows.Controls.TextBlock
        $details.Text = if ($app.Purpose) { "$($app.Purpose)`n$($app.Description)" } else { $app.Description }
        $details.TextWrapping = 'Wrap'
        $details.Margin = '20,4,0,3'
        $null = $stack.Children.Add($details)
        $status = New-Object Windows.Controls.TextBlock
        $status.TextWrapping = 'Wrap'
        $status.Margin = '20,0,0,0'
        $statusParts = @()
        if (-not $app.IsAvailable) { $statusParts += '暂不可选' }
        elseif ($app.InstallState -eq 'Installed') {
            $version = if ($app.InstalledVersion) { " $($app.InstalledVersion)" } else { '' }
            $statusParts += "已检测到安装$version（本次会话缓存）"
        } else { $statusParts += '尚未确认安装状态（不代表未安装）' }
        if ($app.AlreadySelected) { $statusParts += '已在安装页勾选，将保留' }
        elseif ($app.IsRecommended) { $statusParts += '组合推荐，可取消' }
        $status.Text = $statusParts -join ' · '
        $null = $stack.Children.Add($status)
        $null = $content.Children.Add($row)
        $choices.Add($check)
    }

    $footer = New-Object Windows.Controls.StackPanel
    $footer.Margin = '0,12,0,0'
    [Windows.Controls.Grid]::SetRow($footer, 1)
    $null = $grid.Children.Add($footer)
    $count = New-Object Windows.Controls.TextBlock
    $count.TextWrapping = 'Wrap'
    $count.Margin = '0,0,0,8'
    $null = $footer.Children.Add($count)
    $buttons = New-Object Windows.Controls.WrapPanel
    $buttons.HorizontalAlignment = 'Right'
    $null = $footer.Children.Add($buttons)
    $cancel = New-Object Windows.Controls.Button
    $cancel.Content = '取消'
    $cancel.IsCancel = $true
    $cancel.MinWidth = 72
    $cancel.Padding = '12,7'
    $cancel.Margin = '0,0,8,0'
    $cancel.Foreground = [Windows.SystemColors]::ControlTextBrush
    $cancel.Background = [Windows.SystemColors]::ControlBrush
    $null = $buttons.Children.Add($cancel)
    $confirm = New-Object Windows.Controls.Button
    $confirm.Content = '加入已选清单'
    $confirm.IsDefault = $true
    $confirm.MinWidth = 126
    $confirm.Padding = '12,7'
    $confirm.Foreground = [Windows.SystemColors]::ControlTextBrush
    $confirm.Background = [Windows.SystemColors]::ControlBrush
    $null = $buttons.Children.Add($confirm)
    $dialog.Tag = @{ Choices = $choices; ConfirmButton = $confirm; CancelButton = $cancel; ScrollViewer = $scroll; Footer = $footer }
    $confirm.Tag = $dialog
    $confirm.Add_Click({ $this.Tag.DialogResult = $true })
    $cancel.Tag = $dialog
    $cancel.Add_Click({ $this.Tag.DialogResult = $false })
    $refreshCount = {
        $selectedCount = @($dialog.Tag.Choices | Where-Object { $_.IsChecked }).Count
        $count.Text = "已勾选 $selectedCount 项。确认后仍需在安装页点击安装/更新。"
        $confirm.IsEnabled = $selectedCount -gt 0
    }.GetNewClosure()
    foreach ($check in $choices) {
        $check.Add_Checked($refreshCount)
        $check.Add_Unchecked($refreshCount)
    }
    & $refreshCount
    return $dialog
}
