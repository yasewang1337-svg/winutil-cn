BeforeAll {
    $script:root = Split-Path $PSScriptRoot -Parent
    $script:extractor = Join-Path $script:root '汉化/maintenance/extract-functions-i18n.ps1'
    $script:borrowedExtractor = Join-Path $script:root '汉化/maintenance/extract-borrowed.ps1'
    function Write-FixtureText([string]$Path, [string]$Text) {
        [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($true))
    }
    function New-TranslationFixture([string]$Path) {
        $null = New-Item -ItemType Directory -Path (Join-Path $Path 'functions/private'), (Join-Path $Path '汉化') -Force
        Write-FixtureText (Join-Path $Path 'functions/private/example.ps1') 'function Test-Example { "hello"; "keep" }'
        $map = Join-Path $Path '汉化/i18n-functions.json'
        Write-FixtureText $map '[{"file":"functions/private/example.ps1","en":"keep","zh":"保留","kind":"runtime"}]'
        return $map
    }
    function New-TranslationDiff([string]$Path, [string]$Old = 'hello', [string]$New = '你好') {
        $text = @('diff --git a/functions/private/example.ps1 b/functions/private/example.ps1',
            '--- a/functions/private/example.ps1', '+++ b/functions/private/example.ps1', '@@ -1 +1 @@',
            ('-Write-Host "' + $Old + '"'), ('+Write-Host "' + $New + '"')) -join "`n"
        Write-FixtureText $Path $text
    }
    function New-BuildFixture([string]$Path) {
        $null = New-Item -ItemType Directory -Path $Path -Force
        Copy-Item -LiteralPath (Join-Path $script:root '汉化') -Destination $Path -Recurse
        Copy-Item -LiteralPath (Join-Path $script:root 'Compile.ps1') -Destination $Path
        foreach ($dir in @('functions/private','config','scripts','xaml','tools')) { $null = New-Item -ItemType Directory -Path (Join-Path $Path $dir) -Force }
        Write-FixtureText (Join-Path $Path 'functions/private/example.ps1') 'function Test-Example { "hello" }'
        Write-FixtureText (Join-Path $Path 'scripts/start.ps1') '$sync = @{ configs = @{} }'
        Write-FixtureText (Join-Path $Path 'scripts/main.ps1') 'Write-Output "fixture only"'
        Write-FixtureText (Join-Path $Path 'xaml/inputXML.xaml') '<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" />'
        Write-FixtureText (Join-Path $Path 'tools/autounattend.xml') '<unattend />'
        Write-FixtureText (Join-Path $Path 'config/applications.json') '{"example": {"category": "Utilities", "description": "Example application", "content":"Example", "winget":"Example.App", "choco":"na", "link":"https://example.com", "foss":true}}'
        Write-FixtureText (Join-Path $Path 'config/tweaks.json') '{"WPFTweaksExample":{"category":"Essential Tweaks","Content":"Example setting","Description":"Example description"}}'
        Write-FixtureText (Join-Path $Path 'config/feature.json') '{"WPFFeaturesExample":{"category":"Features","Content":"Example feature"}}'
        Write-FixtureText (Join-Path $Path '汉化/i18n-functions.json') '[{"file":"functions/private/example.ps1","en":"hello","zh":"你好","kind":"runtime"}]'
        Write-FixtureText (Join-Path $Path '汉化/i18n-borrowed.json') '{"tweaks":{"WPFTweaksExample":{"Content":"示例设置"}},"feature":{}}'
        Write-FixtureText (Join-Path $Path '汉化/i18n-supplement.json') '{"tweaks":{},"feature":{}}'
        Write-FixtureText (Join-Path $Path '汉化/i18n-apps.json') '{"example":"示例软件介绍"}'
        Write-FixtureText (Join-Path $Path '汉化/extra-apps.json') '{"extra":{"category":"实用工具","description":"额外软件","content":"Extra", "winget":"Extra.App", "choco":"na", "link":"https://example.com", "foss":true}}'
        return (Join-Path $Path '汉化/run-all.ps1')
    }
    function Get-BuildInputHashes([string]$Path) {
        $hashes = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $Path -File -Recurse | Where-Object Name -ne 'winutil.ps1' | Sort-Object FullName) {
            $hashes[$file.FullName.Substring($Path.Length)] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
        return (ConvertTo-Json -InputObject $hashes -Compress)
    }
}

Describe 'Translation extraction preserves existing data' {
    BeforeEach {
        $script:fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:map = New-TranslationFixture $script:fixture
        $script:diff = Join-Path $script:fixture 'translations.diff'
        $script:originalHash = (Get-FileHash $script:map).Hash
    }
    It 'fails on zero changes and keeps the original mapping byte for byte' {
        Write-FixtureText $script:diff ''
        { & $script:extractor -DiffPath $script:diff -RepositoryRoot $script:fixture } | Should -Throw
        (Get-FileHash $script:map).Hash | Should -Be $script:originalHash
    }
    It 'requires an explicit input instead of silently reading the working tree' {
        { & $script:extractor -RepositoryRoot $script:fixture } | Should -Throw
        (Get-FileHash $script:map).Hash | Should -Be $script:originalHash
    }
    It 'supports an explicit Git revision range and preserves output for equal revisions' {
        { & $script:extractor -BaseRef HEAD -TargetRef HEAD -RepositoryRoot $script:root -OutputPath $script:map } | Should -Throw '*未提取到*'
        (Get-FileHash $script:map).Hash | Should -Be $script:originalHash
    }
    It 'merges one changed string without dropping unrelated translations and keeps array JSON on repeat' {
        New-TranslationDiff $script:diff
        & $script:extractor -DiffPath $script:diff -RepositoryRoot $script:fixture
        $entries = Get-Content $script:map -Raw -Encoding UTF8 | ConvertFrom-Json
        $entries.Count | Should -Be 2
        ($entries | Where-Object en -eq 'keep').zh | Should -Be '保留'
        ($entries | Where-Object en -eq 'hello').zh | Should -Be '你好'
        & $script:extractor -DiffPath $script:diff -RepositoryRoot $script:fixture
        $repeated = Get-Content $script:map -Raw -Encoding UTF8 | ConvertFrom-Json
        @($repeated).Count | Should -Be 2
    }
    It 'preserves single-entry array shape when updating an existing key' {
        New-TranslationDiff $script:diff -Old keep -New 新翻译
        & $script:extractor -DiffPath $script:diff -RepositoryRoot $script:fixture
        (Get-Content $script:map -Raw -Encoding UTF8).TrimStart().StartsWith('[') | Should -BeTrue
        @(Get-Content $script:map -Raw -Encoding UTF8 | ConvertFrom-Json).Count | Should -Be 1
    }
    It 'rejects traversal paths before publishing anything' {
        New-TranslationDiff $script:diff
        $text = (Get-Content $script:diff -Raw -Encoding UTF8).Replace('+++ b/functions/private/example.ps1','+++ b/functions/../../outside.ps1')
        Write-FixtureText $script:diff $text
        { & $script:extractor -DiffPath $script:diff -RepositoryRoot $script:fixture } | Should -Throw
        (Get-FileHash $script:map).Hash | Should -Be $script:originalHash
    }
    It 'rejects invalid existing JSON rather than replacing it with a partial table' {
        New-TranslationDiff $script:diff
        Write-FixtureText $script:map '[invalid'
        $hash = (Get-FileHash $script:map).Hash
        { & $script:extractor -DiffPath $script:diff -RepositoryRoot $script:fixture } | Should -Throw
        (Get-FileHash $script:map).Hash | Should -Be $hash
    }
    It 'rejects duplicate JSON fields and conflicting records without replacing the original file' {
        New-TranslationDiff $script:diff
        foreach ($json in @(
            '[{"file":"functions/private/example.ps1","en":"keep","en":"other","zh":"保留","kind":"runtime"}]',
            '[{"file":"functions/private/example.ps1","en":"keep","zh":"甲","kind":"runtime"},{"file":"functions/private/example.ps1","en":"keep","zh":"乙","kind":"runtime"}]'
        )) {
            Write-FixtureText $script:map $json
            $hash = (Get-FileHash $script:map).Hash
            { & $script:extractor -DiffPath $script:diff -RepositoryRoot $script:fixture } | Should -Throw
            (Get-FileHash $script:map).Hash | Should -Be $hash
        }
    }
    It 'rejects unmatched changed blocks instead of pairing unrelated lines' {
        New-TranslationDiff $script:diff
        Add-Content -LiteralPath $script:diff -Value '+Write-Host "另一行"' -Encoding UTF8
        { & $script:extractor -DiffPath $script:diff -RepositoryRoot $script:fixture } | Should -Throw
        (Get-FileHash $script:map).Hash | Should -Be $script:originalHash
    }
    It 'rejects string replacements that alter interpolated variable names' {
        New-TranslationDiff $script:diff -Old 'Hello $name' -New '你好 $other'
        { & $script:extractor -DiffPath $script:diff -RepositoryRoot $script:fixture } | Should -Throw
        (Get-FileHash $script:map).Hash | Should -Be $script:originalHash
    }
    It 'does not publish or leave a temporary file if final validation fails' {
        . (Join-Path $script:root '汉化/maintenance/common.ps1')
        { Write-WinUtilTranslationJson -Path $script:map -Json '[{"candidate":"待校验"}]' -Validate { throw 'simulated final validation failure' } } | Should -Throw
        (Get-FileHash $script:map).Hash | Should -Be $script:originalHash
        @(Get-ChildItem -LiteralPath (Split-Path $script:map -Parent) -Filter '*.tmp').Count | Should -Be 0
    }
}

Describe 'Borrowed translation extraction is an explicit merge' {
    BeforeEach {
        $script:source = Join-Path $TestDrive 'reference.ps1'
        $script:borrowed = Join-Path $TestDrive 'borrowed.json'
        Write-FixtureText $script:borrowed '{"tweaks":{"WPFTweaksOld":{"Content":"保留设置"}},"feature":{"WPFFeaturesOld":{"Content":"保留功能"}}}'
        $script:borrowedHash = (Get-FileHash $script:borrowed).Hash
    }
    It 'fails with no Chinese matches and keeps the original table' {
        Write-FixtureText $script:source '# no config or translations'
        { & $script:borrowedExtractor -SourcePath $script:source -OutputPath $script:borrowed } | Should -Throw
        (Get-FileHash $script:borrowed).Hash | Should -Be $script:borrowedHash
    }
    It 'merges a small Chinese section without dropping old settings or other sections' {
        $content = '$sync.configs.tweaks = @''' + "`n" + '{"WPFTweaksNew":{"Content":"新设置","Description":"English text"}}' + "`n" + '''@'
        Write-FixtureText $script:source $content
        & $script:borrowedExtractor -SourcePath $script:source -OutputPath $script:borrowed
        $value = Get-Content $script:borrowed -Raw -Encoding UTF8 | ConvertFrom-Json
        $value.tweaks.WPFTweaksOld.Content | Should -Be '保留设置'
        $value.tweaks.WPFTweaksNew.Content | Should -Be '新设置'
        $value.feature.WPFFeaturesOld.Content | Should -Be '保留功能'
        $value.tweaks.WPFTweaksNew.PSObject.Properties.Name | Should -Not -Contain 'Description'
    }
    It 'rejects duplicate input keys without publishing a partial extraction' {
        $content = '$sync.configs.tweaks = @''' + "`n" + '{"WPFTweaksNew":{"Content":"甲","Content":"乙"}}' + "`n" + '''@'
        Write-FixtureText $script:source $content
        { & $script:borrowedExtractor -SourcePath $script:source -OutputPath $script:borrowed } | Should -Throw
        (Get-FileHash $script:borrowed).Hash | Should -Be $script:borrowedHash
    }
}

Describe 'Maintenance paths use the active PowerShell filesystem location' {
    It 'merges relative diff and output paths in the selected checkout without touching parent sentinels' {
        $parent = Join-Path $TestDrive 'relative functions parent'
        $child = Join-Path $parent '中文 checkout with spaces'
        $parentMap = New-TranslationFixture $parent
        $childMap = New-TranslationFixture $child
        $parentOutput = Join-Path $parent 'output.json'
        $childOutput = Join-Path $child 'output.json'
        Copy-Item -LiteralPath $parentMap -Destination $parentOutput
        Copy-Item -LiteralPath $childMap -Destination $childOutput
        New-TranslationDiff (Join-Path $parent 'translations.diff') -New '错误的父目录翻译'
        New-TranslationDiff (Join-Path $child 'translations.diff') -New '正确的当前目录翻译'
        $parentHash = (Get-FileHash $parentOutput).Hash
        $processDirectory = [Environment]::CurrentDirectory
        Push-Location -LiteralPath $child
        try {
            # Deliberately make the process cwd and PowerShell cwd different; this is the original failure mode.
            [Environment]::CurrentDirectory = $parent
            & $script:extractor -DiffPath '.\translations.diff' -RepositoryRoot '.' -OutputPath '.\output.json'
            $value = Get-Content -LiteralPath $childOutput -Raw -Encoding UTF8 | ConvertFrom-Json
            @($value).Count | Should -Be 2
            ($value | Where-Object en -eq 'keep').zh | Should -Be '保留'
            ($value | Where-Object en -eq 'hello').zh | Should -Be '正确的当前目录翻译'
            (Get-FileHash $parentOutput).Hash | Should -Be $parentHash
        } finally {
            [Environment]::CurrentDirectory = $processDirectory
            Pop-Location
        }
    }
    It 'merges relative borrowed source and output paths without reading or writing the parent copy' {
        $parent = Join-Path $TestDrive 'relative borrowed parent'
        $child = Join-Path $parent '中文 reference with spaces'
        $null = New-Item -ItemType Directory -Path $child -Force
        $parentOutput = Join-Path $parent 'output.json'
        $childOutput = Join-Path $child 'output.json'
        Write-FixtureText $parentOutput '{"tweaks":{"WPFTweaksOld":{"Content":"父目录哨兵"}},"feature":{}}'
        Write-FixtureText $childOutput '{"tweaks":{"WPFTweaksOld":{"Content":"保留旧翻译"}},"feature":{}}'
        $prefix = '$sync.configs.tweaks = @''' + "`n"
        $suffix = "`n" + '''@'
        Write-FixtureText (Join-Path $parent 'source.ps1') ($prefix + '{"WPFTweaksNew":{"Content":"错误的父目录翻译"}}' + $suffix)
        Write-FixtureText (Join-Path $child 'source.ps1') ($prefix + '{"WPFTweaksNew":{"Content":"正确的当前目录翻译"}}' + $suffix)
        $parentHash = (Get-FileHash $parentOutput).Hash
        $processDirectory = [Environment]::CurrentDirectory
        Push-Location -LiteralPath $child
        try {
            [Environment]::CurrentDirectory = $parent
            & $script:borrowedExtractor -SourcePath '.\source.ps1' -OutputPath '.\output.json'
            $value = Get-Content -LiteralPath $childOutput -Raw -Encoding UTF8 | ConvertFrom-Json
            $value.tweaks.WPFTweaksOld.Content | Should -Be '保留旧翻译'
            $value.tweaks.WPFTweaksNew.Content | Should -Be '正确的当前目录翻译'
            (Get-FileHash $parentOutput).Hash | Should -Be $parentHash
        } finally {
            [Environment]::CurrentDirectory = $processDirectory
            Pop-Location
        }
    }
    It 'rejects non-filesystem input, output and repository providers' {
        $fixture = Join-Path $TestDrive 'provider-check'
        $map = New-TranslationFixture $fixture
        $diff = Join-Path $fixture 'translations.diff'
        New-TranslationDiff $diff
        $hash = (Get-FileHash $map).Hash
        { & $script:extractor -DiffPath 'Env:PATH' -RepositoryRoot $fixture -OutputPath $map } | Should -Throw '*文件系统路径*'
        { & $script:extractor -DiffPath $diff -RepositoryRoot $fixture -OutputPath 'Env:PATH' } | Should -Throw '*文件系统路径*'
        { & $script:extractor -DiffPath $diff -RepositoryRoot 'Env:PATH' -OutputPath $map } | Should -Throw '*文件系统路径*'
        { & $script:borrowedExtractor -SourcePath 'Env:PATH' -OutputPath $map } | Should -Throw '*文件系统路径*'
        (Get-FileHash $map).Hash | Should -Be $hash
    }
}

Describe 'Localized builds stage source edits before publishing output' {
    It 'builds translated output with extra apps without changing any source input bytes' {
        $fixture = Join-Path $TestDrive 'isolated-build'
        $entry = New-BuildFixture $fixture
        $before = Get-BuildInputHashes $fixture
        & $entry -WarningAction SilentlyContinue | Out-Null
        (Get-BuildInputHashes $fixture) | Should -Be $before
        $output = Join-Path $fixture 'winutil.ps1'
        $bytes = [IO.File]::ReadAllBytes($output)
        ($bytes[0..2] -join ',') | Should -Be '239,187,191'
        $text = Get-Content $output -Raw -Encoding UTF8
        $text | Should -Match '你好'
        $text | Should -Match '示例软件介绍'
        $text | Should -Match 'WPFInstallextra'
        $errors = $null
        $null = [Management.Automation.Language.Parser]::ParseInput($text,[ref]$null,[ref]$errors)
        $errors.Count | Should -Be 0
    }
    It 'keeps the last successful output and source hashes after an invalid input failure' {
        $fixture = Join-Path $TestDrive 'invalid-input'
        $entry = New-BuildFixture $fixture
        $output = Join-Path $fixture 'winutil.ps1'
        Write-FixtureText $output '# last successful artifact'
        Write-FixtureText (Join-Path $fixture 'config/tweaks.json') '{invalid'
        $before = Get-BuildInputHashes $fixture
        $outputHash = (Get-FileHash $output).Hash
        { & $entry -WarningAction SilentlyContinue | Out-Null } | Should -Throw
        (Get-BuildInputHashes $fixture) | Should -Be $before
        (Get-FileHash $output).Hash | Should -Be $outputHash
    }
    It 'keeps the last successful output when Compile fails after staging translations' {
        $fixture = Join-Path $TestDrive 'compile-failure'
        $entry = New-BuildFixture $fixture
        $output = Join-Path $fixture 'winutil.ps1'
        Write-FixtureText $output '# last successful artifact'
        Write-FixtureText (Join-Path $fixture 'Compile.ps1') 'throw "simulated compile failure"'
        $before = Get-BuildInputHashes $fixture
        $outputHash = (Get-FileHash $output).Hash
        { & $entry -WarningAction SilentlyContinue | Out-Null } | Should -Throw
        (Get-BuildInputHashes $fixture) | Should -Be $before
        (Get-FileHash $output).Hash | Should -Be $outputHash
    }
}
