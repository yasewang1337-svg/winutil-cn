[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../.artifacts/interface-previews'),
    [switch]$IncludeCompact
)

# Render actual WPF controls without starting WinUtil or executing system actions.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$root = Split-Path $PSScriptRoot -Parent
$output = [IO.Path]::GetFullPath($OutputDirectory)
$null = New-Item -ItemType Directory -Path $output -Force
foreach ($file in @(
    'private/Initialize-InstallAppArea.ps1', 'private/Initialize-InstallAppEntry.ps1',
    'private/Initialize-InstallCategoryAppList.ps1', 'private/Initialize-WinUtilAppFilterBar.ps1',
    'private/Initialize-WinUtilSelectedAppsPopup.ps1', 'private/Add-SelectedAppsMenuItem.ps1',
    'private/Find-AppsByNameOrDescription.ps1', 'private/Reset-WinUtilAppFilter.ps1',
    'private/Update-WinUtilAppSelectionUi.ps1', 'public/Invoke-WPFSelectedCheckboxesUpdate.ps1',
    'public/Initialize-WPFUI.ps1', 'public/Invoke-WPFUIElements.ps1', 'public/Invoke-WPFTab.ps1',
    'private/Invoke-WinutilThemeChange.ps1', 'private/Invoke-WinUtilFontScaling.ps1',
    'private/Initialize-WinUtilAppActions.ps1',
    'private/Initialize-WinUtilAppCommandBar.ps1', 'private/Show-WinUtilAppActions.ps1',
    'private/Initialize-WinUtilWindowChrome.ps1', 'private/Set-WinUtilNavigationLayout.ps1',
    'private/Test-WinUtilTitleBarSource.ps1', 'private/Initialize-WinUtilISOControls.ps1'
)) { . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root "functions/$file")))) }

function Set-Preferences { param([switch]$save) }
function Invoke-WPFButton { param($Button) throw 'Preview cannot execute application actions.' }
function Find-TweaksByNameOrDescription { param($SearchString) }
function Start-Process { throw 'Preview cannot start external programs.' }

$catalog = @{}
foreach ($file in @('config/applications.json', '汉化/extra-apps.json')) {
    $apps = [IO.File]::ReadAllText((Join-Path $root $file)) | ConvertFrom-Json
    foreach ($app in $apps.PSObject.Properties) {
        if ($app.Value.Category) { $catalog["WPFInstall$($app.Name)"] = $app.Value }
    }
}
$scenarios = @(@{ Width = 1280; Height = 800; Scale = 1.0; Name = 'desktop' })
if ($IncludeCompact) { $scenarios += @{ Width = 800; Height = 600; Scale = 1.5; Name = 'compact-150' } }
$pages = [ordered]@{ home = 'WPFTab6BT'; software = 'WPFTab1BT'; updates = 'WPFTab4BT'; 'windows-iso' = 'WPFTab5BT'; 'windows10-iso' = 'WPFTab5BT' }
$reports = @()
foreach ($mode in @('Dark', 'Light')) {
    foreach ($scenario in $scenarios) {
        foreach ($page in $pages.Keys) {
            $text = [IO.File]::ReadAllText((Join-Path $root 'xaml/inputXML.xaml'))
            $xml = [xml]($text -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace '^<Win.*', '<Window')
            $reader = [Xml.XmlNodeReader]::new($xml)
            try { $form = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
            $script:sync = @{
                Form = $form; preferences = @{}; selectedApps = [Collections.Generic.List[string]]::new()
                configs = @{ themes = [IO.File]::ReadAllText((Join-Path $root 'config/themes.json')) | ConvertFrom-Json; applicationsHashtable = $catalog }
            }
            foreach ($node in $xml.SelectNodes('//*[@Name]')) { $sync[$node.Name] = $form.FindName($node.Name) }
            try {
                Invoke-WinutilThemeChange -theme $mode
                Initialize-WinUtilWindowChrome
                Invoke-WPFUIElements -configVariable ([IO.File]::ReadAllText((Join-Path $root 'config/appnavigation.json')) | ConvertFrom-Json) -targetGridName appscategory -columncount 1
                Initialize-WPFUI -TargetGridName appscategory
                Initialize-WPFUI -TargetGridName appspanel
                Initialize-WinUtilISOControls
                Invoke-WinUtilFontScaling -ScaleFactor $scenario.Scale
                Invoke-WPFTab $pages[$page]
                Set-WinUtilNavigationLayout -AvailableWidth $scenario.Width
                if ($page -eq 'windows10-iso') { $sync.WPFWindowsISODownloadVersion.SelectedIndex = 1 }
                $surface = $form.Content
                $size = [Windows.Size]::new($scenario.Width, $scenario.Height)
                $surface.Measure($size)
                $surface.Arrange([Windows.Rect]::new($size))
                $surface.UpdateLayout()
                $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new($scenario.Width, $scenario.Height, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
                $bitmap.Render($surface)
                $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
                $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
                $name = "$page-$($mode.ToLowerInvariant())-$($scenario.Name).png"
                $stream = [IO.File]::Create((Join-Path $output $name))
                try { $encoder.Save($stream) } finally { $stream.Dispose() }
                $reports += [ordered]@{ File = $name; Theme = $mode; Width = $scenario.Width; Height = $scenario.Height; Scale = $scenario.Scale; Page = $page; CatalogCount = $catalog.Count }
            } finally { $form.Close() }
        }
    }
}
[ordered]@{ RenderedUtc = [DateTime]::UtcNow.ToString('o'); SystemActionsExecuted = $false; Previews = $reports } |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'preview-manifest.json') -Encoding UTF8
Write-Output "Rendered $($reports.Count) WPF previews to $output. No system actions were executed."
