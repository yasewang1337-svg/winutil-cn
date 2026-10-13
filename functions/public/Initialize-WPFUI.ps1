function Initialize-WPFUI {
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$TargetGridName,
        [switch]$DeferCatalogue,
        [switch]$ReuseContainer
    )

    switch ($TargetGridName) {
        "appscategory"{
            # TODO
            # Switch UI generation of the sidebar to this function
            # $sync.ItemsControl = Initialize-InstallAppArea -TargetElement $TargetGridName
            # ...

            Initialize-WinUtilSelectedAppsPopup

            Initialize-WinUtilAppActions
            if ($sync.WPFInstall) {
                $sync.WPFInstall.SetResourceReference([Windows.Controls.Control]::StyleProperty, 'PrimaryButtonStyle')
            }
        }
        "appspanel" {
            if (-not $ReuseContainer -or -not $sync.ItemsControl) {
                $sync.ItemsControl = Initialize-InstallAppArea -TargetElement $TargetGridName
            }
            # Progress controls are shared by maintenance/ISO callbacks. Keep
            # their lightweight container available before any page is opened.
            if ($DeferCatalogue) { return }
            $sync.ItemsControl.Items.Clear()
            Initialize-InstallCategoryAppList -TargetElement $sync.ItemsControl -Apps $sync.configs.applicationsHashtable
            Update-WinUtilAppSelectionUi
        }
        default {
            Write-Output "$TargetGridName not yet implemented"
        }
    }
}

