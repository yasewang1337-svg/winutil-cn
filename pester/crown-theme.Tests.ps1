BeforeAll {
    $script:crownThemes = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../config/themes.json')) | ConvertFrom-Json

    function Get-CrownThemeContrastRatio {
        param([string]$Foreground, [string]$Background)
        $luminance = foreach ($hex in @($Foreground, $Background)) {
            $linear = foreach ($offset in @(1, 3, 5)) {
                $channel = [Convert]::ToInt32($hex.Substring($offset, 2), 16) / 255.0
                if ($channel -le 0.04045) { $channel / 12.92 }
                else { [math]::Pow(($channel + 0.055) / 1.055, 2.4) }
            }
            $linear[0] * 0.2126 + $linear[1] * 0.7152 + $linear[2] * 0.0722
        }
        ([math]::Max($luminance[0], $luminance[1]) + 0.05) / ([math]::Min($luminance[0], $luminance[1]) + 0.05)
    }
}

Describe 'Crown palette accessibility contracts' {
    It 'provides the same resources when switching either theme' {
        $lightKeys = @($crownThemes.Light.PSObject.Properties.Name | Sort-Object)
        $darkKeys = @($crownThemes.Dark.PSObject.Properties.Name | Sort-Object)
        ($lightKeys -join ',') | Should -Be ($darkKeys -join ',')
        foreach ($key in @('BrandSurfaceColor', 'BrandBorderColor', 'SidebarBackgroundColor', 'TitleBarBackgroundColor', 'ControlBorderColor')) {
            $lightKeys | Should -Contain $key
        }
    }

    It 'uses parseable color values for every <Theme> brush' -ForEach @(@{Theme='Dark'}, @{Theme='Light'}) {
        foreach ($property in $crownThemes.$Theme.PSObject.Properties | Where-Object { $_.Name -like '*Color' }) {
            $property.Value | Should -Match '^(#[0-9A-Fa-f]{6}|Transparent)$' -Because "$Theme $($property.Name) is loaded as a WPF brush"
        }
    }

    It 'keeps normal and secondary text readable on all <Theme> content and control states' -ForEach @(@{Theme='Dark'}, @{Theme='Light'}) {
        $palette = $crownThemes.$Theme
        foreach ($background in @(
            'MainBackgroundColor', 'PanelBackgroundColor', 'SidebarBackgroundColor', 'TitleBarBackgroundColor',
            'BrandSurfaceColor', 'AppInstallHighlightedColor', 'AppInstallSelectedColor',
            'ButtonBackgroundColor', 'ButtonBackgroundMouseoverColor', 'ButtonBackgroundPressedColor', 'ToolTipBackgroundColor'
        )) {
            foreach ($foreground in @('MainForegroundColor', 'SecondaryForegroundColor')) {
                (Get-CrownThemeContrastRatio $palette.$foreground $palette.$background) | Should -BeGreaterOrEqual 4.5 -Because "$Theme $foreground on $background must remain readable"
            }
        }
    }

    It 'keeps links and semantic text readable on <Theme> list and brand surfaces' -ForEach @(@{Theme='Dark'}, @{Theme='Light'}) {
        $palette = $crownThemes.$Theme
        foreach ($background in @('MainBackgroundColor', 'PanelBackgroundColor', 'BrandSurfaceColor', 'AppInstallHighlightedColor', 'AppInstallSelectedColor')) {
            foreach ($foreground in @('AccentColor', 'LinkForegroundColor', 'LinkHoverForegroundColor', 'FOSSHighlightColor', 'DangerForegroundColor')) {
                (Get-CrownThemeContrastRatio $palette.$foreground $palette.$background) | Should -BeGreaterOrEqual 4.5 -Because "$Theme $foreground on $background must remain readable"
            }
        }
    }

    It 'keeps primary action text readable through all <Theme> pointer states' -ForEach @(@{Theme='Dark'}, @{Theme='Light'}) {
        $palette = $crownThemes.$Theme
        foreach ($background in @('ButtonPrimaryColor', 'ButtonPrimaryHoverColor', 'ButtonPrimaryPressedColor')) {
            (Get-CrownThemeContrastRatio $palette.PrimaryButtonForegroundColor $palette.$background) | Should -BeGreaterOrEqual 4.5 -Because "$Theme primary text remains visible when hovering or pressing"
        }
        (Get-CrownThemeContrastRatio $palette.ProgressBarTextColor $palette.ProgressBarForegroundColor) | Should -BeGreaterOrEqual 4.5
    }

    It 'keeps essential control edges distinguishable from <Theme> control surfaces' -ForEach @(@{Theme='Dark'}, @{Theme='Light'}) {
        $palette = $crownThemes.$Theme
        foreach ($background in @(
            'MainBackgroundColor', 'PanelBackgroundColor', 'SidebarBackgroundColor', 'ComboBoxBackgroundColor',
            'AppInstallHighlightedColor', 'AppInstallSelectedColor', 'ButtonBackgroundColor',
            'ButtonBackgroundMouseoverColor', 'ButtonBackgroundPressedColor'
        )) {
            (Get-CrownThemeContrastRatio $palette.ControlBorderColor $palette.$background) | Should -BeGreaterOrEqual 3.0 -Because "$Theme $background needs a visible control boundary, independent of subtle decorative separators"
        }
    }

    It 'keeps focus and checked indicators distinguishable on <Theme> surfaces' -ForEach @(@{Theme='Dark'}, @{Theme='Light'}) {
        $palette = $crownThemes.$Theme
        foreach ($background in @('MainBackgroundColor', 'PanelBackgroundColor', 'SidebarBackgroundColor', 'AppInstallSelectedColor', 'ButtonBackgroundMouseoverColor', 'ButtonBackgroundPressedColor')) {
            foreach ($foreground in @('AccentColor', 'CheckboxMouseOverColor', 'ToggleButtonOnColor', 'ToggleButtonOffColor')) {
                (Get-CrownThemeContrastRatio $palette.$foreground $palette.$background) | Should -BeGreaterOrEqual 3.0 -Because "$Theme $foreground must identify focus or state on $background"
            }
        }
    }
}
