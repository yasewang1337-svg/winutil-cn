[CmdletBinding()]
param([string]$OutFile = '.artifacts/home-preview.png', [int]$Width = 1100, [int]$Height = 760, [double]$Scale = 1.0, [ValidateSet('Dark','Light')][string]$Theme = 'Dark')

# Render the actual home XAML without showing a window or executing application startup.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$repoRoot = Split-Path $PSScriptRoot -Parent
foreach ($file in @('public/Invoke-WPFTab.ps1','private/Invoke-WinutilThemeChange.ps1','private/Invoke-WinUtilFontScaling.ps1')) {
    . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $repoRoot "functions/$file"))))
}
function Set-Preferences { param([switch]$save) }
$text = [IO.File]::ReadAllText((Join-Path $repoRoot 'xaml/inputXML.xaml'))
$xml = [xml]($text -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace '^<Win.*', '<Window')
$reader = [System.Xml.XmlNodeReader]::new($xml)
try {
    $form = [Windows.Markup.XamlReader]::Load($reader)
    $sync = @{ Form = $form; preferences = @{}; configs = @{ themes = Get-Content (Join-Path $repoRoot 'config/themes.json') -Raw -Encoding UTF8 | ConvertFrom-Json } }
    foreach ($node in $xml.SelectNodes('//*[@Name]')) { $sync[$node.Name] = $form.FindName($node.Name) }
    Invoke-WinutilThemeChange -theme $Theme
    Invoke-WinUtilFontScaling -ScaleFactor $Scale
    Invoke-WPFTab 'WPFTab6BT'
    $brand = [Windows.Controls.TextBlock]::new()
    $brand.Text = 'WinUtil CN'
    $brand.FontSize = 18
    $brand.FontWeight = 'Bold'
    $brand.Foreground = $form.Resources['MainForegroundColor']
    [void]$sync.NavLogoPanel.Children.Add($brand)
    $visual = $form.Content
    $visual.Measure([Windows.Size]::new($Width, $Height))
    $visual.Arrange([Windows.Rect]::new(0, 0, $Width, $Height))
    $visual.UpdateLayout()
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new($Width, $Height, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($visual)
    $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $path = [IO.Path]::GetFullPath($OutFile)
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    $stream = [IO.File]::Create($path)
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
    Write-Output $path
} finally {
    $reader.Close()
    if ($form) { $form.Close() }
}
