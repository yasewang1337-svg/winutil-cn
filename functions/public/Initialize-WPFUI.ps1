function Initialize-WPFUI {
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$TargetGridName
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
            $sync.ItemsControl = Initialize-InstallAppArea -TargetElement $TargetGridName
            Initialize-InstallCategoryAppList -TargetElement $sync.ItemsControl -Apps $sync.configs.applicationsHashtable
            Find-AppsByNameOrDescription -SearchString ''
        }
        default {
            Write-Output "$TargetGridName not yet implemented"
        }
    }
}

