BeforeAll {
    $script:bundleRoot = Split-Path $PSScriptRoot -Parent
    foreach ($name in @('Get-WinUtilBundlePlan', 'New-WinUtilBundleDialog', 'Show-WinUtilBundleDialog', 'Update-WinUtilSelections')) {
        . ([scriptblock]::Create((Get-Content (Join-Path $script:bundleRoot "functions/private/$name.ps1") -Raw -Encoding UTF8)))
    }
    . ([scriptblock]::Create((Get-Content (Join-Path $script:bundleRoot 'functions/public/Invoke-WPFBundle.ps1') -Raw -Encoding UTF8)))
    function Reset-WPFCheckBoxes { param($doToggles, $checkboxfilterpattern) }
}

Describe 'Bundle selection plans' {
    BeforeEach {
        $script:catalog = @{
            WPFInstallone = [pscustomobject]@{ content = 'One'; description = 'Editor'; winget = 'Dependency.Shared;Vendor.One' }
            WPFInstalltwo = [pscustomobject]@{ content = 'Two'; description = 'Browser'; winget = 'Vendor.Two' }
        }
        $script:bundle = [pscustomobject]@{
            name = 'Example'; region = 'Test'; desc = 'Choose what you need'
            apps = @('WPFInstallone', 'WPFInstalltwo'); defaultApps = @('WPFInstallone')
            purposes = @{ WPFInstallone = 'Edit documents' }
        }
    }

    It 'selects only conservative recommendations when the installed state is unknown' {
        $plan = @(Get-WinUtilBundlePlan -Bundle $bundle -Applications $catalog)
        @($plan | Where-Object IsSelected).Id | Should -Be 'WPFInstallone'
        $plan[1].IsSelected | Should -BeFalse
        $plan[0].InstallState | Should -Be 'Unknown'
    }

    It 'does not revert legacy bundles without defaults to selecting every candidate' {
        $bundle.PSObject.Properties.Remove('defaultApps')
        @(Get-WinUtilBundlePlan -Bundle $bundle -Applications $catalog | Where-Object IsSelected).Count | Should -Be 0
    }

    It 'preserves an existing choice even if it is not a recommendation' {
        $plan = @(Get-WinUtilBundlePlan -Bundle $bundle -Applications $catalog -SelectedApps WPFInstalltwo)
        $plan[1].AlreadySelected | Should -BeTrue
        $plan[1].IsSelected | Should -BeTrue
    }

    It 'keeps installed apps available for updates without automatically selecting them' {
        $cache = @([pscustomobject]@{ Id = 'Vendor.One'; Version = '1.2' })
        $plan = @(Get-WinUtilBundlePlan -Bundle $bundle -Applications $catalog -InstalledPrograms $cache)
        $plan[0].InstallState | Should -Be 'Installed'
        $plan[0].InstalledVersion | Should -Be '1.2'
        $plan[0].IsAvailable | Should -BeTrue
        $plan[0].IsSelected | Should -BeFalse
        $plan[1].InstallState | Should -Be 'Unknown'
    }

    It 'does not mistake a dependency for the application or carry cache state across calls' {
        $cache = @([pscustomobject]@{ Id = 'Dependency.Shared'; Version = '2.0' })
        $first = @(Get-WinUtilBundlePlan -Bundle $bundle -Applications $catalog -InstalledPrograms $cache)
        $first[0].InstallState | Should -Be 'Unknown'
        $null = Get-WinUtilBundlePlan -Bundle $bundle -Applications $catalog -InstalledPrograms @([pscustomobject]@{ Id = 'Vendor.One' })
        $next = @(Get-WinUtilBundlePlan -Bundle $bundle -Applications $catalog)
        $next[0].InstallState | Should -Be 'Unknown'
        $next[0].IsSelected | Should -BeTrue
    }

    It 'deduplicates candidate IDs and disables unavailable or malformed catalog entries' {
        $bundle.apps = @('WPFInstallone', 'WPFInstallone', 'WPFInstallmissing', 'NotAnApp')
        $bundle.defaultApps = @('WPFInstallmissing', 'NotAnApp')
        $catalog.NotAnApp = @{ content = 'Wrong group' }
        $plan = @(Get-WinUtilBundlePlan -Bundle $bundle -Applications $catalog)
        $plan.Count | Should -Be 3
        @($plan | Where-Object IsSelected).Count | Should -Be 0
        $plan[1].IsAvailable | Should -BeFalse
        $plan[2].IsAvailable | Should -BeFalse
    }

    It 'does not mutate caller-owned selections, recommendations or install cache' {
        $selected = [System.Collections.Generic.List[string]]::new()
        $selected.Add('WPFInstalltwo')
        $cache = @([pscustomobject]@{ Id = 'Vendor.One'; Version = '1.2' })
        $before = @{ Bundle = $bundle; Selected = @($selected); Cache = $cache } | ConvertTo-Json -Depth 10
        $null = Get-WinUtilBundlePlan -Bundle $bundle -Applications $catalog -SelectedApps $selected -InstalledPrograms $cache
        (@{ Bundle = $bundle; Selected = @($selected); Cache = $cache } | ConvertTo-Json -Depth 10) | Should -Be $before
    }
}

Describe 'Bundle confirmation boundary' {
    BeforeEach {
        $script:sync = @{
            configs = @{
                bundles = @{ example = @{ name = 'Example'; apps = @('WPFInstallone', 'WPFInstalltwo'); defaultApps = @('WPFInstallone') } }
                applications = @{
                    WPFInstallone = @{ content = 'One' }
                    WPFInstalltwo = @{ content = 'Two' }
                }
            }
            selectedApps = [System.Collections.Generic.List[string]]::new()
        }
        $script:sync.selectedApps.Add('WPFInstalloutside')
        Mock Reset-WPFCheckBoxes {}
        Mock Write-Host {}
    }

    It 'leaves every selection and checkbox unchanged on cancellation' {
        Mock Show-WinUtilBundleDialog { [pscustomobject]@{ Confirmed = $false; Apps = @('WPFInstallone') } }
        Invoke-WPFBundle -BundleId example
        @($sync.selectedApps).Count | Should -Be 1
        $sync.selectedApps[0] | Should -Be 'WPFInstalloutside'
        Should -Invoke Reset-WPFCheckBoxes -Times 0 -Exactly
    }

    It 'only adds confirmed valid candidates once and preserves selections outside the bundle' {
        Mock Show-WinUtilBundleDialog {
            [pscustomobject]@{ Confirmed = $true; Apps = @('WPFInstalltwo', 'WPFInstalltwo', 'WPFInstallmissing') }
        }
        Invoke-WPFBundle -BundleId example
        @($sync.selectedApps).Count | Should -Be 2
        $sync.selectedApps | Should -Contain 'WPFInstalloutside'
        $sync.selectedApps | Should -Contain 'WPFInstalltwo'
        $sync.selectedApps | Should -Not -Contain 'WPFInstallone'
        Should -Invoke Reset-WPFCheckBoxes -Times 1 -Exactly
    }

    It 'returns no selected apps when a populated dialog is closed without confirming' {
        Mock New-WinUtilBundleDialog {
            $fake = [pscustomobject]@{ Tag = @{ Choices = @([pscustomobject]@{ IsChecked = $true; Tag = 'WPFInstallone' }) } }
            $fake | Add-Member ScriptMethod ShowDialog { return $null }
            $fake
        }
        $result = Show-WinUtilBundleDialog -Bundle $sync.configs.bundles.example -Plan @()
        $result.Confirmed | Should -BeFalse
        $result.Apps.Count | Should -Be 0
    }
}

Describe 'Bundle catalog recommendations' {
    It 'limits defaults and purpose metadata to existing candidates while retaining the apps API' {
        $bundles = Get-Content (Join-Path $bundleRoot 'config/bundles.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($entry in $bundles.PSObject.Properties) {
            if ($entry.Name -eq '_meta') { continue }
            $entry.Value.apps.Count | Should -BeGreaterThan 0
            foreach ($id in $entry.Value.defaultApps) { $entry.Value.apps | Should -Contain $id }
            foreach ($purpose in $entry.Value.purposes.PSObject.Properties) { $entry.Value.apps | Should -Contain $purpose.Name }
        }
    }
}

Describe 'Bundle preview layout' {
    BeforeAll { Add-Type -AssemblyName PresentationFramework }

    It 'keeps a scrollable list and usable footer at small sizes and enlarged text' -TestCases @(
        @{ Width = 720; Height = 530; FontSize = 14 }
        @{ Width = 500; Height = 330; FontSize = 21 }
    ) {
        param($Width, $Height, $FontSize)
        $bundle = @{ name = 'Bundle'; desc = 'Adjust recommendations'; region = 'Test' }
        $plan = @(1..7 | ForEach-Object {
            [pscustomobject]@{
                Id = "WPFInstallapp$_"; Name = "Application $_"; Description = 'A description that wraps on narrower screens.'
                Purpose = 'Optional utility'; IsSelected = $false; IsAvailable = $true; AlreadySelected = $false
                InstallState = 'Unknown'; IsRecommended = $false
            }
        })
        $dialog = New-WinUtilBundleDialog -Bundle $bundle -Plan $plan
        try {
            $dialog.FontSize = $FontSize
            $grid = $dialog.Content
            $size = [Windows.Size]::new($Width, $Height)
            $grid.Measure($size)
            $grid.Arrange([Windows.Rect]::new($size))
            $grid.UpdateLayout()
            $dialog.Tag.Choices.Count | Should -Be 7
            $dialog.Tag.ScrollViewer.ActualHeight | Should -BeGreaterThan 40
            $dialog.Tag.ScrollViewer.ExtentHeight | Should -BeGreaterThan $dialog.Tag.ScrollViewer.ViewportHeight
            $dialog.Tag.Footer.ActualHeight | Should -BeGreaterThan 40
            $dialog.Tag.Footer.ActualHeight | Should -BeLessThan $Height
            $dialog.Tag.ConfirmButton.IsEnabled | Should -BeFalse
            $dialog.Tag.Choices[0].IsChecked = $true
            $dialog.Tag.ConfirmButton.IsEnabled | Should -BeTrue
        } finally { $dialog.Close() }
    }
}
