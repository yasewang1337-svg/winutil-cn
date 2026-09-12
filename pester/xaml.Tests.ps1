BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
}

Describe 'Chinese WPF startup layout' {
    It 'loads the runtime XAML without showing a window' {
        $text = Get-Content (Join-Path $script:root 'xaml/inputXML.xaml') -Raw -Encoding UTF8
        $xml = [xml]($text -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace '^<Win.*', '<Window')
        $reader = [System.Xml.XmlNodeReader]::new($xml)
        try {
            $form = [Windows.Markup.XamlReader]::Load($reader)
            $form | Should -BeOfType ([Windows.Window])
            $form.FindName('appspanel') | Should -Not -BeNullOrEmpty
        } finally {
            $reader.Close()
            if ($null -ne $form) { $form.Close() }
        }
    }
}
