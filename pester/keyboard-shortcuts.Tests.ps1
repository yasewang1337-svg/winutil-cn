BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    foreach ($file in @('private/Invoke-WinUtilKeyboardShortcut.ps1', 'public/Invoke-WPFTab.ps1')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root "functions/$file"))))
    }
    function Invoke-WPFButton { param($Button) }
    function Find-AppsByNameOrDescription { param($SearchString) }
    function Find-TweaksByNameOrDescription { param($SearchString) }
    function New-TestShortcut($Key, $Modifiers = 'None', $Source = $null, $SystemKey = 'None') {
        [pscustomobject]@{
            Key = [Windows.Input.Key]$Key; SystemKey = [Windows.Input.Key]$SystemKey
            KeyboardDevice = [pscustomobject]@{ Modifiers = [Enum]::Parse([Windows.Input.ModifierKeys], $Modifiers) }
            OriginalSource = $Source; Handled = $false
        }
    }
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'scripts/main.ps1'), [ref]$tokens, [ref]$errors)
    $script:keyHandlerAssignment = $ast.Find({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left.Extent.Text -eq '$commonKeyEvents'
    }, $true).Extent.Text
}

Describe 'Search and navigation keyboard shortcuts' {
    BeforeEach {
        $text = [IO.File]::ReadAllText((Join-Path $root 'xaml/inputXML.xaml'))
        $xml = [xml]($text -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace '^<Win.*', '<Window')
        $reader = [Xml.XmlNodeReader]::new($xml)
        try { $script:form = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
        $script:sync = @{ Form = $form; currentTab = 'WPFTab1'; selectedApps = @('SelectedApp'); ProcessRunning = $false }
        foreach ($node in $xml.SelectNodes('//*[@Name]')) { $sync[$node.Name] = $form.FindName($node.Name) }
        $sync.InstallSelectedOnly = [Windows.Controls.CheckBox]::new()
        $sync.InstallSelectedOnly.IsChecked = $true
        $sync.InstallInstalledOnly = [Windows.Controls.CheckBox]::new()
        $sync.InstallInstalledOnly.IsChecked = $true
        $sync.SearchBar.Text = 'existing query'
        $sync.SearchBar.Select(3, 2)
        Mock Invoke-WPFButton {}
        Mock Find-AppsByNameOrDescription {}
        Mock Find-TweaksByNameOrDescription {}
    }
    AfterEach { $form.Close() }

    It 'selects the existing query on the current searchable page <Tab>' -ForEach @(
        @{ Tab = 'WPFTab1' }, @{ Tab = 'WPFTab2' }
    ) {
        $sync.currentTab = $Tab
        $event = New-TestShortcut F Control
        Invoke-WinUtilKeyboardShortcut $event
        $sync.currentTab | Should -Be $Tab
        $sync.SearchBar.SelectedText | Should -Be 'existing query'
        $event.Handled | Should -BeTrue
        $sync.selectedApps | Should -Be 'SelectedApp'
        $sync.InstallSelectedOnly.IsChecked | Should -BeTrue
        Should -Invoke Invoke-WPFButton -Times 0 -Exactly
        Should -Invoke Find-AppsByNameOrDescription -Times 0 -Exactly
    }

    It 'opens software search from non-searchable page <Tab> using actual navigation' -ForEach @(
        @{ Tab = 'WPFTab3' }, @{ Tab = 'WPFTab4' }, @{ Tab = 'WPFTab5' }, @{ Tab = 'WPFTab6' }
    ) {
        Invoke-WPFTab ($Tab + 'BT')
        $sync.SearchBar.Visibility | Should -Be 'Collapsed'
        $event = New-TestShortcut F Control
        Invoke-WinUtilKeyboardShortcut $event
        $sync.currentTab | Should -Be 'WPFTab1'
        $sync.WPFTab1.IsSelected | Should -BeTrue
        $sync.SearchBar.Visibility | Should -Be 'Visible'
        $sync.WPFSearchRow.Visibility | Should -Be 'Visible'
        $event.Handled | Should -BeTrue
        $sync.selectedApps | Should -Be 'SelectedApp'
        $sync.InstallSelectedOnly.IsChecked | Should -BeTrue
        $sync.InstallInstalledOnly.IsChecked | Should -BeTrue
        Should -Invoke Find-AppsByNameOrDescription -Times 1 -Exactly
        Should -Invoke Invoke-WPFButton -Times 0 -Exactly
    }

    It 'keeps disabled navigation disabled instead of consuming an unavailable search shortcut' {
        Invoke-WPFTab WPFTab6BT
        $sync.WPFTab1BT.IsEnabled = $false
        $event = New-TestShortcut F Control
        Invoke-WinUtilKeyboardShortcut $event
        $sync.currentTab | Should -Be 'WPFTab6'
        $sync.SearchBar.Visibility | Should -Be 'Collapsed'
        $event.Handled | Should -BeFalse
    }

    It 'clears only the search text with Escape through the production routed handler' {
        . ([scriptblock]::Create($keyHandlerAssignment))
        $form.Add_PreviewKeyDown($commonKeyEvents)
        $parameters = [Windows.Interop.HwndSourceParameters]::new('WinUtil isolated search shortcut test')
        $parameters.WindowStyle = 0
        $source = [Windows.Interop.HwndSource]::new($parameters)
        try {
            $event = [Windows.Input.KeyEventArgs]::new([Windows.Input.Keyboard]::PrimaryDevice, $source, 0, [Windows.Input.Key]::Escape)
            $event.RoutedEvent = [Windows.UIElement]::PreviewKeyDownEvent
            $sync.SearchBar.RaiseEvent($event)
            $sync.SearchBar.Text | Should -Be ''
            $event.Handled | Should -BeTrue
        } finally { $source.Dispose() }
        $sync.InstallSelectedOnly.IsChecked | Should -BeTrue
        $sync.InstallInstalledOnly.IsChecked | Should -BeTrue
        $sync.selectedApps | Should -Be 'SelectedApp'
    }

    It 'leaves Escape in other controls and modified Escape untouched' {
        foreach ($event in @(
            (New-TestShortcut Escape None $sync.WPFPageTitle),
            (New-TestShortcut Escape Control $sync.SearchBar),
            (New-TestShortcut Escape Shift $sync.SearchBar)
        )) {
            Invoke-WinUtilKeyboardShortcut $event
            $sync.SearchBar.Text | Should -Be 'existing query'
            $event.Handled | Should -BeFalse
        }
    }

    It 'preserves the existing Alt navigation <SystemKey>' -ForEach @(
        @{ SystemKey='I'; Target='WPFTab1BT' }, @{ SystemKey='T'; Target='WPFTab2BT' },
        @{ SystemKey='C'; Target='WPFTab3BT' }, @{ SystemKey='U'; Target='WPFTab4BT' },
        @{ SystemKey='W'; Target='WPFTab5BT' }
    ) {
        $event = New-TestShortcut System Alt $sync.SearchBar $SystemKey
        Invoke-WinUtilKeyboardShortcut $event
        $event.Handled | Should -BeTrue
        Should -Invoke Invoke-WPFButton -Times 1 -Exactly -ParameterFilter { $Button -eq $Target }
    }

    It 'allows Ctrl Q to use the existing window closing guard' {
        $script:closeRequested = $false
        $closing = [ComponentModel.CancelEventHandler]{ param($sender, $eventArgs) $script:closeRequested = $true; $eventArgs.Cancel = $true }
        $form.Add_Closing($closing)
        try {
            $event = New-TestShortcut Q Control
            Invoke-WinUtilKeyboardShortcut $event
            $closeRequested | Should -BeTrue
            $event.Handled | Should -BeTrue
        } finally { $form.Remove_Closing($closing) }
    }

    It 'keeps all shortcuts inert while a task is running or an event was already handled' {
        foreach ($mode in @('Busy', 'Handled')) {
            foreach ($event in @(
                (New-TestShortcut F Control), (New-TestShortcut Escape None $sync.SearchBar),
                (New-TestShortcut System Alt $sync.SearchBar I)
            )) {
                $sync.ProcessRunning = $mode -eq 'Busy'
                $event.Handled = $mode -eq 'Handled'
                Invoke-WinUtilKeyboardShortcut $event
                $sync.SearchBar.SelectedText | Should -Be 'st'
                $sync.SearchBar.Text | Should -Be 'existing query'
                $sync.currentTab | Should -Be 'WPFTab1'
            }
        }
        Should -Invoke Invoke-WPFButton -Times 0 -Exactly
    }
}
