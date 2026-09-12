BeforeAll {
    $script:root = Split-Path $PSScriptRoot -Parent
}

Describe 'Portable function translations' {
    It 'uses repository-relative translation paths that exist' {
        $map = Get-Content (Join-Path $script:root '汉化/i18n-functions.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($item in $map) {
            $item.file | Should -Match '^functions/'
            Test-Path -LiteralPath (Join-Path $script:root $item.file) | Should -BeTrue -Because $item.file
        }
    }

    It 'translates from a different checkout and can be run twice without changing output' {
        $fixture = Join-Path $TestDrive 'different-checkout'
        $localization = Join-Path $fixture '汉化'
        $null = New-Item -ItemType Directory -Path $localization -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $fixture 'functions/private') -Force
        $target = Join-Path $fixture 'functions/private/example.ps1'
        [IO.File]::WriteAllText($target, 'function Test-Example { "hello" }', [Text.UTF8Encoding]::new($true))
        $map = @([pscustomobject]@{file='functions/private/example.ps1'; en='hello'; zh='你好'; kind='runtime'})
        ConvertTo-Json -InputObject $map | Set-Content (Join-Path $localization 'i18n-functions.json') -Encoding UTF8
        Copy-Item (Join-Path $script:root '汉化/apply-functions.ps1') $localization
        & (Join-Path $localization 'apply-functions.ps1')
        Get-Content $target -Raw -Encoding UTF8 | Should -Match '你好'
        $hash = (Get-FileHash $target).Hash
        & (Join-Path $localization 'apply-functions.ps1')
        (Get-FileHash $target).Hash | Should -Be $hash
    }
}
