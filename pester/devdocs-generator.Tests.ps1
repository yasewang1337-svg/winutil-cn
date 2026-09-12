BeforeAll {
    $script:repoRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $script:repoRoot 'tools/devdocs-generator.ps1')
    $script:originalStageWriter = (Get-Command Write-DevDocsStagedPage).ScriptBlock
    $script:originalPublisher = (Get-Command Publish-DevDocsPage).ScriptBlock

    function Write-FixtureJson {
        param($Value, [string]$Path)
        [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 30), [Text.UTF8Encoding]::new($true))
    }
    function New-DevDocsFixture {
        param([string]$Root)
        foreach ($directory in @('config','tools','functions/nested','docs/content/dev/tweaks/Old-English','docs/content/dev/features/Old-English')) {
            [IO.Directory]::CreateDirectory((Join-Path $Root $directory)) | Out-Null
        }
        Write-FixtureJson -Path (Join-Path $Root 'config/tweaks.json') -Value ([ordered]@{ WPFTweaksExample = [ordered]@{ Content='中文设置'; Description='只生成参考，不执行系统操作。'; category='任意中文分类'; link='https://example.invalid/keep-source-link'; registry=@(@{Path='HKCU:\Software\Example';Name='Value';Type='DWord';Value=1;OriginalValue=0}) } })
        Write-FixtureJson -Path (Join-Path $Root 'config/feature.json') -Value ([ordered]@{ WPFFeatureExample = [ordered]@{Content='中文功能';category='功能';Type='Button';function='Invoke-Example';link='https://example.invalid/keep-feature-link'} })
        [IO.File]::WriteAllText((Join-Path $Root 'functions/nested/Invoke-Example.ps1'), "function Invoke-Example { '这是参考代码，不能执行' }", [Text.UTF8Encoding]::new($true))
        $routes = @()
        foreach ($section in @('tweaks','features')) {
            $path = "$section/Old-English/Example.md"
            $destination = Join-Path $Root "docs/content/dev/$path"
            [IO.File]::WriteAllText($destination, "---`ntitle: Legacy $section`n---`nOld generated reference", [Text.UTF8Encoding]::new($true))
            $id = if ($section -eq 'tweaks') { 'WPFTweaksExample' } else { 'WPFFeatureExample' }
            $routes += [ordered]@{source=$section;id=$id;path=$path;legacySha256=(Get-DevDocsHash $destination)}
            [IO.File]::WriteAllText((Join-Path $Root "docs/content/dev/$section/Old-English/_index.md"), "手写索引 $section", [Text.UTF8Encoding]::new($true))
            [IO.File]::WriteAllText((Join-Path $Root "docs/content/dev/$section/Old-English/notes.md"), "未登记的手写页面 $section", [Text.UTF8Encoding]::new($true))
        }
        Write-FixtureJson -Path (Join-Path $Root 'tools/devdocs-routes.json') -Value ([ordered]@{schemaVersion=1;routes=$routes})
    }
    function Get-FixtureDocHashes {
        param([string]$Root)
        $files = Get-ChildItem (Join-Path $Root 'docs/content/dev') -File -Recurse | Sort-Object FullName
        return (($files | ForEach-Object { $_.FullName.Substring($Root.Length) + ':' + (Get-DevDocsHash $_.FullName) }) -join "`n")
    }
}

Describe 'Development reference generation preserves source and authored pages' {
    BeforeEach {
        $script:fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-DevDocsFixture $script:fixture
        $script:beforeDocs = Get-FixtureDocHashes $script:fixture
        $script:routesFile = Join-Path $script:fixture 'tools/devdocs-routes.json'
    }

    It 'generates all Chinese categories on stable routes and does not change source links' {
        $tweakSource = Join-Path $script:fixture 'config/tweaks.json'
        $featureSource = Join-Path $script:fixture 'config/feature.json'
        $hashes = @((Get-DevDocsHash $tweakSource), (Get-DevDocsHash $featureSource))
        $result = Invoke-DevDocsGenerator -Root $script:fixture
        $result.Pages | Should -Be 2
        $result.Changed | Should -Be 2
        (Get-DevDocsHash $tweakSource) | Should -Be $hashes[0]
        (Get-DevDocsHash $featureSource) | Should -Be $hashes[1]
        Get-Content (Join-Path $script:fixture 'docs/content/dev/tweaks/Old-English/Example.md') -Raw -Encoding UTF8 | Should -Match '中文设置'
        $featurePage = Get-Content (Join-Path $script:fixture 'docs/content/dev/features/Old-English/Example.md') -Raw -Encoding UTF8
        $featurePage | Should -Match 'functions/nested/Invoke-Example.ps1'
        $featurePage | Should -Match '这是参考代码，不能执行'
        Get-Content (Join-Path $script:fixture 'docs/content/dev/tweaks/Old-English/_index.md') -Raw -Encoding UTF8 | Should -Be '手写索引 tweaks'
        Get-Content (Join-Path $script:fixture 'docs/content/dev/features/Old-English/notes.md') -Raw -Encoding UTF8 | Should -Be '未登记的手写页面 features'
    }

    It 'is idempotent when sources have not changed' {
        Invoke-DevDocsGenerator -Root $script:fixture | Out-Null
        $generated = Get-FixtureDocHashes $script:fixture
        (Invoke-DevDocsGenerator -Root $script:fixture).Changed | Should -Be 0
        Get-FixtureDocHashes $script:fixture | Should -Be $generated
    }

    It 'validates without publishing or modifying existing pages' {
        $result = Invoke-DevDocsGenerator -Root $script:fixture -ValidateOnly
        $result.ValidatedOnly | Should -BeTrue
        $result.Changed | Should -Be 0
        Get-FixtureDocHashes $script:fixture | Should -Be $script:beforeDocs
    }

    It 'requires a mapping for every source item instead of silently skipping a category' {
        $routes = Get-Content $script:routesFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $routes.routes = @($routes.routes[0])
        Write-FixtureJson $routes $script:routesFile
        { Invoke-DevDocsGenerator -Root $script:fixture } | Should -Throw '*缺少文档映射*'
        Get-FixtureDocHashes $script:fixture | Should -Be $script:beforeDocs
    }

    It 'rejects duplicate output paths before generating anything' {
        $routes = Get-Content $script:routesFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $routes.routes[1].path = $routes.routes[0].path
        Write-FixtureJson $routes $script:routesFile
        { Invoke-DevDocsGenerator -Root $script:fixture } | Should -Throw '*重复的文档路径*'
        Get-FixtureDocHashes $script:fixture | Should -Be $script:beforeDocs
    }

    It 'rejects traversal and index ownership claims before touching files' {
        $routes = Get-Content $script:routesFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $routes.routes[0].path = 'tweaks/../../outside.md'
        Write-FixtureJson $routes $script:routesFile
        { Invoke-DevDocsGenerator -Root $script:fixture } | Should -Throw '*不安全的文档路径*'
        $routes.routes[0].path = 'tweaks/Old-English/_index.md'
        Write-FixtureJson $routes $script:routesFile
        { Invoke-DevDocsGenerator -Root $script:fixture } | Should -Throw '*不得覆盖索引*'
        Get-FixtureDocHashes $script:fixture | Should -Be $script:beforeDocs
    }

    It 'does not overwrite an unrecognized hand-written page at a mapped target' {
        $target = Join-Path $script:fixture 'docs/content/dev/tweaks/Old-English/Example.md'
        [IO.File]::WriteAllText($target, '后来增加的手写页面', [Text.UTF8Encoding]::new($true))
        $before = Get-FixtureDocHashes $script:fixture
        { Invoke-DevDocsGenerator -Root $script:fixture } | Should -Throw '*不是本条目拥有的生成页*'
        Get-FixtureDocHashes $script:fixture | Should -Be $before
    }

    It 'preserves every existing page if a handler is missing' {
        Remove-Item -LiteralPath (Join-Path $script:fixture 'functions/nested/Invoke-Example.ps1')
        { Invoke-DevDocsGenerator -Root $script:fixture } | Should -Throw '*找不到*处理函数*'
        Get-FixtureDocHashes $script:fixture | Should -Be $script:beforeDocs
    }

    It 'preserves every existing page when source JSON is invalid' {
        [IO.File]::WriteAllText((Join-Path $script:fixture 'config/tweaks.json'), '{ invalid JSON')
        { Invoke-DevDocsGenerator -Root $script:fixture } | Should -Throw
        Get-FixtureDocHashes $script:fixture | Should -Be $script:beforeDocs
    }

    It 'does not publish a partial set after generation fails' {
        Mock Write-DevDocsStagedPage {
            param($Path,$Content)
            if ($Path -match 'features') { throw '模拟写入失败' }
            & $script:originalStageWriter -Path $Path -Content $Content
        }
        { Invoke-DevDocsGenerator -Root $script:fixture } | Should -Throw '*模拟写入失败*'
        Get-FixtureDocHashes $script:fixture | Should -Be $script:beforeDocs
    }

    It 'rejects incomplete rendered content before publication' {
        Mock New-DevDocsPage { 'incomplete page' }
        { Invoke-DevDocsGenerator -Root $script:fixture } | Should -Throw '*暂存页验证失败*'
        Get-FixtureDocHashes $script:fixture | Should -Be $script:beforeDocs
    }

    It 'detects concurrent source edits before publication' {
        Mock Write-DevDocsStagedPage {
            param($Path,$Content)
            & $script:originalStageWriter -Path $Path -Content $Content
            [IO.File]::AppendAllText((Join-Path $script:fixture 'config/tweaks.json'), ' ')
        }
        { Invoke-DevDocsGenerator -Root $script:fixture } | Should -Throw '*源文件发生变化*'
        Get-FixtureDocHashes $script:fixture | Should -Be $script:beforeDocs
    }

    It 'restores already published files if a later publication fails' {
        Mock Publish-DevDocsPage {
            param($Source,$Destination,$NewFile)
            if ($Destination -match 'features') { throw '模拟发布失败' }
            & $script:originalPublisher -Source $Source -Destination $Destination -NewFile:$NewFile
        }
        { Invoke-DevDocsGenerator -Root $script:fixture } | Should -Throw '*模拟发布失败*'
        Get-FixtureDocHashes $script:fixture | Should -Be $script:beforeDocs
    }

    It 'removes only its own newly published page when rolling back a later failure' {
        $newPage = Join-Path $script:fixture 'docs/content/dev/tweaks/Old-English/Example.md'
        Remove-Item -LiteralPath $newPage
        $before = Get-FixtureDocHashes $script:fixture
        Mock Publish-DevDocsPage {
            param($Source,$Destination,$NewFile)
            if ($Destination -match 'features') { throw '模拟发布失败' }
            & $script:originalPublisher -Source $Source -Destination $Destination -NewFile:$NewFile
        }
        { Invoke-DevDocsGenerator -Root $script:fixture } | Should -Throw '*模拟发布失败*'
        Test-Path -LiteralPath $newPage | Should -BeFalse
        Get-FixtureDocHashes $script:fixture | Should -Be $before
    }

    It 'covers the full current repository catalog in an isolated copy and preserves every old route' {
        $isolated = Join-Path $TestDrive 'full-current-catalog'
        foreach ($directory in @('config','tools','docs/content/dev')) { [IO.Directory]::CreateDirectory((Join-Path $isolated $directory)) | Out-Null }
        Copy-Item -LiteralPath (Join-Path $script:repoRoot 'config/tweaks.json'),(Join-Path $script:repoRoot 'config/feature.json') -Destination (Join-Path $isolated 'config')
        Copy-Item -LiteralPath (Join-Path $script:repoRoot 'tools/devdocs-routes.json') -Destination (Join-Path $isolated 'tools')
        Copy-Item -LiteralPath (Join-Path $script:repoRoot 'functions') -Destination $isolated -Recurse
        Copy-Item -LiteralPath (Join-Path $script:repoRoot 'docs/content/dev/tweaks'),(Join-Path $script:repoRoot 'docs/content/dev/features') -Destination (Join-Path $isolated 'docs/content/dev') -Recurse
        $existingPaths = @(Get-ChildItem (Join-Path $isolated 'docs/content/dev') -Recurse -File | ForEach-Object FullName)
        $routes = Get-Content (Join-Path $isolated 'tools/devdocs-routes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $hashes = @((Get-DevDocsHash (Join-Path $isolated 'config/tweaks.json')), (Get-DevDocsHash (Join-Path $isolated 'config/feature.json')))
        (Invoke-DevDocsGenerator -Root $isolated).Pages | Should -Be @($routes.routes).Count
        foreach ($path in $existingPaths) { Test-Path -LiteralPath $path | Should -BeTrue -Because $path }
        (Get-DevDocsHash (Join-Path $isolated 'config/tweaks.json')) | Should -Be $hashes[0]
        (Get-DevDocsHash (Join-Path $isolated 'config/feature.json')) | Should -Be $hashes[1]
        foreach ($route in $routes.routes) {
            $page = Get-Content (Join-Path $isolated ('docs/content/dev/' + $route.path)) -Raw -Encoding UTF8
            $page | Should -Match ([regex]::Escape("winutil-devdocs: $($route.source)/$($route.id)"))
        }
    }
}
