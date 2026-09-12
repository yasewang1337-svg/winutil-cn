BeforeAll {
    $script:repoRoot = Split-Path $PSScriptRoot -Parent
    $script:configs = @{}
    Get-ChildItem (Join-Path $script:repoRoot 'config') -Filter '*.json' -File | ForEach-Object {
        $script:configs[$_.BaseName] = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    # The release build injects this layer; validate the same effective catalog.
    $script:apps = @{}
    foreach ($p in $script:configs.applications.PSObject.Properties) { $script:apps[$p.Name] = $p.Value }
    $extra = Get-Content (Join-Path $script:repoRoot '汉化/extra-apps.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $extra.PSObject.Properties) {
        if ($p.Name -ne '_meta' -and -not $script:apps.ContainsKey($p.Name)) { $script:apps[$p.Name] = $p.Value }
    }
}

Describe 'Release configuration consistency' {
    It 'loads every configuration as valid JSON' {
        $script:configs.Count | Should -BeGreaterThan 0
        foreach ($name in $script:configs.Keys) { $script:configs[$name] | Should -Not -BeNullOrEmpty -Because $name }
    }

    It 'requires display metadata and at least one installable package id for every app' {
        foreach ($name in $script:apps.Keys) {
            $app = $script:apps[$name]
            foreach ($field in @('content', 'category', 'description', 'link')) {
                $app.$field | Should -Not -BeNullOrEmpty -Because "$name.$field"
            }
            [bool]($app.winget -or $app.choco) | Should -BeTrue -Because $name
        }
    }

    It 'keeps every bundle app resolvable in the compiled catalog' {
        foreach ($bundle in $script:configs.bundles.PSObject.Properties) {
            if ($bundle.Name -eq '_meta') { continue }
            foreach ($id in $bundle.Value.apps) {
                $id | Should -Match '^WPFInstall'
                $script:apps.ContainsKey(($id -replace '^WPFInstall', '')) | Should -BeTrue -Because "$($bundle.Name): $id"
            }
        }
    }

    It 'keeps preset references resolvable' {
        foreach ($preset in $script:configs.preset.PSObject.Properties) {
            foreach ($id in $preset.Value) {
                $script:configs.tweaks.PSObject.Properties.Name | Should -Contain $id -Because $preset.Name
            }
        }
    }

    It 'provides rollback metadata for registry and service tweaks, allowing zero or false values' {
        foreach ($tweak in $script:configs.tweaks.PSObject.Properties) {
            foreach ($entry in $tweak.Value.registry) {
                $entry.PSObject.Properties.Name | Should -Contain 'OriginalValue' -Because $tweak.Name
            }
            foreach ($entry in $tweak.Value.service) {
                $entry.PSObject.Properties.Name | Should -Contain 'OriginalType' -Because $tweak.Name
            }
        }
    }
}
