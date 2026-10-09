BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    foreach ($file in @('public/Invoke-WPFTab.ps1','private/Invoke-WinutilThemeChange.ps1','private/Invoke-WinUtilFontScaling.ps1','private/Initialize-WinUtilWindowChrome.ps1','private/Set-WinUtilNavigationLayout.ps1','private/Test-WinUtilTitleBarSource.ps1')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:root "functions/$file"))))
    }
    function Set-Preferences { param([switch]$save) }
    function Get-IsoLayoutTextBlocks($Element) {
        if ($Element -is [Windows.Controls.TextBlock]) { $Element }
        for ($index=0; $index -lt [Windows.Media.VisualTreeHelper]::GetChildrenCount($Element); $index++) {
            Get-IsoLayoutTextBlocks ([Windows.Media.VisualTreeHelper]::GetChild($Element,$index))
        }
    }
    function Get-IsoLayoutArrows($Element) {
        if($Element -is [Windows.Shapes.Path]) { $Element }
        for($index=0;$index -lt [Windows.Media.VisualTreeHelper]::GetChildrenCount($Element);$index++) {
            Get-IsoLayoutArrows ([Windows.Media.VisualTreeHelper]::GetChild($Element,$index))
        }
    }
    function Get-IsoNaturalTextSize($Text, $Width) {
        $probe=[Windows.Controls.TextBlock]::new(); $probe.Text=$Text.Text
        $probe.FontFamily=$Text.FontFamily; $probe.FontSize=$Text.FontSize
        $probe.FontWeight=$Text.FontWeight; $probe.FontStyle=$Text.FontStyle
        $probe.TextWrapping=$Text.TextWrapping
        [Windows.Media.TextOptions]::SetTextFormattingMode($probe,[Windows.Media.TextOptions]::GetTextFormattingMode($Text))
        $measureWidth=if($Text.TextWrapping -eq 'NoWrap'){[double]::PositiveInfinity}else{$Width+0.5}
        $probe.Measure([Windows.Size]::new($measureWidth,[double]::PositiveInfinity))
        return $probe.DesiredSize
    }
}
Describe 'Windows image preparation layout without executing image operations' {
    BeforeEach {
        $text=[IO.File]::ReadAllText((Join-Path $script:root 'xaml/inputXML.xaml'))
        $xml=[xml]($text -replace 'mc:Ignorable="d"','' -replace 'x:N','N' -replace '^<Win.*','<Window')
        $reader=[Xml.XmlNodeReader]::new($xml)
        try {$form=[Windows.Markup.XamlReader]::Load($reader)} finally {$reader.Close()}
        $script:sync=@{Form=$form;preferences=@{};configs=@{themes=([IO.File]::ReadAllText((Join-Path $script:root 'config/themes.json'))|ConvertFrom-Json)}}
        foreach ($node in $xml.SelectNodes('//*[@Name]')) {$sync[$node.Name]=$form.FindName($node.Name)}
    }
    AfterEach {$form.Close()}
    It 'keeps <Stage> image controls readable and scrollable at <Width> / <Scale> in <Theme>' -ForEach @(
        foreach($theme in @('Light','Dark')) { foreach($width in @(1280,800)) { foreach($scale in @(1.0,1.5)) { foreach($stage in @('Initial','AllSteps')) {
            @{Theme=$theme;Width=$width;Scale=$scale;Stage=$stage}
        } } } }
    ) {
        Invoke-WinutilThemeChange -theme $Theme
        Initialize-WinUtilWindowChrome
        Invoke-WinUtilFontScaling -ScaleFactor $Scale
        Invoke-WPFTab 'WPFTab5BT'
        Set-WinUtilNavigationLayout -AvailableWidth $Width
        $sync.WPFWindowsISODownloadVersion.SelectedIndex=1
        if($Stage -eq 'AllSteps') {
            foreach($name in @('WPFWin11ISOMountSection','WPFWin11ISOVerifyResultPanel','WPFWin11ISOModifySection','WPFWin11ISOOutputSection','WPFWin11ISOOptionUSB','WPFWin11ISOFileInfo')) {$sync[$name].Visibility='Visible'}
            $sync.WPFWin11ISOPath.Text='C:\ISO\Windows_11_25H2_Chinese_Simplified_x64_consumer_editions.iso'
            $sync.WPFWin11ISOFileInfo.Text='文件大小：6.4 GB'
            $sync.WPFWin11ISOMountDriveLetter.Text='挂载位置：E:\'
            $sync.WPFWin11ISOArchLabel.Text='Windows 11 · x64 · 包含 6 个版本'
            $null=$sync.WPFWin11ISOEditionComboBox.Items.Add('6: Windows 11 Pro for Workstations (x64)')
            $sync.WPFWin11ISOEditionComboBox.SelectedIndex=0
            $null=$sync.WPFWin11ISOUSBDriveComboBox.Items.Add('Disk 3: SanDisk Extreme Pro USB Device · 128 GB · F:')
            $sync.WPFWin11ISOUSBDriveComboBox.SelectedIndex=0
            $sync.WPFWin11ISOStatusLog.Text="[预览] 已读取镜像信息。`n[预览] 所有步骤展开用于布局检查；未执行制作或磁盘操作。"
        }
        $height=if($Width -eq 800){600}else{800}
        $grid=$form.Content
        $grid.Measure([Windows.Size]::new($Width,$height));$grid.Arrange([Windows.Rect]::new(0,0,$Width,$height));$grid.UpdateLayout()
        $scroll=$sync.WPFWindowsISOScrollViewer
        $scroll.HorizontalScrollBarVisibility | Should -Be 'Disabled'
        $scroll.ExtentWidth | Should -BeLessOrEqual ($scroll.ViewportWidth+1)
        $content=$scroll.Content
        foreach($label in @(Get-IsoLayoutTextBlocks $content)) {
            if(-not $label.IsVisible -and $label.ActualHeight -le 0){continue}
            if([string]::IsNullOrWhiteSpace($label.Text)){continue}
            $natural=Get-IsoNaturalTextSize $label $label.ActualWidth
            $label.ActualHeight | Should -BeGreaterOrEqual ($natural.Height-1) -Because $label.Text
            $label.ActualWidth | Should -BeGreaterOrEqual ($natural.Width-1) -Because $label.Text
            $position=$label.TranslatePoint([Windows.Point]::new(0,0),$content)
            ($position.X+$label.ActualWidth) | Should -BeLessOrEqual ($content.ActualWidth+1) -Because $label.Text
        }
        $controls=@('WPFWin11ISODownloadLink','WPFWindowsISODownloadVersion','WPFWin11ISOBrowseButton','WPFWin11ISOCleanResetButton')
        if($Stage -eq 'AllSteps') {$controls+=@('WPFWin11ISOMountButton','WPFWin11ISOEditionComboBox','WPFWin11ISOModifyButton','WPFWin11ISOChooseISOButton','WPFWin11ISOChooseUSBButton','WPFWin11ISOUSBDriveComboBox','WPFWin11ISORefreshUSBButton','WPFWin11ISOWriteUSBButton')}
        foreach($name in $controls) {
            $control=$sync[$name]
            $control.ActualWidth | Should -BeGreaterThan 0
            if($control -is [Windows.Controls.ComboBox]) {
                $control.FontSize | Should -Be ([double]$sync.configs.themes.shared.FontSize*$Scale) -Because "$name should follow the selected text size"
            }
            foreach($label in @(Get-IsoLayoutTextBlocks $control)) {
                if([string]::IsNullOrWhiteSpace($label.Text)){continue}
                if($control -is [Windows.Controls.ComboBox]) {
                    $label.FontSize | Should -Be ([double]$sync.configs.themes.shared.FontSize*$Scale) -Because "$name selection should follow the selected text size"
                    $arrows=@(Get-IsoLayoutArrows $control)
                    $arrows.Count | Should -BeGreaterThan 0 -Because "$name has a separate drop-down affordance"
                    $textRight=$label.TranslatePoint([Windows.Point]::new(0,0),$control).X+$label.ActualWidth
                    foreach($arrow in $arrows) {
                        $arrowLeft=$arrow.TranslatePoint([Windows.Point]::new(0,0),$control).X
                        $textRight | Should -BeLessOrEqual ($arrowLeft-1) -Because "$name text must not run under its arrow"
                    }
                }
                $point=$label.TranslatePoint([Windows.Point]::new(0,0),$control)
                $point.X | Should -BeGreaterOrEqual -1 -Because $name
                $point.Y | Should -BeGreaterOrEqual -1 -Because $name
                ($point.X+$label.ActualWidth) | Should -BeLessOrEqual ($control.ActualWidth+1) -Because $name
                ($point.Y+$label.ActualHeight) | Should -BeLessOrEqual ($control.ActualHeight+1) -Because $name
            }
            $offset=$control.TranslatePoint([Windows.Point]::new(0,0),$content).Y
            $scroll.ScrollToVerticalOffset([math]::Max(0,$offset-8));$grid.UpdateLayout()
            $visible=$control.TranslatePoint([Windows.Point]::new(0,0),$scroll)
            $visible.Y | Should -BeGreaterOrEqual -1 -Because $name
            ($visible.Y+$control.ActualHeight) | Should -BeLessOrEqual ($scroll.ActualHeight+1) -Because $name
        }
    }
    It 'keeps the <Theme> download options readable and native ComboBox accessibility available' -ForEach @(@{Theme='Light'},@{Theme='Dark'}) {
        Invoke-WinutilThemeChange -theme $Theme
        Invoke-WinUtilFontScaling -ScaleFactor 1.5
        Invoke-WPFTab 'WPFTab5BT'
        $grid=$form.Content
        $grid.Measure([Windows.Size]::new(1280,800));$grid.Arrange([Windows.Rect]::new(0,0,1280,800));$grid.UpdateLayout()
        $combo=$sync.WPFWindowsISODownloadVersion
        $combo.Focusable | Should -BeTrue
        $combo.IsTabStop | Should -BeTrue
        $peer=[Windows.Automation.Peers.ComboBoxAutomationPeer]::new($combo)
        $peer.GetPattern([Windows.Automation.Peers.PatternInterface]::Selection) | Should -Not -BeNullOrEmpty
        $peer.GetPattern([Windows.Automation.Peers.PatternInterface]::ExpandCollapse) | Should -Not -BeNullOrEmpty
        $null=$combo.ApplyTemplate()
        $popup=$combo.Template.FindName('PART_Popup',$combo)
        $surface=$popup.Child
        $surface.Measure([Windows.Size]::new(420,400));$surface.Arrange([Windows.Rect]::new(0,0,420,$surface.DesiredSize.Height));$surface.UpdateLayout()
        $surface.Background.Color | Should -Be $form.Resources.ComboBoxBackgroundColor.Color
        foreach($item in $combo.Items) {
            $item.Foreground.Color | Should -Be $form.Resources.MainForegroundColor.Color
            $item.FontSize | Should -Be 21
            $item.ActualHeight | Should -BeGreaterThan 0
        }
    }
}
