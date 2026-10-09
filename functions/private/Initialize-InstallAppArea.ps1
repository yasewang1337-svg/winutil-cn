    function Initialize-InstallAppArea {
        <#
            .SYNOPSIS
                Creates a [Windows.Controls.ScrollViewer] containing a [Windows.Controls.ItemsControl] which is setup to use Virtualization to only load the visible elements for performance reasons.
                This is used as the parent object for all category and app entries on the install tab
                Used to as part of the Install Tab UI generation

                Also creates an overlay with a progress bar and text to indicate that an install or uninstall is in progress

            .PARAMETER TargetElement
                The element to which the AppArea should be added

        #>
        param($TargetElement)
        $targetGrid = $sync.Form.FindName($TargetElement)
        $null = $targetGrid.Children.Clear()

        $targetGrid.RowDefinitions.Clear()
        $toolbarRow = [Windows.Controls.RowDefinition]::new()
        $toolbarRow.Height = 'Auto'
        $null = $targetGrid.RowDefinitions.Add($toolbarRow)
        $null = $targetGrid.RowDefinitions.Add([Windows.Controls.RowDefinition]::new())
        $toolbar = Initialize-WinUtilAppFilterBar
        $null = $targetGrid.Children.Add($toolbar)
        $appContentGrid = [Windows.Controls.Grid]::new()
        [Windows.Controls.Grid]::SetRow($appContentGrid, 1)
        $null = $targetGrid.Children.Add($appContentGrid)

        # Create the outer Border for the aren where the apps will be placed
        $Border = New-Object Windows.Controls.Border
        $Border.VerticalAlignment = "Stretch"
        $Border.SetResourceReference([Windows.Controls.Control]::StyleProperty, "BorderStyle")
        $sync.InstallAppAreaBorder = $Border

        # Add a ScrollViewer, because the ItemsControl does not support scrolling by itself
        $scrollViewer = New-Object Windows.Controls.ScrollViewer
        $scrollViewer.VerticalScrollBarVisibility = 'Auto'
        $scrollViewer.HorizontalAlignment = 'Stretch'
        $scrollViewer.VerticalAlignment = 'Stretch'
        $scrollViewer.CanContentScroll = $true
        $sync.InstallAppAreaScrollViewer = $scrollViewer
        $Border.Child = $scrollViewer

        # Initialize the Blur Effect for the ScrollViewer, which will be used to indicate that an install/uninstall is in progress
        $blurEffect = New-Object Windows.Media.Effects.BlurEffect
        $blurEffect.Radius = 0
        $scrollViewer.Effect = $blurEffect

        ## Create the ItemsControl, which will be the parent of all the app entries
        $itemsControl = New-Object Windows.Controls.ItemsControl
        $itemsControl.HorizontalAlignment = 'Stretch'
        $itemsControl.VerticalAlignment = 'Stretch'
        $scrollViewer.Content = $itemsControl

        # Use WrapPanel to create dynamic columns based on AppEntryWidth and window width
        $itemsPanelTemplate = New-Object Windows.Controls.ItemsPanelTemplate
        $factory = New-Object Windows.FrameworkElementFactory ([Windows.Controls.WrapPanel])
        $factory.SetValue([Windows.Controls.WrapPanel]::OrientationProperty, [Windows.Controls.Orientation]::Horizontal)
        $factory.SetValue([Windows.Controls.WrapPanel]::HorizontalAlignmentProperty, [Windows.HorizontalAlignment]::Left)
        $itemsPanelTemplate.VisualTree = $factory
        $itemsControl.ItemsPanel = $itemsPanelTemplate

        # Add the Border containing the App Area to the target Grid
        $appContentGrid.Children.Add($Border) | Out-Null

        $empty = [Windows.Controls.Border]::new()
        $empty.Padding = '24'
        $empty.Visibility = 'Collapsed'
        $empty.HorizontalAlignment = 'Stretch'
        $empty.VerticalAlignment = 'Center'
        $emptyText = [Windows.Controls.TextBlock]::new()
        $emptyText.TextWrapping = 'Wrap'
        $emptyText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'MainForegroundColor')
        $emptyText.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'FontFamily')
        $emptyText.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'ButtonFontSize')
        $empty.Child = $emptyText
        $sync.InstallFilterEmpty = $empty
        $sync.InstallFilterEmptyText = $emptyText
        $null = $appContentGrid.Children.Add($empty)

        $overlay = New-Object Windows.Controls.Border
        $overlay.CornerRadius = New-Object Windows.CornerRadius(10)
        $overlay.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, "AppInstallOverlayBackgroundColor")
        $overlay.Visibility = [Windows.Visibility]::Collapsed

        # Also add the overlay to the target Grid on top of the App Area
        $appContentGrid.Children.Add($overlay) | Out-Null
        $sync.InstallAppAreaOverlay = $overlay

        $overlayText = New-Object Windows.Controls.TextBlock
        $overlayText.Text = "Installing apps..."
        $overlayText.HorizontalAlignment = 'Center'
        $overlayText.VerticalAlignment = 'Center'
        $overlayText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, "MainForegroundColor")
        $overlayText.Background = "Transparent"
        $overlayText.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, "HeaderFontSize")
        $overlayText.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, "FontFamily")
        $overlayText.SetResourceReference([Windows.Controls.TextBlock]::FontWeightProperty, "MainFontWeight")
        $overlayText.SetResourceReference([Windows.Controls.TextBlock]::MarginProperty, "MainMargin")
        $sync.InstallAppAreaOverlayText = $overlayText

        $progressbar = New-Object Windows.Controls.ProgressBar
        $progressbar.Name = "ProgressBar"
        $progressbar.Width = 250
        $progressbar.Height = 50
        $sync.ProgressBar = $progressbar

        # Add a TextBlock overlay for the progress bar text
        $progressBarTextBlock = New-Object Windows.Controls.TextBlock
        $progressBarTextBlock.Name = "progressBarTextBlock"
        $progressBarTextBlock.FontWeight = [Windows.FontWeights]::Bold
        $progressBarTextBlock.FontSize = 16
        $progressBarTextBlock.Width = $progressbar.Width
        $progressBarTextBlock.Height = $progressbar.Height
        $progressBarTextBlock.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, "ProgressBarTextColor")
        $progressBarTextBlock.TextTrimming = "CharacterEllipsis"
        $progressBarTextBlock.Background = "Transparent"
        $sync.progressBarTextBlock = $progressBarTextBlock

        # Create a Grid to overlay the text on the progress bar
        $progressGrid = New-Object Windows.Controls.Grid
        $progressGrid.Width = $progressbar.Width
        $progressGrid.Height = $progressbar.Height
        $progressGrid.Margin = "0,10,0,10"
        $progressGrid.Children.Add($progressbar) | Out-Null
        $progressGrid.Children.Add($progressBarTextBlock) | Out-Null

        $overlayStackPanel = New-Object Windows.Controls.StackPanel
        $overlayStackPanel.Orientation = "Vertical"
        $overlayStackPanel.HorizontalAlignment = 'Center'
        $overlayStackPanel.VerticalAlignment = 'Center'
        $overlayStackPanel.Children.Add($overlayText) | Out-Null
        $overlayStackPanel.Children.Add($progressGrid) | Out-Null

        $overlay.Child = $overlayStackPanel

        return $itemsControl
    }
