<#
.SYNOPSIS
Generates development reference pages without changing runtime configuration.
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent),
    [switch]$ValidateOnly
)

function Get-DevDocsHash {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Resolve-DevDocsChildPath {
    param([string]$Root, [string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath -match '\\|:|(^|/)\.\.?(/|$)' -or $RelativePath -notmatch '^[A-Za-z0-9_./-]+$') {
        throw "不安全的文档路径：$RelativePath"
    }
    $base = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $resolved = [IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
    if (-not $resolved.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { throw "路径超出文档目录：$RelativePath" }
    # Do not follow a junction/symlink into an unrelated directory.
    $cursor = $resolved
    while ($cursor.Length -ge $base.TrimEnd([IO.Path]::DirectorySeparatorChar).Length) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "文档路径包含链接或重解析点：$cursor" }
        }
        $cursor = Split-Path $cursor -Parent
        if (-not $cursor) { break }
    }
    return $resolved
}

function Get-DevDocsPlan {
    param([string]$Root)
    $routesPath = Join-Path $Root 'tools/devdocs-routes.json'
    $routeData = Get-Content -LiteralPath $routesPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($routeData.schemaVersion -ne 1 -or -not $routeData.routes) { throw '文档映射为空或版本不受支持。' }
    $inputs = @(@{ Path = $routesPath; Hash = Get-DevDocsHash $routesPath })
    $catalogs = @{}
    foreach ($section in @('tweaks', 'features')) {
        $sourceName = if ($section -eq 'tweaks') { 'tweaks.json' } else { 'feature.json' }
        $path = Join-Path $Root "config/$sourceName"
        $data = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if (-not $data -or -not @($data.PSObject.Properties).Count) { throw "源配置为空：$sourceName" }
        $hash = Get-DevDocsHash $path
        $catalogs[$section] = @{ Data = $data; RelativePath = "config/$sourceName"; Hash = $hash }
        $inputs += @{ Path = $path; Hash = $hash }
    }
    $functionFiles = @{}
    Get-ChildItem -LiteralPath (Join-Path $Root 'functions') -File -Recurse -Filter '*.ps1' -ErrorAction Stop | ForEach-Object {
        if ($functionFiles.ContainsKey($_.BaseName)) { throw "函数文件名重复：$($_.BaseName)" }
        $functionFiles[$_.BaseName] = $_.FullName
    }
    $seenItems = @{}
    $seenPaths = @{}
    $pages = @()
    $docsRoot = Resolve-DevDocsChildPath -Root $Root -RelativePath 'docs/content/dev'
    foreach ($route in $routeData.routes) {
        if ($route.source -notin @('tweaks', 'features') -or $route.id -notmatch '^WPF[A-Za-z0-9_]+$') { throw '映射中的配置来源或条目 ID 无效。' }
        $key = "$($route.source)/$($route.id)"
        if ($seenItems.ContainsKey($key)) { throw "重复的条目映射：$key" }
        if ($seenPaths.ContainsKey($route.path)) { throw "重复的文档路径：$($route.path)" }
        if ($route.path -notlike "$($route.source)/*.md" -or [IO.Path]::GetFileName($route.path) -ieq '_index.md') { throw "映射不得覆盖索引或其他栏目：$($route.path)" }
        $target = Resolve-DevDocsChildPath -Root $docsRoot -RelativePath $route.path
        $itemProperty = $catalogs[$route.source].Data.PSObject.Properties[$route.id]
        if (-not $itemProperty -or [string]::IsNullOrWhiteSpace($itemProperty.Value.Content)) { throw "映射没有对应的有效配置：$key" }
        $item = $itemProperty.Value
        $marker = "<!-- winutil-devdocs: $key; schema=1 -->"
        $existingHash = $null
        if (Test-Path -LiteralPath $target) {
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "目标不是文件：$target" }
            $existingHash = Get-DevDocsHash $target
            $existing = Get-Content -LiteralPath $target -Raw -Encoding UTF8 -ErrorAction Stop
            if (-not $existing.Contains($marker) -and $existingHash -ne $route.legacySha256) {
                throw "目标不是本条目拥有的生成页，已保留原文件：$($route.path)"
            }
        }
        foreach ($alias in $route.aliases) {
            if ($alias -notmatch "^/dev/$($route.source)/[A-Za-z0-9_/-]+/$" -or $alias -match '(^|/)\.\.?(/|$)') { throw "无效的旧地址别名：$alias" }
        }
        $handler = $item.function
        if ($route.handler) {
            if ($handler -and $handler -ne $route.handler) { throw "处理函数映射与源配置冲突：$key" }
            $handler = $route.handler
        }
        $handlerPath = $null
        $handlerText = $null
        if ($handler) {
            if (-not $functionFiles.ContainsKey($handler)) { throw "找不到 $key 的处理函数：$handler" }
            $handlerPath = $functionFiles[$handler]
            $handlerText = Get-Content -LiteralPath $handlerPath -Raw -Encoding UTF8 -ErrorAction Stop
            $errors = $null
            $ast = [Management.Automation.Language.Parser]::ParseInput($handlerText, $handlerPath, [ref]$null, [ref]$errors)
            if (@($errors).Count -or -not $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $handler }, $true)) {
                throw "处理函数定义无效：$handlerPath"
            }
            $inputs += @{ Path = $handlerPath; Hash = Get-DevDocsHash $handlerPath }
        } elseif ($item.Type -eq 'Button' -and -not $item.InvokeScript) {
            throw "按钮缺少处理函数或执行脚本：$key"
        }
        $seenItems[$key] = $true; $seenPaths[$route.path] = $true
        $pages += [pscustomobject]@{
            Route = $route; Item = $item; Target = $target; Marker = $marker; ExistingHash = $existingHash
            Source = $catalogs[$route.source]; HandlerPath = $handlerPath; HandlerText = $handlerText
            StagedHash = $null; WriteSucceeded = $false
        }
    }
    foreach ($section in $catalogs.Keys) {
        foreach ($item in $catalogs[$section].Data.PSObject.Properties) {
            if (-not $seenItems.ContainsKey("$section/$($item.Name)")) { throw "源配置缺少文档映射：$section/$($item.Name)" }
        }
    }
    return [pscustomobject]@{ Pages = $pages; Inputs = $inputs; DocsRoot = $docsRoot }
}

function New-DevDocsPage {
    param($Page, [string]$Root)
    $itemJson = [ordered]@{}
    $itemJson[$Page.Route.id] = $Page.Item
    $json = ConvertTo-Json -InputObject $itemJson -Depth 100
    # ConvertFrom-Json verifies the complete snippet, including the closing braces.
    $null = $json | ConvertFrom-Json -ErrorAction Stop
    $title = ConvertTo-Json -InputObject ([string]$Page.Item.Content) -Compress
    $lines = @('---', "title: $title", 'description: "当前源配置生成的开发参考"', 'generated: true')
    if ($Page.Route.aliases) {
        $lines += 'aliases:'
        foreach ($alias in $Page.Route.aliases) { $lines += '  - ' + (ConvertTo-Json -InputObject ([string]$alias) -Compress) }
    }
    $lines += @('---', '', $Page.Marker, '', '> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。', '')
    $lines += ('- 稳定 ID：`' + $Page.Route.id + '`')
    $lines += ('- 当前分类：' + [string]$Page.Item.category)
    $lines += ('- 源配置：`' + $Page.Source.RelativePath + '`')
    $lines += ('- 源配置 SHA-256：`' + $Page.Source.Hash + '`')
    if ($Page.Item.Description) { $lines += @('', [string]$Page.Item.Description) }
    if ($Page.Route.source -eq 'tweaks') {
        $lines += @('', '本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。')
    }
    $lines += @('', '## 配置定义', '', '```json', $json, '```')
    if ($Page.HandlerPath) {
        $relative = $Page.HandlerPath.Substring($Root.TrimEnd('\', '/').Length + 1).Replace('\', '/')
        $lines += @('', '## 入口函数', '', ('来源：`' + $relative + '`。这里只展示入口，其他被调用函数以仓库源码为准。'), '', '```powershell', $Page.HandlerText.TrimEnd(), '```')
    }
    return (($lines -join "`n").Replace("`r`n", "`n") + "`n")
}

function Write-DevDocsStagedPage {
    param([string]$Path, [string]$Content)
    [IO.Directory]::CreateDirectory((Split-Path $Path -Parent)) | Out-Null
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Publish-DevDocsPage {
    param([string]$Source, [string]$Destination, [switch]$NewFile)
    [IO.Directory]::CreateDirectory((Split-Path $Destination -Parent)) | Out-Null
    if ($NewFile) { [IO.File]::Copy($Source, $Destination, $false) }
    else { Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop }
}

function Invoke-DevDocsGenerator {
    [CmdletBinding()]
    param([string]$Root = (Split-Path $PSScriptRoot -Parent), [switch]$ValidateOnly)
    $ErrorActionPreference = 'Stop'
    $Root = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path.TrimEnd('\', '/')
    $plan = Get-DevDocsPlan -Root $Root
    $workspaceParent = Resolve-DevDocsChildPath -Root $Root -RelativePath '.artifacts'
    $workspace = Join-Path $workspaceParent ('devdocs-' + [guid]::NewGuid().ToString('N'))
    $stage = Join-Path $workspace 'pages'
    $backup = Join-Path $workspace 'backup'
    $keepBackup = $false
    $published = @()
    try {
        [IO.Directory]::CreateDirectory($stage) | Out-Null
        foreach ($page in $plan.Pages) {
            $path = Resolve-DevDocsChildPath -Root $stage -RelativePath $page.Route.path
            Write-DevDocsStagedPage -Path $path -Content (New-DevDocsPage -Page $page -Root $Root)
        }
        $stagedFiles = @(Get-ChildItem -LiteralPath $stage -Recurse -File -Filter '*.md')
        if ($stagedFiles.Count -ne $plan.Pages.Count) { throw '暂存页数不完整，未发布任何文档。' }
        foreach ($page in $plan.Pages) {
            $path = Resolve-DevDocsChildPath -Root $stage -RelativePath $page.Route.path
            $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
            if (-not $text.Contains($page.Marker) -or -not $text.Contains('## 配置定义') -or -not $text.Contains($page.Route.id)) { throw "暂存页验证失败：$($page.Route.path)" }
            $page.StagedHash = Get-DevDocsHash $path
        }
        foreach ($sourceInput in $plan.Inputs) {
            if ((Get-DevDocsHash $sourceInput.Path) -ne $sourceInput.Hash) { throw "生成期间源文件发生变化，请重新运行：$($sourceInput.Path)" }
        }
        # Back up and check every destination before writing the first page.
        foreach ($page in $plan.Pages) {
            $exists = Test-Path -LiteralPath $page.Target
            if ($exists -ne [bool]$page.ExistingHash -or ($exists -and (Get-DevDocsHash $page.Target) -ne $page.ExistingHash)) { throw "生成期间文档发生变化，已停止：$($page.Route.path)" }
            if ($exists -and -not $ValidateOnly) {
                $saved = Resolve-DevDocsChildPath -Root $backup -RelativePath $page.Route.path
                [IO.Directory]::CreateDirectory((Split-Path $saved -Parent)) | Out-Null
                Copy-Item -LiteralPath $page.Target -Destination $saved -ErrorAction Stop
            }
        }
        if (-not $ValidateOnly) {
            try {
                foreach ($page in $plan.Pages) {
                    $source = Resolve-DevDocsChildPath -Root $stage -RelativePath $page.Route.path
                    if ($page.ExistingHash -eq $page.StagedHash) { continue }
                    $exists = Test-Path -LiteralPath $page.Target
                    if ($exists -ne [bool]$page.ExistingHash -or ($exists -and (Get-DevDocsHash $page.Target) -ne $page.ExistingHash)) { throw "发布期间文档发生变化，已停止：$($page.Route.path)" }
                    # Include the current target in rollback even if the copy itself fails midway.
                    $published += $page
                    Publish-DevDocsPage -Source $source -Destination $page.Target -NewFile:(-not $page.ExistingHash)
                    $page.WriteSucceeded = $true
                    if ((Get-DevDocsHash $page.Target) -ne $page.StagedHash) { throw "发布后文件校验失败：$($page.Route.path)" }
                }
            } catch {
                $publishError = $_
                foreach ($page in $published) {
                    try {
                        if ($page.ExistingHash) {
                            if ($page.WriteSucceeded -and (Get-DevDocsHash $page.Target) -ne $page.StagedHash) { throw '已发布的页面又被修改，保留当前内容供人工核对。' }
                            Copy-Item -LiteralPath (Join-Path $backup $page.Route.path) -Destination $page.Target -Force -ErrorAction Stop
                        } elseif (Test-Path -LiteralPath $page.Target) {
                            if (-not $page.WriteSucceeded -or (Get-DevDocsHash $page.Target) -ne $page.StagedHash) { throw '新目标的内容或归属无法确认，保留当前文件供人工核对。' }
                            $target = Resolve-DevDocsChildPath -Root $plan.DocsRoot -RelativePath $page.Route.path
                            Remove-Item -LiteralPath $target -Force -ErrorAction Stop
                        }
                    } catch { $keepBackup = $true; Write-Warning "回滚失败，备份保留在 ${backup}：$($_.Exception.Message)" }
                }
                throw $publishError
            }
        }
        [pscustomobject]@{ Pages = $plan.Pages.Count; Changed = $published.Count; ValidatedOnly = [bool]$ValidateOnly }
        Write-Host "开发参考验证完成：$($plan.Pages.Count) 项，更新 $($published.Count) 页。源配置和手写页面未改动。"
    } finally {
        if (-not $keepBackup -and (Test-Path -LiteralPath $workspace)) {
            $absolute = [IO.Path]::GetFullPath($workspace)
            $parent = [IO.Path]::GetFullPath($workspaceParent).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
            if (-not $absolute.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($absolute) -notmatch '^devdocs-[a-f0-9]{32}$') { throw '拒绝清理边界不明的暂存目录。' }
            Remove-Item -LiteralPath $absolute -Recurse -Force -ErrorAction Stop
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-DevDocsGenerator -Root $RepositoryRoot -ValidateOnly:$ValidateOnly
}
