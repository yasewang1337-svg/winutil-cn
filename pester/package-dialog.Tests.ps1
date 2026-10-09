BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    . ([scriptblock]::Create((Get-Content (Join-Path $PSScriptRoot '../functions/private/Show-WinUtilPackageDialog.ps1') -Raw -Encoding UTF8)))
    function Find-PackageDialogControl($root, [string]$name) {
        if ($root -isnot [Windows.DependencyObject]) { return }
        if ($root -is [Windows.FrameworkElement] -and $root.Name -eq $name) { return $root }
        foreach ($child in [Windows.LogicalTreeHelper]::GetChildren($root)) {
            $found = Find-PackageDialogControl $child $name
            if ($found) { return $found }
        }
    }
    function New-DialogResult([string]$name, [string]$status) {
        [pscustomobject]@{
            Name = $name; Status = $status; StatusText = 'Do not trust this label'
            Reason = "真实原因：$name"; Manager = 'Winget'; PackageId = "Example.$name"
            ExitCode = 0; ExitCodeHex = '0x00000000'; NeedsReboot = $false
            OutputPath = "C:\测试日志\$name.stdout.log"; ErrorPath = "C:\测试日志\$name.stderr.log"
        }
    }
}

Describe 'Selectable package results in a real WPF window' {
    BeforeEach {
        $script:sync = @{ form = $null }
        $script:dialog = $null
    }
    AfterEach {
        if ($script:dialog) { $script:dialog.Close() }
    }
    It 'keeps the original review dialog when Results is omitted' {
        $script:dialog = Show-WinUtilPackageDialog -Title '确认' -Details '旧确认详情' -CreateOnly
        $dialog.Content.Children[2].GetType().Name | Should -Be TextBox
        $dialog.Content.Children[2].Text | Should -Be '旧确认详情'
        $dialog.Tag | Should -Be Close
    }
    It 'orders failures first without mutating results and selects the first failure' {
        $inputRows = @((New-DialogResult '成功项' 'Succeeded'), (New-DialogResult '失败一' 'Failed'), (New-DialogResult '跳过项' 'Skipped'), (New-DialogResult '失败二' 'Failed'), (New-DialogResult '重启项' 'RebootRequired'))
        $script:dialog = Show-WinUtilPackageDialog -Results $inputRows -CreateOnly
        $list = Find-PackageDialogControl $dialog PackageResultsList
        ($list.Items | ForEach-Object { $_.Tag.Status }) -join ',' | Should -Be 'Failed,Failed,RebootRequired,Skipped,Succeeded'
        $list.SelectedIndex | Should -Be 0
        (Find-PackageDialogControl $dialog PackageResultDetails).Text | Should -Match '真实原因：失败一'
        (Find-PackageDialogControl $dialog PackageResultDetails).Text | Should -Match '状态：失败'
        $inputRows[0].Name | Should -Be '成功项'
        $inputRows[1].StatusText | Should -Be 'Do not trust this label'
    }
    It 'updates selectable details when selection changes, including zero exit code and both logs' {
        $failed = New-DialogResult '失败项' 'Failed'; $failed.ExitCode = 123; $failed.ExitCodeHex = '0x0000007B'
        $success = New-DialogResult '成功项' 'Succeeded'
        $script:dialog = Show-WinUtilPackageDialog -Results @($failed, $success) -CreateOnly
        $list = Find-PackageDialogControl $dialog PackageResultsList
        $details = Find-PackageDialogControl $dialog PackageResultDetails
        $details.Text | Should -Match '退出码：123 / 0x0000007B'
        $list.SelectedIndex = 1
        $details.Text | Should -Match '软件：成功项'
        $details.Text | Should -Match '包管理器：Winget'
        $details.Text | Should -Match '包 ID：Example.成功项'
        $details.Text | Should -Match '退出码：0 / 0x00000000'
        $details.Text | Should -Match '输出日志：C:\\测试日志\\成功项.stdout.log'
        $details.Text | Should -Match '错误日志：C:\\测试日志\\成功项.stderr.log'
        $details.IsReadOnly | Should -BeTrue
        $details.Focusable | Should -BeTrue
    }
    It 'filters only confirmed successes while keeping failures, reboot, skipped and unknown rows' {
        $rows = @('Succeeded', 'Failed', 'Skipped', 'RebootRequired', 'Unexpected') | ForEach-Object { New-DialogResult $_ $_ }
        $script:dialog = Show-WinUtilPackageDialog -Results $rows -CreateOnly
        $list = Find-PackageDialogControl $dialog PackageResultsList
        $filter = Find-PackageDialogControl $dialog PackageResultsFilter
        $list.SelectedIndex = 1
        $selected = $list.SelectedItem
        $filter.IsChecked = $true
        $list.Items.Count | Should -Be 4
        @($list.Items | Where-Object { $_.Tag.Status -eq 'Succeeded' }).Count | Should -Be 0
        $list.SelectedItem | Should -Be $selected
        (Find-PackageDialogControl $dialog PackageResultsCount).Text | Should -Match '显示 4 / 5 项'
        $filter.IsChecked = $false
        $list.Items.Count | Should -Be 5
    }
    It 'picks a visible result when a selected success is filtered out' {
        $script:dialog = Show-WinUtilPackageDialog -Results @((New-DialogResult '成功' 'Succeeded'), (New-DialogResult '失败' 'Failed')) -CreateOnly
        $list = Find-PackageDialogControl $dialog PackageResultsList
        $list.SelectedIndex = 1
        (Find-PackageDialogControl $dialog PackageResultsFilter).IsChecked = $true
        $list.SelectedItem.Tag.Status | Should -Be Failed
        (Find-PackageDialogControl $dialog PackageResultDetails).Text | Should -Match '软件：失败'
    }
    It 'distinguishes no results from a filter with no unsuccessful items' {
        $script:dialog = Show-WinUtilPackageDialog -Results @() -CreateOnly
        (Find-PackageDialogControl $dialog PackageResultDetails).Text | Should -Match '无法确认是否完成'
        (Find-PackageDialogControl $dialog PackageResultCopy).IsEnabled | Should -BeFalse
        $dialog.Close()
        $script:dialog = Show-WinUtilPackageDialog -Results @((New-DialogResult '成功' 'Succeeded')) -CreateOnly
        (Find-PackageDialogControl $dialog PackageResultsFilter).IsChecked = $true
        (Find-PackageDialogControl $dialog PackageResultDetails).Text | Should -Match '所有软件均已报告成功'
        (Find-PackageDialogControl $dialog PackageResultCopy).IsEnabled | Should -BeFalse
        (Find-PackageDialogControl $dialog PackageResultsFilter).IsChecked = $false
        (Find-PackageDialogControl $dialog PackageResultCopy).IsEnabled | Should -BeTrue
    }
    It 'does not turn absent fields or unknown status into success' {
        $script:dialog = Show-WinUtilPackageDialog -Results @([pscustomobject]@{Name = '未知软件'}) -CreateOnly
        $text = (Find-PackageDialogControl $dialog PackageResultDetails).Text
        $text | Should -Match '状态：结果未知'
        $text | Should -Match '退出码：未取得'
        $text | Should -Match '未提供详细原因'
        $text | Should -Match '没有可用的日志路径'
        $text | Should -Match '操作：未提供'
    }
    It 'shows the actual selected action including uninstall rather than implying installation' {
        $rows = @('Install', 'Uninstall', 'UpgradeAll') | ForEach-Object {
            $row = New-DialogResult $_ 'Succeeded'
            $row | Add-Member -NotePropertyName Action -NotePropertyValue $_
            $row
        }
        $script:dialog = Show-WinUtilPackageDialog -Results $rows -CreateOnly
        $list = Find-PackageDialogControl $dialog PackageResultsList
        $details = Find-PackageDialogControl $dialog PackageResultDetails
        $details.Text | Should -Match '操作：安装/升级'
        $list.SelectedIndex = 1
        $details.Text | Should -Match '操作：卸载'
        $details.Text | Should -Not -Match '操作：安装'
        $list.SelectedIndex = 2
        $details.Text | Should -Match '操作：更新全部'
    }
    It 'preserves the existing Primary return contract for failed-only retries' {
        $script:dialog = Show-WinUtilPackageDialog -Results @((New-DialogResult '失败' 'Failed')) -PrimaryLabel '仅重试失败项' -CreateOnly
        $button = @($dialog.Content.Children[1].Children | Where-Object Content -eq '仅重试失败项')[0]
        $button.Focusable | Should -BeTrue
        $button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        $dialog.Tag | Should -Be Primary
    }
    It 'keeps a failed reboot requirement visible in details' {
        $failed = New-DialogResult '待重启' 'Failed'; $failed.NeedsReboot = $true; $failed.ExitCode = $null
        $script:dialog = Show-WinUtilPackageDialog -Results @($failed) -CreateOnly
        $text = (Find-PackageDialogControl $dialog PackageResultDetails).Text
        $text | Should -Match '状态：失败'
        $text | Should -Match '重启提示：请先保存工作'
        $text | Should -Match '退出码：未取得'
    }
    It 'keeps each result log path when a retry has a different latest log directory' {
        $result = New-DialogResult '早先成功项' 'Succeeded'
        $script:dialog = Show-WinUtilPackageDialog -Results @($result) -LogDirectory 'C:\重试批次日志' -CreateOnly
        $text = (Find-PackageDialogControl $dialog PackageResultDetails).Text
        $text | Should -Match '输出日志：C:\\测试日志\\早先成功项.stdout.log'
        $text | Should -Match '最近一轮日志文件夹：C:\\重试批次日志'
    }
    It 'keeps list and details usable with long Chinese text and a narrow large-font <Theme> theme' -ForEach @(@{Theme='dark';Background='Black';Foreground='White'}, @{Theme='light';Background='White';Foreground='Black'}) {
        $owner = New-Object Windows.Window
        $owner.Resources['MainBackgroundColor'] = [Windows.Media.Brushes]::$Background
        $owner.Resources['MainForegroundColor'] = [Windows.Media.Brushes]::$Foreground
        $owner.Resources['FontSize'] = 22.0
        $script:sync = @{form = $owner}
        try {
            $rows = @(1..12 | ForEach-Object { New-DialogResult ('测试中文长软件名称及便携版安装组件' * 3) 'Failed' })
            $script:dialog = Show-WinUtilPackageDialog -Description '部分软件操作未完成，请逐项查看原因后重试。' -Results $rows -PrimaryLabel '仅重试失败项' -CloseLabel '关闭' -CreateOnly
            $dialog.Content.Measure([Windows.Size]::new(360, 500))
            $dialog.Content.Arrange([Windows.Rect]::new(0, 0, 360, 500))
            $dialog.Content.UpdateLayout()
            $list = Find-PackageDialogControl $dialog PackageResultsList
            $details = Find-PackageDialogControl $dialog PackageResultDetails
            $dialog.FontSize | Should -Be 22
            $details.Foreground.ToString() | Should -Be $owner.Resources['MainForegroundColor'].ToString()
            $details.Background.ToString() | Should -Be $owner.Resources['MainBackgroundColor'].ToString()
            $list.ActualHeight | Should -BeGreaterThan 60
            $details.ActualHeight | Should -BeGreaterThan 40
            $list.ActualWidth | Should -BeLessOrEqual 360
            $details.ActualWidth | Should -BeLessOrEqual 360
            [Windows.Controls.ScrollViewer]::GetHorizontalScrollBarVisibility($list) | Should -Be Disabled
            $selectedItem = $list.SelectedItem
            $selectedBorder = $selectedItem.Template.FindName('SelectionBorder', $selectedItem)
            $selectedBorder.Background.ToString() | Should -Be ([Windows.SystemColors]::HighlightBrush.ToString())
            $selectedItem.Foreground.ToString() | Should -Be ([Windows.SystemColors]::HighlightTextBrush.ToString())
        } finally { $owner.Close() }
    }
}

Describe 'Copy selected result feedback without changing the real clipboard' {
    BeforeAll {
        $script:previousClipboardFunction = Get-Item Function:\global:Set-Clipboard -ErrorAction SilentlyContinue
        function global:Set-Clipboard {
            param([string]$Value, $ErrorAction)
            if ($global:PackageDialogClipboardTest.Fail) { throw 'Clipboard busy' }
            $global:PackageDialogClipboardTest.Value = $Value
        }
    }
    BeforeEach {
        $global:PackageDialogClipboardTest = @{Fail = $false; Value = ''}
        $script:sync = @{form = $null}
        $script:dialog = Show-WinUtilPackageDialog -Results @((New-DialogResult '失败项' 'Failed'), (New-DialogResult '成功项' 'Succeeded')) -CreateOnly
    }
    AfterEach { $dialog.Close() }
    AfterAll {
        if ($script:previousClipboardFunction) { Set-Item Function:\global:Set-Clipboard $script:previousClipboardFunction.ScriptBlock }
        else { Remove-Item Function:\global:Set-Clipboard -ErrorAction SilentlyContinue }
        Remove-Variable PackageDialogClipboardTest -Scope Global -ErrorAction SilentlyContinue
    }
    It 'copies only the selected item and clears feedback after another selection' {
        $copy = Find-PackageDialogControl $dialog PackageResultCopy
        $copy.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        $global:PackageDialogClipboardTest.Value | Should -Match '软件：失败项'
        $global:PackageDialogClipboardTest.Value | Should -Not -Match '软件：成功项'
        (Find-PackageDialogControl $dialog PackageResultFeedback).Text | Should -Match '已复制'
        (Find-PackageDialogControl $dialog PackageResultsList).SelectedIndex = 1
        (Find-PackageDialogControl $dialog PackageResultFeedback).Text | Should -BeNullOrEmpty
    }
    It 'shows an actionable failure instead of reporting copy success' {
        $global:PackageDialogClipboardTest.Fail = $true
        $copy = Find-PackageDialogControl $dialog PackageResultCopy
        $copy.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        (Find-PackageDialogControl $dialog PackageResultFeedback).Text | Should -Match '复制失败'
        (Find-PackageDialogControl $dialog PackageResultFeedback).Text | Should -Match 'Ctrl\+A、Ctrl\+C'
        $global:PackageDialogClipboardTest.Value | Should -BeNullOrEmpty
    }
}
